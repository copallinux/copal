//! Blank media: what each kind holds, and what the drive says is in it.

use crate::SECTOR;

/// One kind of blank. `sectors` is the unformatted capacity, which is how
/// xorriso writes a BD-R (no spare area) and what a DVD-R always is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Media {
    pub name: &'static str,
    pub label: &'static str,
    pub sectors: u64,
    /// 1x for this family in bytes per second: CD 153 600, DVD 1 385 000,
    /// BD 4 495 625. Burn speeds are multiples of it.
    pub unit: u64,
    /// The letter xorriso's -speed takes after the multiple: c, d or b.
    pub speed_suffix: char,
}

const CD: u64 = 153_600;
const DVD: u64 = 1_385_000;
const BD: u64 = 4_495_625;

pub const TABLE: &[Media] = &[
    Media { name: "cd", label: "CD-R 700 MB", sectors: 359_846, unit: CD, speed_suffix: 'c' },
    Media { name: "dvd", label: "DVD±R 4.7 GB", sectors: 2_295_104, unit: DVD, speed_suffix: 'd' },
    Media { name: "dvd-dl", label: "DVD±R DL 8.5 GB", sectors: 4_171_712, unit: DVD, speed_suffix: 'd' },
    Media { name: "bd25", label: "BD-R 25 GB", sectors: 12_219_392, unit: BD, speed_suffix: 'b' },
    Media { name: "bd50", label: "BD-R DL 50 GB", sectors: 24_438_784, unit: BD, speed_suffix: 'b' },
    Media { name: "bd100", label: "BD-R XL 100 GB", sectors: 48_878_592, unit: BD, speed_suffix: 'b' },
    Media { name: "bd128", label: "BD-R XL 128 GB", sectors: 62_500_864, unit: BD, speed_suffix: 'b' },
];

pub fn by_name(name: &str) -> Option<Media> {
    TABLE.iter().copied().find(|m| m.name == name)
}

impl Media {
    pub fn bytes(&self) -> u64 {
        self.sectors * SECTOR
    }

    /// The sectors a plan may fill: 2% held back, and 32 MiB more for the
    /// volume descriptors, path tables and directories of a busy disc.
    pub fn budget(&self) -> u64 {
        budget(self.sectors)
    }

    /// The fastest whole multiple a source read at `rate` bytes/s can feed,
    /// keeping a fifth in hand. None when the source cannot feed even 1x.
    pub fn safe_speed(&self, rate: f64) -> Option<u32> {
        let x = (rate * 0.8 / self.unit as f64).floor() as u32;
        (x >= 1).then_some(x)
    }

    pub fn speed_arg(&self, x: u32) -> String {
        format!("{x}{}", self.speed_suffix)
    }

    /// Seconds to burn `bytes` at `x` times.
    pub fn burn_secs(&self, bytes: u64, x: u32) -> u64 {
        bytes / (self.unit * u64::from(x.max(1)))
    }
}

pub fn budget(sectors: u64) -> u64 {
    (sectors * 98 / 100).saturating_sub(16_384)
}

/// What the drive reported about the disc in it.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Probe {
    /// "BD-R sequential recording", "DVD+R", "stdio file", ...
    pub kind: String,
    /// "is blank", "is written , is appendable", "is written , is closed", ...
    pub status: String,
    /// Sectors still writable, from -tell_media_space.
    pub free: u64,
    pub vendor: String,
}

impl Probe {
    pub fn blank(&self) -> bool {
        self.status.contains("blank")
    }

    pub fn appendable(&self) -> bool {
        self.blank() || self.status.contains("appendable")
    }

    /// The nearest table entry, for speeds and labels. A disc whose free space
    /// is smaller than any blank (an appendable one) still gets its family.
    pub fn family(&self) -> Option<Media> {
        let k = self.kind.to_ascii_uppercase();
        let fam = if k.starts_with("BD") {
            'b'
        } else if k.starts_with("DVD") {
            'd'
        } else if k.starts_with("CD") {
            'c'
        } else {
            return None;
        };
        let mut best = None;
        for m in TABLE.iter().filter(|m| m.speed_suffix == fam) {
            best = Some(*m);
            if m.sectors >= self.free {
                break;
            }
        }
        best
    }
}

/// Asks the drive at `dev` what is in it.
pub fn probe(dev: &str) -> Result<Probe, String> {
    let o = crate::xorriso::run(&crate::xorriso::probe_args(dev), |_| {}).map_err(|e| format!("xorriso: {e}"))?;
    let p = parse_probe(&format!("{}\n{}", o.out, o.messages.join("\n")));
    if p.kind.is_empty() {
        let why = o.failures().next().cloned().unwrap_or_else(|| format!("xorriso exited {}", o.code));
        return Err(why);
    }
    Ok(p)
}

/// Reads `xorriso -outdev DEV -tell_media_space -toc` output.
pub fn parse_probe(text: &str) -> Probe {
    let mut p = Probe::default();
    for line in text.lines() {
        let Some((key, val)) = line.split_once(':') else { continue };
        let val = val.trim();
        match key.trim() {
            "Media current" => p.kind = val.to_string(),
            "Media status" => p.status = val.to_string(),
            "After commit" => p.free = val.trim_end_matches('s').trim().parse().unwrap_or(0),
            "Drive type" => p.vendor = val.to_string(),
            _ => {}
        }
    }
    p
}

#[cfg(test)]
mod tests {
    use super::*;

    const STDIO: &str = "After commit : 706192s
Drive current: -outdev 'stdio:/tmp/blank.iso'
Drive access : exclusive:unrestricted
Drive type   : vendor 'YOYODYNE' product 'WARP DRIVE' revision 'FX01'
Media current: stdio file, overwriteable
Media status : is blank
Media blocks : 0 readable , 706224 writable , 706224 overall
Media summary: 0 sessions, 0 data blocks, 0 data, 1379m free
";

    #[test]
    fn reads_the_report() {
        let p = parse_probe(STDIO);
        assert_eq!(p.kind, "stdio file, overwriteable");
        assert!(p.blank() && p.appendable());
        assert_eq!(p.free, 706_192);
        assert_eq!(p.family(), None);
    }

    #[test]
    fn families() {
        let p = Probe { kind: "BD-R sequential recording".into(), free: 24_438_784, ..Default::default() };
        assert_eq!(p.family().unwrap().name, "bd50");
        let half = Probe { free: 3_000_000, ..p.clone() };
        assert_eq!(half.family().unwrap().name, "bd25");
        let dvd = Probe { kind: "DVD+R".into(), free: 2_295_104, ..Default::default() };
        assert_eq!(dvd.family().unwrap().name, "dvd");
    }

    #[test]
    fn speeds() {
        let bd = by_name("bd50").unwrap();
        // the share as xorriso reads it today: 4.2 MB/s cannot feed 1x BD
        assert_eq!(bd.safe_speed(4.2e6), None);
        assert_eq!(bd.safe_speed(25e6), Some(4));
        assert_eq!(bd.speed_arg(4), "4b");
        let dvd = by_name("dvd").unwrap();
        assert_eq!(dvd.safe_speed(4.2e6), Some(2));
        assert_eq!(bd.burn_secs(50_000_000_000, 4), 2780);
    }
}
