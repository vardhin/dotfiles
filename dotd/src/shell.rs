// The shell's side: Dot Shell's `dot` socket ($XDG_RUNTIME_DIR/dotshell.sock),
// one JSON request per connection, one line back, the same as bin/dot.
// dotd uses it to push feeds and to run panel actions (open, reveal).

use crate::paths;
use anyhow::{Context, Result, bail};
use serde_json::{Value, json};
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::time::timeout;

pub async fn call(req: Value) -> Result<Value> {
    let run = async {
        let mut s = UnixStream::connect(paths::shell_socket()).await.context("Dot Shell is not running")?;
        s.write_all(format!("{req}\n").as_bytes()).await?;
        let mut line = String::new();
        BufReader::new(s).read_line(&mut line).await?;
        let reply: Value = serde_json::from_str(&line).context("no reply from Dot Shell")?;
        if reply.get("ok") != Some(&Value::Bool(true)) {
            bail!("{}", reply.get("error").and_then(Value::as_str).unwrap_or("refused"));
        }
        Ok(reply)
    };
    timeout(Duration::from_secs(5), run).await.context("Dot Shell did not answer")?
}

pub async fn feed(id: &str, data: &Value, merge: bool) -> Result<()> {
    call(json!({ "cmd": "feed", "id": id, "data": data, "merge": merge })).await.map(drop)
}

pub async fn action(run: &str) -> Result<()> {
    call(json!({ "cmd": "action", "run": run })).await.map(drop)
}
