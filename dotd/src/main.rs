// dotd: Dot Shell's event daemon. Sources turn what happens on the laptop
// into events, rules (~/.config/dotd/rules.toml) send them to sinks:
// notifications, live panel feeds, the downloads sort and the index queue.
// The shell only renders. Runs as a systemd user service (dotd.service).
//
//   dotd                                run the daemon
//   dotd status | reload | feeds
//   dotd undo [ID]                      put a sorted download back
//   dotd event SOURCE KIND ['{json}']   send an event (for scripts)
//   dotd query TEXT                     search the index
//   dotd rescan                         walk the indexed folders again

mod bench;
mod daemon;
mod downloads;
mod event;
mod extract;
mod heavy;
mod index;
mod ml;
mod notify;
mod paths;
mod rules;
mod server;
mod shell;
mod sort;
mod watch;

use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::cell::RefCell;
use std::rc::Rc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::signal::unix::{SignalKind, signal};
use tokio::sync::mpsc;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("bench") {
        if let Err(e) = bench::run(&args[1..]) {
            eprintln!("dotd: {e:#}");
            std::process::exit(1);
        }
        return;
    }
    let rt = tokio::runtime::Builder::new_current_thread().enable_all().build().unwrap();
    let local = tokio::task::LocalSet::new();
    let r = local.block_on(&rt, async {
        if args.is_empty() || args[0] == "run" { serve().await } else { client(&args).await }
    });
    if let Err(e) = r {
        eprintln!("dotd: {e:#}");
        std::process::exit(1);
    }
}

async fn serve() -> Result<()> {
    let d: daemon::Shared = Rc::new(RefCell::new(daemon::Daemon::new()));
    // The queue file Phase 11 wrote before the index existed: the walk covers it.
    let _ = std::fs::remove_file(paths::state_dir().join("index.queue"));
    match index::Index::spawn() {
        Ok(ix) => d.borrow_mut().index = Some(ix),
        Err(e) => eprintln!("dotd: index: {e:#}"),
    }
    let (tx, mut rx) = mpsc::unbounded_channel::<event::Event>();

    // Feeds out as soon as the shell is there (it may not be yet).
    {
        let d = d.clone();
        tokio::task::spawn_local(async move { daemon::resend_feeds(&d).await });
    }
    {
        let (d, tx) = (d.clone(), tx.clone());
        tokio::task::spawn_local(async move {
            if let Err(e) = downloads::run(d, tx).await {
                eprintln!("dotd: downloads: {e:#}");
            }
        });
    }
    {
        let d = d.clone();
        tokio::task::spawn_local(async move {
            let Ok(mut hup) = signal(SignalKind::hangup()) else { return };
            while hup.recv().await.is_some() {
                if let Err(e) = d.borrow_mut().reload() {
                    eprintln!("dotd: {e:#}");
                }
            }
        });
    }
    {
        let d = d.clone();
        tokio::task::spawn_local(async move {
            while let Some(e) = rx.recv().await {
                daemon::handle(&d, e).await;
            }
        });
    }

    let mut term = signal(SignalKind::terminate())?;
    tokio::select! {
        r = server::run(d.clone(), tx) => r,
        _ = term.recv() => {
            let _ = std::fs::remove_file(paths::socket());
            Ok(())
        }
        _ = tokio::signal::ctrl_c() => {
            let _ = std::fs::remove_file(paths::socket());
            Ok(())
        }
    }
}

async fn client(args: &[String]) -> Result<()> {
    let req = match args[0].as_str() {
        "status" | "reload" | "feeds" | "rescan" => json!({ "cmd": args[0] }),
        "undo" => json!({ "cmd": "undo", "arg": args.get(1).cloned().unwrap_or_default() }),
        "query" => json!({ "cmd": "query", "q": args[1..].join(" ") }),
        "event" => {
            if args.len() < 3 {
                bail!("usage: dotd event SOURCE KIND ['{{json}}']");
            }
            let data: Value = match args.get(3) {
                Some(s) => serde_json::from_str(s).context("event data must be a JSON object")?,
                None => json!({}),
            };
            json!({ "cmd": "event", "source": args[1], "kind": args[2], "data": data })
        }
        "-h" | "--help" | "help" => {
            println!("{}", HELP.trim());
            return Ok(());
        }
        other => bail!("unknown command {other}; see dotd --help"),
    };
    let mut s = UnixStream::connect(paths::socket())
        .await
        .context("dotd is not running (systemctl --user start dotd)")?;
    s.write_all(format!("{req}\n").as_bytes()).await?;
    let mut line = String::new();
    BufReader::new(s).read_line(&mut line).await?;
    let reply: Value = serde_json::from_str(&line).context("no reply from dotd")?;
    if reply["ok"] != Value::Bool(true) {
        bail!("{}", reply["error"].as_str().unwrap_or("refused"));
    }
    println!("{}", serde_json::to_string_pretty(&reply)?);
    Ok(())
}

const HELP: &str = "
dotd: Dot Shell's event daemon

  dotd                                run the daemon (dotd.service does this)
  dotd status | reload | feeds
  dotd undo [ID]                      put a sorted download back (no ID: the last)
  dotd event SOURCE KIND ['{json}']   send an event, for scripts
  dotd query TEXT                     search the index
  dotd rescan                         walk the indexed folders again

Config: ~/.config/dotd/rules.toml, sort.toml, index.toml (reloaded when saved),
        extractors/*.toml (dotd reload)
State:  ~/.local/state/dotd/moves.log
Data:   ~/.local/share/dotd/index.db, derived/<blake3>.json, thumbs/
";
