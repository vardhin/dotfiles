// The index: every file under the watched folders, what extractors found in
// it, and full-text search over both.
//
//   file event → mime → blake3 → known hash? → reuse, update the path
//                                 └ new → extractors by mime, cheap tier
//                                         first, then medium
//                                         → derived/<blake3>.json
//                                         → FTS5 (name, folder, text)
//
// What is learned lives by content hash in ~/.local/share/dotd/derived/,
// never next to the file, so a moved or renamed file costs one hash and no
// extraction. index.db (same folder) is rebuilt from those and the files.
// Work goes newest file first. One worker thread owns the database for
// writing; queries read it through their own connection (WAL).
//
// ~/.config/dotd/index.toml says what is watched:
//   roots = ["~"]                     walked recursively; dotfolders skipped
//   exclude = ["~/Documents/git"]     folders left out
//   exclude_names = ["node_modules"]  folder names left out anywhere
// and a folder holding a .noindex file is left out with all below it.

use crate::extract::{self, Extractor};
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
}

#[derive(Clone)]
pub struct Index {
    tx: Sender<Msg>,
    reader: Arc<Mutex<Option<Connection>>>,
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
}

#[derive(Debug, Serialize)]
pub struct Hit {
    pub path: String,
    pub name: String,
    pub dir: String,
    pub mime: String,
    pub mtime: i64,
    pub snippet: String,
    pub score: f64,
}

pub fn db_path() -> PathBuf {
    paths::data_dir().join("index.db")
}

pub fn derived_path(hash: &str) -> PathBuf {
    paths::data_dir().join("derived").join(format!("{hash}.json"))
}

fn open(path: &Path) -> Result<Connection> {
    std::fs::create_dir_all(path.parent().unwrap())?;
    let c = Connection::open(path).with_context(|| format!("{}", path.display()))?;
    c.busy_timeout(Duration::from_secs(5))?;
    c.execute_batch(
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
         );",
    )?;
    Ok(c)
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
        let (tx, rx) = mpsc::channel();
        let cfg = load_config();
        {
            let tx = tx.clone();
            let cfg = cfg.clone();
            std::thread::Builder::new().name("dotd-watch".into()).spawn(move || {
                if let Err(e) = crate::watch::run(&cfg, tx) {
                    eprintln!("dotd: watch: {e:#}");
                }
            })?;
        }
        std::thread::Builder::new().name("dotd-index".into()).spawn(move || {
            let mut w = Worker::new(writer, cfg);
            w.run(rx);
        })?;
        Ok(Index { tx, reader: Arc::new(Mutex::new(Some(reader))) })
    }

    pub fn send(&self, m: Msg) {
        let _ = self.tx.send(m);
    }

    fn with_reader<T>(&self, f: impl FnOnce(&Connection) -> Result<T>) -> Result<T> {
        let g = self.reader.lock().unwrap();
        f(g.as_ref().context("index closed")?)
    }

    // Full-text search: every word as a prefix, the name weighed most.
    // `want` narrows it to a mime prefix and to folders; with no words it
    // lists the newest files that fit instead.
    pub fn query(&self, q: &str, limit: usize, want: &Want) -> Result<Vec<Hit>> {
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
                "SELECT f.path, f.name, f.mime, f.mtime, '', 0.0 FROM files f {w}
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
                        bm25(fts, 10.0, 2.0, 1.0)
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
                let dir = Path::new(&path).parent().map(|d| d.to_string_lossy().into_owned()).unwrap_or_default();
                Ok(Hit {
                    name: r.get(1)?,
                    mime: r.get(2)?,
                    mtime: r.get(3)?,
                    snippet: r.get(4)?,
                    score: -r.get::<_, f64>(5)?,
                    path,
                    dir,
                })
            })?;
            let mut hits: Vec<Hit> = rows.filter_map(|r| r.ok()).collect();
            if !q.trim().is_empty() {
                rerank(&mut hits, q);
                hits.truncate(limit);
            }
            Ok(hits)
        })
    }

    pub fn stats(&self) -> Value {
        self.with_reader(|c| {
            let n = |sql: &str| c.query_row(sql, [], |r| r.get::<_, i64>(0)).unwrap_or(0);
            Ok(json!({
                "files": n("SELECT count(*) FROM files"),
                "hashed": n("SELECT count(*) FROM files WHERE hash IS NOT NULL"),
                "contents": n("SELECT count(DISTINCT hash) FROM files WHERE hash IS NOT NULL"),
                "runs": n("SELECT count(*) FROM runs"),
                "failed": n("SELECT count(*) FROM runs WHERE ok = 0"),
            }))
        })
        .unwrap_or_else(|e| json!({ "error": format!("{e:#}") }))
    }
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

// ── The worker ──────────────────────────────────────────────────────

struct Worker {
    db: Connection,
    cfg: Config,
    filter: Filter,
    extractors: Vec<Extractor>,
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

impl Worker {
    fn new(db: Connection, cfg: Config) -> Worker {
        let filter = Filter::new(&cfg);
        let extractors = extract::load();
        eprintln!("dotd: index: {} extractors", extractors.len());
        Worker { db, cfg, filter, extractors, scan: 0, last_scan: Instant::now(), done: 0, cursors: HashMap::new() }
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
                self.extractors = extract::load();
                eprintln!("dotd: index: {} extractors", self.extractors.len());
                Ok(())
            }
        };
        if let Err(e) = r {
            eprintln!("dotd: index: {e:#}");
        }
    }

    // Walk every root; rows not seen afterwards are files that went away.
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
                        self.refresh(&h)?;
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
                match self.due(&x, below)? {
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
                self.extract(&x, &path, &hash, &mime)?;
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

    // The newest file (at or below `below` mtime) this extractor has not
    // seen at its version: (mtime, path, hash, mime).
    fn due(&self, x: &Extractor, below: i64) -> Result<Option<(i64, String, String, String)>> {
        if below == i64::MIN {
            return Ok(None);
        }
        let mut conds: Vec<String> = Vec::new();
        let mut args: Vec<String> = vec![x.name.clone(), x.version.to_string(), x.max_size.to_string(), below.to_string()];
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
             WHERE f.hash IS NOT NULL AND f.size <= CAST(?3 AS INTEGER) AND f.mtime <= CAST(?4 AS INTEGER) AND ({})
               AND NOT EXISTS (SELECT 1 FROM runs r WHERE r.hash = f.hash AND r.extractor = ?1
                               AND r.version = CAST(?2 AS INTEGER))
             ORDER BY f.mtime DESC LIMIT 1",
            conds.join(" OR ")
        );
        let mut st = self.db.prepare_cached(&sql)?;
        Ok(st
            .query_row(rusqlite::params_from_iter(args.iter()), |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)))
            .optional()?)
    }

    fn extract(&mut self, x: &Extractor, path: &str, hash: &str, mime: &str) -> Result<()> {
        let now = crate::event::now_ms() as i64;
        let (ok, mut out) = match x.run(Path::new(path), hash, mime) {
            Ok(v) => (true, v),
            Err(e) => {
                eprintln!("dotd: index: {} on {path}: {e:#}", x.name);
                (false, json!({ "error": format!("{e:#}") }))
            }
        };
        if let Some(Value::String(t)) = out.get_mut("text") {
            if t.len() > self.cfg.max_text {
                let mut cut = self.cfg.max_text;
                while !t.is_char_boundary(cut) {
                    cut -= 1;
                }
                t.truncate(cut);
            }
        }
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
        self.db.execute(
            "INSERT OR REPLACE INTO runs (hash, extractor, version, ok, at) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![hash, x.name, x.version, ok as i64, now],
        )?;
        self.refresh(hash)
    }

    // The searchable text of every file with this content.
    fn refresh(&mut self, hash: &str) -> Result<()> {
        let body = body_of(&read_derived(hash));
        let rows: Vec<(i64, String, String)> = self
            .db
            .prepare("SELECT id, path, name FROM files WHERE hash = ?1")?
            .query_map([hash], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
            .collect::<Result<_, _>>()?;
        for (id, path, name) in rows {
            self.db.execute("DELETE FROM fts WHERE rowid = ?1", [id])?;
            self.db.execute(
                "INSERT INTO fts (rowid, name, dir, body) VALUES (?1, ?2, ?3, ?4)",
                params![id, words(&name), dir_words(Path::new(&path)), body],
            )?;
        }
        Ok(())
    }
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

// Text for FTS from a derived record: titles, text, tags and string meta.
fn body_of(d: &Map<String, Value>) -> String {
    let mut out = String::new();
    let Some(xs) = d.get("extractors").and_then(Value::as_object) else { return out };
    for x in xs.values() {
        for k in ["title", "text"] {
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
}
