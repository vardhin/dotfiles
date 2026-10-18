// ~/.config/dotd/rules.toml: what happens to an event.
//
//   [[rule]]
//   match  = { source = "downloads", kind = "finished" }
//   sort   = true                      move it by sort.toml (first, so the
//                                      rest see the new path)
//   index  = true                      queue it for the index
//   feed   = "downloads"               push to a shell feed
//   notify = { title = "Downloaded", body = "{name} → {bin}", urgency = "low",
//              actions = ["open", "reveal", "undo"] }
//
// Rules are tried in order and the first match runs; `continue = true` lets
// the next ones be tried too. match keys are source, kind or any data field;
// values are globs with * ("image/*").

use crate::event::{Event, glob};
use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Debug, Default, Deserialize)]
pub struct Rules {
    #[serde(default, rename = "rule")]
    pub rules: Vec<Rule>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Rule {
    #[serde(default, rename = "match")]
    pub when: BTreeMap<String, String>,
    #[serde(default)]
    pub notify: Option<Notify>,
    #[serde(default)]
    pub feed: Option<String>,
    #[serde(default)]
    pub sort: bool,
    #[serde(default)]
    pub index: bool,
    #[serde(default, rename = "continue")]
    pub go_on: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Notify {
    pub title: String,
    #[serde(default)]
    pub body: String,
    #[serde(default = "low")]
    pub urgency: String,
    #[serde(default)]
    pub actions: Vec<String>,
}

fn low() -> String {
    "low".into()
}

impl Rule {
    pub fn matches(&self, e: &Event) -> bool {
        self.when
            .iter()
            .all(|(k, pat)| e.field(k).is_some_and(|v| glob(pat, &v)))
    }
}

impl Rules {
    pub fn load(path: &Path) -> Result<Rules> {
        match std::fs::read_to_string(path) {
            Ok(text) => toml::from_str(&text).with_context(|| format!("{}", path.display())),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Rules::default()),
            Err(e) => Err(e).with_context(|| format!("{}", path.display())),
        }
    }

    // The rules that run for an event, in order.
    pub fn for_event(&self, e: &Event) -> Vec<Rule> {
        let mut out = Vec::new();
        for r in &self.rules {
            if r.matches(e) {
                out.push(r.clone());
                if !r.go_on {
                    break;
                }
            }
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Map;

    #[test]
    fn first_match_wins() {
        let rules: Rules = toml::from_str(
            r#"
            [[rule]]
            match = { source = "downloads", mime = "image/*" }
            feed = "pics"
            continue = true
            [[rule]]
            match = { source = "downloads" }
            feed = "downloads"
            [[rule]]
            match = { source = "downloads" }
            feed = "never"
            "#,
        )
        .unwrap();
        let mut d = Map::new();
        d.insert("mime".into(), "image/png".into());
        let e = Event::new("downloads", "finished", d);
        let feeds: Vec<_> = rules.for_event(&e).into_iter().filter_map(|r| r.feed).collect();
        assert_eq!(feeds, ["pics", "downloads"]);
    }
}
