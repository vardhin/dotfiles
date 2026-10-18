// The daemon's state and the event pipeline: an event comes in from a
// source, the rules that match it run their sinks in order:
//   sort → index → feed → notify
// (sort first, so the others see where the file went).

use crate::event::{Event, now_ms};
use crate::notify::{self, Note};
use crate::paths;
use crate::rules::{Rule, Rules};
use crate::shell;
use crate::sort::{MoveLog, SortConfig, ext_of};
use anyhow::Result;
use serde::Serialize;
use serde_json::{Map, Value, json};
use std::cell::RefCell;
use std::collections::{BTreeMap, HashSet};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::time::Instant;

// The shell's events in (services/Dotd.qml); they gate the heavy tier later.
#[derive(Debug, Default, Clone, Serialize)]
pub struct ShellState {
    pub idle: bool,
    pub ac: bool,
    pub temp: i64,
    pub seen: u64,
}

#[derive(Debug, Clone)]
pub struct Active {
    pub name: String,
    pub path: PathBuf,
    pub size: u64,
    pub speed: f64,
    pub checked: Instant,
    // The last time it grew; one that stops for STALE is dropped.
    pub grew: Instant,
}

#[derive(Debug, Clone)]
pub struct Recent {
    pub id: Option<u64>,
    pub name: String,
    pub path: PathBuf,
    pub ts: u64,
}

// The downloads feed: what is downloading, and the last few that finished.
#[derive(Debug, Default)]
pub struct Downloads {
    pub active: Vec<Active>,
    pub recent: Vec<Recent>,
}

const RECENT: usize = 12;

impl Downloads {
    pub fn add(&mut self, r: Recent) {
        self.recent.retain(|x| x.path != r.path);
        self.recent.insert(0, r);
        self.recent.truncate(RECENT);
    }

    pub fn json(&self) -> Value {
        let active: Vec<Value> = self
            .active
            .iter()
            .map(|a| json!({ "name": a.name, "path": a.path, "size": a.size, "pct": 0, "speed": speed(a.speed) }))
            .collect();
        let recent: Vec<Value> = self
            .recent
            .iter()
            .map(|r| {
                json!({
                    "id": r.id.map(|i| i.to_string()).unwrap_or_default(),
                    "name": r.name,
                    "path": r.path,
                    "bin": paths::bin(&r.path),
                    "ts": r.ts,
                    "undo": r.id.is_some(),
                })
            })
            .collect();
        json!({
            "active": active,
            "recent": recent,
            "activeName": self.active.first().map(|a| a.name.as_str()).unwrap_or(""),
            "activePct": 0,
            "count": self.recent.len(),
        })
    }
}

fn speed(bps: f64) -> String {
    if bps <= 0.0 {
        return String::new();
    }
    let (v, u) = if bps >= 1e6 { (bps / 1e6, "MB/S") } else { (bps / 1e3, "KB/S") };
    format!("{v:.1} {u}")
}

pub struct Daemon {
    pub rules: Rules,
    pub sort: SortConfig,
    pub moves: MoveLog,
    pub downloads: Downloads,
    // The last data pushed to each feed, re-sent when the shell (re)connects.
    pub feeds: BTreeMap<String, Value>,
    pub shell: ShellState,
    // Paths dotd itself put in ~/Downloads (an undo): not sorted again.
    pub ignore: HashSet<PathBuf>,
    shell_down: bool,
}

pub type Shared = Rc<RefCell<Daemon>>;

impl Daemon {
    pub fn new() -> Daemon {
        let mut d = Daemon {
            rules: Rules::default(),
            sort: SortConfig::default(),
            moves: MoveLog::open(paths::state_dir().join("moves.log")),
            downloads: Downloads::default(),
            feeds: BTreeMap::new(),
            shell: ShellState::default(),
            ignore: HashSet::new(),
            shell_down: false,
        };
        if let Err(e) = d.reload() {
            eprintln!("dotd: {e:#}");
        }
        d.seed_downloads();
        d
    }

    pub fn reload(&mut self) -> Result<()> {
        let dir = paths::config_dir();
        self.rules = Rules::load(&dir.join("rules.toml"))?;
        self.sort = SortConfig::load(&dir.join("sort.toml"))?;
        eprintln!("dotd: {} rules, {} sort targets", self.rules.rules.len(), self.sort.rules.len());
        Ok(())
    }

    // The recent list at start: files sitting in ~/Downloads and the moves
    // still in place, newest first.
    fn seed_downloads(&mut self) {
        let mut all: Vec<Recent> = Vec::new();
        if let Ok(rd) = std::fs::read_dir(paths::downloads()) {
            for e in rd.flatten() {
                let name = e.file_name().to_string_lossy().into_owned();
                let Ok(meta) = e.metadata() else { continue };
                if !meta.is_file() || name.starts_with('.') || crate::downloads::partial(&name) {
                    continue;
                }
                let ts = meta
                    .modified()
                    .ok()
                    .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                    .map(|d| d.as_millis() as u64)
                    .unwrap_or(0);
                all.push(Recent { id: None, name, path: e.path(), ts });
            }
        }
        for m in self.moves.moves.iter().filter(|m| !m.undone && m.to.exists()) {
            let name = m.to.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
            all.push(Recent { id: Some(m.id), name, path: m.to.clone(), ts: m.at });
        }
        all.sort_by(|a, b| b.ts.cmp(&a.ts));
        all.truncate(RECENT);
        self.downloads.recent = all;
        self.feeds.insert("downloads".into(), self.downloads.json());
    }
}

// ── Feeds ───────────────────────────────────────────────────────────

pub async fn push(d: &Shared, id: &str, data: Value, merge: bool) {
    let data = {
        let mut dm = d.borrow_mut();
        let entry = dm.feeds.entry(id.to_string()).or_insert_with(|| json!({}));
        match (merge, entry.as_object_mut(), data.as_object()) {
            (true, Some(old), Some(new)) => {
                for (k, v) in new {
                    old.insert(k.clone(), v.clone());
                }
            }
            _ => *entry = data,
        }
        entry.clone()
    };
    send_feed(d, id, &data).await;
}

async fn send_feed(d: &Shared, id: &str, data: &Value) {
    match shell::feed(id, data, false).await {
        Ok(()) => d.borrow_mut().shell_down = false,
        Err(e) => {
            // Said once until it comes back; the feeds go out again when it does.
            let mut dm = d.borrow_mut();
            if !dm.shell_down {
                eprintln!("dotd: feed {id}: {e:#}");
                dm.shell_down = true;
            }
        }
    }
}

pub async fn resend_feeds(d: &Shared) {
    let feeds: Vec<(String, Value)> = d.borrow().feeds.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
    for (id, data) in feeds {
        send_feed(d, &id, &data).await;
    }
}

pub async fn push_downloads(d: &Shared) {
    let data = d.borrow().downloads.json();
    push(d, "downloads", data, false).await;
}

// ── Events ──────────────────────────────────────────────────────────

pub async fn handle(d: &Shared, mut e: Event) {
    let rules: Vec<Rule> = d.borrow().rules.for_event(&e);
    for r in rules {
        if r.sort {
            sort(d, &mut e);
        }
        if r.index {
            index(&e);
        }
        if let Some(feed) = &r.feed {
            if feed == "downloads" && e.source == "downloads" {
                if let Some(path) = e.field("path") {
                    let id = e.data.get("move").and_then(Value::as_u64);
                    let name = e.field("name").unwrap_or_default();
                    d.borrow_mut().downloads.add(Recent { id, name, path: path.into(), ts: e.at });
                }
                push_downloads(d).await;
            } else {
                push(d, feed, Value::Object(e.data.clone()), true).await;
            }
        }
        if let Some(n) = &r.notify {
            let note = Note {
                title: e.fill(&n.title),
                body: e.fill(&n.body),
                urgency: n.urgency.clone(),
                actions: n
                    .actions
                    .iter()
                    .filter(|a| a.as_str() != "undo" || e.data.contains_key("move"))
                    .map(|a| (a.clone(), notify::label(a)))
                    .collect(),
            };
            let (d2, e2) = (d.clone(), e.clone());
            tokio::task::spawn_local(async move {
                if let Some(a) = notify::send(note).await {
                    act(&d2, &a, &e2).await;
                }
            });
        }
    }
}

// A notification's action. open / reveal go through the shell's panel
// actions, so they open the same way a panel click does.
async fn act(d: &Shared, action: &str, e: &Event) {
    let path = e.field("path").unwrap_or_default();
    let r = match action {
        "open" | "reveal" => shell::action(&format!("{action} {path}")).await,
        "undo" => match e.data.get("move").and_then(Value::as_u64) {
            Some(id) => undo(d, Some(id)).await.map(drop),
            None => Ok(()),
        },
        _ => shell::action(&e.fill(action)).await,
    };
    if let Err(err) = r {
        eprintln!("dotd: {action}: {err:#}");
    }
}

fn sort(d: &Shared, e: &mut Event) {
    let Some(path) = e.field("path").map(PathBuf::from) else { return };
    let name = e.field("name").unwrap_or_default();
    let mime = e.field("mime").unwrap_or_default();
    let domain = e.field("domain").unwrap_or_default();
    let mut dm = d.borrow_mut();
    let Some(dir) = dm.sort.target(&mime, &ext_of(&name), &domain) else { return };
    if path.parent() == Some(dir.as_path()) || !path.exists() {
        return;
    }
    match dm.moves.sort(&path, &dir) {
        Ok(m) => {
            eprintln!("dotd: sorted {} -> {}", path.display(), m.to.display());
            set_path(e, &m.to);
            e.data.insert("move".into(), m.id.into());
            e.data.insert("from".into(), path.to_string_lossy().into());
        }
        Err(err) => eprintln!("dotd: sort {}: {err:#}", path.display()),
    }
}

pub fn set_path(e: &mut Event, p: &Path) {
    let s = |x: &Path| Value::String(x.to_string_lossy().into_owned());
    e.data.insert("path".into(), s(p));
    if let Some(n) = p.file_name() {
        e.data.insert("name".into(), n.to_string_lossy().into_owned().into());
    }
    if let Some(dir) = p.parent() {
        e.data.insert("dir".into(), s(dir));
    }
    e.data.insert("bin".into(), paths::bin(p).into());
}

// The index (Phase 12) reads this queue; until then files wait in it.
fn index(e: &Event) {
    let Some(path) = e.field("path") else { return };
    let q = paths::state_dir().join("index.queue");
    let line = json!({ "path": path, "at": now_ms(), "source": e.source });
    let r = std::fs::create_dir_all(paths::state_dir()).and_then(|_| {
        let mut f = std::fs::OpenOptions::new().create(true).append(true).open(&q)?;
        writeln!(f, "{line}")
    });
    if let Err(err) = r {
        eprintln!("dotd: index queue: {err}");
    }
}

// Undo a move (None = the last); the file goes back to ~/Downloads and the
// feed shows it there.
pub async fn undo(d: &Shared, id: Option<u64>) -> Result<PathBuf> {
    let back = {
        let mut dm = d.borrow_mut();
        let (m, back) = dm.moves.undo(id)?;
        dm.ignore.insert(back.clone());
        let name = back.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        dm.downloads.recent.retain(|r| r.id != Some(m.id));
        dm.downloads.add(Recent { id: None, name, path: back.clone(), ts: now_ms() });
        back
    };
    eprintln!("dotd: undo -> {}", back.display());
    push_downloads(d).await;
    Ok(back)
}

pub fn finished(path: &Path, size: u64) -> Event {
    let mut data = Map::new();
    let mime = mime_guess::from_path(path).first_or_octet_stream().essence_str().to_string();
    let name = path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    data.insert("ext".into(), ext_of(&name).into());
    data.insert("mime".into(), mime.into());
    data.insert("size".into(), size.into());
    let mut e = Event::new("downloads", "finished", data);
    set_path(&mut e, path);
    e
}
