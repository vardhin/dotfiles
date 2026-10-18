// dotd bench [--int8] [--threads N] [--detailed] IMAGE...
// Runs the models in this process (not the daemon's) on the given images
// and prints what each one says and how long each step took, to size the
// heavy tier on this CPU.
//
// dotd bench --near TEXT
// The index's nearest texts (e5) and images (MobileCLIP) to TEXT, with
// their cosines, to set TEXT_MIN and IMAGE_MIN in index.rs.

use crate::ml::{self, ClipText, ClipVision, E5, Florence};
use anyhow::Result;
use std::path::Path;
use std::time::Instant;

pub fn run(args: &[String]) -> Result<()> {
    if args.first().map(String::as_str) == Some("--near") {
        return near(&args[1..].join(" "));
    }
    let mut threads = 4;
    let mut variant = "";
    let mut detailed = false;
    let mut files = Vec::new();
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--int8" => variant = "_int8",
            "--detailed" => detailed = true,
            "--threads" => threads = it.next().and_then(|n| n.parse().ok()).unwrap_or(4),
            _ => files.push(a.clone()),
        }
    }
    let ms = |t: Instant| t.elapsed().as_secs_f64() * 1000.0;

    let t = Instant::now();
    let mut e5 = E5::load(threads)?;
    let mut ct = ClipText::load(threads)?;
    let mut cv = ClipVision::load(threads)?;
    let mut fl = Florence::load(threads, variant)?;
    println!("load: {:.0} ms ({threads} threads, florence{variant})", ms(t));

    let passage = format!("passage: {}", "The quick brown fox jumps over the lazy dog near the river bank. ".repeat(40));
    let t = Instant::now();
    e5.embed(&[passage])?;
    println!("e5: 512-token passage {:.0} ms", ms(t));
    let t = Instant::now();
    e5.embed(&["query: red bike at night".into()])?;
    println!("e5: query {:.0} ms", ms(t));

    let labels = ["a photo of a person", "a screenshot of a computer screen", "a photo of a cat", "a photo of food", "a landscape photo", "a document with text", "a drawing or illustration"];
    let t = Instant::now();
    let lv: Vec<Vec<f32>> = labels.iter().map(|l| ct.embed(l)).collect::<Result<_>>()?;
    println!("clip text: {:.0} ms per query", ms(t) / labels.len() as f64);

    for f in &files {
        println!("\n== {f}");
        let t = Instant::now();
        let img = ml::load_image(Path::new(f), "")?;
        println!("  decode {}x{}: {:.0} ms", img.width(), img.height(), ms(t));
        let t = Instant::now();
        let v = cv.embed(&img)?;
        let clip = ms(t);
        let mut sims: Vec<(f32, &str)> = lv.iter().zip(labels).map(|(l, n)| (ml::dot(&v, l), n)).collect();
        sims.sort_by(|a, b| b.0.total_cmp(&a.0));
        println!("  clip: {clip:.0} ms; best {:.3} {}, then {:.3} {}", sims[0].0, sims[0].1, sims[1].0, sims[1].1);
        let t = Instant::now();
        let feats = fl.features(&img)?;
        println!("  florence vision: {:.0} ms", ms(t));
        let t = Instant::now();
        let cap = fl.caption(&feats, detailed)?;
        println!("  caption: {:.0} ms: {cap}", ms(t));
        let t = Instant::now();
        let objs = fl.objects(&feats)?;
        let names: Vec<&str> = objs.iter().map(|o| o.label.as_str()).collect();
        println!("  objects: {:.0} ms: {}", ms(t), names.join(", "));
        let t = Instant::now();
        let text = fl.ocr(&feats)?;
        println!("  ocr: {:.0} ms: {}", ms(t), text.chars().take(120).collect::<String>().replace('\n', " "));
    }
    Ok(())
}

fn near(q: &str) -> Result<()> {
    let db = crate::index::open(&crate::index::db_path())?;
    let tv = E5::load(2)?.embed(&[format!("query: {q}")])?.remove(0);
    let iv = ClipText::load(2)?.embed(q)?;
    for (kind, v) in [(crate::index::VecKind::Text, tv), (crate::index::VecKind::Image, iv)] {
        println!("== {kind:?}");
        for (hash, sim) in crate::index::knn(&db, kind, &v, 12)? {
            let path: String = db
                .query_row("SELECT path FROM files WHERE hash = ?1", [&hash], |r| r.get(0))
                .unwrap_or_else(|_| "(gone)".into());
            println!("  {sim:.3}  {path}");
        }
    }
    Ok(())
}
