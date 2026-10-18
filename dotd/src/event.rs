// An event: something a source saw.
//   { "source": "downloads", "kind": "finished", "at": 1760000000000,
//     "data": { "path": "…", "name": "…", "mime": "application/pdf" } }
// Rules match on source, kind and data fields; sinks read data.

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Event {
    pub source: String,
    pub kind: String,
    #[serde(default = "now_ms")]
    pub at: u64,
    #[serde(default)]
    pub data: Map<String, Value>,
}

impl Event {
    pub fn new(source: &str, kind: &str, data: Map<String, Value>) -> Self {
        Event { source: source.into(), kind: kind.into(), at: now_ms(), data }
    }

    // A data field as text: strings as they are, other values as JSON.
    pub fn field(&self, key: &str) -> Option<String> {
        match key {
            "source" => Some(self.source.clone()),
            "kind" => Some(self.kind.clone()),
            _ => self.data.get(key).map(|v| match v {
                Value::String(s) => s.clone(),
                other => other.to_string(),
            }),
        }
    }

    // "{name} saved to {bin}" with the event's fields; unknown keys stay as written.
    pub fn fill(&self, template: &str) -> String {
        let mut out = String::new();
        let mut rest = template;
        while let Some(i) = rest.find('{') {
            out.push_str(&rest[..i]);
            match rest[i..].find('}') {
                Some(j) => {
                    let key = &rest[i + 1..i + j];
                    match self.field(key) {
                        Some(v) => out.push_str(&v),
                        None => out.push_str(&rest[i..i + j + 1]),
                    }
                    rest = &rest[i + j + 1..];
                }
                None => {
                    out.push_str(&rest[i..]);
                    rest = "";
                }
            }
        }
        out.push_str(rest);
        out
    }
}

pub fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

// Shell-style globs with * only: "image/*", "*.pdf", "exact".
pub fn glob(pattern: &str, text: &str) -> bool {
    let parts: Vec<&str> = pattern.split('*').collect();
    if parts.len() == 1 {
        return pattern == text;
    }
    let (first, last) = (parts[0], parts[parts.len() - 1]);
    if !text.starts_with(first) || text.len() < first.len() + last.len() || !text.ends_with(last) {
        return false;
    }
    let mut pos = first.len();
    let end = text.len() - last.len();
    for mid in &parts[1..parts.len() - 1] {
        match text[pos..end].find(mid) {
            Some(i) => pos += i + mid.len(),
            None => return false,
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn globs() {
        assert!(glob("image/*", "image/png"));
        assert!(!glob("image/*", "video/mp4"));
        assert!(glob("*", ""));
        assert!(glob("a*b*c", "aXXbYYc"));
        assert!(!glob("a*b*c", "acb"));
        assert!(glob("exact", "exact"));
    }

    #[test]
    fn fills() {
        let mut d = Map::new();
        d.insert("name".into(), "a.pdf".into());
        d.insert("size".into(), 12.into());
        let e = Event::new("downloads", "finished", d);
        assert_eq!(e.fill("{name} ({size}) {nope} {kind"), "a.pdf (12) {nope} {kind");
    }
}
