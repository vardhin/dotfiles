// Live updates for the index: one inotify watch per folder under the roots
// (the same folders the walk enters), telling the index worker what
// changed. A new folder is watched and walked; a removed or moved-away one
// takes its files out of the index. A full rescan every few hours catches
// anything missed (a watch limit, an overflow).

use crate::index::{Config, Filter, Msg};
use anyhow::Result;
use inotify::{EventMask, Inotify, WatchDescriptor, WatchMask};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::mpsc::Sender;

fn mask() -> WatchMask {
    WatchMask::CLOSE_WRITE | WatchMask::MOVED_TO | WatchMask::MOVED_FROM | WatchMask::DELETE | WatchMask::CREATE | WatchMask::DONT_FOLLOW | WatchMask::ONLYDIR
}

struct Watcher {
    ino: Inotify,
    dirs: HashMap<WatchDescriptor, PathBuf>,
    filter: Filter,
    full: bool,
}

impl Watcher {
    // Watch a folder and every folder below it that the index enters.
    fn add_tree(&mut self, top: &Path) {
        let mut stack = vec![top.to_path_buf()];
        while let Some(d) = stack.pop() {
            match self.ino.watches().add(&d, mask()) {
                Ok(wd) => {
                    self.dirs.insert(wd, d.clone());
                }
                Err(e) => {
                    if !self.full {
                        eprintln!("dotd: watch {}: {e} (raise fs.inotify.max_user_watches; rescans still run)", d.display());
                        self.full = true;
                    }
                    continue;
                }
            }
            let Ok(rd) = std::fs::read_dir(&d) else { continue };
            for e in rd.flatten() {
                if e.file_type().is_ok_and(|t| t.is_dir()) && !self.filter.skip_dir(&e.path()) {
                    stack.push(e.path());
                }
            }
        }
    }
}

pub fn run(cfg: &Config, tx: Sender<Msg>) -> Result<()> {
    let filter = Filter::new(cfg);
    let mut w = Watcher { ino: Inotify::init()?, dirs: HashMap::new(), filter, full: false };
    for r in cfg.roots.iter().map(|r| crate::paths::expand(r)) {
        w.add_tree(&r);
    }
    eprintln!("dotd: index: watching {} folders", w.dirs.len());
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let events: Vec<(WatchDescriptor, EventMask, Option<String>)> = w
            .ino
            .read_events_blocking(&mut buf)?
            .map(|e| (e.wd.clone(), e.mask, e.name.map(|n| n.to_string_lossy().into_owned())))
            .collect();
        for (wd, m, name) in events {
            if m.contains(EventMask::Q_OVERFLOW) {
                let _ = tx.send(Msg::Rescan);
                continue;
            }
            if m.contains(EventMask::IGNORED) {
                w.dirs.remove(&wd);
                continue;
            }
            let (Some(dir), Some(name)) = (w.dirs.get(&wd).cloned(), name) else { continue };
            let p = dir.join(&name);
            if m.intersects(EventMask::DELETE | EventMask::MOVED_FROM) {
                let _ = tx.send(Msg::Gone(p));
            } else if m.contains(EventMask::ISDIR) {
                if m.intersects(EventMask::CREATE | EventMask::MOVED_TO) && !w.filter.skip_dir(&p) && w.filter.wants(&p) {
                    w.add_tree(&p);
                    let _ = tx.send(Msg::Touch(p));
                }
            } else if m.intersects(EventMask::CLOSE_WRITE | EventMask::MOVED_TO) && w.filter.wants(&p) {
                let _ = tx.send(Msg::Touch(p));
            }
        }
    }
}
