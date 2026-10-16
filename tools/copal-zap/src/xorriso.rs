//! Talking to xorriso, the program that does the real work.
//!
//! Every format here was read off xorriso 1.5.8 itself, not the manual:
//!
//! * Files go in as `-map 'disk' 'iso'` lines in an `-options_from_file`, quoted
//!   the way a shell quotes ('it'"'"'s'). -pathspecs looked simpler and is not:
//!   its '\=' escape applies on the disc side only and '\\' is not an escape at
//!   all, so a name with a backslash came out doubled.
//! * `-md5 on` must come BEFORE `-indev` when verifying. After it, the disc's
//!   checksums are never loaded, check_md5_r finds "not a single file with MD5
//!   checksum" -- and exits 0. Verify also counts the files it listed, so an
//!   empty check cannot pass for a good one.
//! * Listings print names with octal escapes: /It\047s\040a\075b.mp4.
//! * Progress while writing:
//!   `xorriso : UPDATE : Writing:   9141s    8.5%   fifo   0%  buf  50%    3.2xD`
//!   A fifo near 0% means the SOURCE is too slow; the drive is waiting on it.

use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// The program: $XORRISO if set (tests, a copy in a scratch folder), else
/// `xorriso` on PATH.
pub fn program() -> PathBuf {
    std::env::var_os("XORRISO").map(PathBuf::from).unwrap_or_else(|| "xorriso".into())
}

/// Single-quotes a word for xorriso's option reader.
pub fn quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\"'\"'"))
}

/// One `-map` line per file; `root` is the source folder.
pub fn map_lines<'a>(root: &Path, paths: impl Iterator<Item = &'a str>) -> String {
    let root = root.to_string_lossy();
    let root = root.trim_end_matches('/');
    let mut s = String::new();
    for p in paths {
        s.push_str(&format!("-map {} {}\n", quote(&format!("{root}/{p}")), quote(&format!("/{p}"))));
    }
    s
}

/// Undoes the \ooo escapes in xorriso's listings.
pub fn unoctal(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'\\'
            && i + 3 < b.len()
            && (b'0'..=b'3').contains(&b[i + 1])
            && b[i + 2..i + 4].iter().all(|c| (b'0'..=b'7').contains(c))
        {
            out.push((b[i + 1] - b'0') * 64 + (b[i + 2] - b'0') * 8 + (b[i + 3] - b'0'));
            i += 4;
        } else {
            out.push(b[i]);
            i += 1;
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// `-find / -type f -exec get_md5 --` output: (md5, path) pairs.
pub fn parse_md5_list(text: &str) -> Vec<(String, String)> {
    text.lines()
        .filter_map(|l| {
            let (sum, path) = l.split_once("  ")?;
            (sum.len() == 32 && sum.bytes().all(|c| c.is_ascii_hexdigit()))
                .then(|| (sum.to_string(), unoctal(path.trim_start())))
        })
        .collect()
}

/// One progress line while writing.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Progress {
    pub sectors: u64,
    pub percent: f32,
    /// xorriso's own fifo: what it has read from the source and not yet sent.
    pub fifo: u8,
    /// The drive's buffer.
    pub buf: u8,
    /// As a multiple, with its family letter: (3.2, 'D').
    pub speed: Option<(f32, char)>,
}

pub fn parse_progress(line: &str) -> Option<Progress> {
    let rest = line.split_once("Writing:")?.1;
    let mut w = rest.split_whitespace().peekable();
    let mut p = Progress { sectors: w.next()?.strip_suffix('s')?.parse().ok()?, ..Default::default() };
    p.percent = w.next()?.strip_suffix('%')?.parse().ok()?;
    while let Some(word) = w.next() {
        match word {
            "fifo" => p.fifo = w.next()?.trim_end_matches('%').parse().ok()?,
            "buf" => p.buf = w.next()?.trim_end_matches('%').parse().ok()?,
            s if s.contains('x') => {
                let (n, f) = s.split_once('x')?;
                p.speed = Some((n.parse().ok()?, f.chars().next()?));
            }
            _ => {}
        }
    }
    Some(p)
}

/// How a run ended.
#[derive(Debug)]
pub struct Outcome {
    pub code: i32,
    /// stdout: the result channel (listings, reports).
    pub out: String,
    /// stderr lines that were not progress: notes, warnings, failures.
    pub messages: Vec<String>,
}

impl Outcome {
    pub fn ok(&self) -> bool {
        self.code == 0
    }
    pub fn failures(&self) -> impl Iterator<Item = &String> {
        self.messages.iter().filter(|m| m.contains(": FAILURE :") || m.contains(": SORRY :") || m.contains("MISMATCH"))
    }
}

/// Runs xorriso with `args`, calling `on` for every progress line.
/// Severity SORRY and worse make the exit code 32.
pub fn run(args: &[String], mut on: impl FnMut(&Progress)) -> std::io::Result<Outcome> {
    let mut child = Command::new(program())
        .args(["-abort_on", "FAILURE", "-return_with", "SORRY", "32"])
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    let stdout = child.stdout.take().unwrap();
    let reader = std::thread::spawn(move || {
        let mut s = String::new();
        let _ = std::io::Read::read_to_string(&mut BufReader::new(stdout), &mut s);
        s
    });
    let mut messages = Vec::new();
    for line in BufReader::new(child.stderr.take().unwrap()).lines() {
        let line = line?;
        match parse_progress(&line) {
            Some(p) => on(&p),
            None if !line.trim().is_empty() => messages.push(line),
            None => {}
        }
    }
    let code = child.wait()?.code().unwrap_or(-1);
    let out = reader.join().unwrap_or_default();
    // "MD5 MISMATCH: '/file'" comes on the result channel, and names the file
    messages.extend(out.lines().filter(|l| l.contains("MISMATCH")).map(String::from));
    Ok(Outcome { code, out, messages })
}

/// Arguments that write a disc: `outdev` is "/dev/sr0" or "stdio:/dev/null".
pub fn write_args(outdev: &str, label: &str, options: &Path, cue: &Path, speed: Option<&str>) -> Vec<String> {
    let mut a: Vec<String> = vec!["-outdev".into(), outdev.into()];
    if let Some(s) = speed {
        a.extend(["-speed".into(), s.into()]);
    }
    a.extend(
        [
            "-volid", label, "-joliet", "on", "-compliance", "joliet_long_names", "-md5", "on",
            "-options_from_file",
        ]
        .map(String::from),
    );
    a.push(options.to_string_lossy().into_owned());
    // the cue rides along under the disc's own label, a name no source has:
    // a fixed "/CUE.txt" collided with the CUE.txt of a folder once retired
    a.extend(["-map".into(), cue.to_string_lossy().into_owned(), format!("/{label}.cue"), "-commit".into()]);
    a
}

/// Arguments that verify a disc and list its files with their checksums.
pub fn verify_args(indev: &str) -> Vec<String> {
    ["-md5", "on", "-indev", indev, "-check_md5_r", "sorry", "/", "--", "-find", "/", "-type", "f", "-exec", "get_md5", "--"]
        .map(String::from)
        .to_vec()
}

pub fn probe_args(dev: &str) -> Vec<String> {
    ["-outdev", dev, "-tell_media_space", "-toc"].map(String::from).to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quoting() {
        assert_eq!(quote("plain"), "'plain'");
        assert_eq!(quote("It's"), "'It'\"'\"'s'");
        let l = map_lines(Path::new("/r/"), ["a b/c'd.mp4"].into_iter());
        assert_eq!(l, "-map '/r/a b/c'\"'\"'d.mp4' '/a b/c'\"'\"'d.mp4'\n");
    }

    #[test]
    fn octal() {
        assert_eq!(unoctal("/It\\047s\\040a\\075b\\040[x1].mp4"), "/It's a=b [x1].mp4");
        assert_eq!(unoctal("/1989vs1989\\357\\274\\232\\040pump.webm"), "/1989vs1989： pump.webm");
        assert_eq!(unoctal("/top/back\\134slash.mp4"), "/top/back\\slash.mp4");
        assert_eq!(unoctal("/end\\04"), "/end\\04");
    }

    #[test]
    fn md5_list() {
        let t = "637a926cf5592aae2ff34c7b54b17e0a  /It\\047s\\040a\\075b\\040[x1].mp4\nnoise\n";
        assert_eq!(parse_md5_list(t), vec![("637a926cf5592aae2ff34c7b54b17e0a".into(), "/It's a=b [x1].mp4".into())]);
    }

    #[test]
    fn progress() {
        let p = parse_progress("xorriso : UPDATE : Writing:       9141s    8.5%   fifo   0%  buf  50%    3.2xD ").unwrap();
        assert_eq!(p, Progress { sectors: 9141, percent: 8.5, fifo: 0, buf: 50, speed: Some((3.2, 'D')) });
        let first = parse_progress("xorriso : UPDATE : Writing:        283s    0.3%   fifo   0%  buf  50%").unwrap();
        assert_eq!(first.speed, None);
        assert_eq!(parse_progress("xorriso : UPDATE :       1 files added in 1 seconds"), None);
    }
}
