// The models dotd runs itself, on ONNX Runtime (ort), CPU only. Their files
// live in ~/.local/share/dotd/models (fetched by dotd-models); a missing one
// turns its feature off, it does not stop dotd.
//
//   E5          multilingual-e5-small, int8: 384-d text vectors, for files'
//               text ("passage: …") and for queries ("query: …")
//   ClipVision  MobileCLIP-S2 image tower: 512-d vectors for images and
//   ClipText    video frames, and its text tower for queries, so "red bike
//               at night" finds a photo with no words in it
//   Florence    Florence-2-base-ft: a caption, the objects in an image and
//               the text in it, by greedy decoding
//
// Every vector is L2-normalised, so a dot product is the cosine.

use crate::paths;
use anyhow::{Context, Result, bail};
use image::{DynamicImage, ImageDecoder, ImageReader, RgbImage, imageops::FilterType};
use ort::session::{Session, builder::GraphOptimizationLevel};
use ort::value::{DynValue, Tensor, TensorRef};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use tokenizers::{Tokenizer, TruncationParams};

pub fn models_dir() -> PathBuf {
    paths::data_dir().join("models")
}

fn env() -> Result<&'static ort::environment::Environment> {
    static ENV: OnceLock<Result<ort::environment::Environment, String>> = OnceLock::new();
    ENV.get_or_init(|| ort::init().with_name("dotd").build().map_err(|e| e.to_string()))
        .as_ref()
        .map_err(|e| anyhow::anyhow!("onnx runtime: {e}"))
}

// No spinning: a spinning pool keeps cores busy between runs, and the heavy
// tier is meant to be invisible.
fn session(path: &Path, threads: usize) -> Result<Session> {
    if !path.exists() {
        bail!("{} is missing (run dotd-models)", path.display());
    }
    let env = env()?;
    let build = || -> ort::Result<Session> {
        Ok(Session::builder(env)?
            .with_optimization_level(GraphOptimizationLevel::Level3)?
            .with_intra_threads(threads)?
            .with_inter_threads(1)?
            .with_intra_op_spinning(false)?
            .commit_from_file(path)?)
    };
    build().with_context(|| format!("load {}", path.display()))
}

fn tokenizer(path: &Path) -> Result<Tokenizer> {
    Tokenizer::from_file(path).map_err(|e| anyhow::anyhow!("{}: {e}", path.display()))
}

fn normalize(v: &mut [f32]) {
    let n = v.iter().map(|x| x * x).sum::<f32>().sqrt().max(1e-12);
    v.iter_mut().for_each(|x| *x /= n);
}

pub fn dot(a: &[f32], b: &[f32]) -> f32 {
    a.iter().zip(b).map(|(x, y)| x * y).sum()
}

// The calling thread, and threads it starts from now on (ONNX Runtime's
// pools), run only when the CPU has nothing else to do.
pub fn sched_idle() {
    let p = libc::sched_param { sched_priority: 0 };
    if unsafe { libc::sched_setscheduler(0, libc::SCHED_IDLE, &p) } != 0 {
        eprintln!("dotd: SCHED_IDLE: {}", std::io::Error::last_os_error());
    }
}

// ── Loaded once, shared ─────────────────────────────────────────────

// A model loaded on first use and kept (32 GB of memory: nothing is
// unloaded). A load that failed is not tried again until reset (dotd reload).
pub struct Slot<T> {
    name: &'static str,
    state: Mutex<SlotState<T>>,
}

enum SlotState<T> {
    Empty,
    Ready(T),
    Failed,
}

impl<T> Slot<T> {
    pub fn new(name: &'static str) -> Slot<T> {
        Slot { name, state: Mutex::new(SlotState::Empty) }
    }

    // None when the model cannot be had.
    pub fn with<R>(&self, load: impl FnOnce() -> Result<T>, f: impl FnOnce(&mut T) -> Result<R>) -> Option<Result<R>> {
        let mut g = self.state.lock().unwrap_or_else(|p| p.into_inner());
        if let SlotState::Empty = *g {
            *g = match load() {
                Ok(m) => SlotState::Ready(m),
                Err(e) => {
                    eprintln!("dotd: {}: {e:#}", self.name);
                    SlotState::Failed
                }
            };
        }
        match &mut *g {
            SlotState::Ready(m) => Some(f(m)),
            _ => None,
        }
    }

    pub fn ready(&self) -> bool {
        matches!(*self.state.lock().unwrap_or_else(|p| p.into_inner()), SlotState::Ready(_))
    }

    pub fn reset(&self) {
        let mut g = self.state.lock().unwrap_or_else(|p| p.into_inner());
        if let SlotState::Failed = *g {
            *g = SlotState::Empty;
        }
    }
}

// What queries and the index worker share: e5 for both, MobileCLIP's text
// tower for queries. Two threads each; neither runs for long.
pub struct Shared {
    pub e5: Slot<E5>,
    pub clip_text: Slot<ClipText>,
}

impl Shared {
    pub fn new() -> Shared {
        Shared { e5: Slot::new("e5"), clip_text: Slot::new("clip text") }
    }

    pub fn e5(&self, texts: &[String]) -> Option<Result<Vec<Vec<f32>>>> {
        self.e5.with(|| E5::load(2), |m| m.embed(texts))
    }

    pub fn clip_text(&self, q: &str) -> Option<Result<Vec<f32>>> {
        self.clip_text.with(|| ClipText::load(2), |m| m.embed(q))
    }

    pub fn reset(&self) {
        self.e5.reset();
        self.clip_text.reset();
    }
}

// ── E5 ──────────────────────────────────────────────────────────────

pub const E5_DIM: usize = 384;

pub struct E5 {
    s: Session,
    tok: Tokenizer,
}

impl E5 {
    pub fn load(threads: usize) -> Result<E5> {
        let dir = models_dir().join("e5");
        let mut tok = tokenizer(&dir.join("tokenizer.json"))?;
        tok.with_truncation(Some(TruncationParams { max_length: 512, ..Default::default() }))
            .map_err(|e| anyhow::anyhow!("{e}"))?;
        Ok(E5 { s: session(&dir.join("model.onnx"), threads)?, tok })
    }

    // Texts carry their own "query: " / "passage: " prefix.
    pub fn embed(&mut self, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        if texts.is_empty() {
            return Ok(Vec::new());
        }
        let enc = self.tok.encode_batch(texts.to_vec(), true).map_err(|e| anyhow::anyhow!("{e}"))?;
        let (b, n) = (enc.len(), enc.iter().map(|e| e.get_ids().len()).max().unwrap_or(1));
        // XLM-R pads with 1.
        let mut ids = vec![1i64; b * n];
        let mut mask = vec![0i64; b * n];
        for (i, e) in enc.iter().enumerate() {
            for (j, &t) in e.get_ids().iter().enumerate() {
                ids[i * n + j] = t as i64;
                mask[i * n + j] = 1;
            }
        }
        let types = vec![0i64; b * n];
        let out = self.s.run(ort::inputs![
            "input_ids" => Tensor::from_array(([b, n], ids))?,
            "attention_mask" => Tensor::from_array(([b, n], mask.clone()))?,
            "token_type_ids" => Tensor::from_array(([b, n], types))?,
        ])?;
        let (_, h) = out["last_hidden_state"].try_extract_tensor::<f32>()?;
        // Mean over the real tokens.
        let mut vs = Vec::with_capacity(b);
        for i in 0..b {
            let mut v = vec![0f32; E5_DIM];
            let mut count = 0f32;
            for j in 0..n {
                if mask[i * n + j] == 1 {
                    let row = &h[(i * n + j) * E5_DIM..(i * n + j + 1) * E5_DIM];
                    v.iter_mut().zip(row).for_each(|(a, x)| *a += x);
                    count += 1.0;
                }
            }
            v.iter_mut().for_each(|a| *a /= count.max(1.0));
            normalize(&mut v);
            vs.push(v);
        }
        Ok(vs)
    }
}

// ── MobileCLIP-S2 ───────────────────────────────────────────────────

pub const CLIP_DIM: usize = 512;
const CLIP_SIZE: u32 = 256;
const CLIP_CTX: usize = 77;

pub struct ClipVision {
    s: Session,
}

impl ClipVision {
    pub fn load(threads: usize) -> Result<ClipVision> {
        Ok(ClipVision { s: session(&models_dir().join("clip/vision.onnx"), threads)? })
    }

    pub fn embed(&mut self, img: &RgbImage) -> Result<Vec<f32>> {
        // Shortest edge to 256 (bilinear), centre crop, 0..1, no mean/std.
        let (w, h) = img.dimensions();
        let s = CLIP_SIZE as f32 / w.min(h) as f32;
        let (nw, nh) = (((w as f32 * s).round() as u32).max(CLIP_SIZE), ((h as f32 * s).round() as u32).max(CLIP_SIZE));
        let r = image::imageops::resize(shrink(img, nw.max(nh) * 2).as_ref(), nw, nh, FilterType::Triangle);
        let (x0, y0) = ((nw - CLIP_SIZE) / 2, (nh - CLIP_SIZE) / 2);
        let px = chw(&r, x0, y0, CLIP_SIZE, |_, v| v);
        let out = self.s.run(ort::inputs!["pixel_values" => Tensor::from_array(([1usize, 3, 256, 256], px))?])?;
        let (_, e) = out["image_embeds"].try_extract_tensor::<f32>()?;
        let mut v = e.to_vec();
        normalize(&mut v);
        Ok(v)
    }
}

pub struct ClipText {
    s: Session,
    tok: Tokenizer,
}

impl ClipText {
    pub fn load(threads: usize) -> Result<ClipText> {
        let dir = models_dir().join("clip");
        Ok(ClipText { s: session(&dir.join("text.onnx"), threads)?, tok: tokenizer(&dir.join("tokenizer.json"))? })
    }

    pub fn embed(&mut self, text: &str) -> Result<Vec<f32>> {
        let enc = self.tok.encode(text, true).map_err(|e| anyhow::anyhow!("{e}"))?;
        let mut ids: Vec<i64> = enc.get_ids().iter().map(|&t| t as i64).collect();
        if ids.len() > CLIP_CTX {
            // Keep the end-of-text token: the model pools at it.
            let eot = *ids.last().unwrap();
            ids.truncate(CLIP_CTX);
            ids[CLIP_CTX - 1] = eot;
        }
        ids.resize(CLIP_CTX, 0);
        let out = self.s.run(ort::inputs!["input_ids" => Tensor::from_array(([1usize, CLIP_CTX], ids))?])?;
        let (_, e) = out["text_embeds"].try_extract_tensor::<f32>()?;
        let mut v = e.to_vec();
        normalize(&mut v);
        Ok(v)
    }
}

// ── Florence-2 ──────────────────────────────────────────────────────

const FL_SIZE: u32 = 768;
const FL_LAYERS: usize = 6;
const FL_HEADS: usize = 12;
const FL_HEAD_DIM: usize = 64;
const FL_D: usize = 768;
const BOS: u32 = 0;
const EOS: u32 = 2;
const LOC0: u32 = 50269;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Task {
    Caption,
    DetailedCaption,
    Objects,
    Ocr,
}

impl Task {
    fn prompt(self) -> &'static str {
        match self {
            Task::Caption => "What does the image describe?",
            Task::DetailedCaption => "Describe with a paragraph what is shown in the image.",
            Task::Objects => "Locate the objects with category name in the image.",
            Task::Ocr => "What is the text in the image?",
        }
    }
    fn max_tokens(self) -> usize {
        match self {
            Task::Caption => 48,
            Task::DetailedCaption => 160,
            Task::Objects => 200,
            Task::Ocr => 160,
        }
    }
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct Object {
    pub label: String,
    // x1 y1 x2 y2 as fractions of the image.
    pub box_: [f32; 4],
}

pub struct Florence {
    vision: Session,
    embed: Session,
    encoder: Session,
    decoder: Session,
    tok: Tokenizer,
}

pub struct Features(Vec<f32>, usize);

impl Florence {
    // variant "" for fp32, "_int8" for the quantised parts.
    pub fn load(threads: usize, variant: &str) -> Result<Florence> {
        let dir = models_dir().join("florence");
        let part = |n: &str| {
            let q = dir.join(format!("{n}{variant}.onnx"));
            session(&if q.exists() { q } else { dir.join(format!("{n}.onnx")) }, threads)
        };
        Ok(Florence {
            vision: part("vision_encoder")?,
            embed: part("embed_tokens")?,
            encoder: part("encoder_model")?,
            decoder: part("decoder_model_merged")?,
            tok: tokenizer(&dir.join("tokenizer.json"))?,
        })
    }

    // The image through the vision tower once; every task reuses it.
    pub fn features(&mut self, img: &RgbImage) -> Result<Features> {
        // Squashed to 768², bicubic, ImageNet mean and std.
        let r = image::imageops::resize(shrink(img, FL_SIZE * 2).as_ref(), FL_SIZE, FL_SIZE, FilterType::CatmullRom);
        const MEAN: [f32; 3] = [0.485, 0.456, 0.406];
        const STD: [f32; 3] = [0.229, 0.224, 0.225];
        let px = chw(&r, 0, 0, FL_SIZE, |c, v| (v - MEAN[c]) / STD[c]);
        let s = FL_SIZE as usize;
        let out = self.vision.run(ort::inputs!["pixel_values" => Tensor::from_array(([1, 3, s, s], px))?])?;
        let (shape, f) = out["image_features"].try_extract_tensor::<f32>()?;
        Ok(Features(f.to_vec(), shape[1] as usize))
    }

    fn embed_ids(&mut self, ids: &[i64]) -> Result<Vec<f32>> {
        let out = self.embed.run(ort::inputs!["input_ids" => TensorRef::from_array_view(([1, ids.len()], ids))?])?;
        Ok(out["inputs_embeds"].try_extract_tensor::<f32>()?.1.to_vec())
    }

    // Greedy decoding with the model's own rules: </s> starts, <s> is forced
    // first, no 3-gram repeats, </s> ends.
    fn generate(&mut self, feats: &Features, task: Task) -> Result<Vec<u32>> {
        let enc = self.tok.encode(task.prompt(), true).map_err(|e| anyhow::anyhow!("{e}"))?;
        let ids: Vec<i64> = enc.get_ids().iter().map(|&t| t as i64).collect();
        let mut x = feats.0.clone();
        x.extend(self.embed_ids(&ids)?);
        let len = feats.1 + ids.len();
        let mask = vec![1i64; len];
        let hidden = {
            let out = self.encoder.run(ort::inputs![
                "attention_mask" => TensorRef::from_array_view(([1, len], mask.as_slice()))?,
                "inputs_embeds" => TensorRef::from_array_view(([1, len, FL_D], x.as_slice()))?,
            ])?;
            out["last_hidden_state"].try_extract_tensor::<f32>()?.1.to_vec()
        };

        let empty = || Tensor::<f32>::from_array(([1usize, FL_HEADS, 0, FL_HEAD_DIM], Vec::<f32>::new()));
        let mut past_dec: Vec<(DynValue, DynValue)> = Vec::new();
        let mut past_enc: Vec<(DynValue, DynValue)> = Vec::new();
        for _ in 0..FL_LAYERS {
            past_dec.push((empty()?.into_dyn(), empty()?.into_dyn()));
            past_enc.push((empty()?.into_dyn(), empty()?.into_dyn()));
        }
        let mut seq: Vec<u32> = vec![EOS];
        for step in 0..task.max_tokens() {
            let emb = self.embed_ids(&[*seq.last().unwrap() as i64])?;
            let mut inputs: Vec<(std::borrow::Cow<str>, ort::session::SessionInputValue)> = vec![
                ("encoder_attention_mask".into(), Tensor::from_array(([1, len], mask.clone()))?.into()),
                ("encoder_hidden_states".into(), TensorRef::from_array_view(([1, len, FL_D], hidden.as_slice()))?.into()),
                ("inputs_embeds".into(), Tensor::from_array(([1usize, 1, FL_D], emb))?.into()),
                ("use_cache_branch".into(), Tensor::from_array(([1usize], vec![step > 0]))?.into()),
            ];
            for (i, ((dk, dv), (ek, ev))) in past_dec.iter().zip(&past_enc).enumerate() {
                inputs.push((format!("past_key_values.{i}.decoder.key").into(), dk.into()));
                inputs.push((format!("past_key_values.{i}.decoder.value").into(), dv.into()));
                inputs.push((format!("past_key_values.{i}.encoder.key").into(), ek.into()));
                inputs.push((format!("past_key_values.{i}.encoder.value").into(), ev.into()));
            }
            let mut out = self.decoder.run(inputs)?;
            let (shape, logits) = out["logits"].try_extract_tensor::<f32>()?;
            let v = shape[2] as usize;
            let last = &logits[logits.len() - v..];
            let next = if step == 0 { BOS } else { pick(last, &seq) };
            let mut dec = Vec::with_capacity(FL_LAYERS);
            let mut encs = Vec::with_capacity(FL_LAYERS);
            for i in 0..FL_LAYERS {
                let mut take = |k: &str| out.remove(format!("present.{i}.{k}")).context("decoder output");
                dec.push((take("decoder.key")?, take("decoder.value")?));
                if step == 0 {
                    encs.push((take("encoder.key")?, take("encoder.value")?));
                }
            }
            drop(out);
            past_dec = dec;
            if step == 0 {
                past_enc = encs;
            }
            seq.push(next);
            if next == EOS {
                break;
            }
        }
        Ok(seq)
    }

    pub fn caption(&mut self, f: &Features, detailed: bool) -> Result<String> {
        let seq = self.generate(f, if detailed { Task::DetailedCaption } else { Task::Caption })?;
        Ok(self.text(&seq))
    }

    pub fn ocr(&mut self, f: &Features) -> Result<String> {
        let seq = self.generate(f, Task::Ocr)?;
        Ok(self.text(&seq))
    }

    // "car<loc_52><loc_340><loc_410><loc_600>person<loc_…>…": a label, then
    // one or more boxes of four 0..999 bins each.
    pub fn objects(&mut self, f: &Features) -> Result<Vec<Object>> {
        let seq = self.generate(f, Task::Objects)?;
        let mut out = Vec::new();
        let mut label: Vec<u32> = Vec::new();
        let mut name = String::new();
        let mut bins: Vec<f32> = Vec::new();
        for &t in seq.iter().filter(|&&t| t > EOS) {
            if (LOC0..LOC0 + 1000).contains(&t) {
                if !label.is_empty() {
                    name = self.text(&label);
                    label.clear();
                }
                bins.push(((t - LOC0) as f32 + 0.5) / 1000.0);
                if bins.len() == 4 {
                    if !name.is_empty() {
                        let b = [bins[0], bins[1], bins[2], bins[3]].map(|v| (v * 1000.0).round() / 1000.0);
                        out.push(Object { label: name.clone(), box_: b });
                    }
                    bins.clear();
                }
            } else {
                label.push(t);
                bins.clear();
            }
        }
        Ok(out)
    }

    fn text(&self, ids: &[u32]) -> String {
        let ids: Vec<u32> = ids.iter().copied().filter(|&t| t > EOS && !(LOC0..LOC0 + 1000).contains(&t)).collect();
        self.tok.decode(&ids, true).map(|s| s.trim().to_string()).unwrap_or_default()
    }
}

// The best next token that does not repeat a 3-gram already in `seq`.
fn pick(logits: &[f32], seq: &[u32]) -> u32 {
    let mut banned: Vec<u32> = Vec::new();
    if seq.len() >= 2 {
        let tail = &seq[seq.len() - 2..];
        for w in seq.windows(3) {
            if w[..2] == *tail {
                banned.push(w[2]);
            }
        }
    }
    let mut best = (EOS, f32::NEG_INFINITY);
    for (i, &l) in logits.iter().enumerate() {
        if l > best.1 && !banned.contains(&(i as u32)) {
            best = (i as u32, l);
        }
    }
    best.0
}

// ── Images ──────────────────────────────────────────────────────────

// An image as RGB, turned the way its EXIF says. GIFs give their first
// frame. What the image crate cannot read (HEIC, RAW, AVIF) comes from the
// thumbnail the thumbs extractor made, when there is one.
pub fn load_image(path: &Path, hash: &str) -> Result<RgbImage> {
    let direct = || -> Result<DynamicImage> {
        let mut dec = ImageReader::open(path)?.with_guessed_format()?.into_decoder()?;
        let o = dec.orientation()?;
        let mut img = DynamicImage::from_decoder(dec)?;
        img.apply_orientation(o);
        Ok(img)
    };
    match direct() {
        Ok(img) => Ok(img.into_rgb8()),
        Err(e) => {
            let thumb = paths::data_dir().join("thumbs").join(format!("{hash}.png"));
            if thumb.exists() {
                Ok(image::open(&thumb)?.into_rgb8())
            } else {
                Err(e)
            }
        }
    }
}

// A big photo is first cut down to about `max` px a side with a fast box
// filter; the exact resize after it then has little to do.
fn shrink(img: &RgbImage, max: u32) -> std::borrow::Cow<'_, RgbImage> {
    let (w, h) = img.dimensions();
    if w.max(h) <= max {
        return std::borrow::Cow::Borrowed(img);
    }
    let s = max as f32 / w.max(h) as f32;
    let (nw, nh) = (((w as f32 * s) as u32).max(1), ((h as f32 * s) as u32).max(1));
    std::borrow::Cow::Owned(image::imageops::thumbnail(img, nw, nh))
}

// A size² square from (x0, y0) as planar CHW floats, each 0..1 value passed
// through f(channel, value).
fn chw(img: &RgbImage, x0: u32, y0: u32, size: u32, f: impl Fn(usize, f32) -> f32) -> Vec<f32> {
    let n = (size * size) as usize;
    let mut px = vec![0f32; 3 * n];
    for y in 0..size {
        for x in 0..size {
            let p = img.get_pixel(x0 + x, y0 + y);
            let i = (y * size + x) as usize;
            for c in 0..3 {
                px[c * n + i] = f(c, p[c] as f32 / 255.0);
            }
        }
    }
    px
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_repeat_trigram() {
        let mut l = vec![0f32; 10];
        l[5] = 9.0;
        l[6] = 8.0;
        // 3 4 5 seen; after 3 4 again, 5 is banned.
        assert_eq!(pick(&l, &[3, 4, 5, 3, 4]), 6);
        assert_eq!(pick(&l, &[3, 4]), 5);
    }
}
