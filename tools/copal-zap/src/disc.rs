//! One disc's life: planned, rehearsed, burned, verified, retired.
//!
//! A *set* is one plan of one folder: a directory under
//! `$XDG_DATA_HOME/copal-zap/` (or `$COPAL_ZAP_HOME`) holding a cue per disc
//! and, beside each, a log of the stages it has passed. Plain text both: the
//! state of a backup should be readable without the program that made it.

use crate::media::Media;
use crate::plan::{self, Cue, Entry};
use crate::xorriso::{self, Outcome, Progress};
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

pub fn home() -> PathBuf {
    if let Some(h) = std::env::var_os("COPAL_ZAP_HOME") {
        return h.into();
    }
    let data = std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/share"));
    data.join("copal-zap")
}

/// A rehearsal shorter than this measured xorriso's startup, not the source.
pub const MEASURE_SECS: f64 = 5.0;

/// Where simulated plans live: beside the real ones, never among them, so a
/// simulation cannot mark a real disc burned. ~/.local/share/copal-zap-sim.
pub fn sim_home() -> PathBuf {
    let h = home();
    let name = h.file_name().map_or_else(|| "copal-zap".into(), |n| n.to_string_lossy().into_owned());
    h.with_file_name(format!("{name}-sim"))
}

/// The file in a set's directory that makes it a simulation.
const SIMULATED: &str = "SIMULATED";

/// The folder copal-zap opens on when given none.
pub fn default_root() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join("Downloads/SharedVM")
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Stage {
    Planned,
    Rehearsed,
    Burned,
    Verified,
    Retired,
}

impl Stage {
    pub fn word(self) -> &'static str {
        match self {
            Stage::Planned => "planned",
            Stage::Rehearsed => "rehearsed",
            Stage::Burned => "burned",
            Stage::Verified => "verified",
            Stage::Retired => "retired",
        }
    }
    fn from_word(w: &str) -> Option<Stage> {
        [Stage::Planned, Stage::Rehearsed, Stage::Burned, Stage::Verified, Stage::Retired]
            .into_iter()
            .find(|s| s.word() == w)
    }
}

#[derive(Debug)]
pub enum Error {
    Io(io::Error),
    /// The plan or the disc is not in a state for this.
    Refused(String),
    /// Files no longer as planned: (path, "gone" | "changed").
    Changed(Vec<(String, &'static str)>),
    Xorriso(Outcome),
}

impl From<io::Error> for Error {
    fn from(e: io::Error) -> Self {
        Error::Io(e)
    }
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Error::Io(e) => write!(f, "{e}"),
            Error::Refused(s) => write!(f, "{s}"),
            Error::Changed(v) => {
                write!(f, "{} files are not as planned:", v.len())?;
                for (p, why) in v.iter().take(20) {
                    write!(f, "\n  {why:7} {p}")?;
                }
                if v.len() > 20 {
                    write!(f, "\n  ... and {} more", v.len() - 20)?;
                }
                Ok(())
            }
            Error::Xorriso(o) => {
                write!(f, "xorriso exited {}", o.code)?;
                for m in o.failures().take(10) {
                    write!(f, "\n  {m}")?;
                }
                Ok(())
            }
        }
    }
}

pub type Result<T> = std::result::Result<T, Error>;

pub struct Set {
    pub dir: PathBuf,
    pub name: String,
}

pub struct Disc {
    pub label: String,
    pub cue_path: PathBuf,
    log_path: PathBuf,
    /// Burns to an image, never a drive; cannot retire. See `simulate_burn`.
    pub simulated: bool,
}

/// A line of a disc's log: when, what, and the numbers that came of it.
#[derive(Clone, Debug, PartialEq)]
pub struct Mark {
    pub when: u64,
    pub stage: Stage,
    pub detail: String,
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

impl Set {
    /// Writes a new plan. An existing set of that name is replaced only when
    /// none of its discs has been burned.
    pub fn create(home: &Path, name: &str, root: &Path, media: &Media, discs: &[plan::Disc]) -> Result<Set> {
        let dir = home.join(name);
        if dir.exists() {
            let old = Set { dir: dir.clone(), name: name.into() };
            for d in old.discs()? {
                if d.stage()? >= Stage::Burned {
                    return Err(Error::Refused(format!("{name}: {} is already {}; not replacing", d.label, d.stage()?.word())));
                }
            }
            fs::remove_dir_all(&dir)?;
        }
        fs::create_dir_all(&dir)?;
        let of = discs.len();
        for (i, d) in discs.iter().enumerate() {
            let label = plan::disc_label(name, i + 1, of);
            let cue = Cue { root: root.to_path_buf(), media: media.name.into(), entries: d.entries.clone() };
            fs::write(dir.join(format!("{label}.cue")), cue.render())?;
            let disc = Disc::at(&dir, &label);
            disc.mark(Stage::Planned, &format!("{} files {} bytes", d.entries.len(), d.bytes()))?;
        }
        Ok(Set { dir, name: name.into() })
    }

    /// A plan whose discs are images: everything a real one does -- every
    /// source byte read, every file checksummed, the image read back -- with
    /// a file where the disc would be, deleted once it has been verified.
    pub fn create_simulated(home: &Path, name: &str, root: &Path, media: &Media, discs: &[plan::Disc]) -> Result<Set> {
        let set = Set::create(home, name, root, media, discs)?;
        fs::write(
            set.dir.join(SIMULATED),
            "A copal-zap simulation: its discs are image files, and it cannot retire.\n",
        )?;
        Ok(set)
    }

    pub fn simulated(&self) -> bool {
        self.dir.join(SIMULATED).exists()
    }

    pub fn open(home: &Path, name: &str) -> Result<Set> {
        let dir = home.join(name);
        if !dir.is_dir() {
            return Err(Error::Refused(format!("no set {name} in {}", home.display())));
        }
        Ok(Set { dir, name: name.into() })
    }

    pub fn list(home: &Path) -> Result<Vec<Set>> {
        let mut v = Vec::new();
        if let Ok(rd) = fs::read_dir(home) {
            for e in rd.flatten() {
                if e.path().is_dir() {
                    v.push(Set { dir: e.path(), name: e.file_name().to_string_lossy().into_owned() });
                }
            }
        }
        v.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(v)
    }

    /// Discs in number order (D2 before D10).
    pub fn discs(&self) -> Result<Vec<Disc>> {
        let mut v: Vec<(usize, Disc)> = Vec::new();
        for e in fs::read_dir(&self.dir)?.flatten() {
            let n = e.file_name().to_string_lossy().into_owned();
            if let Some(label) = n.strip_suffix(".cue") {
                let num = label.rsplit_once("_D").and_then(|(_, r)| r.split('_').next()?.parse().ok()).unwrap_or(0);
                v.push((num, Disc::at(&self.dir, label)));
            }
        }
        v.sort_by_key(|(n, _)| *n);
        Ok(v.into_iter().map(|(_, d)| d).collect())
    }

    pub fn disc(&self, which: &str) -> Result<Disc> {
        // "3", "D3", or the whole label
        let want = which.trim_start_matches(['D', 'd']);
        for d in self.discs()? {
            let num = d.label.rsplit_once("_D").and_then(|(_, r)| r.split('_').next()).unwrap_or("");
            if d.label == which || num == want {
                return Ok(d);
            }
        }
        Err(Error::Refused(format!("{}: no disc {which}", self.name)))
    }
}

impl Disc {
    fn at(dir: &Path, label: &str) -> Disc {
        Disc {
            label: label.into(),
            cue_path: dir.join(format!("{label}.cue")),
            log_path: dir.join(format!("{label}.log")),
            simulated: dir.join(SIMULATED).exists(),
        }
    }

    pub fn cue(&self) -> Result<Cue> {
        Cue::parse(&fs::read_to_string(&self.cue_path)?).map_err(Error::Refused)
    }

    pub fn marks(&self) -> Result<Vec<Mark>> {
        let text = match fs::read_to_string(&self.log_path) {
            Ok(t) => t,
            Err(e) if e.kind() == io::ErrorKind::NotFound => String::new(),
            Err(e) => return Err(e.into()),
        };
        Ok(text
            .lines()
            .filter_map(|l| {
                let mut f = l.splitn(3, '\t');
                Some(Mark {
                    when: f.next()?.parse().ok()?,
                    stage: Stage::from_word(f.next()?)?,
                    detail: f.next().unwrap_or("").into(),
                })
            })
            .collect())
    }

    pub fn stage(&self) -> Result<Stage> {
        Ok(self.marks()?.last().map_or(Stage::Planned, |m| m.stage))
    }

    /// The last mark of `stage`, for its numbers.
    pub fn last(&self, stage: Stage) -> Result<Option<Mark>> {
        Ok(self.marks()?.into_iter().rev().find(|m| m.stage == stage))
    }

    fn mark(&self, stage: Stage, detail: &str) -> Result<()> {
        let mut f = fs::OpenOptions::new().create(true).append(true).open(&self.log_path)?;
        writeln!(f, "{}\t{}\t{}", now(), stage.word(), detail)?;
        Ok(())
    }

    /// Every file still has its planned size and mtime.
    pub fn check(&self) -> Result<Cue> {
        let cue = self.cue()?;
        let bad = changed(&cue);
        if bad.is_empty() { Ok(cue) } else { Err(Error::Changed(bad)) }
    }

    /// The cue goes on the disc as /LABEL.cue; a source file of that name
    /// would be silently replaced by it.
    fn no_collision(&self, cue: &Cue) -> Result<()> {
        let own = format!("{}.cue", self.label);
        if cue.entries.iter().any(|e| e.path == own) {
            return Err(Error::Refused(format!("the folder has a file named {own}, which is this disc's cue")));
        }
        Ok(())
    }

    fn options(&self, cue: &Cue) -> Result<PathBuf> {
        let p = self.cue_path.with_extension("map");
        fs::write(&p, xorriso::map_lines(&cue.root, cue.entries.iter().map(|e| e.path.as_str())))?;
        Ok(p)
    }

    /// Builds the whole disc into /dev/null: every source byte is read, the
    /// file list is proved, and the source's real rate is measured. Returns
    /// bytes per second -- or None when the run was too short to mean it.
    pub fn rehearse(&self, on: impl FnMut(&Progress)) -> Result<Option<f64>> {
        let cue = self.check()?;
        self.no_collision(&cue)?;
        let opts = self.options(&cue)?;
        let t = Instant::now();
        let o = xorriso::run(&xorriso::write_args("stdio:/dev/null", &self.label, &opts, &self.cue_path, None), on)?;
        if !o.ok() {
            return Err(Error::Xorriso(o));
        }
        // UNDER FIVE SECONDS IS XORRISO STARTING UP, NOT THE SOURCE. A 400 KB
        // disc "measured" 3.8 MB/s, and burn then refused it as too slow.
        let took = t.elapsed().as_secs_f64();
        let rate = (took >= MEASURE_SECS).then(|| cue.bytes() as f64 / took);
        if self.stage()? < Stage::Burned {
            let detail = rate.map_or_else(|| format!("unmeasured, {took:.1} s"), |r| format!("{r:.0} B/s"));
            self.mark(Stage::Rehearsed, &detail)?;
        }
        Ok(rate)
    }

    /// The rate the last rehearsal measured, if it ran long enough to.
    pub fn rehearsed_rate(&self) -> Result<Option<f64>> {
        Ok(self.last(Stage::Rehearsed)?.and_then(|m| m.detail.split_whitespace().next()?.parse().ok()))
    }

    /// Streams the disc straight to `dev`. `speed` is xorriso's form ("4b");
    /// None picks one from the rehearsal, or leaves it to the drive.
    pub fn burn(&self, dev: &str, speed: Option<String>, media: Option<&Media>, on: impl FnMut(&Progress)) -> Result<()> {
        if self.simulated && !dev.starts_with("stdio:") {
            return Err(Error::Refused(format!("{} is a simulation: it burns to an image, never to {dev}", self.label)));
        }
        // a simulation may be burned again; a disc cannot
        if self.stage()? >= Stage::Burned && !self.simulated {
            return Err(Error::Refused(format!("{} is already {}", self.label, self.stage()?.word())));
        }
        let cue = self.check()?;
        self.no_collision(&cue)?;
        let speed = match (speed, media, self.rehearsed_rate()?) {
            (Some(s), _, _) => Some(s),
            (None, Some(m), Some(rate)) => match m.safe_speed(rate) {
                Some(x) => Some(m.speed_arg(x)),
                None => {
                    return Err(Error::Refused(format!(
                        "the source reads at {:.1} MB/s, slower than 1x {} ({:.1} MB/s); the burn would starve",
                        rate / 1e6,
                        m.label,
                        m.unit as f64 / 1e6
                    )))
                }
            },
            _ => None,
        };
        let opts = self.options(&cue)?;
        let o = xorriso::run(&xorriso::write_args(dev, &self.label, &opts, &self.cue_path, speed.as_deref()), on)?;
        if !o.ok() {
            return Err(Error::Xorriso(o));
        }
        self.mark(Stage::Burned, &format!("{dev} speed {}", speed.as_deref().unwrap_or("drive")))
    }

    /// Re-reads the disc against the MD5 of every file recorded as it was
    /// written, checks every planned file is on it, then checks the sources
    /// are still as planned -- so nothing changed between read and confirm.
    pub fn verify(&self, dev: &str) -> Result<usize> {
        let cue = self.cue()?;
        let o = xorriso::run(&xorriso::verify_args(dev), |_| {})?;
        if !o.ok() {
            return Err(Error::Xorriso(o));
        }
        let listed = xorriso::parse_md5_list(&o.out);
        let on: std::collections::HashSet<&str> = listed.iter().map(|(_, p)| p.as_str()).collect();
        let missing: Vec<(String, &'static str)> = cue
            .entries
            .iter()
            .filter(|e| !on.contains(format!("/{}", e.path).as_str()))
            .map(|e| (e.path.clone(), "missing"))
            .collect();
        if !missing.is_empty() {
            return Err(Error::Changed(missing));
        }
        let own = format!("/{}.cue", self.label);
        if !on.contains(own.as_str()) || listed.len() != cue.entries.len() + 1 {
            return Err(Error::Refused(format!(
                "{} files on the disc, the cue wants {} and {own}",
                listed.len(),
                cue.entries.len()
            )));
        }
        self.check()?;
        self.mark(Stage::Verified, &format!("{} files", listed.len()))?;
        Ok(listed.len())
    }

    /// A simulated burn: the disc written to `IMAGES/LABEL.iso`. With no
    /// `images`, the first place with room for it: the simulation's own
    /// folder, then ROOT/_discs/sim (which no plan ever reads). Returns the
    /// image; a failed burn leaves none behind.
    pub fn simulate_burn(&self, images: Option<&Path>, on: impl FnMut(&Progress)) -> Result<PathBuf> {
        if !self.simulated {
            return Err(Error::Refused(format!("{} is a real plan; simulate with a simulated one", self.label)));
        }
        let cue = self.cue()?;
        // the data, its sectors' slack and directories, and room to spare
        let need = cue.bytes() + cue.entries.len() as u64 * 4096 + (64 << 20);
        let places: Vec<PathBuf> = match images {
            Some(p) => vec![p.to_path_buf()],
            None => vec![
                self.cue_path.parent().and_then(Path::parent).unwrap_or(Path::new(".")).join("images"),
                cue.root.join("_discs").join("sim"),
            ],
        };
        let dir = places
            .iter()
            .find(|p| free_bytes(p).is_some_and(|f| f >= need))
            .ok_or_else(|| {
                let room: Vec<String> = places
                    .iter()
                    .map(|p| format!("{} has {}", p.display(), free_bytes(p).map_or("?".into(), |f| format!("{} MB", f >> 20))))
                    .collect();
                Error::Refused(format!("no room for a {} MB image: {}", need >> 20, room.join(", ")))
            })?;
        fs::create_dir_all(dir)?;
        let img = dir.join(format!("{}.iso", self.label));
        let _ = fs::remove_file(&img);
        // no media, so no speed and no "too slow": an image has no drive to
        // starve. The window still says what a real burn would need.
        let r = self.burn(&format!("stdio:{}", img.display()), None, None, on);
        if r.is_err() {
            let _ = fs::remove_file(&img);
        }
        r.map(|()| img)
    }

    /// Verifies the image the last simulated burn wrote, then deletes it,
    /// whether it passed or not: it has done its job either way.
    pub fn simulate_verify(&self) -> Result<usize> {
        let burned = self.last(Stage::Burned)?.ok_or_else(|| Error::Refused(format!("{} has not been burned", self.label)))?;
        let dev = burned.detail.split(" speed ").next().unwrap_or("").to_string();
        let img = PathBuf::from(dev.strip_prefix("stdio:").unwrap_or(""));
        if !self.simulated || !img.is_file() {
            return Err(Error::Refused(format!("{}: no image to verify; burn the simulation again", self.label)));
        }
        let r = self.verify(&dev);
        let _ = fs::remove_file(&img);
        r
    }

    /// Moves the disc's files into ROOT/_burned/LABEL/, keeping their paths.
    /// A rename on one filesystem: nothing is copied. Refuses unless verified,
    /// unchanged, and every source folder is writable -- a half-done retire is
    /// worse than none.
    pub fn retire(&self) -> Result<PathBuf> {
        if self.simulated {
            return Err(Error::Refused(format!(
                "{} is a simulation: retire is locked, it would move real files for a disc that does not exist",
                self.label
            )));
        }
        if self.stage()? != Stage::Verified {
            return Err(Error::Refused(format!("{} is {}, not verified", self.label, self.stage()?.word())));
        }
        let cue = self.check()?;
        let ro = read_only_dirs(&cue);
        if !ro.is_empty() {
            return Err(Error::Refused(format!(
                "read-only here (made on the Mac?), nothing moved; make these group-writable first:\n  {}",
                ro.join("\n  ")
            )));
        }
        let dest = cue.root.join("_burned").join(&self.label);
        let mut unmoved = Vec::new();
        for e in &cue.entries {
            let to = dest.join(&e.path);
            if let Some(p) = to.parent() {
                fs::create_dir_all(p)?;
            }
            if to.exists() || fs::rename(cue.root.join(&e.path), &to).is_err() {
                unmoved.push((e.path.clone(), "unmoved"));
            }
        }
        fs::copy(&self.cue_path, dest.join(format!("{}.cue", self.label)))?;
        if !unmoved.is_empty() {
            return Err(Error::Changed(unmoved));
        }
        self.mark(Stage::Retired, &dest.to_string_lossy())?;
        Ok(dest)
    }
}

/// Bytes free where `p` is, or where its nearest existing parent is.
/// From df(1): POSIX output, so BusyBox's and coreutils' agree.
pub fn free_bytes(p: &Path) -> Option<u64> {
    let mut at = p;
    while !at.exists() {
        at = at.parent()?;
    }
    let out = std::process::Command::new("df").arg("-Pk").arg(at).output().ok()?;
    let text = String::from_utf8_lossy(&out.stdout);
    let kb: u64 = text.lines().nth(1)?.split_whitespace().nth(3)?.parse().ok()?;
    Some(kb * 1024)
}

pub fn changed(cue: &Cue) -> Vec<(String, &'static str)> {
    let mut bad = Vec::new();
    for Entry { bytes, mtime, path } in &cue.entries {
        match fs::symlink_metadata(cue.root.join(path)) {
            Err(_) => bad.push((path.clone(), "gone")),
            Ok(md) if md.len() != *bytes || plan::mtime(&md) != *mtime => bad.push((path.clone(), "changed")),
            Ok(_) => {}
        }
    }
    bad
}

/// Source folders this user cannot write, so retire could not empty them.
pub fn read_only_dirs(cue: &Cue) -> Vec<String> {
    let mut dirs: Vec<&str> = cue.entries.iter().map(|e| e.path.rsplit_once('/').map_or("", |(d, _)| d)).collect();
    dirs.sort();
    dirs.dedup();
    dirs.into_iter()
        .filter(|d| !plan::writable(&cue.root.join(d)))
        .map(|d| if d.is_empty() { ".".into() } else { d.into() })
        .collect()
}
