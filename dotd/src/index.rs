// The index: every file under the watched folders, what extractors found in
// it, and search over both, by words and by meaning.
//
//   file event → mime → blake3 → known hash? → reuse, update the path
//                                 └ new → extractors by mime, cheap tier
//                                         first, then medium
//                                         → derived/<blake3>.json
//                                         → FTS5 (name, folder, text)
//                                         → e5 vectors of that text
//   heavy tier (heavy.rs, own thread, AC + idle + cool CPU only)
//                                         → MobileCLIP vectors of images
//                                           and video frames
//                                         → Florence-2 caption, objects,
//                                           text → FTS5, e5 again
//
// What is learned lives by content hash in ~/.local/share/dotd/derived/,
// never next to the file, so a moved or renamed file costs one hash and no
// extraction. index.db (same folder) holds the files, FTS5 and the vectors
// (sqlite-vec). Work goes newest file first. The worker thread does the
// walk and the cheap and medium tiers, the heavy thread its own tier; each
// writes through its own connection, and queries read through a third (WAL).
//
// ~/.config/dotd/index.toml says what is watched:
//   roots = ["~"]                     walked recursively; dotfolders skipped
//   exclude = ["~/Documents/git"]     folders left out
//   exclude_names = ["node_modules"]  folder names left out anywhere
//   [heavy]                           when the heavy tier may run
// and a folder holding a .noindex file is left out with all below it.

use crate::extract::{self, Extractor};
use crate::heavy::{self, HeavyConfig};
use crate::ml;
use crate::paths;
use anyhow::{Context, Result};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::collections::HashMap;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, UNIX_EPOCH};

#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    #[serde(default = "home_root")]
    pub roots: Vec<String>,
    #[serde(default)]
    pub exclude: Vec<String>,
    #[serde(default)]
    pub exclude_names: Vec<String>,
    // Characters of text kept per extractor.
    #[serde(default = "max_text")]
    pub max_text: usize,
    // Hours between full rescans (inotify catches the rest).
    #[serde(default = "rescan_hours")]
    pub rescan_hours: u64,
    #[serde(default)]
    pub heavy: HeavyConfig,
}

fn home_root() -> Vec<String> {
    vec!["~".into()]
}
fn max_text() -> usize {
    1_000_000
}
fn rescan_hours() -> u64 {
    6
}

impl Default for Config {
    fn default() -> Self {
        toml::from_str("").unwrap()
    }
}

pub struct Filter {
    roots: Vec<PathBuf>,
    exclude: Vec<PathBuf>,
    names: Vec<String>,
}

impl Filter {
    pub fn new(c: &Config) -> Filter {
        Filter {
            roots: c.roots.iter().map(|r| paths::expand(r)).collect(),
            exclude: c.exclude.iter().map(|r| paths::expand(r)).collect(),
            names: c.exclude_names.clone(),
        }
    }

    // A folder the walk does not go into.
    pub fn skip_dir(&self, dir: &Path) -> bool {
        let name = dir.file_name().map(|n| n.to_string_lossy()).unwrap_or_default();
        name.starts_with('.')
            || self.names.iter().any(|n| *n == name)
            || self.exclude.iter().any(|x| dir.starts_with(x))
            || dir.join(".noindex").exists()
    }

    // A path an inotify event names: under a root, and no folder on the way
    // is skipped.
    pub fn wants(&self, path: &Path) -> bool {
        let Some(root) = self.roots.iter().find(|r| path.starts_with(r)) else { return false };
        if path.file_name().is_some_and(|n| n.to_string_lossy().starts_with('.')) {
            return false;
        }
        let mut dir = path.parent();
        while let Some(d) = dir {
            if d == root.as_path() || !d.starts_with(root) {
                break;
            }
            if self.skip_dir(d) {
                return false;
            }
            dir = d.parent();
        }
        true
    }
}

pub enum Msg {
    // A file appeared or changed; a folder appeared (walked).
    Touch(PathBuf),
    // A file or folder went away.
    Gone(PathBuf),
    Rescan,
    Reload,
    // New work elsewhere (the heavy tier wrote text for e5): look again.
    Nudge,
}

#[derive(Clone)]
pub struct Index {
    tx: Sender<Msg>,
    reader: Arc<Mutex<Option<Connection>>>,
    ml: Arc<ml::Shared>,
    pub gate: Arc<heavy::Gate>,
    heavy: Arc<Mutex<heavy::Status>>,
}

// What a query is narrowed to: a mime prefix ("image/") and folders ("~/Music").
#[derive(Debug, Default, Clone, Deserialize)]
pub struct Want {
    #[serde(default)]
    pub mime: String,
    #[serde(default)]
    pub dir: Vec<String>,
}

impl Want {
    pub fn is_empty(&self) -> bool {
        self.mime.is_empty() && self.dir.is_empty()
    }

    fn admits(&self, path: &str, mime: &str) -> bool {
        (self.mime.is_empty() || mime.starts_with(&self.mime))
            && (self.dir.is_empty()
                || self.dir.iter().any(|d| path.starts_with(&format!("{}/", paths::expand(d).to_string_lossy().trim_end_matches('/')))))
    }
}

#[derive(Debug, Serialize)]
pub struct Hit {
    pub path: String,
    pub name: String,
    pub dir: String,
    pub mime: String,
    pub mtime: i64,
    pub snippet: String,
    // What Florence-2 saw, for images found by what they show.
    #[serde(skip_serializing_if = "String::is_empty")]
    pub caption: String,
    pub score: f64,
    #[serde(skip)]
    pub hash: String,
}

pub fn db_path() -> PathBuf {
    paths::data_dir().join("index.db")
}

pub fn derived_path(hash: &str) -> PathBuf {
    paths::data_dir().join("derived").join(format!("{hash}.json"))
}

// sqlite-vec in every connection opened from here on.
fn with_vec() {
    static VEC: std::sync::Once = std::sync::Once::new();
    VEC.call_once(|| unsafe {
        #[allow(clippy::missing_transmute_annotations)]
        rusqlite::ffi::sqlite3_auto_extension(Some(std::mem::transmute(sqlite_vec::sqlite3_vec_init as *const ())));
    });
}

pub fn open(path: &Path) -> Result<Connection> {
    with_vec();
    std::fs::create_dir_all(path.parent().unwrap())?;
    let c = Connection::open(path).with_context(|| format!("{}", path.display()))?;
    c.busy_timeout(Duration::from_secs(5))?;
    schema(&c)?;
    Ok(c)
}

fn schema(c: &Connection) -> Result<()> {
    c.execute_batch(&format!(
        "PRAGMA journal_mode = WAL;
         PRAGMA synchronous = NORMAL;
         CREATE TABLE IF NOT EXISTS files (
             id INTEGER PRIMARY KEY,
             path TEXT NOT NULL UNIQUE,
             name TEXT NOT NULL,
             ext TEXT NOT NULL,
             mime TEXT NOT NULL,
             size INTEGER NOT NULL,
             mtime INTEGER NOT NULL,
             hash TEXT,
             seen INTEGER NOT NULL DEFAULT 0
         );
         CREATE INDEX IF NOT EXISTS files_hash ON files(hash);
         CREATE INDEX IF NOT EXISTS files_mtime ON files(mtime);
         CREATE TABLE IF NOT EXISTS runs (
             hash TEXT NOT NULL,
             extractor TEXT NOT NULL,
             version INTEGER NOT NULL,
             ok INTEGER NOT NULL,
             at INTEGER NOT NULL,
             PRIMARY KEY (hash, extractor)
         );
         CREATE VIRTUAL TABLE IF NOT EXISTS fts USING fts5(
             name, dir, body, tokenize = 'unicode61 remove_diacritics 2'
         );
         -- One row per vector; its id is the rowid in vec_text or vec_image.
         -- part: the text chunk, or the video frame.
         CREATE TABLE IF NOT EXISTS vecs (
             id INTEGER PRIMARY KEY,
             hash TEXT NOT NULL,
             kind TEXT NOT NULL,
             part INTEGER NOT NULL
         );
         CREATE INDEX IF NOT EXISTS vecs_hash ON vecs(hash, kind);
         CREATE VIRTUAL TABLE IF NOT EXISTS vec_text USING vec0(embedding float[{}] distance_metric=cosine);
         CREATE VIRTUAL TABLE IF NOT EXISTS vec_image USING vec0(embedding float[{}] distance_metric=cosine);",
        ml::E5_DIM,
        ml::CLIP_DIM
    ))?;
    Ok(())
}

pub fn load_config() -> Config {
    let p = paths::config_dir().join("index.toml");
    match std::fs::read_to_string(&p) {
        Ok(t) => toml::from_str(&t).unwrap_or_else(|e| {
            eprintln!("dotd: {}: {e}", p.display());
            Config::default()
        }),
        Err(_) => Config::default(),
    }
}

impl Index {
    pub fn spawn() -> Result<Index> {
        let db = db_path();
        let writer = open(&db)?;
        let reader = open(&db)?;
        let heavy_db = open(&db)?;
        let (tx, rx) = mpsc::channel();
        let cfg = load_config();
        let ml = Arc::new(ml::Shared::new());
        let gate = Arc::new(heavy::Gate::default());
        let status = Arc::new(Mutex::new(heavy::Status::default()));
        {
            let tx = tx.clone();
            let cfg = cfg.clone();
            std::thread::Builder::new().name("dotd-watch".into()).spawn(move || {
                if let Err(e) = crate::watch::run(&cfg, tx) {
                    eprintln!("dotd: watch: {e:#}");
                }
            })?;
        }
        {
            let ml = ml.clone();
            std::thread::Builder::new().name("dotd-index".into()).spawn(move || {
                let mut w = Worker::new(writer, cfg, ml);
                w.run(rx);
            })?;
        }
        {
            let (gate, status, tx) = (gate.clone(), status.clone(), tx.clone());
            std::thread::Builder::new().name("dotd-heavy".into()).spawn(move || heavy::run(heavy_db, gate, status, tx))?;
        }
        // The query models load now, so the first search is not the slow one.
        {
            let ml = ml.clone();
            std::thread::Builder::new().name("dotd-load".into()).spawn(move || {
                let _ = ml.clip_text("");
                let _ = ml.e5(&["query: ".into()]);
            })?;
        }
        Ok(Index { tx, reader: Arc::new(Mutex::new(Some(reader))), ml, gate, heavy: status })
    }

    pub fn send(&self, m: Msg) {
        let _ = self.tx.send(m);
    }

    fn with_reader<T>(&self, f: impl FnOnce(&Connection) -> Result<T>) -> Result<T> {
        let g = self.reader.lock().unwrap();
        f(g.as_ref().context("index closed")?)
    }

    // Words (FTS5) and meaning (e5 over the text, MobileCLIP over images),
    // fused by rank. `want` narrows it to a mime prefix and to folders; with
    // no words it lists the newest files that fit instead.
    pub fn query(&self, q: &str, limit: usize, want: &Want) -> Result<Vec<Hit>> {
        let mut hits = self.words(q, limit, want)?;
        if q.chars().filter(|c| c.is_alphanumeric()).count() >= 3 {
            let (text, image) = self.meaning(q, want);
            if !text.is_empty() || !image.is_empty() {
                hits = fuse(vec![(hits, 1.0), (text, 1.0), (image, 1.0)]);
            }
        }
        hits.truncate(limit);
        self.captions(&mut hits);
        Ok(hits)
    }

    // Full-text search: every word as a prefix, the name weighed most; the
    // candidates come back re-ranked, more than asked for.
    fn words(&self, q: &str, limit: usize, want: &Want) -> Result<Vec<Hit>> {
        let expr = fts_query(q);
        if expr.is_empty() && want.is_empty() {
            return Ok(Vec::new());
        }
        let dirs: Vec<String> = want.dir.iter().map(|d| paths::expand(d).to_string_lossy().into_owned()).collect();
        // Prefix tests by substr, so % and _ in names are plain letters.
        let mut cond = Vec::new();
        let mut args: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
        if !want.mime.is_empty() {
            cond.push(format!("substr(f.mime, 1, length(?{0})) = ?{0}", args.len() + 1));
            args.push(Box::new(want.mime.clone()));
        }
        if !dirs.is_empty() {
            let mut any = Vec::new();
            for d in &dirs {
                any.push(format!("substr(f.path, 1, length(?{0})) = ?{0}", args.len() + 1));
                args.push(Box::new(format!("{}/", d.trim_end_matches('/'))));
            }
            cond.push(format!("({})", any.join(" OR ")));
        }
        let sql = if expr.is_empty() {
            let w = if cond.is_empty() { String::new() } else { format!("WHERE {}", cond.join(" AND ")) };
            args.push(Box::new(limit as i64));
            format!(
                "SELECT f.path, f.name, f.mime, f.mtime, '', 0.0, coalesce(f.hash, '') FROM files f {w}
                 ORDER BY f.mtime DESC LIMIT ?{}",
                args.len()
            )
        } else {
            args.push(Box::new(expr));
            let m = args.len();
            // Candidates for the re-rank below.
            args.push(Box::new((limit * 5).clamp(40, 400) as i64));
            let extra: String = cond.iter().map(|c| format!(" AND {c}")).collect();
            format!(
                "SELECT f.path, f.name, f.mime, f.mtime,
                        snippet(fts, 2, '[', ']', '…', 10),
                        bm25(fts, 10.0, 2.0, 1.0), coalesce(f.hash, '')
                 FROM fts JOIN files f ON f.id = fts.rowid
                 WHERE fts MATCH ?{m}{extra}
                 ORDER BY bm25(fts, 10.0, 2.0, 1.0)
                 LIMIT ?{}",
                args.len()
            )
        };
        self.with_reader(|c| {
            let mut st = c.prepare_cached(&sql)?;
            let refs: Vec<&dyn rusqlite::ToSql> = args.iter().map(|b| b.as_ref()).collect();
            let rows = st.query_map(refs.as_slice(), |r| {
                let path: String = r.get(0)?;
                Ok(Hit {
                    dir: parent(&path),
                    name: r.get(1)?,
                    mime: r.get(2)?,
                    mtime: r.get(3)?,
                    snippet: r.get(4)?,
                    caption: String::new(),
                    score: -r.get::<_, f64>(5)?,
                    hash: r.get(6)?,
                    path,
                })
            })?;
            let mut hits: Vec<Hit> = rows.filter_map(|r| r.ok()).collect();
            if !q.trim().is_empty() {
                rerank(&mut hits, q);
            }
            Ok(hits)
        })
    }

    // Files whose text (e5) or picture (MobileCLIP) is near the query, each
    // list best first. Empty when the models are not there.
    fn meaning(&self, q: &str, want: &Want) -> (Vec<Hit>, Vec<Hit>) {
        let tv = self.ml.e5(&[format!("query: {q}")]).and_then(|r| r.ok()).and_then(|mut v| v.pop());
        let iv = self.ml.clip_text(q).and_then(|r| r.ok());
        self.with_reader(|c| {
            let near = |kind: VecKind, v: &Option<Vec<f32>>, min: f32| -> Result<Vec<Hit>> {
                let Some(v) = v else { return Ok(Vec::new()) };
                let mut out = Vec::new();
                for (hash, sim) in knn(c, kind, v, 60)? {
                    if sim < min {
                        break;
                    }
                    out.extend(files_of(c, &hash, sim as f64, want)?);
                }
                Ok(out)
            };
            Ok((near(VecKind::Text, &tv, TEXT_MIN)?, near(VecKind::Image, &iv, IMAGE_MIN)?))
        })
        .unwrap_or_else(|e| {
            eprintln!("dotd: query: {e:#}");
            (Vec::new(), Vec::new())
        })
    }

    // Images and videos say what is in them when the words did not match.
    fn captions(&self, hits: &mut [Hit]) {
        for h in hits.iter_mut().filter(|h| !h.hash.is_empty() && !h.snippet.contains('[')) {
            if h.mime.starts_with("image/") || h.mime.starts_with("video/") {
                let d = read_derived(&h.hash);
                if let Some(c) = d.get("extractors").and_then(|x| x.get("florence")).and_then(|f| f.get("caption")).and_then(Value::as_str) {
                    h.caption = c.to_string();
                }
            }
        }
    }

    pub fn stats(&self) -> Value {
        let heavy = serde_json::to_value(&*self.heavy.lock().unwrap()).unwrap_or_default();
        let models = json!({ "e5": self.ml.e5.ready(), "clipText": self.ml.clip_text.ready() });
        self.with_reader(|c| {
            let n = |sql: &str| c.query_row(sql, [], |r| r.get::<_, i64>(0)).unwrap_or(0);
            Ok(json!({
                "files": n("SELECT count(*) FROM files"),
                "hashed": n("SELECT count(*) FROM files WHERE hash IS NOT NULL"),
                "contents": n("SELECT count(DISTINCT hash) FROM files WHERE hash IS NOT NULL"),
                "runs": n("SELECT count(*) FROM runs"),
                "failed": n("SELECT count(*) FROM runs WHERE ok = 0"),
                "vectors": {
                    "text": n("SELECT count(*) FROM vecs WHERE kind = 'text'"),
                    "image": n("SELECT count(*) FROM vecs WHERE kind = 'image'"),
                },
                "captioned": n("SELECT count(*) FROM runs WHERE extractor = 'florence' AND ok = 1"),
                "models": models,
                "heavy": heavy,
            }))
        })
        .unwrap_or_else(|e| json!({ "error": format!("{e:#}") }))
    }
}

fn parent(path: &str) -> String {
    Path::new(path).parent().map(|d| d.to_string_lossy().into_owned()).unwrap_or_default()
}

// Below these a neighbour is noise (dotd bench --near). Cosine: e5 puts
// the text a query means at 0.85–0.88 and unrelated prose at 0.74–0.80;
// MobileCLIP puts the photos a query shows at 0.21–0.28 and the rest
// under 0.19.
const TEXT_MIN: f32 = 0.845;
const IMAGE_MIN: f32 = 0.22;

// Reciprocal rank fusion: each list adds w / (60 + rank) for a file. A file
// that both names the words and means them wins; one only a single list
// found still places by its rank there.
fn fuse(lists: Vec<(Vec<Hit>, f64)>) -> Vec<Hit> {
    let mut by: HashMap<String, Hit> = HashMap::new();
    for (list, w) in lists {
        for (rank, mut h) in list.into_iter().enumerate() {
            let add = w / (60.0 + rank as f64);
            match by.get_mut(&h.path) {
                Some(old) => {
                    old.score += add;
                    if old.snippet.is_empty() {
                        old.snippet = std::mem::take(&mut h.snippet);
                    }
                }
                None => {
                    h.score = add;
                    by.insert(h.path.clone(), h);
                }
            }
        }
    }
    let mut hits: Vec<Hit> = by.into_values().collect();
    hits.sort_by(|a, b| b.score.total_cmp(&a.score).then(b.mtime.cmp(&a.mtime)));
    for h in &mut hits {
        h.score = (h.score * 1000.0).round() / 1000.0;
    }
    hits
}

// Match first, then recency: +6 when every word starts a word of the file
// name, and up to +4 for a new file (halving every 90 days), on top of bm25
// (about 0..20). Without it, long code and logs that repeat a word beat the
// document named after it.
fn rerank(hits: &mut [Hit], q: &str) {
    let words: Vec<String> = q.split_whitespace().map(|w| w.trim_matches(|c: char| !c.is_alphanumeric()).to_lowercase()).filter(|w| !w.is_empty()).collect();
    let now = std::time::SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as i64).unwrap_or(0);
    for h in hits.iter_mut() {
        let name = h.name.to_lowercase();
        let parts: Vec<&str> = name.split(|c: char| !c.is_alphanumeric()).filter(|p| !p.is_empty()).collect();
        if words.iter().all(|w| parts.iter().any(|p| p.starts_with(w.as_str()))) {
            h.score += 6.0;
        }
        let days = ((now - h.mtime).max(0) as f64) / 86_400_000.0;
        h.score += 4.0 * 0.5f64.powf(days / 90.0);
    }
    hits.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
}

// "red bike" -> "red"* "bike"*  (quotes doubled, so any text is safe)
pub fn fts_query(q: &str) -> String {
    q.split_whitespace()
        .map(|w| w.trim_matches(|c: char| !c.is_alphanumeric()))
        .filter(|w| !w.is_empty())
        .map(|w| format!("\"{}\"*", w.replace('"', "\"\"")))
        .collect::<Vec<_>>()
        .join(" ")
}

// ── Vectors ─────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy)]
pub enum VecKind {
    Text,
    Image,
}

impl VecKind {
    fn name(self) -> &'static str {
        match self {
            VecKind::Text => "text",
            VecKind::Image => "image",
        }
    }
    fn table(self) -> &'static str {
        match self {
            VecKind::Text => "vec_text",
            VecKind::Image => "vec_image",
        }
    }
}

fn blob(v: &[f32]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

// A content's vectors of one kind, replacing what it had.
pub fn put_vecs(db: &Connection, hash: &str, kind: VecKind, vs: &[Vec<f32>]) -> Result<()> {
    let tx = db.unchecked_transaction()?;
    drop_vecs(&tx, hash, kind)?;
    for (i, v) in vs.iter().enumerate() {
        tx.execute("INSERT INTO vecs (hash, kind, part) VALUES (?1, ?2, ?3)", params![hash, kind.name(), i as i64])?;
        let id = tx.last_insert_rowid();
        tx.execute(&format!("INSERT INTO {} (rowid, embedding) VALUES (?1, ?2)", kind.table()), params![id, blob(v)])?;
    }
    tx.commit()?;
    Ok(())
}

fn drop_vecs(db: &Connection, hash: &str, kind: VecKind) -> Result<()> {
    db.execute(
        &format!("DELETE FROM {} WHERE rowid IN (SELECT id FROM vecs WHERE hash = ?1 AND kind = ?2)", kind.table()),
        params![hash, kind.name()],
    )?;
    db.execute("DELETE FROM vecs WHERE hash = ?1 AND kind = ?2", params![hash, kind.name()])?;
    Ok(())
}

// The k nearest contents, (hash, cosine) best first; a content with several
// vectors (chunks, frames) counts by its best.
pub fn knn(c: &Connection, kind: VecKind, q: &[f32], k: usize) -> Result<Vec<(String, f32)>> {
    let sql = format!(
        "SELECT v.hash, n.distance FROM
           (SELECT rowid, distance FROM {} WHERE embedding MATCH ?1 AND k = ?2) n
         JOIN vecs v ON v.id = n.rowid ORDER BY n.distance",
        kind.table()
    );
    let mut st = c.prepare_cached(&sql)?;
    let rows = st.query_map(params![blob(q), k as i64], |r| Ok((r.get::<_, String>(0)?, r.get::<_, f64>(1)?)))?;
    let mut out: Vec<(String, f32)> = Vec::new();
    for r in rows {
        let (hash, dist) = r?;
        if !out.iter().any(|(h, _)| *h == hash) {
            out.push((hash, 1.0 - dist as f32));
        }
    }
    Ok(out)
}

// The files holding a content, as hits, narrowed by `want`.
fn files_of(c: &Connection, hash: &str, score: f64, want: &Want) -> Result<Vec<Hit>> {
    let mut st = c.prepare_cached("SELECT path, name, mime, mtime FROM files WHERE hash = ?1 ORDER BY mtime DESC")?;
    let rows = st.query_map([hash], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?, r.get::<_, String>(2)?, r.get::<_, i64>(3)?)))?;
    let mut out = Vec::new();
    for r in rows {
        let (path, name, mime, mtime) = r?;
        if want.admits(&path, &mime) {
            out.push(Hit { dir: parent(&path), path, name, mime, mtime, snippet: String::new(), caption: String::new(), score, hash: hash.into() });
        }
    }
    Ok(out)
}

// ── Work shared by the worker and the heavy thread ──────────────────

// The newest file (at or below `below` mtime) this extractor has not seen
// at its version: (mtime, path, hash, mime).
pub fn due(db: &Connection, x: &Extractor, below: i64) -> Result<Option<(i64, String, String, String)>> {
    if below == i64::MIN {
        return Ok(None);
    }
    if x.builtin && x.name == "e5" {
        // Any content another extractor has finished with.
        let mut st = db.prepare_cached(
            "SELECT f.mtime, f.path, f.hash, f.mime FROM files f
             WHERE f.hash IS NOT NULL AND f.mtime <= ?2
               AND EXISTS (SELECT 1 FROM runs r WHERE r.hash = f.hash AND r.extractor != 'e5' AND r.ok = 1)
               AND NOT EXISTS (SELECT 1 FROM runs r WHERE r.hash = f.hash AND r.extractor = 'e5' AND r.version = ?1)
             ORDER BY f.mtime DESC LIMIT 1",
        )?;
        return Ok(st.query_row(params![x.version, below], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?))).optional()?);
    }
    let mut conds: Vec<String> = Vec::new();
    let mut args: Vec<String> = vec![x.name.clone(), x.version.to_string(), x.max_size.to_string(), below.to_string(), x.min_size.to_string()];
    for m in &x.mimes {
        args.push(m.clone());
        conds.push(format!("f.mime GLOB ?{}", args.len()));
    }
    for e in &x.exts {
        args.push(e.to_lowercase());
        conds.push(format!("f.ext = ?{}", args.len()));
    }
    if conds.is_empty() {
        return Ok(None);
    }
    let sql = format!(
        "SELECT f.mtime, f.path, f.hash, f.mime FROM files f
         WHERE f.hash IS NOT NULL AND f.size <= CAST(?3 AS INTEGER) AND f.size >= CAST(?5 AS INTEGER)
           AND f.mtime <= CAST(?4 AS INTEGER) AND ({})
           AND NOT EXISTS (SELECT 1 FROM runs r WHERE r.hash = f.hash AND r.extractor = ?1
                           AND r.version = CAST(?2 AS INTEGER))
         ORDER BY f.mtime DESC LIMIT 1",
        conds.join(" OR ")
    );
    let mut st = db.prepare_cached(&sql)?;
    Ok(st
        .query_row(rusqlite::params_from_iter(args.iter()), |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))
        .optional()?)
}

// Keep what an extractor said about a content: into its derived record, the
// runs table, and (text = true, it may have found words) the FTS rows of
// every file with that content, which also sends it back to e5.
#[allow(clippy::too_many_arguments)]
pub fn record(db: &Connection, max: usize, x: &Extractor, hash: &str, mime: &str, ok: bool, mut out: Value, text: bool) -> Result<()> {
    // The worker and the heavy thread both rewrite derived records.
    static DERIVED: Mutex<()> = Mutex::new(());
    let now = crate::event::now_ms() as i64;
    if let Some(Value::String(t)) = out.get_mut("text") {
        if t.len() > max {
            let mut cut = max;
            while !t.is_char_boundary(cut) {
                cut -= 1;
            }
            t.truncate(cut);
        }
    }
    {
        let _g = DERIVED.lock().unwrap_or_else(|p| p.into_inner());
        let mut d = read_derived(hash);
        d.insert("hash".into(), hash.into());
        d.insert("mime".into(), mime.into());
        let xs = d.entry("extractors").or_insert_with(|| json!({}));
        if let (Some(obj), Some(o)) = (xs.as_object_mut(), out.as_object_mut()) {
            o.insert("version".into(), x.version.into());
            o.insert("at".into(), now.into());
            o.insert("ok".into(), ok.into());
            obj.insert(x.name.clone(), Value::Object(o.clone()));
        }
        write_derived(hash, &d)?;
    }
    db.execute(
        "INSERT OR REPLACE INTO runs (hash, extractor, version, ok, at) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![hash, x.name, x.version, ok as i64, now],
    )?;
    if text {
        refresh(db, hash, true)?;
    }
    Ok(())
}

// The searchable text of every file with this content; `again` = it may
// have changed, so e5 embeds it anew.
pub fn refresh(db: &Connection, hash: &str, again: bool) -> Result<()> {
    let body = body_of(&read_derived(hash));
    let rows: Vec<(i64, String, String)> = db
        .prepare("SELECT id, path, name FROM files WHERE hash = ?1")?
        .query_map([hash], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
        .collect::<Result<_, _>>()?;
    for (id, path, name) in rows {
        db.execute("DELETE FROM fts WHERE rowid = ?1", [id])?;
        db.execute(
            "INSERT INTO fts (rowid, name, dir, body) VALUES (?1, ?2, ?3, ?4)",
            params![id, words(&name), dir_words(Path::new(&path)), body],
        )?;
    }
    if again {
        db.execute("DELETE FROM runs WHERE hash = ?1 AND extractor = 'e5'", [hash])?;
    }
    Ok(())
}

// ── The worker ──────────────────────────────────────────────────────

struct Worker {
    db: Connection,
    cfg: Config,
    filter: Filter,
    extractors: Vec<Extractor>,
    ml: Arc<ml::Shared>,
    scan: i64,
    last_scan: Instant,
    done: u64,
    // Per extractor: the mtime its search continues below. Work goes newest
    // first, so nothing above it is due; a new or changed file resets them.
    cursors: HashMap<String, i64>,
}

fn mtime_of(m: &std::fs::Metadata) -> i64 {
    m.modified().ok().and_then(|t| t.duration_since(UNIX_EPOCH).ok()).map(|d| d.as_millis() as i64).unwrap_or(0)
}

// The plugins, and e5 when its model is there.
fn extractors() -> Vec<Extractor> {
    let mut xs = extract::load();
    if !ml::models_dir().join("e5/model.onnx").exists() {
        xs.retain(|x| x.name != "e5");
        eprintln!("dotd: index: no e5 model (dotd-models), search is by words only");
    }
    eprintln!("dotd: index: {} extractors", xs.len());
    xs
}

impl Worker {
    fn new(db: Connection, cfg: Config, ml: Arc<ml::Shared>) -> Worker {
        let filter = Filter::new(&cfg);
        Worker { db, cfg, filter, extractors: extractors(), ml, scan: 0, last_scan: Instant::now(), done: 0, cursors: HashMap::new() }
    }

    fn run(&mut self, rx: Receiver<Msg>) {
        self.rescan();
        loop {
            // Events first, then one unit of work; idle waits for events.
            loop {
                match rx.try_recv() {
                    Ok(m) => self.handle(m),
                    Err(mpsc::TryRecvError::Empty) => break,
                    Err(mpsc::TryRecvError::Disconnected) => return,
                }
            }
            if self.last_scan.elapsed() > Duration::from_secs(self.cfg.rescan_hours * 3600) {
                self.rescan();
            }
            match self.step() {
                Ok(true) => continue,
                Ok(false) => {}
                Err(e) => eprintln!("dotd: index: {e:#}"),
            }
            match rx.recv_timeout(Duration::from_secs(60)) {
                Ok(m) => self.handle(m),
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => return,
            }
        }
    }

    fn handle(&mut self, m: Msg) {
        self.cursors.clear();
        let r = match m {
            Msg::Touch(p) => {
                if p.is_dir() {
                    if self.filter.wants(&p) && !self.filter.skip_dir(&p) {
                        self.walk(&p)
                    } else {
                        Ok(())
                    }
                } else if self.filter.wants(&p) {
                    self.touch(&p).map(drop)
                } else {
                    Ok(())
                }
            }
            Msg::Gone(p) => self.gone(&p),
            Msg::Rescan => {
                self.rescan();
                Ok(())
            }
            Msg::Reload => {
                self.cfg = load_config();
                self.filter = Filter::new(&self.cfg);
                self.extractors = extractors();
                self.ml.reset();
                Ok(())
            }
            Msg::Nudge => Ok(()),
        };
        if let Err(e) = r {
            eprintln!("dotd: index: {e:#}");
        }
    }

    // Walk every root; rows not seen afterwards are files that went away,
    // and vectors no file holds any more go with them.
    fn rescan(&mut self) {
        self.cursors.clear();
        let t = Instant::now();
        self.scan = self.db.query_row("SELECT coalesce(max(seen), 0) + 1 FROM files", [], |r| r.get(0)).unwrap_or(1);
        for root in self.filter.roots.clone() {
            if let Err(e) = self.walk(&root) {
                eprintln!("dotd: index: walk {}: {e:#}", root.display());
            }
        }
        let gone: Vec<(i64,)> = self
            .db
            .prepare("SELECT id FROM files WHERE seen < ?1")
            .and_then(|mut s| s.query_map([self.scan], |r| Ok((r.get(0)?,)))?.collect())
            .unwrap_or_default();
        for (id,) in &gone {
            let _ = self.db.execute("DELETE FROM fts WHERE rowid = ?1", [id]);
            let _ = self.db.execute("DELETE FROM files WHERE id = ?1", [id]);
        }
        // Their runs go too, so the content is embedded again if it comes back.
        let _ = self.db.execute_batch(
            "CREATE TEMP TABLE IF NOT EXISTS lost AS SELECT DISTINCT hash FROM vecs WHERE 0;
             DELETE FROM lost;
             INSERT INTO lost SELECT DISTINCT hash FROM vecs WHERE hash NOT IN (SELECT hash FROM files WHERE hash IS NOT NULL);
             DELETE FROM vec_text WHERE rowid IN (SELECT id FROM vecs WHERE hash IN (SELECT hash FROM lost));
             DELETE FROM vec_image WHERE rowid IN (SELECT id FROM vecs WHERE hash IN (SELECT hash FROM lost));
             DELETE FROM vecs WHERE hash IN (SELECT hash FROM lost);
             DELETE FROM runs WHERE extractor IN ('e5', 'clip') AND hash IN (SELECT hash FROM lost);",
        );
        self.last_scan = Instant::now();
        let total: i64 = self.db.query_row("SELECT count(*) FROM files", [], |r| r.get(0)).unwrap_or(0);
        eprintln!("dotd: index: scanned {total} files in {:.1} s, {} gone", t.elapsed().as_secs_f64(), gone.len());
    }

    fn walk(&mut self, top: &Path) -> Result<()> {
        let tx = self.db.unchecked_transaction()?;
        let mut stack = vec![top.to_path_buf()];
        while let Some(dir) = stack.pop() {
            let Ok(rd) = std::fs::read_dir(&dir) else { continue };
            for e in rd.flatten() {
                let Ok(ft) = e.file_type() else { continue };
                let p = e.path();
                if ft.is_dir() {
                    if !self.filter.skip_dir(&p) {
                        stack.push(p);
                    }
                } else if ft.is_file() && !e.file_name().to_string_lossy().starts_with('.') {
                    if let Err(err) = self.touch(&p) {
                        eprintln!("dotd: index: {}: {err:#}", p.display());
                    }
                }
            }
        }
        tx.commit()?;
        Ok(())
    }

    // Record a file; true if it is new or changed (its hash is then due).
    fn touch(&self, p: &Path) -> Result<bool> {
        let meta = std::fs::metadata(p)?;
        if !meta.is_file() {
            return Ok(false);
        }
        let path = p.to_string_lossy().into_owned();
        let (size, mtime) = (meta.len() as i64, mtime_of(&meta));
        let old: Option<(i64, i64, i64)> = self
            .db
            .query_row("SELECT id, size, mtime FROM files WHERE path = ?1", [&path], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))
            .optional()?;
        if let Some((id, s, m)) = old {
            if s == size && m == mtime {
                self.db.execute("UPDATE files SET seen = ?1 WHERE id = ?2", params![self.scan, id])?;
                return Ok(false);
            }
            self.db.execute(
                "UPDATE files SET size = ?1, mtime = ?2, hash = NULL, seen = ?3 WHERE id = ?4",
                params![size, mtime, self.scan, id],
            )?;
            return Ok(true);
        }
        let name = p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        let ext = crate::sort::ext_of(&name);
        let mime = mime_guess::from_path(p).first_or_octet_stream().essence_str().to_string();
        self.db.execute(
            "INSERT INTO files (path, name, ext, mime, size, mtime, seen) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![path, name, ext, mime, size, mtime, self.scan],
        )?;
        let id = self.db.last_insert_rowid();
        self.db.execute(
            "INSERT INTO fts (rowid, name, dir, body) VALUES (?1, ?2, ?3, '')",
            params![id, words(&name), dir_words(p)],
        )?;
        Ok(true)
    }

    fn gone(&mut self, p: &Path) -> Result<()> {
        let path = p.to_string_lossy();
        let like = format!("{}/%", path.replace('\\', "\\\\").replace('%', "\\%").replace('_', "\\_"));
        let ids: Vec<i64> = self
            .db
            .prepare("SELECT id FROM files WHERE path = ?1 OR path LIKE ?2 ESCAPE '\\'")?
            .query_map(params![path, like], |r| r.get(0))?
            .collect::<Result<_, _>>()?;
        for id in ids {
            self.db.execute("DELETE FROM fts WHERE rowid = ?1", [id])?;
            self.db.execute("DELETE FROM files WHERE id = ?1", [id])?;
        }
        Ok(())
    }

    // One unit of work: hash one file, or run one extractor on one file.
    // false = nothing left to do.
    fn step(&mut self) -> Result<bool> {
        let unhashed: Option<(i64, String)> = self
            .db
            .query_row("SELECT id, path FROM files WHERE hash IS NULL ORDER BY mtime DESC LIMIT 1", [], |r| Ok((r.get(0)?, r.get(1)?)))
            .optional()?;
        if let Some((id, path)) = unhashed {
            match hash_file(Path::new(&path)) {
                Ok(h) => {
                    self.db.execute("UPDATE files SET hash = ?1 WHERE id = ?2", params![h, id])?;
                    self.cursors.clear();
                    // Seen before under another name: its text comes along.
                    if derived_path(&h).exists() {
                        refresh(&self.db, &h, false)?;
                    }
                }
                Err(_) => {
                    // Gone or unreadable: drop it; a later event brings it back.
                    self.db.execute("DELETE FROM fts WHERE rowid = ?1", [id])?;
                    self.db.execute("DELETE FROM files WHERE id = ?1", [id])?;
                }
            }
            self.tick();
            return Ok(true);
        }
        // Per tier, the newest file any extractor still owes, so one
        // extractor's long backlog never holds up another's new file.
        for tier in extract::TIERS {
            let mut best: Option<(i64, Extractor, String, String, String)> = None;
            for x in self.extractors.clone().into_iter().filter(|x| x.tier == tier) {
                let below = *self.cursors.get(&x.name).unwrap_or(&i64::MAX);
                match due(&self.db, &x, below)? {
                    Some((mtime, path, hash, mime)) => {
                        self.cursors.insert(x.name.clone(), mtime);
                        if best.as_ref().is_none_or(|b| mtime > b.0) {
                            best = Some((mtime, x, path, hash, mime));
                        }
                    }
                    None => {
                        self.cursors.insert(x.name.clone(), i64::MIN);
                    }
                }
            }
            if let Some((_, x, path, hash, mime)) = best {
                if x.builtin {
                    self.embed(&x, &path, &hash, &mime)?;
                } else {
                    self.extract(&x, &path, &hash, &mime)?;
                }
                self.tick();
                return Ok(true);
            }
        }
        Ok(false)
    }

    fn tick(&mut self) {
        self.done += 1;
        if self.done % 1000 == 0 {
            let left: i64 = self.db.query_row("SELECT count(*) FROM files WHERE hash IS NULL", [], |r| r.get(0)).unwrap_or(0);
            eprintln!("dotd: index: {} done, {left} to hash", self.done);
        }
    }

    fn extract(&mut self, x: &Extractor, path: &str, hash: &str, mime: &str) -> Result<()> {
        let (ok, out) = match x.run(Path::new(path), hash, mime) {
            Ok(v) => (true, v),
            Err(e) => {
                eprintln!("dotd: index: {} on {path}: {e:#}", x.name);
                (false, json!({ "error": format!("{e:#}") }))
            }
        };
        record(&self.db, self.cfg.max_text, x, hash, mime, ok, out, true)?;
        // e5 has new text to look at, above where it had got to.
        self.cursors.remove("e5");
        Ok(())
    }

    // e5: the text the other extractors found, as up to four vectors.
    // Skipped when that text has not changed since it was last embedded.
    fn embed(&mut self, x: &Extractor, path: &str, hash: &str, mime: &str) -> Result<()> {
        let d = read_derived(hash);
        let name = Path::new(path).file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        let text = embed_text(&d, &crate::sort::ext_of(&name));
        let src = if text.is_empty() { String::new() } else { blake3::hash(text.as_bytes()).to_hex()[..16].to_string() };
        let old = d.get("extractors").and_then(|e| e.get("e5"));
        let same = old.and_then(|o| o.get("src")).and_then(Value::as_str) == Some(src.as_str())
            && self.db.query_row("SELECT count(*) FROM vecs WHERE hash = ?1 AND kind = 'text'", [hash], |r| r.get::<_, i64>(0))? > 0;
        let out = if text.is_empty() {
            drop_vecs(&self.db, hash, VecKind::Text)?;
            json!({ "chunks": 0 })
        } else if same {
            json!({ "src": src, "chunks": old.and_then(|o| o.get("chunks")).cloned().unwrap_or(json!(0)) })
        } else {
            let passages: Vec<String> = chunks(&text).into_iter().map(|c| format!("passage: {name}\n{c}")).collect();
            match self.ml.e5(&passages) {
                Some(Ok(vs)) => {
                    put_vecs(&self.db, hash, VecKind::Text, &vs)?;
                    json!({ "src": src, "chunks": vs.len() })
                }
                Some(Err(e)) => {
                    eprintln!("dotd: index: e5 on {path}: {e:#}");
                    return record(&self.db, self.cfg.max_text, x, hash, mime, false, json!({ "error": format!("{e:#}") }), false);
                }
                None => {
                    // The model would not load: e5 is off until dotd reload.
                    self.extractors.retain(|x| x.name != "e5");
                    return Ok(());
                }
            }
        };
        record(&self.db, self.cfg.max_text, x, hash, mime, true, out, false)
    }
}

// What e5 reads: prose. Titles, text, captions and tags from documents,
// OCR and Florence-2, and plain text files that are writing, not code,
// logs or data: those read as near anything and crowd out real matches.
const PROSE_FROM: [&str; 5] = ["pdf-text", "office", "ocr", "florence", "text"];
const PROSE_EXTS: [&str; 5] = ["md", "txt", "org", "rst", "tex"];

fn embed_text(d: &Map<String, Value>, ext: &str) -> String {
    let mut out = String::new();
    let Some(xs) = d.get("extractors").and_then(Value::as_object) else { return out };
    for (name, x) in xs {
        if !PROSE_FROM.contains(&name.as_str()) || (name == "text" && !PROSE_EXTS.contains(&ext)) {
            continue;
        }
        for k in ["title", "caption", "text"] {
            if let Some(s) = x.get(k).and_then(Value::as_str) {
                out.push_str(s);
                out.push('\n');
            }
        }
        if let Some(tags) = x.get("tags").and_then(Value::as_array) {
            let t: Vec<&str> = tags.iter().filter_map(Value::as_str).collect();
            if !t.is_empty() {
                out.push_str(&t.join(", "));
                out.push('\n');
            }
        }
        if out.len() > 8 * CHUNK {
            break;
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

// About 300 tokens each: e5 reads 512 at most.
const CHUNK: usize = 1200;
const CHUNKS: usize = 4;

fn chunks(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut rest = text.trim();
    while !rest.is_empty() && out.len() < CHUNKS {
        if rest.len() <= CHUNK {
            out.push(rest.to_string());
            break;
        }
        let mut cut = CHUNK;
        while !rest.is_char_boundary(cut) {
            cut -= 1;
        }
        if let Some(sp) = rest[..cut].rfind(char::is_whitespace) {
            if sp > CHUNK / 2 {
                cut = sp;
            }
        }
        out.push(rest[..cut].trim().to_string());
        rest = rest[cut..].trim_start();
    }
    out
}

// Names as words: "PhD_Research-v2.pdf" also matches "research".
fn words(name: &str) -> String {
    let split: String = name.chars().map(|c| if c == '_' || c == '-' || c == '.' { ' ' } else { c }).collect();
    format!("{name} {split}")
}

// The folders under home, as words.
fn dir_words(p: &Path) -> String {
    let h = paths::home();
    let d = p.parent().unwrap_or(p);
    let rel = d.strip_prefix(&h).unwrap_or(d);
    rel.components().map(|c| words(&c.as_os_str().to_string_lossy())).collect::<Vec<_>>().join(" ")
}

pub fn read_derived(hash: &str) -> Map<String, Value> {
    std::fs::read_to_string(derived_path(hash))
        .ok()
        .and_then(|t| serde_json::from_str::<Value>(&t).ok())
        .and_then(|v| v.as_object().cloned())
        .unwrap_or_default()
}

fn write_derived(hash: &str, d: &Map<String, Value>) -> Result<()> {
    let p = derived_path(hash);
    std::fs::create_dir_all(p.parent().unwrap())?;
    let tmp = p.with_extension("json.tmp");
    std::fs::write(&tmp, serde_json::to_vec(d)?)?;
    std::fs::rename(&tmp, &p)?;
    Ok(())
}

// Text for FTS from a derived record: titles, captions, text, tags and
// string meta.
fn body_of(d: &Map<String, Value>) -> String {
    let mut out = String::new();
    let Some(xs) = d.get("extractors").and_then(Value::as_object) else { return out };
    for x in xs.values() {
        for k in ["title", "caption", "text"] {
            if let Some(s) = x.get(k).and_then(Value::as_str) {
                out.push_str(s);
                out.push('\n');
            }
        }
        if let Some(tags) = x.get("tags").and_then(Value::as_array) {
            for t in tags.iter().filter_map(Value::as_str) {
                out.push_str(t);
                out.push(' ');
            }
        }
        if let Some(meta) = x.get("meta").and_then(Value::as_object) {
            for v in meta.values().filter_map(Value::as_str) {
                out.push_str(v);
                out.push(' ');
            }
        }
    }
    out
}

// blake3 of the content. Files over 256 MB are hashed from their size and
// three 8 MB samples (start, middle, end): still unique in practice, and a
// film does not cost a full read.
pub fn hash_file(p: &Path) -> Result<String> {
    const BIG: u64 = 256 << 20;
    const CHUNK: usize = 8 << 20;
    let mut f = std::fs::File::open(p)?;
    let size = f.metadata()?.len();
    let mut h = blake3::Hasher::new();
    if size <= BIG {
        let mut buf = vec![0u8; 1 << 20];
        loop {
            let n = f.read(&mut buf)?;
            if n == 0 {
                break;
            }
            h.update(&buf[..n]);
        }
        return Ok(h.finalize().to_hex().to_string());
    }
    use std::io::{Seek, SeekFrom};
    h.update(b"sampled");
    h.update(&size.to_le_bytes());
    let mut buf = vec![0u8; CHUNK];
    for at in [0, size / 2, size - CHUNK as u64] {
        f.seek(SeekFrom::Start(at))?;
        f.read_exact(&mut buf)?;
        h.update(&buf);
    }
    Ok(format!("s{}", &h.finalize().to_hex()[..63]))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn queries() {
        assert_eq!(fts_query("red bike"), "\"red\"* \"bike\"*");
        assert_eq!(fts_query("  \"x\" (y) "), "\"x\"* \"y\"*");
        assert_eq!(fts_query("--"), "");
    }

    #[test]
    fn name_words() {
        assert_eq!(words("PhD_Research-v2.pdf"), "PhD_Research-v2.pdf PhD Research v2 pdf");
    }

    #[test]
    fn filter() {
        let c: Config = toml::from_str(r#"roots = ["/r"]
exclude = ["/r/skip"]
exclude_names = ["node_modules"]"#).unwrap();
        let f = Filter::new(&c);
        assert!(f.wants(Path::new("/r/a/b.txt")));
        assert!(!f.wants(Path::new("/r/skip/b.txt")));
        assert!(!f.wants(Path::new("/r/x/node_modules/y.js")));
        assert!(!f.wants(Path::new("/r/.cache/y")));
        assert!(!f.wants(Path::new("/elsewhere/y")));
    }

    #[test]
    fn chunking() {
        assert_eq!(chunks("short"), vec!["short"]);
        let long = "word ".repeat(1000);
        let c = chunks(&long);
        assert_eq!(c.len(), CHUNKS);
        assert!(c.iter().all(|s| s.len() <= CHUNK && !s.ends_with(' ')));
    }

    #[test]
    fn vectors() {
        with_vec();
        let db = Connection::open_in_memory().unwrap();
        schema(&db).unwrap();
        let mut a = vec![0f32; ml::CLIP_DIM];
        a[0] = 1.0;
        let mut b = vec![0f32; ml::CLIP_DIM];
        b[1] = 1.0;
        put_vecs(&db, "ha", VecKind::Image, &[a.clone()]).unwrap();
        put_vecs(&db, "hb", VecKind::Image, &[b, a.clone()]).unwrap();
        put_vecs(&db, "ha", VecKind::Image, &[a.clone()]).unwrap();
        let near = knn(&db, VecKind::Image, &a, 10).unwrap();
        assert_eq!(near.len(), 2);
        assert!((near[0].1 - 1.0).abs() < 1e-5);
        let n: i64 = db.query_row("SELECT count(*) FROM vecs", [], |r| r.get(0)).unwrap();
        assert_eq!(n, 3);
    }

    #[test]
    fn fusing() {
        let h = |p: &str| Hit { path: p.into(), name: p.into(), dir: String::new(), mime: String::new(), mtime: 0, snippet: String::new(), caption: String::new(), score: 0.0, hash: String::new() };
        let out = fuse(vec![(vec![h("a"), h("b")], 1.0), (vec![h("c"), h("b")], 1.0)]);
        assert_eq!(out[0].path, "b");
    }
}
