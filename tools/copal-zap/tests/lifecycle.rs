//! A disc's whole life against the real xorriso, written to image files
//! instead of a drive. Skipped (and says so) when no xorriso can be run:
//! set $XORRISO to one, as `make check` does.

use copal_zap::disc::{Error, Set, Stage};
use copal_zap::media;
use copal_zap::plan;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

fn have_xorriso() -> bool {
    std::process::Command::new(copal_zap::xorriso::program())
        .arg("-version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn scratch(name: &str) -> PathBuf {
    let d = Path::new(env!("CARGO_TARGET_TMPDIR")).join(name);
    if d.exists() {
        // a previous run may have left a folder read-only
        for e in walk(&d) {
            let _ = fs::set_permissions(&e, fs::Permissions::from_mode(0o755));
        }
        fs::remove_dir_all(&d).unwrap();
    }
    fs::create_dir_all(&d).unwrap();
    d
}

fn walk(d: &Path) -> Vec<PathBuf> {
    let mut v = vec![d.to_path_buf()];
    if let Ok(rd) = fs::read_dir(d) {
        for e in rd.flatten() {
            if e.file_type().unwrap().is_dir() {
                v.extend(walk(&e.path()));
            }
        }
    }
    v
}

/// Bytes that do not compress or repeat, so a flipped one is a real change.
fn noise(n: usize, seed: u64) -> Vec<u8> {
    let mut x = seed | 1;
    (0..n)
        .map(|_| {
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            x as u8
        })
        .collect()
}

fn put(root: &Path, rel: &str, data: &[u8]) {
    let p = root.join(rel);
    fs::create_dir_all(p.parent().unwrap()).unwrap();
    fs::write(p, data).unwrap();
}

#[test]
fn a_disc_from_plan_to_retire() {
    if !have_xorriso() {
        eprintln!("SKIPPED: no xorriso (set $XORRISO)");
        return;
    }
    let base = scratch("lifecycle");
    let root = base.join("SharedVM");
    let home = base.join("home");
    // disc 1: awkward names; disc 2: a project folder kept whole
    put(&root, "It's a=b [x1].mp4", &noise(3_000_000, 1));
    put(&root, "It's a=b [x1].txt", b"transcript");
    put(&root, "It's a=b [x1].en.vtt", b"WEBVTT");
    put(&root, "1989vs1989： pump.webm", &noise(5000, 2));
    put(&root, "odd/two\"quote\" a\\b.mp4", &noise(7000, 3));
    put(&root, "odd/ tab\tlead.txt", b"x");
    put(&root, "zz/proj/.git/HEAD", b"ref: refs/heads/main\n");
    put(&root, "zz/proj/src/main.rs", &noise(2_000_000, 4));
    put(&root, "._It's a=b [x1].mp4", b"mac");
    put(&root, ".DS_Store", b"mac");

    let scan = plan::scan(&root).unwrap();
    assert_eq!(scan.entries.len(), 8);
    assert_eq!(scan.skipped, 2);
    // a budget that fits disc 1's ~3 MB and forces the 2 MB project onto disc 2
    let discs = plan::fill(&scan.entries, 1600).unwrap();
    assert_eq!(discs.len(), 2, "{discs:#?}");
    assert!(discs[1].entries.iter().all(|e| e.path.starts_with("zz/proj/")));
    let bd = media::by_name("bd25").unwrap();
    let set = Set::create(&home, "SHAREDVM_TEST", &root, &bd, &discs).unwrap();
    let d1 = set.disc("1").unwrap();
    let d2 = set.disc("D2").unwrap();
    assert_eq!(d1.label, "SHAREDVM_TEST_D1_OF_2");
    assert_eq!(d1.stage().unwrap(), Stage::Planned);

    // rehearse: every byte read, a rate measured
    let mut updates = 0;
    // a 5 MB disc rehearses in well under the five seconds a rate needs
    let rate = d1.rehearse(|_| updates += 1).unwrap();
    assert_eq!(rate, None);
    assert_eq!(d1.stage().unwrap(), Stage::Rehearsed);
    assert_eq!(d1.rehearsed_rate().unwrap(), None);
    assert!(d1.last(Stage::Rehearsed).unwrap().unwrap().detail.starts_with("unmeasured"));

    // burn to an image; a second burn is refused
    let img = base.join("d1.iso");
    let dev = format!("stdio:{}", img.display());
    d1.burn(&dev, None, None, |_| {}).unwrap();
    assert_eq!(d1.stage().unwrap(), Stage::Burned);
    assert!(matches!(d1.burn(&dev, None, None, |_| {}), Err(Error::Refused(_))));

    // retire before verify is refused
    assert!(matches!(d1.retire(), Err(Error::Refused(_))));

    // verify: 6 files + the disc's own /LABEL.cue
    assert_eq!(d1.verify(&dev).unwrap(), 7);
    assert_eq!(d1.stage().unwrap(), Stage::Verified);

    // a flipped byte inside the 3 MB file fails verify with xorriso's mismatch
    let mut bytes = fs::read(&img).unwrap();
    let video = noise(3_000_000, 1);
    let probe = &video[1_000_000..1_000_016];
    let at = bytes.windows(16).position(|w| w == probe).unwrap();
    bytes[at] ^= 0xff;
    let bad = base.join("bad.iso");
    fs::write(&bad, bytes).unwrap();
    match d1.verify(&format!("stdio:{}", bad.display())) {
        Err(Error::Xorriso(o)) => assert!(o.failures().any(|m| m.contains("MISMATCH")), "{:?}", o.messages),
        other => panic!("corrupt image verified: {other:?}"),
    }

    // retire: renamed, not copied; the paths keep their shape
    let dest = d1.retire().unwrap();
    assert_eq!(d1.stage().unwrap(), Stage::Retired);
    assert!(!root.join("It's a=b [x1].mp4").exists());
    assert_eq!(fs::read(dest.join("It's a=b [x1].mp4")).unwrap(), noise(3_000_000, 1));
    assert!(dest.join("odd/ tab\tlead.txt").exists());
    assert!(dest.join("SHAREDVM_TEST_D1_OF_2.cue").exists());

    // a fresh scan no longer sees what is retired; the set is not replaced
    let again = plan::scan(&root).unwrap();
    assert_eq!(again.entries.len(), 2, "{:?}", again.entries);
    assert!(matches!(Set::create(&home, "SHAREDVM_TEST", &root, &bd, &discs), Err(Error::Refused(_))));

    // disc 2: a source changed after the burn is caught by verify
    let img2 = format!("stdio:{}", base.join("d2.iso").display());
    d2.burn(&img2, None, None, |_| {}).unwrap();
    let rs = root.join("zz/proj/src/main.rs");
    let keep = fs::read(&rs).unwrap();
    fs::write(&rs, b"edited").unwrap();
    assert!(matches!(d2.verify(&img2), Err(Error::Changed(_))));
    assert_eq!(d2.stage().unwrap(), Stage::Burned);

    // restored contents, but a new mtime: still not as planned
    fs::write(&rs, &keep).unwrap();
    assert!(matches!(d2.check(), Err(Error::Changed(_))));
}

#[test]
fn retire_moves_nothing_out_of_a_read_only_folder() {
    if !have_xorriso() {
        eprintln!("SKIPPED: no xorriso (set $XORRISO)");
        return;
    }
    let base = scratch("readonly");
    let root = base.join("src");
    put(&root, "top.mp4", b"a");
    put(&root, "ro/x.mp4", b"b");
    let scan = plan::scan(&root).unwrap();
    let discs = plan::fill(&scan.entries, 1000).unwrap();
    let bd = media::by_name("bd25").unwrap();
    let set = Set::create(&base.join("home"), "RO", &root, &bd, &discs).unwrap();
    let d = set.disc("1").unwrap();
    let dev = format!("stdio:{}", base.join("ro.iso").display());
    d.burn(&dev, None, None, |_| {}).unwrap();
    d.verify(&dev).unwrap();

    fs::set_permissions(root.join("ro"), fs::Permissions::from_mode(0o555)).unwrap();
    let r = d.retire();
    fs::set_permissions(root.join("ro"), fs::Permissions::from_mode(0o755)).unwrap();
    match r {
        Err(Error::Refused(m)) => assert!(m.contains("ro"), "{m}"),
        other => panic!("retired from a read-only folder: {other:?}"),
    }
    assert!(root.join("top.mp4").exists() && root.join("ro/x.mp4").exists());
    assert_eq!(d.stage().unwrap(), Stage::Verified);
    d.retire().unwrap();
}

#[test]
fn a_simulation_reads_everything_and_touches_nothing() {
    if !have_xorriso() {
        eprintln!("SKIPPED: no xorriso (set $XORRISO)");
        return;
    }
    let base = scratch("simulate");
    let root = base.join("src");
    put(&root, "a.mp4", &noise(400_000, 7));
    put(&root, "a.txt", b"transcript");
    let scan = plan::scan(&root).unwrap();
    let discs = plan::fill(&scan.entries, 1000).unwrap();
    let bd = media::by_name("bd25").unwrap();
    let set = Set::create_simulated(&base.join("sim"), "SIM", &root, &bd, &discs).unwrap();
    assert!(set.simulated());
    let d = set.disc("1").unwrap();
    assert!(d.simulated);
    d.rehearse(|_| {}).unwrap();

    // never a drive
    assert!(matches!(d.burn("/dev/sr0", None, None, |_| {}), Err(Error::Refused(_))));

    // an image, where it was told; verified; then gone
    let images = base.join("images");
    let img = d.simulate_burn(Some(&images), |_| {}).unwrap();
    assert!(img.starts_with(&images) && img.is_file());
    assert_eq!(d.stage().unwrap(), Stage::Burned);
    assert_eq!(d.simulate_verify().unwrap(), 3);
    assert!(!img.exists(), "the image outlived its verify");
    assert_eq!(d.stage().unwrap(), Stage::Verified);
    assert!(matches!(d.simulate_verify(), Err(Error::Refused(_))));

    // retire is locked, and the sources are where they were
    assert!(matches!(d.retire(), Err(Error::Refused(m)) if m.contains("simulation")));
    assert!(root.join("a.mp4").exists() && !root.join("_burned").exists());

    // a simulation can be played again; with no room it says so
    let img = d.simulate_burn(None, |_| {}).unwrap();
    assert!(img.is_file());
    d.simulate_verify().unwrap();
    assert!(!img.exists());

    // and a real plan will not pretend
    let real = Set::create(&base.join("real"), "REAL", &root, &bd, &discs).unwrap();
    assert!(!real.simulated());
    assert!(matches!(real.disc("1").unwrap().simulate_burn(Some(&images), |_| {}), Err(Error::Refused(_))));
}

#[test]
fn free_space_is_read() {
    let base = scratch("free");
    let f = copal_zap::disc::free_bytes(&base.join("not/made/yet")).unwrap();
    assert!(f > 0);
}

#[test]
fn a_folder_once_retired_backs_up_again() {
    // a retired folder holds its old disc's cue; backing it up again must
    // keep that file, not lose it under the new disc's cue
    if !have_xorriso() {
        eprintln!("SKIPPED: no xorriso (set $XORRISO)");
        return;
    }
    let base = scratch("again");
    let root = base.join("src");
    put(&root, "a.mp4", b"video");
    put(&root, "CUE.txt", b"# copal-zap cue 1, the old style");
    put(&root, "OLD_D1_OF_1.cue", b"# copal-zap cue 1");
    let scan = plan::scan(&root).unwrap();
    let discs = plan::fill(&scan.entries, 1000).unwrap();
    let bd = media::by_name("bd25").unwrap();
    let set = Set::create(&base.join("home"), "NEW", &root, &bd, &discs).unwrap();
    let d = set.disc("1").unwrap();
    let dev = format!("stdio:{}", base.join("new.iso").display());
    d.burn(&dev, None, None, |_| {}).unwrap();
    assert_eq!(d.verify(&dev).unwrap(), 4);

    // and a source file with the new disc's own cue name is refused up front
    put(&root, "CLASH_D1_OF_1.cue", b"mine");
    let scan = plan::scan(&root).unwrap();
    let discs = plan::fill(&scan.entries, 1000).unwrap();
    let set = Set::create(&base.join("home"), "CLASH", &root, &bd, &discs).unwrap();
    let d = set.disc("1").unwrap();
    assert!(matches!(d.rehearse(|_| {}), Err(Error::Refused(m)) if m.contains("CLASH_D1_OF_1.cue")));
}
