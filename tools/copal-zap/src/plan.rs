//! A folder, walked and cut into discs.
//!
//! The unit of placement is a *group*, not a file:
//! * files in one directory that share a stem travel together
//!   (`video.mp4` with `video.txt`, `video.en.vtt` with them);
//! * anything two or more levels down travels as its second-level folder
//!   (`top/project/...` is one group: a git checkout is never split).
//!
//! Groups fill discs in path order, so each disc is one contiguous range of
//! names that can be written on its label.

use crate::SECTOR;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

/// Folders under the root that are never planned: copal-zap's own, and where
/// `retire` puts what is already on a verified disc.
pub const SKIP_DIRS: &[&str] = &["_discs", "_burned"];

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    pub bytes: u64,
    /// Nanoseconds since 1970. Whole seconds were not enough: a file
    /// rewritten at the same size within the second it was planned in looked
    /// untouched.
    pub mtime: i128,
    /// Relative to the root, '/'-separated.
    pub path: String,
}

impl Entry {
    /// Sectors on the disc: the data rounded up, and one for its directory
    /// record and Rock Ridge fields.
    pub fn sectors(&self) -> u64 {
        self.bytes.div_ceil(SECTOR) + 1
    }
}

#[derive(Debug, Default)]
pub struct Scan {
    pub entries: Vec<Entry>,
    /// Mac metadata, sockets, links: seen and left out, counted for the window.
    pub skipped: usize,
    /// Directories found read-only. Retire cannot empty them.
    pub read_only: Vec<String>,
}

/// Walks `root`. Regular files only; symlinks are not followed.
pub fn scan(root: &Path) -> io::Result<Scan> {
    let mut s = Scan::default();
    walk(root, root, &mut s)?;
    s.entries.sort_by(|a, b| a.path.cmp(&b.path));
    s.read_only.sort();
    Ok(s)
}

fn walk(root: &Path, dir: &Path, s: &mut Scan) -> io::Result<()> {
    let rel = rel(root, dir);
    if !rel.is_empty() && !writable(dir) {
        s.read_only.push(rel.clone());
    }
    for item in fs::read_dir(dir)? {
        let item = item?;
        let name = item.file_name().to_string_lossy().into_owned();
        let ty = item.file_type()?;
        if name.starts_with("._") || name == ".DS_Store" {
            s.skipped += 1;
            continue;
        }
        if ty.is_dir() {
            if rel.is_empty() && SKIP_DIRS.contains(&name.as_str()) {
                continue;
            }
            walk(root, &item.path(), s)?;
        } else if ty.is_file() {
            let md = item.metadata()?;
            s.entries.push(Entry { bytes: md.len(), mtime: mtime(&md), path: rel_join(&rel, &name) });
        } else {
            s.skipped += 1;
        }
    }
    Ok(())
}

pub fn mtime(md: &fs::Metadata) -> i128 {
    use std::os::unix::fs::MetadataExt;
    i128::from(md.mtime()) * 1_000_000_000 + i128::from(md.mtime_nsec())
}

/// "1792118844.033051965": seconds, a dot, nine digits of nanoseconds.
pub fn show_mtime(ns: i128) -> String {
    format!("{}.{:09}", ns.div_euclid(1_000_000_000), ns.rem_euclid(1_000_000_000))
}

pub fn read_mtime(s: &str) -> Option<i128> {
    let (secs, frac) = s.split_once('.').unwrap_or((s, "0"));
    if frac.is_empty() || frac.len() > 9 || !frac.bytes().all(|c| c.is_ascii_digit()) {
        return None;
    }
    let nanos: i128 = format!("{frac:0<9}").parse().ok()?;
    Some(secs.parse::<i128>().ok()? * 1_000_000_000 + nanos)
}

/// access(2) for W_OK: asks the kernel, which knows the 9p share's view of a
/// folder the Mac made (uid 501), where the mode bits alone would mislead.
pub fn writable(dir: &Path) -> bool {
    use std::os::unix::ffi::OsStrExt;
    let Ok(c) = std::ffi::CString::new(dir.as_os_str().as_bytes()) else { return false };
    extern "C" {
        fn access(path: *const std::ffi::c_char, mode: i32) -> i32;
    }
    const W_OK: i32 = 2;
    unsafe { access(c.as_ptr(), W_OK) == 0 }
}

fn rel(root: &Path, p: &Path) -> String {
    p.strip_prefix(root).map(|r| r.to_string_lossy().into_owned()).unwrap_or_default()
}

fn rel_join(dir: &str, name: &str) -> String {
    if dir.is_empty() { name.to_string() } else { format!("{dir}/{name}") }
}

/// The group a path belongs to.
pub fn group(path: &str) -> String {
    let parts: Vec<&str> = path.split('/').collect();
    if parts.len() >= 3 {
        return format!("{}/{}/", parts[0], parts[1]);
    }
    let (dir, file) = match path.rsplit_once('/') {
        Some((d, f)) => (format!("{d}/"), f),
        None => (String::new(), path),
    };
    // the stem is the name up to its first dot past the start: video.en.vtt
    // goes with video.mp4. A leading dot is part of the name.
    let stem = match file[1.min(file.len())..].find('.') {
        Some(i) => &file[..i + 1],
        None => file,
    };
    format!("{dir}{stem}")
}

#[derive(Clone, Debug, Default)]
pub struct Disc {
    pub entries: Vec<Entry>,
    pub sectors: u64,
}

impl Disc {
    pub fn bytes(&self) -> u64 {
        self.entries.iter().map(|e| e.bytes).sum()
    }
    pub fn first(&self) -> &str {
        self.entries.first().map_or("", |e| e.path.as_str())
    }
    pub fn last(&self) -> &str {
        self.entries.last().map_or("", |e| e.path.as_str())
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct TooBig {
    pub group: String,
    pub sectors: u64,
}

/// Fills discs of `budget` sectors in path order.
pub fn fill(entries: &[Entry], budget: u64) -> Result<Vec<Disc>, TooBig> {
    // groups in order of first appearance; entries are sorted, so a group's
    // members are mostly together, but video.en.vtt sorts after video.mp4's
    // neighbours and must still land with it.
    let mut order: Vec<String> = Vec::new();
    let mut members: std::collections::HashMap<String, Vec<Entry>> = Default::default();
    for e in entries {
        let g = group(&e.path);
        members.entry(g.clone()).or_insert_with(|| {
            order.push(g.clone());
            Vec::new()
        });
        members.get_mut(&g).unwrap().push(e.clone());
    }
    let mut discs = vec![Disc::default()];
    for g in order {
        let m = members.remove(&g).unwrap();
        let s: u64 = m.iter().map(Entry::sectors).sum();
        if s > budget {
            return Err(TooBig { group: g, sectors: s });
        }
        let cur = discs.last_mut().unwrap();
        if cur.sectors + s > budget && !cur.entries.is_empty() {
            discs.push(Disc::default());
        }
        let cur = discs.last_mut().unwrap();
        cur.sectors += s;
        cur.entries.extend(m);
    }
    if discs.len() == 1 && discs[0].entries.is_empty() {
        discs.clear();
    }
    Ok(discs)
}

/// A name for a set of discs from the folder: SHAREDVM_20261015. ISO 9660
/// volume ids allow A-Z, 0-9 and '_', 32 at most, and "_D12_OF_12" needs ten.
pub fn set_name(root: &Path, date: &str) -> String {
    let base = root.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    let mut s: String = base
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c.to_ascii_uppercase() } else { '_' })
        .collect();
    s.truncate(13);
    let s = s.trim_matches('_');
    let s = if s.is_empty() { "DISCS" } else { s };
    format!("{s}_{date}")
}

pub fn disc_label(set: &str, n: usize, of: usize) -> String {
    format!("{set}_D{n}_OF_{of}")
}

// ---- cue files --------------------------------------------------------------
//
// # copal-zap cue 1
// # root <TAB> /home/user/Downloads/SharedVM
// # media <TAB> bd50
// bytes <TAB> mtime (seconds.nanoseconds) <TAB> path
//
// A path is escaped so a tab or newline in a file name cannot break a line:
// '\' -> "\\", TAB -> "\t", LF -> "\n".

pub fn escape(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '\\' => o.push_str("\\\\"),
            '\t' => o.push_str("\\t"),
            '\n' => o.push_str("\\n"),
            c => o.push(c),
        }
    }
    o
}

pub fn unescape(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    let mut it = s.chars();
    while let Some(c) = it.next() {
        if c != '\\' {
            o.push(c);
            continue;
        }
        match it.next() {
            Some('t') => o.push('\t'),
            Some('n') => o.push('\n'),
            Some(c) => o.push(c),
            None => o.push('\\'),
        }
    }
    o
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Cue {
    pub root: PathBuf,
    pub media: String,
    pub entries: Vec<Entry>,
}

impl Cue {
    pub fn render(&self) -> String {
        let mut s = format!(
            "# copal-zap cue 1\n# root\t{}\n# media\t{}\n",
            escape(&self.root.to_string_lossy()),
            self.media
        );
        for e in &self.entries {
            s.push_str(&format!("{}\t{}\t{}\n", e.bytes, show_mtime(e.mtime), escape(&e.path)));
        }
        s
    }

    pub fn parse(text: &str) -> Result<Cue, String> {
        let mut c = Cue::default();
        for (i, line) in text.lines().enumerate() {
            if let Some(h) = line.strip_prefix("# ") {
                if let Some((k, v)) = h.split_once('\t') {
                    match k {
                        "root" => c.root = PathBuf::from(unescape(v)),
                        "media" => c.media = v.to_string(),
                        _ => {}
                    }
                }
                continue;
            }
            let mut f = line.splitn(3, '\t');
            let (Some(b), Some(m), Some(p)) = (f.next(), f.next(), f.next()) else {
                return Err(format!("cue line {}: not bytes, mtime, path", i + 1));
            };
            c.entries.push(Entry {
                bytes: b.parse().map_err(|_| format!("cue line {}: bytes", i + 1))?,
                mtime: read_mtime(m).ok_or_else(|| format!("cue line {}: mtime", i + 1))?,
                path: unescape(p),
            });
        }
        Ok(c)
    }

    pub fn bytes(&self) -> u64 {
        self.entries.iter().map(|e| e.bytes).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn e(path: &str, bytes: u64) -> Entry {
        Entry { bytes, mtime: 1_792_118_844_033_051_965, path: path.into() }
    }

    #[test]
    fn mtimes() {
        assert_eq!(show_mtime(1_792_118_844_033_051_965), "1792118844.033051965");
        assert_eq!(read_mtime("1792118844.033051965"), Some(1_792_118_844_033_051_965));
        assert_eq!(read_mtime("1792118844"), Some(1_792_118_844_000_000_000));
        assert_eq!(read_mtime("12.5"), Some(12_500_000_000));
        assert_eq!(read_mtime("-1.000000001"), Some(-999_999_999));
        assert_eq!(read_mtime("1.x"), None);
        assert_eq!(read_mtime("1.0000000001"), None);
    }

    #[test]
    fn groups() {
        assert_eq!(group("a.mp4"), "a");
        assert_eq!(group("a.txt"), "a");
        assert_eq!(group("a.en.vtt"), "a");
        assert_eq!(group("dir/a.mp4"), "dir/a");
        assert_eq!(group("dir/proj/.git/HEAD"), "dir/proj/");
        assert_eq!(group("dir/proj/src/main.rs"), "dir/proj/");
        assert_eq!(group(".hidden"), ".hidden");
        assert_eq!(group("It's a=b [x1].mp4"), "It's a=b [x1]");
    }

    #[test]
    fn fills_in_order_and_keeps_groups() {
        let es = vec![e("a.mp4", 4096 * 3), e("a.txt", 10), e("b.mp4", 4096 * 3), e("b.txt", 10)];
        // each group is 6 + 1 + 1 + 1 = 9 sectors; a budget of 12 fits one
        let d = fill(&es, 12).unwrap();
        assert_eq!(d.len(), 2);
        assert_eq!(d[0].entries.len(), 2);
        assert_eq!(d[0].first(), "a.mp4");
        assert_eq!(d[1].last(), "b.txt");
        assert_eq!(fill(&es, 18).unwrap().len(), 1);
        assert_eq!(fill(&es, 8).unwrap_err(), TooBig { group: "a".into(), sectors: 9 });
        assert!(fill(&[], 8).unwrap().is_empty());
    }

    #[test]
    fn late_sibling_joins_its_group() {
        // "a.en.vtt" sorts after "a.mp4" but "a-b.mp4" sorts between them
        let mut es = vec![e("a.mp4", 10), e("a-b.mp4", 10), e("a.en.vtt", 10)];
        es.sort_by(|x, y| x.path.cmp(&y.path));
        let d = fill(&es, 4).unwrap();
        assert_eq!(d.len(), 2);
        let on = |p: &str| d.iter().position(|x| x.entries.iter().any(|e| e.path == p));
        assert_eq!(on("a.mp4"), on("a.en.vtt"));
        assert_ne!(on("a.mp4"), on("a-b.mp4"));
    }

    #[test]
    fn names() {
        assert_eq!(set_name(Path::new("/home/user/Downloads/SharedVM"), "20261015"), "SHAREDVM_20261015");
        assert_eq!(set_name(Path::new("/x/my movies (old)"), "20261015"), "MY_MOVIES__OL_20261015");
        assert_eq!(set_name(Path::new("/"), "20261015"), "DISCS_20261015");
        let l = disc_label(&set_name(Path::new("/x/averyveryverylongname"), "20261015"), 12, 12);
        assert!(l.len() <= 32, "{l}");
    }

    #[test]
    fn cue_round_trip_with_awkward_names() {
        let c = Cue {
            root: "/mnt/share".into(),
            media: "bd50".into(),
            entries: vec![e("odd/ tab\tlead.txt", 1), e("back\\slash.mp4", 2), e("new\nline", 3), e("It's a=b [x1].mp4", 4)],
        };
        assert_eq!(Cue::parse(&c.render()).unwrap(), c);
    }
}
