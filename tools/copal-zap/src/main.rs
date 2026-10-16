//! copal-zap: the command line. The window (gui/) calls the same library.

use copal_zap::disc::{self, Disc, Error, Set, Stage};
use copal_zap::media::{self, Media};
use copal_zap::plan;
use copal_zap::xorriso::Progress;
use std::io::Write;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "\
copal-zap -- a folder, cut into discs, burned straight from the source

  copal-zap plan [DIR] [--media NAME | --device DEV] [--name SET]
                         cut DIR (default ~/Downloads/SharedVM) into discs
  copal-zap media [DEV]  what the drive holds (default /dev/sr0)
  copal-zap sets         every plan, and where each disc has got to
  copal-zap show SET     one plan, disc by disc
  copal-zap check    SET DISC     the files are still as planned
  copal-zap rehearse SET DISC     build the disc into /dev/null; measure the source
  copal-zap burn     SET DISC [--device DEV] [--speed 4b]
  copal-zap verify   SET DISC [--device DEV]
  copal-zap retire   SET DISC     move the files into DIR/_burned/LABEL/

  --simulate   the same, with an image file where each disc would be: every
               source byte read and checksummed, the image verified and then
               deleted. Simulated plans are kept apart and can never retire.

  Media: cd dvd dvd-dl bd25 bd50 bd100 bd128.  DISC: 3, D3 or the label.
  Plans live in $COPAL_ZAP_HOME, else $XDG_DATA_HOME/copal-zap.
  $XORRISO names the xorriso to run.";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match run(&args) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("copal-zap: {e}");
            ExitCode::FAILURE
        }
    }
}

struct Opts {
    words: Vec<String>,
    media: Option<String>,
    device: Option<String>,
    name: Option<String>,
    speed: Option<String>,
    simulate: bool,
}

fn opts(args: &[String]) -> Result<Opts, Error> {
    let mut o = Opts { words: vec![], media: None, device: None, name: None, speed: None, simulate: false };
    let mut it = args.iter();
    while let Some(a) = it.next() {
        let mut val = |what: &str| it.next().cloned().ok_or_else(|| Error::Refused(format!("{what} needs a value")));
        match a.as_str() {
            "--media" => o.media = Some(val("--media")?),
            "--device" => o.device = Some(val("--device")?),
            "--name" => o.name = Some(val("--name")?),
            "--speed" => o.speed = Some(val("--speed")?),
            "--simulate" => o.simulate = true,
            "-h" | "--help" => o.words.insert(0, "help".into()),
            s if s.starts_with("--") => return Err(Error::Refused(format!("unknown option {s}"))),
            s => o.words.push(s.into()),
        }
    }
    Ok(o)
}

fn run(args: &[String]) -> Result<(), Error> {
    let o = opts(args)?;
    let home = if o.simulate { disc::sim_home() } else { disc::home() };
    let word = |i: usize| o.words.get(i).map(String::as_str);
    let dev = o.device.clone().unwrap_or_else(|| "/dev/sr0".into());
    match word(0) {
        None | Some("help") => println!("{USAGE}"),
        Some("plan") => plan_cmd(&o, &home)?,
        Some("media") => {
            let dev = word(1).map(String::from).unwrap_or(dev);
            let (p, fam) = probe(&dev)?;
            println!("{dev}: {}", p.kind);
            println!("  status  {}", p.status);
            println!("  free    {} sectors, {}", p.free, gb(p.free * copal_zap::SECTOR));
            if let Some(m) = fam {
                println!("  family  {} (1x = {:.1} MB/s)", m.label, m.unit as f64 / 1e6);
            }
        }
        Some("sets") => {
            for s in Set::list(&home)? {
                let ds = s.discs()?;
                let stages: Vec<String> = ds.iter().map(|d| short(d.stage().unwrap_or(Stage::Planned))).collect();
                println!("{:24} {} discs  {}", s.name, ds.len(), stages.join(" "));
            }
        }
        Some("show") => {
            let s = Set::open(&home, need(word(1), "SET")?)?;
            for d in s.discs()? {
                let c = d.cue()?;
                println!(
                    "{:30} {:9} {:6} files {:>9}  {}",
                    d.label,
                    d.stage()?.word(),
                    c.entries.len(),
                    gb(c.bytes()),
                    range(&c)
                );
            }
        }
        Some(verb @ ("check" | "rehearse" | "burn" | "verify" | "retire")) => {
            let s = Set::open(&home, need(word(1), "SET")?)?;
            let d = s.disc(need(word(2), "DISC")?)?;
            if d.simulated {
                eprintln!("SIMULATION: {} is an image, not a disc", d.label);
            }
            step(verb, &d, &dev, o.speed.clone())?;
        }
        Some(w) => return Err(Error::Refused(format!("unknown command {w}; copal-zap help"))),
    }
    Ok(())
}

fn need<'a>(w: Option<&'a str>, what: &str) -> Result<&'a str, Error> {
    w.ok_or_else(|| Error::Refused(format!("needs {what}")))
}

fn probe(dev: &str) -> Result<(media::Probe, Option<Media>), Error> {
    let p = media::probe(dev).map_err(|e| Error::Refused(format!("{dev}: {e}")))?;
    let fam = p.family();
    Ok((p, fam))
}

fn plan_cmd(o: &Opts, home: &std::path::Path) -> Result<(), Error> {
    let root = o.words.get(1).map(PathBuf::from).unwrap_or_else(disc::default_root);
    // a blank in the drive decides the size; else --media; else BD-R DL
    let (m, budget, capacity) = match (&o.media, &o.device) {
        (Some(n), _) => {
            let m = media::by_name(n).ok_or_else(|| Error::Refused(format!("no media {n}")))?;
            (m, m.budget(), m.sectors)
        }
        (None, Some(dev)) => {
            let (p, fam) = probe(dev)?;
            if !p.appendable() {
                return Err(Error::Refused(format!("{dev}: {} -- not writable", p.status)));
            }
            let m = fam.ok_or_else(|| Error::Refused(format!("{dev}: {} is not a disc I know", p.kind)))?;
            println!("{dev}: {}, {} free", p.kind, gb(p.free * copal_zap::SECTOR));
            (m, media::budget(p.free), p.free)
        }
        (None, None) => {
            let m = media::by_name("bd50").unwrap();
            (m, m.budget(), m.sectors)
        }
    };
    let scan = plan::scan(&root)?;
    let discs = plan::fill(&scan.entries, budget).map_err(|t| {
        Error::Refused(format!("{} needs {} on one disc; {} holds {}", t.group, gb(t.sectors * 2048), m.label, gb(budget * 2048)))
    })?;
    if discs.is_empty() {
        return Err(Error::Refused(format!("{}: nothing to plan", root.display())));
    }
    let name = o.name.clone().unwrap_or_else(|| plan::set_name(&root, &copal_zap::today()));
    let set = if o.simulate {
        Set::create_simulated(home, &name, &root, &m, &discs)?
    } else {
        Set::create(home, &name, &root, &m, &discs)?
    };
    if o.simulate {
        println!("SIMULATION: each disc will be an image, verified and then deleted");
    }
    let total: u64 = discs.iter().map(plan::Disc::bytes).sum();
    println!(
        "{name}: {} files, {}, onto {} x {}  ({})",
        scan.entries.len(),
        gb(total),
        discs.len(),
        m.label,
        set.dir.display()
    );
    for (i, d) in discs.iter().enumerate() {
        println!(
            "  D{:<3} {:6} files {:>9}  {:5.1}% full  {} .. {}",
            i + 1,
            d.entries.len(),
            gb(d.bytes()),
            100.0 * d.sectors as f64 / capacity.max(1) as f64,
            clip(d.first(), 34),
            clip(d.last(), 34)
        );
    }
    if scan.skipped > 0 {
        println!("  left out: {} Mac metadata files, links and specials", scan.skipped);
    }
    if !scan.read_only.is_empty() {
        println!("  READ-ONLY here, so retire cannot empty them ({}):", scan.read_only.len());
        for d in scan.read_only.iter().filter(|d| !d.contains('/')) {
            println!("    {d}");
        }
    }
    Ok(())
}

fn step(verb: &str, d: &Disc, dev: &str, speed: Option<String>) -> Result<(), Error> {
    match verb {
        "check" => {
            let c = d.check()?;
            println!("{}: {} files as planned", d.label, c.entries.len());
        }
        "rehearse" => {
            let rate = d.rehearse(show)?;
            let m = media::by_name(&d.cue()?.media);
            eprintln!();
            let Some(rate) = rate else {
                println!(
                    "{}: rehearsed, but in under {:.0} s: too short to measure the source",
                    d.label,
                    disc::MEASURE_SECS
                );
                return Ok(());
            };
            println!("{}: rehearsed, the source reads at {:.1} MB/s", d.label, rate / 1e6);
            if let Some(m) = m {
                match m.safe_speed(rate) {
                    Some(x) => println!(
                        "  burn at {x}x ({}): about {} min",
                        m.speed_arg(x),
                        m.burn_secs(d.cue()?.bytes(), x) / 60 + 1
                    ),
                    None => println!(
                        "  too slow for {}: 1x needs {:.1} MB/s. A burn would starve.",
                        m.label,
                        m.unit as f64 / 1e6
                    ),
                }
            }
        }
        "burn" if d.simulated => {
            let img = d.simulate_burn(None, show)?;
            eprintln!();
            println!("{}: burned into {}. Next: copal-zap --simulate verify", d.label, img.display());
        }
        "burn" => {
            let m = media::by_name(&d.cue()?.media);
            d.burn(dev, speed, m.as_ref(), show)?;
            eprintln!();
            println!("{}: burned on {dev}. Next: copal-zap verify", d.label);
        }
        "verify" => {
            let n = if d.simulated { d.simulate_verify()? } else { d.verify(dev)? };
            println!("{}: verified, {n} files match the checksums written with them", d.label);
            if d.simulated {
                println!("  the image is deleted; a real disc would now be ready to retire");
            }
        }
        "retire" => {
            let to = d.retire()?;
            println!("{}: retired into {}", d.label, to.display());
        }
        _ => unreachable!(),
    }
    Ok(())
}

fn show(p: &Progress) {
    let speed = p.speed.map(|(x, f)| format!("{x:.1}x{f}")).unwrap_or_default();
    let starved = if p.fifo < 10 && p.percent > 1.0 { "  <- source too slow" } else { "" };
    eprint!("\r  {:5.1}%  fifo {:3}%  buf {:3}%  {speed:7}{starved}   ", p.percent, p.fifo, p.buf);
    let _ = std::io::stderr().flush();
}

fn short(s: Stage) -> String {
    s.word()[..1].to_uppercase()
}

fn gb(b: u64) -> String {
    if b >= 1_000_000_000 {
        format!("{:.2} GB", b as f64 / 1e9)
    } else {
        format!("{:.0} MB", b as f64 / 1e6)
    }
}

fn clip(s: &str, n: usize) -> String {
    if s.chars().count() <= n { s.into() } else { format!("{}…", s.chars().take(n - 1).collect::<String>()) }
}

fn range(c: &plan::Cue) -> String {
    let f = c.entries.first().map_or("", |e| e.path.as_str());
    let l = c.entries.last().map_or("", |e| e.path.as_str());
    format!("{} .. {}", clip(f, 30), clip(l, 30))
}
