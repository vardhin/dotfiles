// The downloads source: inotify on ~/Downloads (and ~/.config/dotd, to pick
// up rule edits).
//   finished   a file closed after writing, or renamed into place (Firefox's
//              .part, Chromium's .crdownload). It must sit still for SETTLE
//              first, so an "open when done" finds it before it is sorted,
//              and a file that is still empty (Firefox's placeholder) waits.
//   active     .part / .crdownload / .download files, their size polled every
//              second for the speed. No percentage until the browser
//              extension (Phase 15) says how big the file will be. One that
//              stops growing for STALE is a dead download and not shown.
// Files already in ~/Downloads when dotd starts are left where they are.

use crate::daemon::{self, Active, Shared};
use anyhow::Result;
use futures_util::StreamExt;
use inotify::{EventMask, Inotify, WatchMask};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{Duration, Instant};
use tokio::sync::mpsc;

use crate::event::Event;
use crate::paths;

const SETTLE: Duration = Duration::from_secs(2);
const TICK: Duration = Duration::from_millis(500);
// A partial file that has not grown for this long is a dead download.
const STALE: Duration = Duration::from_secs(600);

pub fn partial(name: &str) -> bool {
    [".part", ".crdownload", ".download", ".partial"].iter().any(|s| name.ends_with(s))
}

fn skip(name: &str) -> bool {
    name.starts_with('.') || name.ends_with('~') || name.ends_with(".tmp")
}

pub async fn run(d: Shared, events: mpsc::UnboundedSender<Event>) -> Result<()> {
    let dir = paths::downloads();
    std::fs::create_dir_all(&dir)?;
    let conf = paths::config_dir();

    let ino = Inotify::init()?;
    let dl_wd = ino.watches().add(
        &dir,
        WatchMask::CREATE | WatchMask::CLOSE_WRITE | WatchMask::MOVED_TO | WatchMask::MOVED_FROM | WatchMask::DELETE,
    )?;
    let conf_wd = match ino.watches().add(&conf, WatchMask::CLOSE_WRITE | WatchMask::MOVED_TO) {
        Ok(wd) => Some(wd),
        Err(_) => None,
    };
    let mut stream = ino.into_event_stream([0u8; 4096])?;

    // Downloads in progress when dotd starts.
    if let Ok(rd) = std::fs::read_dir(&dir) {
        let mut dm = d.borrow_mut();
        for e in rd.flatten() {
            let name = e.file_name().to_string_lossy().into_owned();
            if partial(&name) {
                track(&mut dm.downloads.active, &name, e.path());
            }
        }
    }

    let mut pending: HashMap<PathBuf, Instant> = HashMap::new();
    let mut tick = tokio::time::interval(TICK);
    let mut last_poll = Instant::now();

    loop {
        tokio::select! {
            ev = stream.next() => {
                let Some(ev) = ev else { break };
                let ev = ev?;
                let Some(name) = ev.name.map(|n| n.to_string_lossy().into_owned()) else { continue };
                if Some(&ev.wd) == conf_wd.as_ref() {
                    if name == "rules.toml" || name == "sort.toml" {
                        if let Err(e) = d.borrow_mut().reload() {
                            eprintln!("dotd: {e:#}");
                        }
                    }
                    continue;
                }
                if ev.wd != dl_wd || skip(&name) || ev.mask.contains(EventMask::ISDIR) {
                    continue;
                }
                let path = dir.join(&name);
                let gone = ev.mask.intersects(EventMask::DELETE | EventMask::MOVED_FROM);
                if partial(&name) {
                    let changed = {
                        let active = &mut d.borrow_mut().downloads.active;
                        if gone {
                            let n = active.len();
                            active.retain(|a| a.path != path);
                            n != active.len()
                        } else {
                            track(active, &name, path)
                        }
                    };
                    if changed {
                        daemon::push_downloads(&d).await;
                    }
                } else if gone {
                    pending.remove(&path);
                } else if ev.mask.intersects(EventMask::CLOSE_WRITE | EventMask::MOVED_TO) {
                    if d.borrow_mut().ignore.remove(&path) {
                        continue;
                    }
                    pending.insert(path, Instant::now() + SETTLE);
                }
            }
            _ = tick.tick() => {
                let now = Instant::now();
                let due: Vec<PathBuf> = pending.iter().filter(|(_, t)| **t <= now).map(|(p, _)| p.clone()).collect();
                for path in due {
                    pending.remove(&path);
                    let Ok(meta) = std::fs::metadata(&path) else { continue };
                    if !meta.is_file() || meta.len() == 0 {
                        continue;
                    }
                    // Still being written by something: wait for its next close.
                    let name = path.file_name().unwrap().to_string_lossy().into_owned();
                    if [".part", ".crdownload"].iter().any(|s| dir.join(format!("{name}{s}")).exists()) {
                        continue;
                    }
                    let _ = events.send(daemon::finished(&path, meta.len()));
                }
                if now.duration_since(last_poll) >= Duration::from_secs(1) {
                    last_poll = now;
                    if poll(&d) {
                        daemon::push_downloads(&d).await;
                    }
                }
            }
        }
    }
    Ok(())
}

// Start tracking a partial file; true if it is new.
fn track(active: &mut Vec<Active>, name: &str, path: PathBuf) -> bool {
    if active.iter().any(|a| a.path == path) {
        return false;
    }
    let shown = [".part", ".crdownload", ".download", ".partial"]
        .iter()
        .find_map(|s| name.strip_suffix(s))
        .unwrap_or(name);
    let Ok(meta) = std::fs::metadata(&path) else { return false };
    let age = meta.modified().ok().and_then(|t| t.elapsed().ok()).unwrap_or_default();
    if age >= STALE {
        return false;
    }
    let now = Instant::now();
    active.push(Active { name: shown.to_string(), path, size: meta.len(), speed: 0.0, checked: now, grew: now });
    true
}

// Sizes and speeds of the active downloads; true if anything shown changed.
fn poll(d: &Shared) -> bool {
    let mut dm = d.borrow_mut();
    let active = &mut dm.downloads.active;
    if active.is_empty() {
        return false;
    }
    let before = active.len();
    active.retain(|a| a.path.exists() && a.grew.elapsed() < STALE);
    let mut changed = before != active.len();
    for a in active.iter_mut() {
        let size = std::fs::metadata(&a.path).map(|m| m.len()).unwrap_or(a.size);
        let dt = a.checked.elapsed().as_secs_f64().max(0.001);
        let speed = size.saturating_sub(a.size) as f64 / dt;
        // Smoothed, so the readout does not flicker.
        a.speed = if a.speed == 0.0 { speed } else { a.speed * 0.6 + speed * 0.4 };
        if size != a.size {
            changed = true;
            a.grew = Instant::now();
        }
        a.size = size;
        a.checked = Instant::now();
    }
    changed
}
