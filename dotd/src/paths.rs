// Where dotd keeps things. XDG variables win; the usual defaults otherwise.
//   config   ~/.config/dotd/{rules,sort}.toml
//   state    ~/.local/state/dotd/{moves.log,index.queue}
//   runtime  $XDG_RUNTIME_DIR/dotd.sock (ours), dotshell.sock (the shell's)

use std::env;
use std::path::{Path, PathBuf};

pub fn home() -> PathBuf {
    env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

fn xdg(var: &str, fallback: &str) -> PathBuf {
    env::var_os(var)
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .unwrap_or_else(|| home().join(fallback))
}

pub fn config_dir() -> PathBuf {
    xdg("XDG_CONFIG_HOME", ".config").join("dotd")
}

pub fn state_dir() -> PathBuf {
    xdg("XDG_STATE_HOME", ".local/state").join("dotd")
}

pub fn runtime_dir() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn socket() -> PathBuf {
    runtime_dir().join("dotd.sock")
}

pub fn shell_socket() -> PathBuf {
    runtime_dir().join("dotshell.sock")
}

pub fn downloads() -> PathBuf {
    home().join("Downloads")
}

// "~/x" -> $HOME/x
pub fn expand(p: &str) -> PathBuf {
    match p.strip_prefix("~/") {
        Some(rest) => home().join(rest),
        None if p == "~" => home(),
        None => PathBuf::from(p),
    }
}

// The folder a file sits in, as the panel's BIN column shows it: the first
// folder under home ("Documents" for ~/Documents/Downloads/x.pdf).
pub fn bin(path: &Path) -> String {
    let h = home();
    path.strip_prefix(&h)
        .ok()
        .and_then(|r| r.components().next())
        .filter(|_| path.parent() != Some(h.as_path()))
        .map(|c| c.as_os_str().to_string_lossy().into_owned())
        .unwrap_or_else(|| "~".into())
}
