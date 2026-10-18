// dotd's socket, $XDG_RUNTIME_DIR/dotd.sock: one JSON object per line each
// way. Requests carry an optional "id", echoed in the reply.
//   {"source":"git","kind":"dirty","data":{…}}     an event (scripts, sources)
//   {"cmd":"event","source":…,"kind":…,"data":…}   the same
//   {"cmd":"shell","idle":false,"ac":true,"temp":52}
//                                                   the shell's state (no reply);
//                                                   a new shell gets the feeds again
//   {"cmd":"undo","arg":"7"}                        undo a sort ("" = the last)
//   {"cmd":"query","q":"f red bike"}                search (the index, Phase 12)
//   {"cmd":"status"}  {"cmd":"reload"}  {"cmd":"feeds"}

use crate::daemon::{self, Shared};
use crate::event::{Event, now_ms};
use crate::paths;
use anyhow::Result;
use serde_json::{Value, json};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::mpsc;

pub async fn run(d: Shared, events: mpsc::UnboundedSender<Event>) -> Result<()> {
    let path = paths::socket();
    // A socket left by a dotd that died; a live one answers, so refuse then.
    if UnixStream::connect(&path).await.is_ok() {
        anyhow::bail!("another dotd is running ({})", path.display());
    }
    let _ = std::fs::remove_file(&path);
    let listener = UnixListener::bind(&path)?;
    eprintln!("dotd: listening on {}", path.display());
    loop {
        let (stream, _) = listener.accept().await?;
        let (d, events) = (d.clone(), events.clone());
        tokio::task::spawn_local(async move {
            if let Err(e) = client(d, events, stream).await {
                eprintln!("dotd: client: {e:#}");
            }
        });
    }
}

async fn client(d: Shared, events: mpsc::UnboundedSender<Event>, stream: UnixStream) -> Result<()> {
    let (r, mut w) = stream.into_split();
    let mut lines = BufReader::new(r).lines();
    let mut greeted = false;
    while let Some(line) = lines.next_line().await? {
        let req: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(e) => {
                w.write_all(format!("{}\n", json!({ "ok": false, "error": e.to_string() })).as_bytes()).await?;
                continue;
            }
        };
        let cmd = req.get("cmd").and_then(Value::as_str).unwrap_or(if req.get("source").is_some() { "event" } else { "" });
        if cmd == "shell" {
            {
                let mut dm = d.borrow_mut();
                dm.shell.idle = req["idle"].as_bool().unwrap_or(false);
                dm.shell.ac = req["ac"].as_bool().unwrap_or(true);
                dm.shell.temp = req["temp"].as_i64().unwrap_or(0);
                dm.shell.seen = now_ms();
            }
            if !greeted {
                greeted = true;
                daemon::resend_feeds(&d).await;
            }
            continue;
        }
        let mut reply = answer(&d, &events, cmd, &req).await;
        if let (Some(id), Some(obj)) = (req.get("id"), reply.as_object_mut()) {
            obj.insert("id".into(), id.clone());
        }
        w.write_all(format!("{reply}\n").as_bytes()).await?;
    }
    Ok(())
}

async fn answer(d: &Shared, events: &mpsc::UnboundedSender<Event>, cmd: &str, req: &Value) -> Value {
    let arg = req.get("arg").and_then(Value::as_str).unwrap_or("").trim();
    match cmd {
        "event" => match serde_json::from_value::<Event>(req.clone()) {
            Ok(e) => {
                let _ = events.send(e);
                json!({ "ok": true })
            }
            Err(e) => json!({ "ok": false, "error": format!("an event needs source and kind: {e}") }),
        },
        "undo" => {
            let id = if arg.is_empty() { None } else { arg.parse().ok() };
            if !arg.is_empty() && id.is_none() {
                return json!({ "ok": false, "error": "undo takes a move id" });
            }
            match daemon::undo(d, id).await {
                Ok(back) => json!({ "ok": true, "path": back }),
                Err(e) => json!({ "ok": false, "error": format!("{e:#}") }),
            }
        }
        // The index arrives in Phase 12; until then nothing matches.
        "query" => json!({ "ok": true, "results": [] }),
        "reload" => match d.borrow_mut().reload() {
            Ok(()) => json!({ "ok": true }),
            Err(e) => json!({ "ok": false, "error": format!("{e:#}") }),
        },
        "feeds" => {
            daemon::resend_feeds(d).await;
            json!({ "ok": true, "feeds": d.borrow().feeds.keys().collect::<Vec<_>>() })
        }
        "status" => {
            let dm = d.borrow();
            json!({
                "ok": true,
                "rules": dm.rules.rules.len(),
                "sort": dm.sort.rules.len(),
                "moves": dm.moves.moves.iter().filter(|m| !m.undone).count(),
                "active": dm.downloads.active.len(),
                "feeds": dm.feeds.keys().collect::<Vec<_>>(),
                "shell": dm.shell,
            })
        }
        _ => json!({ "ok": false, "error": "unknown cmd; one of: event shell undo query reload feeds status" }),
    }
}
