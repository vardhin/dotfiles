// ~/.config/dotd/sort.toml: where a finished download goes.
//
//   [[sort]]
//   to   = "~/Pictures/Downloads"
//   mime = ["image/*"]
//   ext  = ["heic"]
//   domain = ["*.unsplash.com"]        (once the browser extension sends it)
//
// First match wins; a file nothing matches stays in ~/Downloads. A move keeps
// the name, and a clash gets a numeric suffix ("a (1).pdf"). Every move is a
// line in ~/.local/state/dotd/moves.log, so it can be undone:
//   {"id":7,"at":…,"from":"…/Downloads/a.pdf","to":"…/Documents/Downloads/a.pdf"}
//   {"id":7,"at":…,"undone":true}

use crate::event::{glob, now_ms};
use crate::paths;
use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

#[derive(Debug, Default, Deserialize)]
pub struct SortConfig {
    #[serde(default, rename = "sort")]
    pub rules: Vec<SortRule>,
}

#[derive(Debug, Deserialize)]
pub struct SortRule {
    pub to: String,
    #[serde(default)]
    pub mime: Vec<String>,
    #[serde(default)]
    pub ext: Vec<String>,
    #[serde(default)]
    pub domain: Vec<String>,
}

impl SortConfig {
    pub fn load(path: &Path) -> Result<SortConfig> {
        match fs::read_to_string(path) {
            Ok(text) => toml::from_str(&text).with_context(|| format!("{}", path.display())),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(SortConfig::default()),
            Err(e) => Err(e).with_context(|| format!("{}", path.display())),
        }
    }

    pub fn target(&self, mime: &str, ext: &str, domain: &str) -> Option<PathBuf> {
        let ext = ext.to_lowercase();
        self.rules
            .iter()
            .find(|r| {
                r.mime.iter().any(|p| glob(p, mime))
                    || r.ext.iter().any(|x| x.to_lowercase() == ext)
                    || (!domain.is_empty() && r.domain.iter().any(|p| glob(p, domain)))
            })
            .map(|r| paths::expand(&r.to))
    }
}

// "a.tar.gz" -> ("a", ".tar.gz"); "a.pdf" -> ("a", ".pdf"); "a" -> ("a", "")
pub fn split_name(name: &str) -> (&str, &str) {
    let lower = name.to_lowercase();
    for double in [".pkg.tar.zst", ".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2"] {
        if lower.ends_with(double) && name.len() > double.len() {
            let i = name.len() - double.len();
            return (&name[..i], &name[i..]);
        }
    }
    match name.rfind('.') {
        Some(i) if i > 0 => (&name[..i], &name[i..]),
        _ => (name, ""),
    }
}

// The extension without its dot, as sort.toml's ext lists name it ("tar.gz").
pub fn ext_of(name: &str) -> String {
    split_name(name).1.trim_start_matches('.').to_lowercase()
}

// A free path for `name` in `dir`: the name itself, or "stem (n).ext".
pub fn free_path(dir: &Path, name: &str) -> PathBuf {
    let p = dir.join(name);
    if !p.exists() {
        return p;
    }
    let (stem, ext) = split_name(name);
    (1..)
        .map(|n| dir.join(format!("{stem} ({n}){ext}")))
        .find(|p| !p.exists())
        .unwrap()
}

// rename, or copy and remove across filesystems.
pub fn move_file(from: &Path, to: &Path) -> Result<()> {
    if let Some(dir) = to.parent() {
        fs::create_dir_all(dir).with_context(|| format!("mkdir {}", dir.display()))?;
    }
    match fs::rename(from, to) {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(18) => {
            // EXDEV
            fs::copy(from, to).with_context(|| format!("copy to {}", to.display()))?;
            fs::remove_file(from).with_context(|| format!("remove {}", from.display()))
        }
        Err(e) => Err(e).with_context(|| format!("move {} to {}", from.display(), to.display())),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Move {
    pub id: u64,
    pub at: u64,
    #[serde(default)]
    pub from: PathBuf,
    #[serde(default)]
    pub to: PathBuf,
    #[serde(default)]
    pub undone: bool,
}

// moves.log, read once at start and appended to.
pub struct MoveLog {
    path: PathBuf,
    pub moves: Vec<Move>,
}

impl MoveLog {
    pub fn open(path: PathBuf) -> MoveLog {
        let mut moves: Vec<Move> = Vec::new();
        if let Ok(text) = fs::read_to_string(&path) {
            for m in text.lines().filter_map(|l| serde_json::from_str::<Move>(l).ok()) {
                if m.undone {
                    if let Some(prev) = moves.iter_mut().find(|x| x.id == m.id) {
                        prev.undone = true;
                    }
                } else {
                    moves.push(m);
                }
            }
        }
        MoveLog { path, moves }
    }

    fn append(&self, line: &Move) -> Result<()> {
        if let Some(dir) = self.path.parent() {
            fs::create_dir_all(dir)?;
        }
        let mut f = fs::OpenOptions::new().create(true).append(true).open(&self.path)?;
        let mut v = serde_json::to_value(line)?;
        let obj = v.as_object_mut().unwrap();
        if line.undone {
            obj.remove("from");
            obj.remove("to");
        } else {
            obj.remove("undone");
        }
        writeln!(f, "{v}")?;
        Ok(())
    }

    // Move `from` into `dir`, logged. Returns the move.
    pub fn sort(&mut self, from: &Path, dir: &Path) -> Result<Move> {
        let name = from.file_name().context("no file name")?.to_string_lossy().into_owned();
        let to = free_path(dir, &name);
        move_file(from, &to)?;
        let m = Move {
            id: self.moves.iter().map(|m| m.id).max().unwrap_or(0) + 1,
            at: now_ms(),
            from: from.to_path_buf(),
            to,
            undone: false,
        };
        self.append(&m)?;
        self.moves.push(m.clone());
        Ok(m)
    }

    // Put a move back: the file returns to where it came from (with a suffix
    // if something took its name meanwhile). None = the last move not undone.
    // Returns the move and the path the file is back at.
    pub fn undo(&mut self, id: Option<u64>) -> Result<(Move, PathBuf)> {
        let i = match id {
            Some(id) => self.moves.iter().position(|m| m.id == id),
            None => self.moves.iter().rposition(|m| !m.undone),
        };
        let Some(i) = i else { bail!("no such move") };
        let m = self.moves[i].clone();
        if m.undone {
            bail!("move {} is already undone", m.id);
        }
        if !m.to.exists() {
            bail!("{} is gone", m.to.display());
        }
        let dir = m.from.parent().context("no folder")?;
        let name = m.from.file_name().context("no file name")?.to_string_lossy().into_owned();
        let back = free_path(dir, &name);
        move_file(&m.to, &back)?;
        self.moves[i].undone = true;
        self.append(&Move { undone: true, at: now_ms(), ..m.clone() })?;
        Ok((m, back))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names() {
        assert_eq!(split_name("a.tar.gz"), ("a", ".tar.gz"));
        assert_eq!(split_name("a.b.pdf"), ("a.b", ".pdf"));
        assert_eq!(split_name(".hidden"), (".hidden", ""));
        assert_eq!(split_name("noext"), ("noext", ""));
        assert_eq!(ext_of("X.PDF"), "pdf");
    }

    #[test]
    fn sort_and_undo() {
        let t = std::env::temp_dir().join(format!("dotd-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&t);
        let (dl, docs) = (t.join("dl"), t.join("docs"));
        fs::create_dir_all(&dl).unwrap();
        fs::create_dir_all(&docs).unwrap();
        fs::write(dl.join("a.pdf"), "1").unwrap();
        fs::write(docs.join("a.pdf"), "old").unwrap();

        let mut log = MoveLog::open(t.join("moves.log"));
        let m = log.sort(&dl.join("a.pdf"), &docs).unwrap();
        assert_eq!(m.to, docs.join("a (1).pdf"));
        assert!(!dl.join("a.pdf").exists());

        let log2 = MoveLog::open(t.join("moves.log"));
        assert_eq!(log2.moves.len(), 1);

        let (_, back) = log.undo(None).unwrap();
        assert_eq!(back, dl.join("a.pdf"));
        assert!(log.undo(Some(m.id)).is_err());
        let log3 = MoveLog::open(t.join("moves.log"));
        assert!(log3.moves[0].undone);
        fs::remove_dir_all(&t).unwrap();
    }
}
