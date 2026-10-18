// The heavy tier, on its own thread at SCHED_IDLE with at most four
// ONNX Runtime threads. It runs only while the laptop is on AC, the shell
// says you have been idle (2 min), and the CPU is below max_temp; it stops
// between files when any of that ends, and a hot CPU must cool 8 °C before
// it starts again. Newest files first:
//
//   clip      MobileCLIP-S2 vector of every image (≥ 16 KB), and of five
//             frames of every video                    ~0.15 s an image
//   florence  Florence-2 caption, objects (as tags) and text of every
//             image; the text only when tesseract found none
//                                                      ~4–5 s an image
//
// clip goes first over the whole backlog: it is what lets a query find a
// photo by what it shows, and it is thirty times cheaper.
//
// index.toml:
//   [heavy]
//   enabled = true
//   threads = 4
//   max_temp = 80     °C
//   idle = true       false: run while you work too
//   ac = true         false: run on battery too
//   captions = true   false: clip only

use crate::extract::{self, Extractor};
use crate::index::{self, Msg, VecKind};
use crate::ml::{self, ClipVision, Florence};
use anyhow::{Context, Result, bail};
use image::RgbImage;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Deserialize)]
pub struct HeavyConfig {
    #[serde(default = "yes")]
    pub enabled: bool,
    #[serde(default = "four")]
    pub threads: usize,
    #[serde(default = "eighty")]
    pub max_temp: i64,
    #[serde(default = "yes")]
    pub idle: bool,
    #[serde(default = "yes")]
    pub ac: bool,
    #[serde(default = "yes")]
    pub captions: bool,
}

fn yes() -> bool {
    true
}
fn four() -> usize {
    4
}
fn eighty() -> i64 {
    80
}

impl Default for HeavyConfig {
    fn default() -> Self {
        toml::from_str("").unwrap()
    }
}

// The shell's state, set from its socket messages (server.rs).
#[derive(Debug, Default)]
pub struct Gate {
    pub idle: AtomicBool,
    pub ac: AtomicBool,
    pub temp: AtomicI64,
}

impl Gate {
    pub fn set(&self, idle: bool, ac: bool, temp: i64) {
        self.idle.store(idle, Ordering::Relaxed);
        self.ac.store(ac, Ordering::Relaxed);
        self.temp.store(temp, Ordering::Relaxed);
    }
}

// What dotd status shows.
#[derive(Debug, Default, Clone, Serialize)]
pub struct Status {
    pub state: String,
    pub temp: i64,
    pub clip: u64,
    pub florence: u64,
    // Moving averages, ms per file.
    pub clip_ms: u64,
    pub florence_ms: u64,
    pub last: String,
}

struct Heavy {
    db: Connection,
    gate: Arc<Gate>,
    status: Arc<Mutex<Status>>,
    nudge: Sender<Msg>,
    cfg: HeavyConfig,
    max_text: usize,
    read_cfg: Instant,
    clip: Option<ClipVision>,
    florence: Option<Florence>,
    // Models that would not load, until the config is saved again.
    broken: Vec<String>,
    hot: bool,
    sensor: Option<PathBuf>,
    // As in the worker: the mtime each one's search goes on below. Cleared
    // every few minutes, so new files are found.
    cursors: HashMap<String, i64>,
    cursors_at: Instant,
}

pub fn run(db: Connection, gate: Arc<Gate>, status: Arc<Mutex<Status>>, nudge: Sender<Msg>) {
    ml::sched_idle();
    // The walk can hold the database for a while; this thread can wait.
    let _ = db.busy_timeout(Duration::from_secs(120));
    let cfg = index::load_config();
    let mut h = Heavy {
        db,
        gate,
        status,
        nudge,
        max_text: cfg.max_text,
        cfg: cfg.heavy,
        read_cfg: Instant::now(),
        clip: None,
        florence: None,
        broken: Vec::new(),
        hot: false,
        sensor: sensor(),
        cursors: HashMap::new(),
        cursors_at: Instant::now(),
    };
    loop {
        let wait = h.tick();
        if !wait.is_zero() {
            std::thread::sleep(wait);
        }
    }
}

impl Heavy {
    fn set(&self, state: &str) {
        let mut s = self.status.lock().unwrap();
        if s.state != state {
            eprintln!("dotd: heavy: {state}");
            s.state = state.into();
        }
    }

    // One file, or how long to wait before looking again.
    fn tick(&mut self) -> Duration {
        if self.read_cfg.elapsed() > Duration::from_secs(30) {
            let c = index::load_config();
            if c.heavy.threads != self.cfg.threads {
                self.clip = None;
                self.florence = None;
            }
            self.cfg = c.heavy;
            self.max_text = c.max_text;
            self.broken.clear();
            self.read_cfg = Instant::now();
        }
        if let Some(why) = self.closed() {
            self.set(&why);
            return Duration::from_secs(15);
        }
        if self.cursors_at.elapsed() > Duration::from_secs(300) {
            self.cursors.clear();
            self.cursors_at = Instant::now();
        }
        let mut xs = vec![extract::clip()];
        if self.cfg.captions {
            xs.push(extract::florence());
        }
        for x in xs {
            if self.broken.contains(&x.name) {
                continue;
            }
            let below = *self.cursors.get(&x.name).unwrap_or(&i64::MAX);
            match index::due(&self.db, &x, below) {
                Ok(Some((mtime, path, hash, mime))) => {
                    self.cursors.insert(x.name.clone(), mtime);
                    self.set("running");
                    if let Err(e) = self.job(&x, &path, &hash, &mime) {
                        eprintln!("dotd: heavy: {} on {path}: {e:#}", x.name);
                    }
                    return Duration::ZERO;
                }
                Ok(None) => {
                    self.cursors.insert(x.name.clone(), i64::MIN);
                }
                Err(e) => {
                    eprintln!("dotd: heavy: {e:#}");
                    return Duration::from_secs(30);
                }
            }
        }
        self.set("done");
        Duration::from_secs(60)
    }

    // Why it may not run now, if it may not.
    fn closed(&mut self) -> Option<String> {
        if !self.cfg.enabled {
            return Some("off".into());
        }
        let temp = self.sensor.as_deref().and_then(read_temp).unwrap_or_else(|| self.gate.temp.load(Ordering::Relaxed));
        self.status.lock().unwrap().temp = temp;
        if self.cfg.ac && !self.gate.ac.load(Ordering::Relaxed) {
            return Some("waiting for AC".into());
        }
        if self.cfg.idle && !self.gate.idle.load(Ordering::Relaxed) {
            return Some("waiting for idle".into());
        }
        if temp > self.cfg.max_temp {
            self.hot = true;
        } else if temp <= self.cfg.max_temp - 8 {
            self.hot = false;
        }
        if self.hot {
            return Some(format!("cooling ({temp} °C)"));
        }
        None
    }

    fn job(&mut self, x: &Extractor, path: &str, hash: &str, mime: &str) -> Result<()> {
        let t = Instant::now();
        let r = if x.name == "clip" { self.clip(path, hash, mime) } else { self.florence(path, hash) };
        let (ok, out) = match r {
            Ok(Some(v)) => (true, v),
            // The model is missing: not a fact about the file.
            Ok(None) => return Ok(()),
            Err(e) => {
                eprintln!("dotd: heavy: {} on {path}: {e:#}", x.name);
                (false, json!({ "error": format!("{e:#}") }))
            }
        };
        let text = x.name == "florence" && ok;
        index::record(&self.db, self.max_text, x, hash, mime, ok, out, text)?;
        if text {
            let _ = self.nudge.send(Msg::Nudge);
        }
        let ms = t.elapsed().as_millis() as u64;
        let mut g = self.status.lock().unwrap();
        let s = &mut *g;
        let (n, avg) = if x.name == "clip" { (&mut s.clip, &mut s.clip_ms) } else { (&mut s.florence, &mut s.florence_ms) };
        *n += 1;
        *avg = if *avg == 0 { ms } else { (*avg * 9 + ms) / 10 };
        s.last = path.into();
        Ok(())
    }

    fn clip(&mut self, path: &str, hash: &str, mime: &str) -> Result<Option<Value>> {
        let frames = if mime.starts_with("video/") { frames(Path::new(path), 5)? } else { vec![ml::load_image(Path::new(path), hash)?] };
        if frames.is_empty() {
            bail!("no frames");
        }
        if self.clip.is_none() {
            match ClipVision::load(self.cfg.threads) {
                Ok(m) => self.clip = Some(m),
                Err(e) => {
                    eprintln!("dotd: heavy: {e:#}");
                    self.broken.push("clip".into());
                    return Ok(None);
                }
            }
        }
        let m = self.clip.as_mut().unwrap();
        let vs: Vec<Vec<f32>> = frames.iter().map(|f| m.embed(f)).collect::<Result<_>>()?;
        index::put_vecs(&self.db, hash, VecKind::Image, &vs)?;
        Ok(Some(json!({ "frames": vs.len() })))
    }

    fn florence(&mut self, path: &str, hash: &str) -> Result<Option<Value>> {
        let img = ml::load_image(Path::new(path), hash)?;
        if self.florence.is_none() {
            match Florence::load(self.cfg.threads, "") {
                Ok(m) => self.florence = Some(m),
                Err(e) => {
                    eprintln!("dotd: heavy: {e:#}");
                    self.broken.push("florence".into());
                    return Ok(None);
                }
            }
        }
        // Tesseract read the screenshots and scans already, and better.
        let read = index::read_derived(hash)
            .get("extractors")
            .and_then(|x| x.get("ocr"))
            .and_then(|o| o.get("text"))
            .and_then(Value::as_str)
            .is_some_and(|t| t.trim().len() >= 20);
        let m = self.florence.as_mut().unwrap();
        let f = m.features(&img)?;
        let caption = m.caption(&f, false)?;
        let objects = m.objects(&f)?;
        let mut tags: Vec<String> = Vec::new();
        for o in &objects {
            if !tags.contains(&o.label) {
                tags.push(o.label.clone());
            }
        }
        let mut out = json!({ "caption": caption, "tags": tags, "objects": objects });
        if !read {
            let text = m.ocr(&f)?;
            // A word or two of noise is what it reads in a photo with none.
            if text.chars().filter(|c| c.is_alphanumeric()).count() >= 4 {
                out["text"] = text.into();
            }
        }
        Ok(Some(out))
    }
}

// n frames spread through a video (at 10, 30, 50, 70, 90 % for five), each
// about 320 px tall.
fn frames(path: &Path, n: usize) -> Result<Vec<RgbImage>> {
    let out = Command::new("ffprobe")
        .args(["-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0"])
        .arg(path)
        .output()
        .context("ffprobe")?;
    let dur: f64 = String::from_utf8_lossy(&out.stdout).trim().parse().context("no duration")?;
    let mut imgs = Vec::new();
    for i in 0..n {
        let at = format!("{:.2}", dur * (i as f64 + 0.5) / n as f64);
        let out = Command::new("timeout")
            .args(["60", "ffmpeg", "-v", "quiet", "-ss", &at, "-i"])
            .arg(path)
            .args(["-frames:v", "1", "-vf", "scale=-2:320", "-f", "image2pipe", "-c:v", "png", "-"])
            .output()
            .context("ffmpeg")?;
        if out.status.success() && !out.stdout.is_empty() {
            if let Ok(img) = image::load_from_memory(&out.stdout) {
                imgs.push(img.into_rgb8());
            }
        }
    }
    Ok(imgs)
}

// The CPU's sensor, as Sys.qml finds it: the first hwmon named k10temp,
// coretemp, zenpower or cpu_thermal.
fn sensor() -> Option<PathBuf> {
    let rd = std::fs::read_dir("/sys/class/hwmon").ok()?;
    let mut hs: Vec<PathBuf> = rd.flatten().map(|e| e.path()).collect();
    hs.sort();
    hs.into_iter().find(|h| {
        let name = std::fs::read_to_string(h.join("name")).unwrap_or_default();
        ["k10temp", "coretemp", "zenpower", "cpu_thermal"].contains(&name.trim()) && h.join("temp1_input").exists()
    }).map(|h| h.join("temp1_input"))
}

fn read_temp(p: &Path) -> Option<i64> {
    std::fs::read_to_string(p).ok()?.trim().parse::<i64>().ok().map(|m| m / 1000)
}
