// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Paul Richeson
// copal-zap-gui -- a folder, cut into discs, with the dials to burn them by.
//
// EVERY NUMBER ON THE PANEL IS WORKED OUT, NONE IS TYPED IN. Point it at a
// folder and it says how many discs of every kind the folder needs; put a
// blank in the drive and the plan is cut to that blank's real free space;
// rehearse a disc and the source's measured rate becomes the burn speed, the
// burn time and the colour of the first dial. A number the operator has to
// supply is a number the operator can get wrong, and the cost of a wrong one
// here is a coaster.
//
// THE WINDOW BURNS NOTHING ITSELF. Each step is one call into the copal-zap
// library on a thread of its own -- the same calls the command line makes --
// and what comes back is xorriso's progress, one line a second. Closing the
// window mid-burn ends the burn, as closing a terminal would.
//
// ONE CANVAS, AND NO TEXT IN IT. radbeeper-gui learned both on this renderer:
// only the last canvas in a view is drawn, and a fill_text takes its frame's
// geometry with it. So the dials and the strip are one canvas, and every word
// on or under them is an ordinary text widget stacked over it.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use copal_zap::disc::{self, Set, Stage};
use copal_zap::media::{self, Media, Probe};
use copal_zap::plan;
use copal_zap::xorriso::Progress;
use iced::futures::channel::mpsc;
use iced::widget::{button, canvas, column, container, pick_list, row, scrollable, stack, text, text_input, toggler, Space};
use iced::{Color, Element, Fill, Font, Length, Point, Rectangle, Renderer, Subscription, Task, Theme};

const MONO: Font = Font::with_name("DejaVu Sans Mono");

const DIAL_R: f32 = 52.0;
const DIAL_W: f32 = 132.0;
const DIAL_CY: f32 = DIAL_R + 10.0;
const DIALS_H: f32 = DIAL_CY + DIAL_R + 26.0;
const STRIP_TOP: f32 = DIALS_H + 8.0;
const STRIP_H: f32 = 64.0;
const PANEL_H: f32 = STRIP_TOP + STRIP_H + 4.0;

fn main() -> iced::Result {
    let mut renderer = None;
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--folder" => {
                if let Some(f) = args.next() {
                    let _ = FOLDER.set(f);
                }
            }
            "--device" => {
                if let Some(d) = args.next() {
                    let _ = DEVICE.set(d);
                }
            }
            "--renderer" => renderer = args.next(),
            "--simulate" => {
                let _ = SIMULATE.set(true);
            }
            // NOT IN --help: steps played as if pressed, one after another,
            // for screen grabs and for driving the window where nothing can
            // click it. "plan; rehearse 1; burn 1; verify 1". No confirm.
            "--script" => {
                if let Some(s) = args.next() {
                    let _ = SCRIPT.set(s);
                }
            }
            "-h" | "--help" => {
                println!("copal-zap-gui -- a folder cut into discs, with dials");
                println!();
                println!("  --folder DIR   start on DIR (default ~/Downloads/SharedVM)");
                println!("  --device DEV   the burner (default /dev/sr0; stdio:FILE for an image)");
                println!("  --renderer R   wgpu or tiny-skia (default: tiny-skia on a virtio GPU)");
                println!("  --simulate     start in simulation: an image where each disc would be,");
                println!("                 verified and deleted; plans kept apart; Retire locked");
                println!();
                println!("$XORRISO names the xorriso to run; plans live where copal-zap keeps them.");
                return Ok(());
            }
            _ => {}
        }
    }
    pick_renderer(renderer.as_deref());
    iced::application(App::new, App::update, App::view)
        .title(App::title)
        .subscription(App::subscription)
        .theme(App::theme)
        .window(iced::window::Settings {
            size: iced::Size::new(860.0, 820.0),
            platform_specific: iced::window::settings::PlatformSpecific {
                application_id: "copal-zap".to_string(),
                ..Default::default()
            },
            ..Default::default()
        })
        .run()
}

/// Startup flags, read once. A plain function builds the first state, so
/// there is nowhere else to hang them.
static FOLDER: std::sync::OnceLock<String> = std::sync::OnceLock::new();
static DEVICE: std::sync::OnceLock<String> = std::sync::OnceLock::new();
static SCRIPT: std::sync::OnceLock<String> = std::sync::OnceLock::new();
static SIMULATE: std::sync::OnceLock<bool> = std::sync::OnceLock::new();

/// One step of --script.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Step {
    Plan,
    Act(usize, Act),
}

fn parse_script(s: &str) -> Result<Vec<Step>, String> {
    s.split(';')
        .map(str::trim)
        .filter(|w| !w.is_empty())
        .map(|w| {
            let mut it = w.split_whitespace();
            let verb = it.next().unwrap_or("");
            let n = || -> Result<usize, String> {
                let n: usize = it.clone().next().and_then(|n| n.parse().ok()).ok_or(format!("{w}: which disc?"))?;
                n.checked_sub(1).ok_or(format!("{w}: discs count from 1"))
            };
            Ok(match verb {
                "plan" => Step::Plan,
                "rehearse" => Step::Act(n()?, Act::Rehearse),
                "burn" => Step::Act(n()?, Act::Burn),
                "verify" => Step::Act(n()?, Act::Verify),
                "retire" => Step::Act(n()?, Act::Retire),
                _ => return Err(format!("--script: no step {w}")),
            })
        })
        .collect()
}

// ---------------------------------------------------------------- messages ---

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Act {
    Rehearse,
    Burn,
    Verify,
    Retire,
}

impl Act {
    fn word(self) -> &'static str {
        match self {
            Act::Rehearse => "Rehearse",
            Act::Burn => "Burn",
            Act::Verify => "Verify",
            Act::Retire => "Retire",
        }
    }
    /// The stages a disc may be in for this step. Burning wants a rehearsal
    /// first: it is the only way to know the source can keep up.
    ///
    /// A simulation may be burned again once it is through: its disc was an
    /// image, verified and deleted, and playing it again costs nothing. It can
    /// never retire -- the library refuses too; this only greys the button.
    fn allowed(self, s: Stage, simulated: bool) -> bool {
        match self {
            Act::Rehearse => s <= Stage::Rehearsed,
            Act::Burn if simulated => s >= Stage::Rehearsed && s < Stage::Retired,
            Act::Burn => s == Stage::Rehearsed,
            Act::Verify if simulated => s == Stage::Burned,
            Act::Verify => s == Stage::Burned || s == Stage::Verified,
            Act::Retire => s == Stage::Verified && !simulated,
        }
    }
    /// Steps that cannot be taken back ask twice.
    fn asks_twice(self) -> bool {
        matches!(self, Act::Burn | Act::Retire)
    }
}

/// What the plan is cut to.
#[derive(Clone, Debug, PartialEq)]
enum Choice {
    Drive,
    Kind(Media),
}

impl std::fmt::Display for Choice {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Choice::Drive => write!(f, "the disc in the drive"),
            Choice::Kind(m) => write!(f, "{}", m.label),
        }
    }
}

/// A simulation has no drive to ask.
fn choices(simulate: bool) -> Vec<Choice> {
    let mut v = if simulate { vec![] } else { vec![Choice::Drive] };
    v.extend(media::TABLE.iter().map(|m| Choice::Kind(*m)));
    v
}

#[derive(Clone, Debug)]
enum Message {
    FolderEdited(String),
    Rescan,
    Scanned(Result<Arc<plan::Scan>, String>),
    Chose(Choice),
    DeviceEdited(String),
    Simulate(bool),
    Probe,
    Probed(Result<Probe, String>),
    MakePlan,
    Select(usize),
    Act(usize, Act),
    Progress(Progress),
    Done(Result<String, String>),
    /// The next --script step, once the folder has been read.
    Next,
    Quit,
}

// ------------------------------------------------------------------- state ---

/// The plan the folder and the media make, before it is saved.
struct Preview {
    media: Media,
    /// Sectors on the disc being cut to: the table's, or the drive's free.
    capacity: u64,
    discs: Vec<plan::Disc>,
    trouble: Option<String>,
    /// How many of every kind of blank the folder needs.
    others: Vec<(Media, Option<usize>)>,
}

/// A saved disc, as its files say it is.
#[derive(Clone)]
struct DiscView {
    label: String,
    files: usize,
    bytes: u64,
    fill: f32,
    stage: Stage,
    first: String,
    last: String,
    media: Option<Media>,
    rate: Option<f64>,
    simulated: bool,
}

struct SetView {
    name: String,
    discs: Vec<DiscView>,
}

/// The gauges, fed by xorriso's progress lines.
#[derive(Default)]
struct Live {
    rate: Option<f64>,
    last: Option<(Instant, u64)>,
    fifo: Option<u8>,
    buf: Option<u8>,
    percent: Option<f32>,
    speed: Option<(f32, char)>,
}

struct Job {
    disc: usize,
    act: Act,
    started: Instant,
}

struct App {
    skin: Skin,
    folder: String,
    device: String,
    choice: Choice,
    scan: Option<Arc<plan::Scan>>,
    scanning: bool,
    probe: Option<Result<Probe, String>>,
    preview: Option<Preview>,
    set: Option<SetView>,
    selected: usize,
    job: Option<Job>,
    live: Live,
    confirm: Option<(usize, Act)>,
    note: (String, bool),
    script: std::collections::VecDeque<Step>,
    simulate: bool,
}

impl App {
    fn new() -> (App, Task<Message>) {
        let folder = FOLDER
            .get()
            .cloned()
            .unwrap_or_else(|| disc::default_root().to_string_lossy().into_owned());
        let mut app = App {
            skin: Skin::detect(),
            folder,
            device: DEVICE.get().cloned().unwrap_or_else(|| "/dev/sr0".into()),
            choice: Choice::Kind(media::by_name("bd50").unwrap()),
            scan: None,
            scanning: false,
            probe: None,
            preview: None,
            set: None,
            selected: 0,
            job: None,
            live: Live::default(),
            confirm: None,
            note: (String::new(), false),
            script: Default::default(),
            simulate: SIMULATE.get().copied().unwrap_or(false),
        };
        match SCRIPT.get().map(|s| parse_script(s)) {
            Some(Ok(v)) => app.script = v.into(),
            Some(Err(e)) => app.note = (e, true),
            None => {}
        }
        app.load_set();
        let t = app.rescan();
        (app, t)
    }

    fn title(&self) -> String {
        match (&self.job, &self.set) {
            (Some(j), Some(s)) => {
                let pct = self.live.percent.map(|p| format!(" {p:.0}%")).unwrap_or_default();
                let sim = if self.simulate { "simulated " } else { "" };
                format!("{sim}{}{pct} {} -- copal-zap", j.act.word(), s.discs.get(j.disc).map_or("", |d| d.label.as_str()))
            }
            _ if self.simulate => "copal-zap (simulation)".into(),
            _ => "copal-zap".into(),
        }
    }

    fn theme(&self) -> Theme {
        self.skin.theme()
    }

    /// Real plans and simulated ones never share a folder.
    fn home(&self) -> std::path::PathBuf {
        if self.simulate { disc::sim_home() } else { disc::home() }
    }

    fn root(&self) -> std::path::PathBuf {
        let f = self.folder.trim();
        match f.strip_prefix("~/") {
            Some(rest) => std::path::PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(rest),
            None => f.into(),
        }
    }

    fn rescan(&mut self) -> Task<Message> {
        self.scanning = true;
        let root = self.root();
        work(move |send| {
            send(Message::Scanned(plan::scan(&root).map(Arc::new).map_err(|e| format!("{}: {e}", root.display()))));
        })
    }

    /// The newest saved plan of this folder, if there is one.
    fn load_set(&mut self) {
        let root = self.root();
        let home = self.home();
        let Ok(sets) = Set::list(&home) else {
            self.set = None;
            return;
        };
        let mut found = None;
        for s in sets {
            let Ok(ds) = s.discs() else { continue };
            let Some(first) = ds.first() else { continue };
            if first.cue().map(|c| c.root == root).unwrap_or(false) {
                found = Some(s);
            }
        }
        self.set = found.map(|s| view_set(&s));
        if let Some(s) = &self.set {
            self.selected = self.selected.min(s.discs.len().saturating_sub(1));
        }
    }

    fn replan(&mut self) {
        let Some(scan) = self.scan.clone() else {
            self.preview = None;
            return;
        };
        let (m, capacity, trouble) = match &self.choice {
            Choice::Kind(m) => (*m, m.sectors, None),
            Choice::Drive => match &self.probe {
                Some(Ok(p)) => match p.family() {
                    Some(m) if p.appendable() => (m, p.free, None),
                    Some(m) => (m, 0, Some(format!("the disc in the drive {}", p.status))),
                    None => (media::by_name("bd50").unwrap(), 0, Some(format!("{} is not a disc", p.kind))),
                },
                Some(Err(e)) => (media::by_name("bd50").unwrap(), 0, Some(e.clone())),
                None => (media::by_name("bd50").unwrap(), 0, Some("asking the drive...".into())),
            },
        };
        let others = media::TABLE
            .iter()
            .map(|o| (*o, plan::fill(&scan.entries, o.budget()).ok().map(|d| d.len())))
            .collect();
        let (discs, trouble) = if capacity == 0 {
            (Vec::new(), trouble)
        } else {
            match plan::fill(&scan.entries, media::budget(capacity)) {
                Ok(d) => (d, trouble),
                Err(t) => (Vec::new(), Some(format!("{} needs {} on one disc", t.group, gb(t.sectors * 2048)))),
            }
        };
        self.preview = Some(Preview { media: m, capacity, discs, trouble, others });
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        if !matches!(message, Message::Act(..) | Message::Progress(_)) {
            self.confirm = None;
        }
        match message {
            Message::FolderEdited(f) => self.folder = f,
            Message::Rescan => {
                self.load_set();
                return self.rescan();
            }
            Message::Scanned(r) => {
                self.scanning = false;
                match r {
                    Ok(s) => self.scan = Some(s),
                    Err(e) => {
                        self.scan = None;
                        self.note = (e, true);
                    }
                }
                self.replan();
                return Task::done(Message::Next);
            }
            Message::Chose(c) => {
                let probe = c == Choice::Drive;
                self.choice = c;
                self.replan();
                if probe {
                    return self.update(Message::Probe);
                }
            }
            Message::DeviceEdited(d) => self.device = d,
            Message::Simulate(on) => {
                if self.job.is_some() {
                    return Task::none();
                }
                self.simulate = on;
                if on && self.choice == Choice::Drive {
                    self.choice = Choice::Kind(media::by_name("bd50").unwrap());
                }
                self.selected = 0;
                self.load_set();
                self.replan();
                self.note = if on {
                    ("simulation: plans kept apart, discs are images, Retire is locked".into(), false)
                } else {
                    ("real discs: plans, burns and Retire are for real".into(), false)
                };
            }
            Message::Probe => {
                self.probe = None;
                self.replan();
                let dev = self.device.clone();
                return work(move |send| send(Message::Probed(media::probe(&dev))));
            }
            Message::Probed(p) => {
                self.probe = Some(p);
                self.replan();
            }
            Message::MakePlan => {
                let Some(p) = &self.preview else { return Task::none() };
                if p.discs.is_empty() {
                    return Task::none();
                }
                let root = self.root();
                let name = plan::set_name(&root, &copal_zap::today());
                let made = if self.simulate {
                    Set::create_simulated(&self.home(), &name, &root, &p.media, &p.discs)
                } else {
                    Set::create(&self.home(), &name, &root, &p.media, &p.discs)
                };
                match made {
                    Ok(s) => {
                        self.note = (format!("saved {} discs as {}", p.discs.len(), s.name), false);
                        self.set = Some(view_set(&s));
                        self.selected = 0;
                    }
                    Err(e) => self.note = (e.to_string(), true),
                }
            }
            Message::Select(i) => self.selected = i,
            Message::Act(i, act) => {
                if self.job.is_some() {
                    return Task::none();
                }
                let simulated = self.set.as_ref().and_then(|s| s.discs.get(i)).is_some_and(|d| d.simulated);
                if act.asks_twice() && !simulated && self.confirm != Some((i, act)) {
                    self.confirm = Some((i, act));
                    self.selected = i;
                    return Task::none();
                }
                self.confirm = None;
                return self.start(i, act);
            }
            Message::Progress(p) => self.gauge(&p),
            Message::Done(r) => {
                if let Some(j) = self.job.take() {
                    let took = j.started.elapsed().as_secs();
                    self.note = match r {
                        Ok(s) => (format!("{s}  ({}:{:02})", took / 60, took % 60), false),
                        Err(e) => (e, true),
                    };
                }
                // a finished step reads full; a failed one keeps where it stopped
                if !self.note.1 {
                    self.live.percent = Some(100.0);
                }
                self.live.fifo = None;
                self.live.buf = None;
                self.live.speed = None;
                self.load_set();
                // a failed step ends the script: the steps after it assumed it worked
                if self.note.1 {
                    self.script.clear();
                }
                return Task::done(Message::Next);
            }
            Message::Next => {
                if self.job.is_some() {
                    return Task::none();
                }
                match self.script.pop_front() {
                    Some(Step::Plan) => {
                        let t = self.update(Message::MakePlan);
                        return Task::batch([t, Task::done(Message::Next)]);
                    }
                    Some(Step::Act(i, act)) => return self.start(i, act),
                    None => {}
                }
            }
            Message::Quit => return iced::exit(),
        }
        Task::none()
    }

    fn start(&mut self, i: usize, act: Act) -> Task<Message> {
        let Some(set) = &self.set else { return Task::none() };
        let Some(d) = set.discs.get(i) else { return Task::none() };
        let (name, label, dev, home) = (set.name.clone(), d.label.clone(), self.device.clone(), self.home());
        self.job = Some(Job { disc: i, act, started: Instant::now() });
        self.selected = i;
        self.live = Live { percent: Some(0.0), ..Live::default() };
        self.note = (format!("{} {label}...", act.word()), false);
        work(move |send| {
            let r = (|| -> Result<String, disc::Error> {
                let set = Set::open(&home, &name)?;
                let d = set.disc(&label)?;
                let media = d.cue().ok().and_then(|c| media::by_name(&c.media));
                let progress = |p: &Progress| send(Message::Progress(p.clone()));
                Ok(match act {
                    Act::Rehearse => match d.rehearse(progress)? {
                        Some(rate) => {
                            let speed = media
                                .and_then(|m| m.safe_speed(rate).map(|x| format!(": burn at {x}x")))
                                .unwrap_or_else(|| ": TOO SLOW to burn".into());
                            format!("{label} rehearsed, the source reads at {:.1} MB/s{speed}", rate / 1e6)
                        }
                        None => format!(
                            "{label} rehearsed, too quickly to measure the source (under {:.0} s)",
                            disc::MEASURE_SECS
                        ),
                    },
                    Act::Burn if d.simulated => {
                        let img = d.simulate_burn(None, progress)?;
                        format!("{label} burned into {} (an image, not a disc); verify it next", img.display())
                    }
                    Act::Burn => {
                        d.burn(&dev, None, media.as_ref(), progress)?;
                        format!("{label} burned on {dev}; verify it next")
                    }
                    Act::Verify if d.simulated => {
                        format!("{label} verified: {} files match; the image is deleted", d.simulate_verify()?)
                    }
                    Act::Verify => format!("{label} verified: {} files match", d.verify(&dev)?),
                    Act::Retire => format!("{label} retired into {}", d.retire()?.display()),
                })
            })();
            send(Message::Done(r.map_err(|e| e.to_string())));
        })
    }

    fn gauge(&mut self, p: &Progress) {
        let now = Instant::now();
        if let Some((t, s)) = self.live.last {
            let dt = now.duration_since(t).as_secs_f64();
            if dt > 0.2 && p.sectors >= s {
                let r = (p.sectors - s) as f64 * 2048.0 / dt;
                // a little smoothing: one slow second is not a slow source
                self.live.rate = Some(self.live.rate.map_or(r, |o| o * 0.6 + r * 0.4));
            }
        }
        self.live.last = Some((now, p.sectors));
        self.live.fifo = Some(p.fifo);
        self.live.buf = Some(p.buf);
        self.live.percent = Some(p.percent);
        self.live.speed = p.speed;
    }

    fn subscription(&self) -> Subscription<Message> {
        // q closes, as in radbeeper-gui -- but not mid-burn, where a stray key
        // would cost a disc. Super+q (the compositor's) still does.
        // NO CAPTURE: iced refuses a filter_map closure that holds a value,
        // so whether a job is running rides in with the event instead.
        iced::keyboard::listen().with(self.job.is_some()).filter_map(|(busy, event)| match event {
            iced::keyboard::Event::KeyPressed { key, modifiers, .. }
                if !busy
                    && key.as_ref() == iced::keyboard::Key::Character("q")
                    && !(modifiers.control() || modifiers.alt() || modifiers.logo()) =>
            {
                Some(Message::Quit)
            }
            _ => None,
        })
    }

    // ------------------------------------------------------------------ view

    fn view(&self) -> Element<'_, Message> {
        let sk = &self.skin;
        let busy = self.job.is_some();
        let label = |s: &str| text(s.to_string()).size(13).color(sk.dim).width(Length::Fixed(64.0));

        let folder = row![
            label("Folder"),
            text_input("a folder to back up", &self.folder)
                .on_input(Message::FolderEdited)
                .on_submit(Message::Rescan)
                .font(MONO)
                .size(13),
            button(text(if self.scanning { "Reading..." } else { "Rescan" }).size(13))
                .on_press_maybe((!self.scanning && !busy).then_some(Message::Rescan)),
        ]
        .spacing(8)
        .align_y(iced::Center);

        let mut media_row = row![
            label("Media"),
            pick_list(choices(self.simulate), Some(self.choice.clone()), Message::Chose).text_size(13),
        ]
        .spacing(8)
        .align_y(iced::Center);
        media_row = if self.simulate {
            media_row.push(text("Drive: none -- each disc is an image, verified then deleted").size(13).color(sk.hud))
        } else {
            media_row
                .push(text("Drive").size(13).color(sk.dim))
                .push(
                    text_input("/dev/sr0", &self.device)
                        .on_input(Message::DeviceEdited)
                        .font(MONO)
                        .size(13)
                        .width(Length::Fixed(200.0)),
                )
                .push(button(text("Ask the drive").size(13)).on_press_maybe((!busy).then_some(Message::Probe)))
        };
        media_row = media_row.push(Space::new().width(Fill)).push(
            toggler(self.simulate)
                .label("Simulate")
                .text_size(13)
                .on_toggle_maybe((!busy).then_some(Message::Simulate)),
        );

        let probe_line = match &self.probe {
            _ if self.simulate => text("SIMULATION -- every source byte is read and checksummed, as for a disc. Retire is locked.")
                .color(sk.hud),
            None => text(""),
            Some(Ok(p)) => text(format!(
                "drive: {}, {}, {} free",
                p.kind,
                p.status,
                gb(p.free * copal_zap::SECTOR)
            ))
            .color(sk.dim),
            Some(Err(e)) => text(format!("drive: {e}")).color(sk.warn),
        }
        .size(12)
        .font(MONO);

        let mut page = column![folder, media_row, probe_line, self.numbers()].spacing(8);
        page = page.push(self.panel());
        page = page.push(self.discs());
        let note = text(self.note.0.clone()).size(13).font(MONO).color(if self.note.1 { sk.bad } else { sk.fg });
        page = page.push(note);
        container(page.padding(14)).width(Fill).height(Fill).into()
    }

    /// The numbers worked out from the folder and the media.
    fn numbers(&self) -> Element<'_, Message> {
        let sk = &self.skin;
        let Some(scan) = &self.scan else {
            return text(if self.scanning { "reading the folder..." } else { "no folder" }).size(13).color(sk.dim).into();
        };
        let total: u64 = scan.entries.iter().map(|e| e.bytes).sum();
        let mut lines = column![text(format!(
            "{} files, {}   ({} Mac metadata and specials left out)",
            scan.entries.len(),
            gb(total),
            scan.skipped
        ))
        .size(14)
        .font(MONO)]
        .spacing(3);
        if let Some(p) = &self.preview {
            let others: Vec<String> = p
                .others
                .iter()
                .map(|(m, n)| match n {
                    Some(n) => format!("{} {n}", m.name),
                    None => format!("{} --", m.name),
                })
                .collect();
            lines = lines.push(text(format!("discs needed:  {}", others.join("  ·  "))).size(12).font(MONO).color(sk.dim));
            match &p.trouble {
                Some(t) => lines = lines.push(text(t.clone()).size(13).color(sk.warn)),
                None if !p.discs.is_empty() => {
                    let n = p.discs.len();
                    let last = p.discs.last().map_or(0.0, |d| d.sectors as f32 / p.capacity as f32 * 100.0);
                    let rate = self.held_rate();
                    let timing = match rate.map(|r| (r, p.media.safe_speed(r))) {
                        Some((_, Some(x))) => {
                            let secs = p.media.burn_secs(total, x);
                            format!("   at {x}x: {} to burn them all, about as long again to verify", hm(secs))
                        }
                        Some((r, None)) => format!("   the source reads at {:.1} MB/s: too slow for 1x", r / 1e6),
                        None => "   rehearse a disc to measure the source".into(),
                    };
                    lines = lines.push(
                        text(format!(
                            "on {}: {n} disc{}, the last {last:.0}% full{timing}",
                            if self.choice == Choice::Drive { "the disc in the drive" } else { p.media.label },
                            if n == 1 { "" } else { "s" }
                        ))
                        .size(13)
                        .font(MONO),
                    );
                }
                None => {}
            }
            // OFFERED ONLY WHEN IT WOULD CHANGE SOMETHING. Saving over a plan
            // that already says the same thing would only throw away its
            // rehearsals; Set::create refuses outright once a disc is burned.
            let same = self.set.as_ref().is_some_and(|s| {
                s.discs.len() == p.discs.len()
                    && s.discs.iter().zip(&p.discs).all(|(a, b)| a.files == b.entries.len() && a.bytes == b.bytes())
            });
            if !p.discs.is_empty() && self.job.is_none() && !same {
                let what = match &self.set {
                    Some(s) => format!("Save this plan (replaces {}: the folder has changed)", s.name),
                    None => "Save this plan".into(),
                };
                lines = lines.push(button(text(what).size(13)).on_press(Message::MakePlan));
            }
        }
        if !scan.read_only.is_empty() {
            let tops: Vec<&str> = scan.read_only.iter().filter(|d| !d.contains('/')).map(String::as_str).collect();
            lines = lines.push(
                text(format!(
                    "read-only here, so Retire cannot empty them: {}  (on the Mac: chmod g+w)",
                    tops.join(", ")
                ))
                .size(12)
                .color(sk.warn),
            );
        }
        lines.into()
    }

    /// The rate the needle rests on when nothing is running: the selected
    /// disc's last rehearsal, else any disc's.
    fn held_rate(&self) -> Option<f64> {
        let s = self.set.as_ref()?;
        s.discs.get(self.selected).and_then(|d| d.rate).or_else(|| s.discs.iter().rev().find_map(|d| d.rate))
    }

    fn family(&self) -> Media {
        self.set
            .as_ref()
            .and_then(|s| s.discs.get(self.selected)?.media)
            .or(self.preview.as_ref().map(|p| p.media))
            .unwrap_or_else(|| media::by_name("bd50").unwrap())
    }

    /// The dials and the strip, and the words stacked over them.
    fn panel(&self) -> Element<'_, Message> {
        let sk = &self.skin;
        let fam = self.family();
        let running = self.job.is_some();
        let rate = if running { self.live.rate } else { self.held_rate() };
        let max = fam.unit as f64 * 8.0;
        let dials = vec![
            Face {
                value: rate.map(|r| (r / max).clamp(0.0, 1.0) as f32),
                bands: vec![
                    ((fam.unit as f64 / max) as f32, sk.bad),
                    ((fam.unit as f64 * 2.0 / max) as f32, sk.warn),
                    (1.0, sk.ok),
                ],
                ticks: (1..=8).map(|x| x as f32 / 8.0).collect(),
                live: running,
            },
            pct_face(self.live.fifo, sk, running),
            pct_face(self.live.buf, sk, running),
            Face {
                value: self.live.percent.map(|p| p / 100.0),
                bands: vec![(1.0, sk.hud)],
                ticks: (1..=4).map(|x| x as f32 / 4.0).collect(),
                live: running,
            },
        ];
        let strip = match &self.set {
            Some(s) => s.discs.iter().map(|d| (d.fill, sk.stage(d.stage))).collect(),
            None => self
                .preview
                .as_ref()
                .map(|p| p.discs.iter().map(|d| (d.sectors as f32 / p.capacity as f32, sk.faint)).collect())
                .unwrap_or_default(),
        };
        let chart = canvas(Panel {
            skin: sk.clone(),
            dials,
            strip,
            selected: self.set.as_ref().map(|_| self.selected),
            busy: self.job.as_ref().map(|j| j.disc),
        })
        .width(Fill)
        .height(Length::Fixed(PANEL_H));

        // The value sits in the open bottom of the sweep, on the face; the
        // caption goes under the face, on the page, in the page's colours.
        let reading = |big: String, small: &str| {
            column![
                Space::new().height(DIAL_CY + DIAL_R * 0.32),
                text(big).size(14).font(MONO).color(sk.on_face),
                Space::new().height(DIAL_R * 0.30),
                text(small.to_string()).size(11).color(sk.dim),
            ]
            .width(Length::Fixed(DIAL_W))
            .align_x(iced::Center)
        };
        let speed = match (running, self.live.speed) {
            (true, Some((x, f))) => format!("{x:.1}x{f}"),
            _ => match rate.and_then(|r| fam.safe_speed(r)) {
                Some(x) => format!("burn {x}x"),
                None if rate.is_some() => "too slow".into(),
                None => "unmeasured".into(),
            },
        };
        let mbs = rate.map_or("--".into(), |r| format!("{:.1} MB/s", r / 1e6));
        let pct = |v: Option<u8>| v.map_or("--".into(), |v| format!("{v}%"));
        let over = row![
            reading(mbs, &format!("source · {speed}")),
            reading(pct(self.live.fifo), "fifo (source side)"),
            reading(pct(self.live.buf), "drive buffer"),
            reading(self.live.percent.map_or("--".into(), |p| format!("{p:.1}%")), self.job.as_ref().map_or("progress", |j| j.act.word())),
        ];
        stack![chart, over].into()
    }

    fn discs(&self) -> Element<'_, Message> {
        let sk = &self.skin;
        let Some(set) = &self.set else {
            return text("No plan saved for this folder yet. Choose the media, then Save this plan.")
                .size(13)
                .color(sk.dim)
                .into();
        };
        let mut list = column![text(format!("{}  ({})", set.name, self.home().join(&set.name).display()))
            .size(12)
            .font(MONO)
            .color(sk.dim)]
        .spacing(4);
        for (i, d) in set.discs.iter().enumerate() {
            let num = d.label.rsplit_once("_D").map_or(d.label.clone(), |(_, r)| r.replace("_OF_", " of "));
            let speed = match (d.rate, d.media) {
                (Some(r), Some(m)) => m.safe_speed(r).map_or("too slow".into(), |x| format!("{x}x")),
                _ => String::new(),
            };
            let mut r = row![
                button(text(format!("D{num}")).size(13).font(MONO)).on_press(Message::Select(i)).style(if i == self.selected {
                    button::primary
                } else {
                    button::text
                }),
                text(d.stage.word()).size(13).color(sk.stage(d.stage)).width(Length::Fixed(72.0)),
                text(format!("{:6} files {:>9} {:4.0}% {:>8}", d.files, gb(d.bytes), d.fill * 100.0, speed))
                    .size(13)
                    .font(MONO),
                text(format!("{} .. {}", clip(&d.first, 26), clip(&d.last, 26))).size(12).color(sk.dim).width(Fill),
            ]
            .spacing(10)
            .align_y(iced::Center);
            for act in [Act::Rehearse, Act::Burn, Act::Verify, Act::Retire] {
                let ok = act.allowed(d.stage, d.simulated) && self.job.is_none();
                let asking = self.confirm == Some((i, act));
                let word = match (asking, act, d.simulated) {
                    (true, ..) => format!("Sure? {}", act.word()),
                    (_, Act::Retire, true) => "Retire (locked)".into(),
                    _ => act.word().to_string(),
                };
                let b = button(text(word).size(12))
                    .on_press_maybe(ok.then_some(Message::Act(i, act)))
                    .style(if asking { button::danger } else { button::secondary });
                r = r.push(b);
            }
            list = list.push(r);
        }
        scrollable(list).height(Fill).into()
    }
}

fn view_set(s: &Set) -> SetView {
    let discs = s
        .discs()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|d| {
            let c = d.cue().ok()?;
            let m = media::by_name(&c.media);
            let sectors: u64 = c.entries.iter().map(plan::Entry::sectors).sum();
            Some(DiscView {
                files: c.entries.len(),
                bytes: c.bytes(),
                fill: m.map_or(0.0, |m| sectors as f32 / m.sectors as f32),
                stage: d.stage().unwrap_or(Stage::Planned),
                first: c.entries.first().map(|e| e.path.clone()).unwrap_or_default(),
                last: c.entries.last().map(|e| e.path.clone()).unwrap_or_default(),
                media: m,
                rate: d.rehearsed_rate().ok().flatten(),
                simulated: d.simulated,
                label: d.label,
            })
        })
        .collect();
    SetView { name: s.name.clone(), discs }
}

/// Runs `f` on a thread of its own, its messages delivered in order. A full
/// channel waits rather than dropping: the last message is the result.
fn work(f: impl FnOnce(&dyn Fn(Message)) + Send + 'static) -> Task<Message> {
    Task::stream(iced::stream::channel(64, async move |out: mpsc::Sender<Message>| {
        std::thread::spawn(move || {
            let out = Mutex::new(out);
            let send = |m: Message| deliver(&out, m);
            f(&send);
        });
    }))
}

fn deliver(out: &Mutex<mpsc::Sender<Message>>, mut m: Message) {
    loop {
        let Ok(mut tx) = out.lock() else { return };
        match tx.try_send(m) {
            Ok(()) => return,
            Err(e) if e.is_full() => {
                m = e.into_inner();
                drop(tx);
                std::thread::sleep(Duration::from_millis(10));
            }
            Err(_) => return,
        }
    }
}

// ---------------------------------------------------------------- the panel ---

/// One dial: a value from 0 to 1, coloured bands up to given fractions.
#[derive(Clone)]
struct Face {
    value: Option<f32>,
    bands: Vec<(f32, Color)>,
    ticks: Vec<f32>,
    /// A live needle is bright; a held one (the last rehearsal) is dimmed.
    live: bool,
}

fn pct_face(v: Option<u8>, sk: &Skin, live: bool) -> Face {
    // a fifo or buffer near empty is the warning: the drive is waiting
    Face {
        value: v.map(|v| f32::from(v) / 100.0),
        bands: vec![(0.10, sk.bad), (0.40, sk.warn), (1.0, sk.ok)],
        ticks: (1..=10).map(|x| x as f32 / 10.0).collect(),
        live,
    }
}

struct Panel {
    skin: Skin,
    dials: Vec<Face>,
    /// One bar per disc: how full, in what colour.
    strip: Vec<(f32, Color)>,
    selected: Option<usize>,
    busy: Option<usize>,
}

impl canvas::Program<Message> for Panel {
    type State = ();

    fn update(
        &self,
        _state: &mut (),
        event: &iced::Event,
        bounds: Rectangle,
        cursor: iced::mouse::Cursor,
    ) -> Option<canvas::Action<Message>> {
        let iced::Event::Mouse(iced::mouse::Event::ButtonPressed(iced::mouse::Button::Left)) = event else {
            return None;
        };
        self.selected?;
        let p = cursor.position_in(bounds)?;
        let i = strip_hit(p, bounds.width, self.strip.len())?;
        Some(canvas::Action::publish(Message::Select(i)))
    }

    fn draw(
        &self,
        _state: &(),
        renderer: &Renderer,
        _theme: &Theme,
        bounds: Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<canvas::Geometry> {
        let mut frame = canvas::Frame::new(renderer, bounds.size());
        for (k, face) in self.dials.iter().enumerate() {
            self.dial(&mut frame, Point::new(DIAL_W * (k as f32 + 0.5), DIAL_CY), face);
        }
        self.strip(&mut frame, bounds.width);
        vec![frame.into_geometry()]
    }
}

/// Which bar of the strip a point is over.
fn strip_hit(p: Point, width: f32, n: usize) -> Option<usize> {
    if n == 0 || p.y < STRIP_TOP || p.y > STRIP_TOP + STRIP_H {
        return None;
    }
    let i = (p.x / (width / n as f32)) as usize;
    (i < n).then_some(i)
}

impl Panel {
    /// A 270-degree sweep, down-left to down-right, as radbeeper's dials are.
    fn dial(&self, frame: &mut canvas::Frame, c: Point, face: &Face) {
        use canvas::{Path, Stroke};
        let sk = &self.skin;
        let start = std::f32::consts::PI * 0.75;
        let sweep = std::f32::consts::PI * 1.5;
        frame.fill(&Path::circle(c, DIAL_R), sk.face);
        frame.stroke(&Path::circle(c, DIAL_R), Stroke::default().with_width(2.0).with_color(Color { a: 0.5, ..sk.bezel }));
        let mut from = 0.0;
        for (to, tint) in &face.bands {
            let (a0, a1) = (start + sweep * from, start + sweep * to);
            let arc = Path::new(|b| {
                b.arc(canvas::path::Arc {
                    center: c,
                    radius: DIAL_R * 0.84,
                    start_angle: iced::Radians(a0),
                    end_angle: iced::Radians(a1),
                })
            });
            frame.stroke(&arc, Stroke::default().with_width(5.0).with_color(Color { a: 0.75, ..*tint }));
            from = *to;
        }
        for t in std::iter::once(&0.0).chain(face.ticks.iter()) {
            let a = start + sweep * t;
            let (ca, sa) = (a.cos(), a.sin());
            let tick = Path::line(
                Point::new(c.x + ca * DIAL_R * 0.70, c.y + sa * DIAL_R * 0.70),
                Point::new(c.x + ca * DIAL_R * 0.76, c.y + sa * DIAL_R * 0.76),
            );
            frame.stroke(&tick, Stroke::default().with_width(1.5).with_color(Color { a: 0.7, ..sk.face_dim }));
        }
        if let Some(v) = face.value {
            let a = start + sweep * v.clamp(0.0, 1.0);
            let (ca, sa) = (a.cos(), a.sin());
            let (px, py) = (-sa, ca);
            let (reach, back, half) = (DIAL_R * 0.80, DIAL_R * 0.16, 3.2);
            let needle = Path::new(|b| {
                b.move_to(Point::new(c.x + reach * ca, c.y + reach * sa));
                b.line_to(Point::new(c.x + px * half, c.y + py * half));
                b.line_to(Point::new(c.x - back * ca + px * half * 0.55, c.y - back * sa + py * half * 0.55));
                b.line_to(Point::new(c.x - back * ca - px * half * 0.55, c.y - back * sa - py * half * 0.55));
                b.line_to(Point::new(c.x - px * half, c.y - py * half));
                b.close();
            });
            let tint = if face.live { sk.needle } else { Color { a: 0.55, ..sk.needle } };
            frame.fill(&needle, tint);
        }
        frame.fill(&Path::circle(c, 5.0), sk.bezel);
        frame.fill(&Path::circle(c, 2.4), Color { a: 0.9, ..sk.face });
    }

    /// The plan: a bar per disc, its height how full, its colour its stage.
    fn strip(&self, frame: &mut canvas::Frame, width: f32) {
        use canvas::{Path, Stroke};
        let n = self.strip.len();
        let sk = &self.skin;
        frame.fill(&Path::rectangle(Point::new(0.0, STRIP_TOP), iced::Size::new(width, STRIP_H)), sk.wash);
        if n == 0 {
            return;
        }
        let slot = width / n as f32;
        let gap = (slot * 0.18).clamp(0.0, 6.0);
        for (i, (fill, tint)) in self.strip.iter().enumerate() {
            let x = slot * i as f32 + gap / 2.0;
            // never thinner than 3 px: a disc holding one small file is a disc
            let h = ((STRIP_H - 6.0) * fill.clamp(0.0, 1.0)).max(3.0);
            let top = STRIP_TOP + STRIP_H - 3.0 - h;
            frame.fill(&Path::rectangle(Point::new(x, top), iced::Size::new(slot - gap, h)), *tint);
            let ring = Path::rectangle(Point::new(x, STRIP_TOP + 2.0), iced::Size::new(slot - gap, STRIP_H - 4.0));
            if Some(i) == self.busy {
                frame.stroke(&ring, Stroke::default().with_width(2.0).with_color(sk.hud));
            } else if Some(i) == self.selected {
                frame.stroke(&ring, Stroke::default().with_width(1.5).with_color(sk.fg));
            }
        }
    }
}

// ------------------------------------------------------------------- skins ---

/// The two copal looks, as radbeeper-gui carries them: a dark panel, or
/// Antiquity's dark instruments on light paper. Dial faces are dark in both.
#[derive(Debug, Clone)]
struct Skin {
    name: String,
    bg: Color,
    fg: Color,
    dim: Color,
    faint: Color,
    wash: Color,
    face: Color,
    face_dim: Color,
    on_face: Color,
    bezel: Color,
    needle: Color,
    hud: Color,
    ok: Color,
    warn: Color,
    bad: Color,
}

fn rgb(hex: u32) -> Color {
    Color::from_rgb8((hex >> 16) as u8, (hex >> 8) as u8, hex as u8)
}

impl Skin {
    fn dark() -> Skin {
        Skin {
            name: "dark".into(),
            bg: rgb(0x1e1e2e),
            fg: rgb(0xccd6eb),
            dim: rgb(0x9ea3b8),
            faint: rgb(0x73788c),
            wash: Color { a: 0.05, ..rgb(0xccd6eb) },
            face: rgb(0x0a0d14),
            face_dim: rgb(0x9ea3b8),
            on_face: rgb(0xe6ecf7),
            bezel: rgb(0x9ea8bd),
            needle: rgb(0xfafafa),
            hud: rgb(0x8cf2e6),
            ok: rgb(0x66d98c),
            warn: rgb(0xf2d859),
            bad: rgb(0xf75257),
        }
    }

    fn antiquity() -> Skin {
        Skin {
            name: "antiquity".into(),
            bg: rgb(0xfce2ab),
            fg: rgb(0x1e2a3a),
            dim: rgb(0x6b5a30),
            faint: rgb(0x8a7748),
            wash: Color { a: 0.07, ..rgb(0x3a2f18) },
            face: rgb(0x1c1c1c),
            face_dim: rgb(0xb8a888),
            on_face: rgb(0xf5ead2),
            bezel: rgb(0x87704f),
            needle: rgb(0xf5ead2),
            hud: rgb(0x1e6b63),
            ok: rgb(0x7ad991),
            warn: rgb(0xb07a12),
            bad: rgb(0xa33b20),
        }
    }

    /// What the desktop is wearing (~/.config/copal/current/theme/theme.conf).
    fn detect() -> Skin {
        let home = std::env::var("HOME").unwrap_or_default();
        let conf = std::path::PathBuf::from(home).join(".config/copal/current/theme/theme.conf");
        let text = std::fs::read_to_string(conf).unwrap_or_default();
        let light = text.lines().any(|l| {
            l.trim().strip_prefix("VARIANT=").map(|v| v.split('#').next().unwrap_or("").trim().trim_matches('"') == "light")
                == Some(true)
        });
        if light { Skin::antiquity() } else { Skin::dark() }
    }

    fn stage(&self, s: Stage) -> Color {
        match s {
            Stage::Planned => self.faint,
            Stage::Rehearsed => self.dim,
            Stage::Burned => self.warn,
            Stage::Verified => self.ok,
            Stage::Retired => self.hud,
        }
    }

    fn theme(&self) -> Theme {
        Theme::custom(
            self.name.clone(),
            iced::theme::Palette {
                background: self.bg,
                text: self.fg,
                primary: self.hud,
                success: self.ok,
                warning: self.warn,
                danger: self.bad,
            },
        )
    }
}

// ----------------------------------------------------------------- helpers ---

fn gb(b: u64) -> String {
    if b >= 1_000_000_000 {
        format!("{:.2} GB", b as f64 / 1e9)
    } else {
        format!("{:.0} MB", b as f64 / 1e6)
    }
}

fn hm(secs: u64) -> String {
    if secs >= 3600 {
        format!("{}h{:02}", secs / 3600, secs % 3600 / 60)
    } else {
        format!("{} min", secs / 60 + 1)
    }
}

fn clip(s: &str, n: usize) -> String {
    if s.chars().count() <= n {
        s.into()
    } else {
        format!("{}…", s.chars().take(n - 1).collect::<String>())
    }
}

/// tiny-skia on a virtio GPU, before iced probes wgpu and Mesa prints four
/// warnings about a GPU that is not there. See radbeeper-gui's pick_renderer.
fn pick_renderer(asked: Option<&str>) {
    if std::env::var_os("EGL_LOG_LEVEL").is_none() {
        std::env::set_var("EGL_LOG_LEVEL", "fatal");
    }
    if std::env::var_os("MESA_LOG_FILE").is_none() {
        std::env::set_var("MESA_LOG_FILE", "/dev/null");
    }
    if let Some(r) = asked {
        std::env::set_var("ICED_BACKEND", r);
        return;
    }
    if std::env::var_os("ICED_BACKEND").is_none() && software_only() {
        std::env::set_var("ICED_BACKEND", "tiny-skia");
    }
}

fn software_only() -> bool {
    let Ok(cards) = std::fs::read_dir("/sys/class/drm") else { return true };
    let mut saw = false;
    for card in cards.flatten() {
        if !card.file_name().to_string_lossy().starts_with("card") {
            continue;
        }
        saw = true;
        let Ok(t) = std::fs::read_link(card.path().join("device/driver")) else { continue };
        if !t.file_name().is_some_and(|n| n.to_string_lossy().starts_with("virtio")) {
            return false;
        }
    }
    saw
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn steps_follow_the_stages() {
        assert!(Act::Rehearse.allowed(Stage::Planned, false));
        assert!(!Act::Burn.allowed(Stage::Planned, false), "a burn wants a rehearsal first");
        assert!(Act::Burn.allowed(Stage::Rehearsed, false));
        assert!(!Act::Burn.allowed(Stage::Burned, false));
        assert!(Act::Verify.allowed(Stage::Burned, false) && Act::Verify.allowed(Stage::Verified, false));
        assert!(!Act::Retire.allowed(Stage::Burned, false));
        assert!(Act::Retire.allowed(Stage::Verified, false));
        assert!(!Act::Rehearse.allowed(Stage::Retired, false));
        // a simulation replays, verifies its one image, and never retires
        assert!(!Act::Burn.allowed(Stage::Planned, true));
        assert!(Act::Burn.allowed(Stage::Verified, true));
        assert!(!Act::Verify.allowed(Stage::Verified, true), "its image is already deleted");
        assert!(!Act::Retire.allowed(Stage::Verified, true));
        assert_eq!(choices(true).len(), choices(false).len() - 1);
        assert!(Act::Burn.asks_twice() && Act::Retire.asks_twice() && !Act::Verify.asks_twice());
    }

    #[test]
    fn scripts() {
        assert_eq!(
            parse_script("plan; rehearse 1;burn 2 ; verify 1").unwrap(),
            vec![Step::Plan, Step::Act(0, Act::Rehearse), Step::Act(1, Act::Burn), Step::Act(0, Act::Verify)]
        );
        assert!(parse_script("burn").is_err());
        assert!(parse_script("burn 0").is_err());
        assert!(parse_script("zap 1").is_err());
    }

    #[test]
    fn the_strip_knows_which_bar() {
        let y = STRIP_TOP + 10.0;
        assert_eq!(strip_hit(Point::new(5.0, y), 400.0, 4), Some(0));
        assert_eq!(strip_hit(Point::new(399.0, y), 400.0, 4), Some(3));
        assert_eq!(strip_hit(Point::new(5.0, 3.0), 400.0, 4), None);
        assert_eq!(strip_hit(Point::new(5.0, y), 400.0, 0), None);
    }

    #[test]
    fn times() {
        assert_eq!(hm(60), "2 min");
        assert_eq!(hm(3 * 3600 + 5 * 60), "3h05");
    }
}
