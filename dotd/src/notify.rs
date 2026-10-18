// Notifications through notify-send (libnotify), so they land in the shell's
// notification daemon and its history like any app's. With actions,
// notify-send waits for the click and prints the chosen action's name.

use std::process::Stdio;
use tokio::process::Command;

pub struct Note {
    pub title: String,
    pub body: String,
    pub urgency: String,
    // (name, label)
    pub actions: Vec<(String, String)>,
}

// The action clicked, if any. Returns when the notification closes.
pub async fn send(n: Note) -> Option<String> {
    let mut cmd = Command::new("notify-send");
    cmd.args(["-a", "dotd", "-u", &n.urgency]);
    for (name, label) in &n.actions {
        cmd.arg(format!("--action={name}={label}"));
    }
    cmd.arg("--").arg(&n.title).arg(&n.body);
    cmd.stdin(Stdio::null()).stderr(Stdio::null()).kill_on_drop(true);
    match cmd.output().await {
        Ok(out) => {
            let a = String::from_utf8_lossy(&out.stdout).trim().to_string();
            (!a.is_empty()).then_some(a)
        }
        Err(e) => {
            eprintln!("dotd: notify-send: {e}");
            None
        }
    }
}

pub fn label(action: &str) -> String {
    match action {
        "open" => "Open",
        "reveal" => "Show in folder",
        "undo" => "Undo",
        other => other,
    }
    .to_string()
}
