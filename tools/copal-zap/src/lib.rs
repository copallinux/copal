//! copal-zap: a folder, cut into discs.
//!
//! * [`plan`] walks a folder and fills discs in path order, never splitting a
//!   video from its transcript or a project folder from itself.
//! * [`media`] knows what each kind of blank holds and asks the drive.
//! * [`xorriso`] speaks to the program that does the real work.
//! * [`disc`] is one disc's life: planned, rehearsed, burned, verified, retired.

pub mod disc;
pub mod media;
pub mod plan;
pub mod xorriso;

/// A disc sector. Every capacity and every budget here is counted in these.
pub const SECTOR: u64 = 2048;

/// Today as YYYYMMDD in local time: the date someone would write on the disc.
/// (In UTC, an evening burn in California is labelled tomorrow.)
pub fn today() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let (y, m, d) = civil(((secs + utc_offset(secs)) / 86_400) as u64);
    format!("{y:04}{m:02}{d:02}")
}

/// Seconds east of UTC at `secs`, from libc's localtime_r; 0 if it fails.
fn utc_offset(secs: i64) -> i64 {
    // struct tm as musl and glibc lay it out: nine ints, then tm_gmtoff.
    #[repr(C)]
    struct Tm {
        ints: [i32; 9],
        gmtoff: std::ffi::c_long,
        zone: *const std::ffi::c_char,
    }
    extern "C" {
        fn localtime_r(t: *const i64, tm: *mut Tm) -> *mut Tm;
    }
    let mut tm = Tm { ints: [0; 9], gmtoff: 0, zone: std::ptr::null() };
    let ok = unsafe { !localtime_r(&secs, &mut tm).is_null() };
    if ok { tm.gmtoff as i64 } else { 0 }
}

/// Days since 1970-01-01 to (year, month, day). Howard Hinnant's algorithm.
pub fn civil(days: u64) -> (i64, u32, u32) {
    let z = days as i64 + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    let y = yoe + era * 400 + i64::from(m <= 2);
    (y, m, d)
}

#[cfg(test)]
mod tests {
    #[test]
    fn civil_dates() {
        assert_eq!(super::civil(0), (1970, 1, 1));
        assert_eq!(super::civil(20_376), (2025, 10, 15));
        assert_eq!(super::civil(20_741), (2026, 10, 15));
        assert_eq!(super::civil(11_016), (2000, 2, 29));
    }
}
