// Extractors: plugins that read a file and say what is in it. Each is a
// manifest in ~/.config/dotd/extractors/<name>.toml next to its program:
//
//   name    = "pdf-text"
//   mimes   = ["application/pdf"]       globs with *
//   exts    = []                        and/or extensions
//   tier    = "cheap"                   cheap (at once) | medium (queued)
//   version = 1                         bump to re-run it over the index
//   exec    = "pdf-text"                in that folder, or on PATH
//   timeout = 30                        seconds
//   max_size = 200000000                bytes; bigger files are skipped
//   min_size = 0                        bytes; smaller files are skipped
//
// The program gets the file's path as its one argument, and in the
// environment DOTD_HASH (the content hash), DOTD_MIME and DOTD_THUMBS (a
// folder for thumbnails). It prints one JSON object:
//   { "text": "…", "title": "…", "tags": ["…"], "meta": { … } }
// all optional; {} means nothing to say. A non-zero exit is a failure; it is
// recorded, so the file is not tried again until the version changes.
//
// Three more are built in and run inside dotd on its own models (ml.rs):
// e5 (cheap: text vectors of what the others found), and the heavy tier,
// clip (image and video-frame vectors) and florence (captions, objects,
// text), which heavy.rs runs only on AC, idle and a cool CPU.

use crate::paths;
use anyhow::{Context, Result, bail};
use serde::Deserialize;
use serde_json::Value;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Deserialize)]
pub struct Extractor {
    pub name: String,
    #[serde(default)]
    pub mimes: Vec<String>,
    #[serde(default)]
    pub exts: Vec<String>,
    #[serde(default = "cheap")]
    pub tier: String,
    #[serde(default = "one")]
    pub version: i64,
    pub exec: String,
    #[serde(default = "thirty")]
    pub timeout: u64,
    #[serde(default = "max_size")]
    pub max_size: u64,
    #[serde(default)]
    pub min_size: u64,
    #[serde(skip)]
    pub dir: PathBuf,
    #[serde(skip)]
    pub builtin: bool,
}

fn cheap() -> String {
    "cheap".into()
}
fn one() -> i64 {
    1
}
fn thirty() -> u64 {
    30
}
fn max_size() -> u64 {
    200_000_000
}

pub const TIERS: [&str; 2] = ["cheap", "medium"];

// Bump a version to re-run that one over the index.
// e5 2: prose only, no code, logs or data.
pub const E5_VERSION: i64 = 2;
pub const CLIP_VERSION: i64 = 1;
pub const FLORENCE_VERSION: i64 = 1;

// Images the models can read (HEIC and AVIF through their thumbnail); below
// 16 KB they are icons and UI bits, not pictures.
const IMAGES: [&str; 9] =
    ["image/jpeg", "image/png", "image/webp", "image/gif", "image/bmp", "image/tiff", "image/heic", "image/heif", "image/avif"];

fn builtin(name: &str, tier: &str, version: i64, mimes: &[&str], min_size: u64, max_size: u64) -> Extractor {
    Extractor {
        name: name.into(),
        mimes: mimes.iter().map(|m| m.to_string()).collect(),
        exts: Vec::new(),
        tier: tier.into(),
        version,
        exec: String::new(),
        timeout: 0,
        max_size,
        min_size,
        dir: PathBuf::new(),
        builtin: true,
    }
}

// e5 takes any file another extractor found text in; its query is its own.
pub fn e5() -> Extractor {
    builtin("e5", "cheap", E5_VERSION, &[], 0, u64::MAX)
}

pub fn clip() -> Extractor {
    let mut m = IMAGES.to_vec();
    m.push("video/*");
    builtin("clip", "heavy", CLIP_VERSION, &m, 16_000, 100_000_000_000)
}

pub fn florence() -> Extractor {
    builtin("florence", "heavy", FLORENCE_VERSION, &IMAGES, 16_000, 400_000_000)
}

pub fn load() -> Vec<Extractor> {
    let dir = paths::config_dir().join("extractors");
    let mut out: Vec<Extractor> = Vec::new();
    let Ok(rd) = std::fs::read_dir(&dir) else { return out };
    let mut files: Vec<PathBuf> = rd.flatten().map(|e| e.path()).filter(|p| p.extension().is_some_and(|x| x == "toml")).collect();
    files.sort();
    for f in files {
        match std::fs::read_to_string(&f).map_err(anyhow::Error::from).and_then(|t| Ok(toml::from_str::<Extractor>(&t)?)) {
            Ok(mut x) => {
                if ["e5", "clip", "florence"].contains(&x.name.as_str()) {
                    eprintln!("dotd: {}: {} is built in", f.display(), x.name);
                    continue;
                }
                if !TIERS.contains(&x.tier.as_str()) {
                    eprintln!("dotd: {}: tier must be cheap or medium (heavy runs inside dotd)", f.display());
                    continue;
                }
                x.dir = dir.clone();
                out.push(x);
            }
            Err(e) => eprintln!("dotd: {}: {e:#}", f.display()),
        }
    }
    // Last in its tier, so on the same file the plugins go first and e5
    // embeds what they found.
    out.push(e5());
    out
}

impl Extractor {
    fn program(&self) -> PathBuf {
        let local = self.dir.join(&self.exec);
        if local.exists() { local } else { PathBuf::from(&self.exec) }
    }

    pub fn run(&self, path: &Path, hash: &str, mime: &str) -> Result<Value> {
        let thumbs = paths::data_dir().join("thumbs");
        let _ = std::fs::create_dir_all(&thumbs);
        let mut child = Command::new(self.program())
            .arg(path)
            .env("DOTD_HASH", hash)
            .env("DOTD_MIME", mime)
            .env("DOTD_THUMBS", &thumbs)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .with_context(|| format!("run {}", self.exec))?;
        // Read while it runs, so a big output cannot fill the pipe and stall it.
        let mut out = child.stdout.take().unwrap();
        let reader = std::thread::spawn(move || {
            let mut buf = Vec::new();
            let _ = out.read_to_end(&mut buf);
            buf
        });
        let deadline = Instant::now() + Duration::from_secs(self.timeout);
        let status = loop {
            if let Some(s) = child.try_wait()? {
                break s;
            }
            if Instant::now() > deadline {
                let _ = child.kill();
                let _ = child.wait();
                bail!("timed out after {} s", self.timeout);
            }
            std::thread::sleep(Duration::from_millis(30));
        };
        let buf = reader.join().unwrap_or_default();
        if !status.success() {
            bail!("exit {}", status.code().unwrap_or(-1));
        }
        let text = String::from_utf8_lossy(&buf);
        let text = text.trim();
        if text.is_empty() {
            return Ok(Value::Object(Default::default()));
        }
        let v: Value = serde_json::from_str(text).context("output is not JSON")?;
        if !v.is_object() {
            bail!("output is not a JSON object");
        }
        Ok(v)
    }
}
