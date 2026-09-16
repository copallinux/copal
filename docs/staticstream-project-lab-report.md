# One Workspace for Streams: Considering staticstream as a Rust Project That Joins Static Stream and ytq

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

---

## Abstract

Static Stream exists as a Python prototype, `tools/copal-sstr.py`
(`docs/static-stream-lab-report.md`), and `ytq` is a Python download queue
with a curses window, installed by `copal-prep.sh`. This report considers
making them one project: `staticstream`, a Rust Cargo workspace that builds for
every architecture Copal runs on and on the Mac. It would have:
- the format as a library;
- the `record` / `play` command;
- ytq itself, moved into Rust piece by piece. It shares the Python ytq's
  queue until it can replace it, and archives downloads as `.sstr` by
  default;
- a terminal *Workspace* named in the manner of NeXTSTEP and Smalltalk:
  a *Browser* of folders, an *Inspector*, a *Transcript*, a *Shelf*, and
  *Services* sent to the selection.

*Revised after phase 0.* The first version kept ytq in Python beside the
new project. Its owner decided that ytq, now tied closely to Static Stream,
belongs in the Rust project too. Sections V-A, V-C, V-G, V-H and VI say how.

*Revised again after phase 1, which worked.* The Rust `sstr` now does
everything the Python prototype does, with no external crates. It passes
the acceptance test the plan set: 44 comparisons against the prototype in
both directions, through thirteen kinds of damage and a noisy serial line,
with the same repairs, losses, exit codes and bytes. On the same files it
records 5.9× faster, repairs a damaged capture 14.5× faster, and armors
2.6× faster. Section VII has the numbers, the one place Python still wins
and why, and what was found on the way.

*Revised again after phase 2, and at the release.* ytq is Rust, the Python one
is retired, and the project is published under its own name. Section V-A's
five crates are now four modules of one crate: they only ever depended on each
other, shared one version and would have published together, which is a module
boundary and not a package boundary. V-A and V-G say what changed; the 293
comparisons agree across the move.

*Revised again after phase 3, which is finished.* `sstr-workspace` draws the
whole of the screen in V-B: the Browser, the Shelf, the Inspector, the
Transcript, Services and the Queue. It is the one part of the project with no
Python prototype to be compared against, so Section VIII sets out what was
used in place of a crosscheck, and what that cost. `make check` is 356.

*Revised again after phase 4.* Version 1's outer code is built and measured:
two rows, P and Q, where version 0 has one, and two lost records of a group
rebuilt where version 0 loses them. **Version 1 is now what `sstr record`
writes** — and a version 0 reader can still read one, which was not the plan
and is what Section IX-C is about. The 44 comparisons go on being made at
version 0, which is what makes them the chain back to the prototype. `make
dist` builds what the machine it is run on can build, statically, and names
what it cannot — without cargo-make, which V-G proposed and which Section IX
explains the removal of. What is **not** done is the rest of that row: no
binary has been run on a Pi 2B or an x86_64 VM.

Before proposing anything, the report measures what the choice rests on:

| Question | Finding |
|---|---|
| Is Rust worth it? | A line-for-line port of the inner code encodes 105–120 MB/s against Python's 7.0 MB/s, in a 438,592-byte binary |
| Can yt-dlp feed a capture straight through a pipe? | Only partly. With `-o -` it chose a Matroska file that needed no merge (AV1 and Opus), not ytq's MP4. A format that was not offered left a 3,840-byte empty capture that `record` accepted. |
| Can a finished ytq download be archived? | Yes: an MP4 downloaded as ytq does and then recorded came back byte-identical |
| Can the guest build for other architectures? | Not from Alpine's Rust package alone: it ships the standard library for its own target only. cargo-make 0.37.24 and cargo-zigbuild 0.23.4 are in Alpine's repositories. |
| Is the name free? | On crates.io, `sstr` and `staticstr` are taken; `staticstream` is free |
| What do the sibling projects do? | orrery and ascitty build with no external crates at all, because `copal-build` compiles checkouts on nodes that never reach the internet |

The recommendation, set out in Section V:
- **Structure:** one repository and five crates with no external
  dependencies. *(At the release these became four modules of one crate --
  see V-A.)*
- **Configuration:** a shared `~/.config/copal/media.conf` that ytq also
  reads.
- **Build:** a Makefile as the front door, with cargo-make for the
  multi-target release builds only. *(In phase 4 the matrix turned out to be
  a shell loop and cargo-make was dropped -- see V-G.)*
- **Order:** four phases that each end in a test, starting with a Rust
  reader and writer that must agree byte for byte with the Python
  prototype.

Section VI answers "perhaps this is too much": the folders on the disk stay
the structure, and the Workspace is a way of looking at them, not a database
in front of them.

## I. Objective

1. Decide whether Static Stream should become its own Rust project, and what
   it would be called, owned by and made of.
2. Link it with ytq, so that:
   - ytq's configuration joins Copal's;
   - downloads land in an archive folder as `.sstr` by default;
   - a setting exports MP4, as yt-dlp produces, instead or as well.
3. Describe a queue manager, a file browser that selects files to stream,
   and a text stream opener, as one terminal interface.
4. Borrow the organisation and vocabulary of NeXTSTEP and Smalltalk.
5. Build for several architectures.
6. Provide a Makefile that runs `cargo install`, `cargo make` and `cargo run`.
7. Measure what the decisions rest on, and keep the scope comprehensible.

## II. Background

### A. What exists in Copal today

**ytq** is one Python file written by `install_ytq`:
- **Settings:** `KEY=VALUE` lines in `~/.config/ytq/config`. The keys are
  `DIR`, `FORMAT`, `PROFILE`, `KEYRING`, `POLL` and `SUBS`, and an empty
  `~/.config/ytq/auto` switches autostart on. This guest's config holds one
  line, `DIR=~/Downloads/SharedVM`.
- **Queue:** `~/.local/share/ytq/queue.json`, guarded by `queue.lock`, is
  shared by every ytq process; one runner holds `run.lock`. On this guest it
  is a list of 12 entries, each with the fields `url`, `title`, `status`,
  `quality`, `progress`, `file`, `attempts`, `error`, `added`, `live` and
  `cookie_tried`.
- **Interface:** a curses window, and the commands `clip`, `add`, `run`,
  `status`, `cookies`, `transcript`, `list` and `clear`.
- **What a download leaves:** `Author-Title_ID.mp4`, its notes in the MP4's
  metadata, and `Author-Title_ID.txt`, which holds the notes, the
  description and the transcript.

**Static Stream** is the version-0 format and its prototype. `record` and
`play` are there, with `verify`, `armor`, `unarmor` and `recv`, and
`play --serve` for players. Its report measured the format and set out its
limits.

**Copal's configuration** is in two places:
- **System:** `/etc/copal` holds `session`, `debug` and
  `autostart-desktop`.
- **User:** `~/.config/copal` holds the current theme (`current/`,
  including `colors.css` and `shell.sh`) and `wallpaper`.

`copal.conf` is something else: the file that carries a first boot's
settings across on the SD card. It is not a runtime configuration.

### B. The conventions of the sibling projects

`~/code` holds eight repositories under two GitHub owners:
- **the account `vonglurt`:** copal, orrery, ascitty, urfinkel, birdshot,
  codexofconquest;
- **the organisation `yodacon`:** yodacon, gonex.

Three conventions bear on a Rust project:
- **`copal-build` goes by shape.** A checkout with a `Cargo.toml` gets
  `cargo`, and what it makes goes into `~/.local/bin`. It builds on the
  machine itself, and it must never modify a tracked file, because
  `git pull --ff-only` would then refuse every later update.
- **No external crates, and that is the design.**
  - **orrery** (26,040 lines of Rust, including its own HTTP, TLS, X.509,
    SSH and curve arithmetic) explains why: "a dependency is therefore a
    crate fetch that fails on the one machine this is meant to run on." A
    fleet node never reaches the internet.
  - **ascitty**'s three crates (`ascitty-core`, `ascitty-tty`,
    `ascitty-bake`) depend only on each other. Its terminal layer is its
    own, 4,474 lines.
- **The Makefile is the front door.** ascitty's has `help`, `host`, `run`,
  `test`, `check` and release targets; copal's and yodacon's are the same
  kind. Cargo is what the Makefile calls.

### C. The vocabulary of NeXTSTEP and Smalltalk

**Smalltalk-80.** The language is defined in the "Blue Book" [1]. Its
programming environment is described in the companion "Orange Book" [2]:
- **System Browser:** four panes (class categories, classes, message
  categories, messages) over a code pane.
- **Workspace:** a text area where any expression can be selected and run
  with *doIt*, or run and its result shown with *printIt*.
- **Transcript:** the system's running log.
- **Inspector:** any object's fields, opened on it.

Everything is an object that receives messages. Model–View–Controller was
Trygve Reenskaug's, written at Xerox PARC in 1978–79 for Smalltalk-76 and
carried into Smalltalk-80 [3].

**NeXTSTEP** [4] carried those ideas into a desktop. Its Workspace Manager
opened a **File Viewer** with three views: Browser (Cmd-B), Icon (Cmd-I)
and Listing (Cmd-L).
- **Browser view:** shows the hierarchy as side-by-side columns, *Miller
  columns*, after Mark S. Miller [5].
- **Shelf:** along the top of the viewer, it holds icons dragged there for
  later.
- **Dock:** holds applications.
- **Inspector:** Tools > Inspector (Cmd-3), with Cmd-1 to Cmd-4 selecting
  Attributes, Contents, Tools and Access Control.
- **Services:** applications advertise services, and another application's
  selection is sent to them over the pasteboard. The mechanism later
  surfaced as `NSServices` in OpenStep and Cocoa [6].

NeXT and Sun published the OpenStep specification in October 1994.
GNUstep is its free implementation, and GNUstep's GWorkspace is a Workspace
Manager with a File Viewer, Shelf, Dock and Inspectors, still maintained [7].

### D. The Rust ecosystem, and what it would cost

| Need | Crate (version) | Status |
|---|---|---|
| Terminal UI | ratatui 0.30.2, the maintained fork of the archived tui-rs, over crossterm 0.29.0 [8] | active |
| Reed–Solomon correcting **errors** | reed-solomon 0.2.1 (GF(2⁸), errors and erasures) | unmaintained: last release 2018 |
| Reed–Solomon, erasures only | reed-solomon-erasure 6.0.0 (dormant); reed-solomon-simd 3.1.0 ("does not detect or correct errors within a shard") [9]; reed-solomon-novelpoly 2.0.0 | not the inner code `.sstr` needs |
| Fountain code | raptorq 2.0.1, RFC 6330 [10] | active |
| SSH signatures | ssh-key 0.6.7 (RustCrypto), `SshSig` sign and verify, algorithms behind features [11]; ed25519-dalek 3.0.0 | active |
| Checksums and hashes | crc32c 0.6.8, crc32fast 1.5.2, sha2 0.11.0 | active |
| Compression | flate2 1.1.10 on miniz_oxide 0.9.1 (pure Rust); zstd 0.14.0 binds C libzstd; ruzstd 0.9.0 decodes fully but its encoder "does not yet reach the speed, ratio or configurability" of C zstd [12] | mixed |
| Filesystem | notify 8.2.0 (watching), walkdir 2.5.0, ignore 0.4.33 | active |
| Task runner | cargo-make 0.37.24, `Makefile.toml`, `cargo make TASK` [13] | last release January 2025 |
| Cross builds | cross 0.2.5 (needs Docker or Podman; last crates.io release February 2023); cargo-zigbuild 0.23.4, with zig as the linker, musl and chosen glibc versions [14] | active |
| Players | mpv `--input-ipc-server`, JSON commands over a Unix socket; VLC's Lua HTTP and RC interfaces [15], [16] | stable |

In the rustc book [17], `aarch64-apple-darwin` and `x86_64-pc-windows-gnu`
are Tier 1 with host tools, and `aarch64-unknown-linux-musl` and
`x86_64-unknown-linux-musl` are Tier 2 with host tools.

### E. yt-dlp's two ways out

yt-dlp can hand over its output in two ways [18]:
- **A pipe.** With `-o -`, the default format becomes `best/bestvideo+bestaudio`,
  preferring a single file that needs no merge. A forced merge is muxed by
  ffmpeg to stdout when ffmpeg can take both formats. Otherwise yt-dlp warns
  that "the formats will be streamed one after the other", which is not
  playable as one file.
- **A command run on the finished file.** `--exec CMD` runs by default
  `after_move`, when the file is in its final place, with fields such as
  `%(filepath)q`.

yt-dlp can also be embedded as a Python library, `yt_dlp.YoutubeDL`.

## III. Method

1. **Conventions.** Read `~/code/AGENTS.md`, each sibling repository's
   README, Cargo manifests and Makefile targets, and `copal-build`'s header
   in `copal-prep.sh`.
2. **The machine.** Recorded `cargo --version`, `rustc -vV`, the standard
   libraries under `/usr/lib/rustlib`, `zig version`, and `apk policy`
   for cargo-make and cargo-zigbuild.
3. **ytq.** Read ytq's settings loader and help, and the field names of its
   queue entries. The entries' values were not read.
4. **Names.** Queried crates.io with `cargo search` for `sstr`,
   `staticstr`, `staticstream` and `static-stream`, and its API at
   `/api/v1/crates/NAME` for the two candidates. Checked GitHub for an
   account named `staticstream`.
5. **Speed.**
   - Ported the prototype's inner encoder line for line to Rust in a
     scratch crate: GF(2⁸) with polynomial 0x11d, 32 parity bytes, an LFSR
     over a precomputed table, and a table-driven CRC-32.
   - Built it with `cargo build --release` (LTO), ran it twice on 20 MB of
     generated data, and timed the Python `rs_parity()` on 20 MB of random
     data.
6. **yt-dlp into a capture.** On `jNQXAC9IVRw` ("Me at the zoo"), three
   paths:
   - (a) `yt-dlp -f 18 -o - | copal-sstr.py record`;
   - (b) `yt-dlp -o - | copal-sstr.py record`, with the default format;
   - (c) a download with ytq's MP4 preference to a file, then
     `record --input`.

   Each capture was played back and probed; (c) was compared with `cmp`.
7. **The literature.** The vocabulary and crate facts in Section II were
   checked against the sources cited, with the corrections noted there.

## IV. Results

### A. The build machine

| Item | Value |
|---|---|
| Toolchain | cargo 1.96.1 and rustc 1.96.1 from Alpine's `rust` and `cargo` packages; no rustup |
| Host | `aarch64-alpine-linux-musl` |
| Standard libraries installed | `aarch64-alpine-linux-musl` only |
| zig | 0.16.0 |
| In Alpine's repositories | `cargo-make` 0.37.24-r0, `cargo-zigbuild` 0.23.4-r0 (neither installed) |
| crates.io | reachable: `cargo search` returned ratatui 0.30.2 and cargo-make 0.37.24 |

### B. The name

| Name | crates.io | GitHub |
|---|---|---|
| `sstr` | taken: 0.3.1, "An ergonomic stack allocated String" | — |
| `staticstr` | taken: 0.0.1, "A string type that can hold both static and owned strings"; the API answers 200 | — |
| `staticstream` | free: no crate by that name, and the API answers 404 | `github.com/StaticStream` is someone else's user account, created 2025-02-06, with no public repositories |
| `static-stream` | free | — |

Command names are not registered anywhere, so `sstr` as the command is
unaffected. GitHub account names ignore case, so no organisation can be
named `staticstream`. A repository of that name under an existing owner
can.

### C. Rust against Python, the inner code

| Implementation | 20 MB through RS(255,223) | Other |
|---|---|---|
| Python `rs_parity()` (integer register) | 2.86 s, 7.0 MB/s | |
| Rust, release, LTO, run 1 | 0.191 s, 105 MB/s | CRC-32 357 MB/s |
| Rust, run 2 | 0.167 s, 120 MB/s | CRC-32 297 MB/s |

Both runs wrote 22,869,984 bytes, 20 MB plus 32 parity bytes for each 223.
The binary is a 438,592-byte dynamically linked musl PIE for aarch64.

### D. yt-dlp into a capture

| Path | yt-dlp | Capture | Played back |
|---|---|---|---|
| (a) `-f 18 -o -` | exit 1: "Requested format is not available" | 3,840 bytes, `record` exit 0 | no payload: "moov atom not found" |
| (b) `-o -`, default format | exit 0, 2.76 s | recorded | 474,467 bytes, Matroska with AV1 video and Opus audio |
| (c) ytq's MP4 preference to a file, then `record --input` | exit 0 | 533,932 → 692,231 bytes, 2.72 s in all | byte-identical to the MP4 |

## V. Proposal

### A. One project, one crate, no external dependencies

Start it as a repository beside orrery, `github.com/vonglurt/staticstream`,
checked out at `~/code/staticstream`. That is where `copal-build` will find it and
build it on every node without being told. An organisation can come later;
yodacon shows the shape, and moving a repository to one is a transfer, not
a rewrite. Creating either is a public act, and is left to the owner.

```
staticstream/
├─ Cargo.toml                    one package: three binaries, zero dependencies
├─ Makefile                      the front door (Section V-G)
├─ tools/dist.sh                 the release matrix (Section V-G, as built)
├─ README.md  LICENSE  docs/
├─ tests/                        the crosschecks, and the frozen Python ytq
└─ src/
   ├─ lib.rs                     the four modules
   ├─ format/                    the .sstr format: records, RS(255,223), parity,
   │                             checkpoints, SHA-256, CRC-32, zlib, JSON
   ├─ tty.rs                     the armor: lines, offsets, CRCs, erasure maps
   ├─ ytq/                       ytq: queue.json and its locks, settings, the
   │                             runner, the live record, the window
   ├─ workspace/                 the terminal Workspace (V-B)
   └─ bin/
      ├─ sstr.rs                 record, play, verify, armor, recv, serve
      ├─ ytq.rs                  the queue people type
      └─ sstr-workspace.rs       the Workspace
```

**One package, not five.** This was proposed as five crates and built that
way through phases 0 to 2. Preparing the release showed the mistake: they
depended only on each other, shared one version and would have gone to
crates.io together, so they were modules carrying a package's overhead -- five
permanent names for one program. copal-tm was found in that same shape on the
same day, and collapsed for the same reason. The split into `format`, `tty`,
`ytq` and `workspace` is kept; only the packaging is gone, and with it
`--workspace` and `-p` from every make line.

**Names.** The project, repository and crate are `staticstream`, which was
free on crates.io (IV-B), so the format is published under its own name. The
things people type stay short: the binaries are `sstr`, `ytq` and
`sstr-workspace`, and captures are `.sstr` files. The format keeps its name,
Static Stream.

**Dependencies.** None, following orrery and ascitty, for the reason they
give: `copal-build` runs on nodes with no internet. The research makes this
cheaper than it sounds:
- **Reed–Solomon:** the only Rust crate that corrects errors at unknown
  positions has been unmaintained since 2018, so it would be written in any
  case, and it already has been, in Python, tested (Section IV-C gives the
  speed of the port).
- **Checksums:** SHA-256 and CRC-32 are short.
- **Signing:** can stay `ssh-keygen -Y`, as in the prototype, until orrery's
  own Ed25519 and SSH code is worth sharing.
- **Terminal:** ascitty-tty shows a terminal layer of a few thousand lines
  is within reach.

If a crate ever becomes necessary, `cargo vendor` into the repository keeps
the offline build working; birdshot (`vendor-check`) and urfinkel
(`vendor/`) already do that.

### B. The Workspace, in NeXT and Smalltalk terms

| Term | In `sstr-workspace` | Borrowed from |
|---|---|---|
| **Workspace** | the whole terminal window | NeXTSTEP's Workspace Manager |
| **Browser** | Miller columns over any folder, starting at the archive folder; `.sstr`, `.mp4`, `.txt` and folders | the File Viewer's Browser view [4], [5] |
| **Shelf** | a row of items picked for later: files to stream, captures to serve, URLs to queue | the File Viewer's Shelf |
| **Inspector** | the selection's attributes. A capture shows its header (content type, source, license, key), `verify`'s summary and its record times. A video shows its notes, and a queue entry its state and progress. | Tools > Inspector, Cmd-1…4 |
| **Transcript** | the running log: ytq's `ytq.log` and sstr's events, one pane | Smalltalk-80's Transcript [2] |
| **Services** | verbs sent to the selection: Play, Play Paced, Serve, Verify, Armor, Export, Open as Text; Retry and Forget on a queue entry | NeXTSTEP Services [6] |
| **Queue** | ytq's queue as one more object: browse it, inspect an entry, send it Retry or Forget. Opened with Shift-Q | the `status` states ytq already has |

*As built:* **Record is not a Service.** Recording is what ytq does to a
download (V-C) and what `sstr record` does to a file; there is nothing in the
Workspace to send it to, because the object it would make does not exist yet.
The other verbs are all there. **Retry and Forget became `ytq` commands** in
the building -- `ytq retry URL` and `ytq forget URL` -- because a Service is a
command line and those two were keys in ytq's window and nothing else; the
window now runs the same code. That is an addition to ytq beyond the Python
one, and the only one.

The vocabulary follows the object–message model underneath it:
- **An object is a file.** A capture, a video, a transcript, a folder or a
  queue entry can be selected.
- **A verb is a message.** `sstr play cap.sstr` on the command line is the
  message Play sent to that capture. In the Workspace, `p` on the selection
  sends the same message.

A verb is therefore always something a person could have typed, the rule
orrery's console keeps.

```
┌ Workspace ─ ~/Downloads/SharedVM ──────────────────────────────────────────┐
│ Shelf: [cap.sstr] [notes.txt] [youtube.com/shorts/SWHZolxKdVU]             │
├──────────────┬──────────────────────────┬──────────────────────────────────┤
│ SharedVM   ▸ │ Trader-The_setup_I…sstr  │ Inspector                        │
│ Archive    ▸ │ jawed-Me_at_the_zoo…sstr │ Me at the zoo                    │
│ Queue      ▸ │ jawed-Me_at_the_zoo…txt  │ jawed · 2005-04-23 20:31 -0700   │
│              │ Berkman-William_Fish…sstr│ video/mp4 · 692,231 bytes        │
│              │                          │ License: not stated              │
│              │                          │ verify: 2 checkpoints good,      │
│              │                          │ signed by demo@copal (trusted)   │
├──────────────┴──────────────────────────┴──────────────────────────────────┤
│ Transcript  10:03:36 done: jawed-Me_at_the_zoo_jNQXAC9IVRw.sstr + transcript│
├────────────────────────────────────────────────────────────────────────────┤
│ Services: p Play  P Paced  s Serve  v Verify  x Export MP4  t Text  a Armor│
└────────────────────────────────────────────────────────────────────────────┘
```

*As built*, at 100 columns, with one capture on the Shelf and another
selected. The frame is ASCII: a column is compared with `ls` character by
character, and a glyph of ambiguous or double width would have the check
measuring the terminal's font rather than the Browser.

```
 Workspace -- ~/Downloads/SharedVM
 Shelf: [Berkman-William_Fisher_on_CopyrightX.sstr]
----------------------------------------------------------------------------------------------------
Archive                       > |                                 jawed-Me_at_the_zoo_jNQXAC9I..sstr
Berkman-William_Fisher_..sstr   |
Trader-The_setup_Im_wat..sstr   |                                 stream       0354fdb769079848c4ce4
jawed-Me_at_the_zoo_jNQ..sstr   |                                 source       https://www.youtube.c
jawed-Me_at_the_zoo_jNQX..txt   |                                 license      not stated
                                |                                 note         Me at the zoo
                                |                                 key          none: checkpoints det
                                |                                 records      5 (1 data, 1 parity,
                                |                                 payload      43 bytes, sha256 fe5d
                                |                                 repaired     0 header bytes, 0 bod
                                |                                 lost         0 data records, 0 rec
                                |                                 checkpoints  1 good, 0 bad, 0 chai
----------------------------------------------------------------------------------------------------
 Transcript 10:06:04 Berkman-William_Fisher_on_CopyrightX.sstr on the Shelf
 Services to the Shelf:  p Play  P Paced  s Serve  v Verify  x Export TXT  t Text  a Armor
```

**A name too long for its column loses its middle, not its end**, and that is
visible above: `jawed-Me_at_the_zoo_jNQ..sstr` against
`jawed-Me_at_the_zoo_jNQX..txt`. Cut at the end they were the same twenty-nine
characters -- a capture and its transcript drawn identically, on exactly the
names ytq makes. It is `..` and not an ellipsis for the reason the folder
marker is `>`: U+2026 is ambiguous-width.

**The text stream opener** is Open as Text:
- **Text captures:** `text/*` and transcripts are shown in a pager.
- **Paced:** a capture played paced shows text arriving as it was recorded,
  the way a teletype would.
- **Armor:** shown as its lines.

### C. The link with ytq

**Where downloads go.** The setting `OUTPUT` decides what a finished
download leaves:

| `OUTPUT` | Leaves in `ARCHIVE_DIR` |
|---|---|
| `sstr` (default) | `Author-Title_ID.sstr` and `Author-Title_ID.txt`; the MP4 is removed only after `sstr verify` passes |
| `mp4` | `Author-Title_ID.mp4` and `.txt`, as ytq does today |
| `both` | all three |

**How.** ytq keeps downloading to a file, as now, and then runs the
following. The Python ytq does this first, and the Rust ytq does the same
when it takes over.

```sh
sstr record OUT.sstr --input FILE --type video/mp4 --key KEY \
     --source URL --license "…" --note "…"
```

That is path (c), which came back byte-identical (IV-D). It is chosen over a
pipe for three reasons:
- **Format:** a pipe changes the format yt-dlp picks (IV-D (b)).
- **Merging:** it depends on ffmpeg being able to merge to stdout.
- **Post-processing:** ytq's file naming and embedded notes are yt-dlp
  post-processing steps that need a file.

Plain yt-dlp gets the same result with
`--exec 'sstr record --input %(filepath)q --replace'` [18]. `--replace` is
proposed: write the `.sstr` beside the file, verify it, then remove the
original.

**One queue, and one ytq at a time on PATH.** `staticstream-ytq` reads and
writes `queue.json` under the same `queue.lock` protocol the Python ytq
uses. The Rust and Python ytq can therefore run side by side on one queue,
and the Workspace's Queue is that queue. The crate stays a library, with no
binary called `ytq`, until it does everything the Python one does:
- **`copal-build`** copies every executable at the top of `target/release`
  into `~/.local/bin`.
- **`make install`** puts binaries there too.
- **`~/.local/bin` comes before `/usr/local/bin`** on Copal's PATH, so an
  unfinished `ytq` would hide the working one on every node.

Super+Shift+Y keeps working unchanged throughout.

### D. One configuration

Add `~/.config/copal/media.conf`, `KEY=VALUE` like ytq's config and
shell-readable like the rest of Copal's. ytq reads it first, then its own
`~/.config/ytq/config`, so the `DIR` this guest already sets still wins.
`sstr` and the Workspace read both, in the same order. The command line
overrides everything.

| Key | Default | Read by |
|---|---|---|
| `ARCHIVE_DIR` | ytq's `DIR` (the Mac's share when mounted, else `~/Videos`) | ytq, sstr, Workspace |
| `OUTPUT` | `sstr` | ytq |
| `SSTR_KEY` | `~/.ssh/id_ed25519` if it exists, else unsigned | ytq, sstr |
| `SSTR_DEFLATE` | `no` for video, `yes` for `text/*` | sstr |
| `PLAYER` | `mpv` | Workspace |
| `SERVE` | `127.0.0.1:8080` | sstr, Workspace |
| `FORMAT`, `SUBS`, `PROFILE`, `KEYRING`, `POLL` | as in ytq today | ytq |

### E. Architectures

| Target | For | How it gets built |
|---|---|---|
| `aarch64-unknown-linux-musl` | Copal on a Pi 3, Zero 2, CM3 or UTM on Apple Silicon | natively, by `copal-build` or `make` |
| `armv7-unknown-linux-musleabihf` | the Pi 2B | natively on it; or cross, below |
| `x86_64-unknown-linux-musl` | the x86_64 VM | natively; or cross |
| `aarch64-apple-darwin` | the Mac, to play and verify captures in the share | `make` on the Mac, Rust from Homebrew as ascitty's Makefile expects |
| `x86_64-pc-windows-gnu` | optional | cross |

**Natively.** Nothing is needed beyond `cargo`: every Copal machine builds
its own binary, which is what `copal-build` does already.

**Cross, from one machine.** Two things are needed:
- **Standard libraries:** one for each target. Alpine's package has only its
  own (IV-A), so this needs rustup's `rustup target add`.
- **A linker:** cargo-zigbuild, which Alpine packages, over the installed
  zig.

`make dist` checks for both and says which is missing rather than failing
inside cargo. cross is not proposed for the guest, because it needs Docker
or Podman.

*As built.* `make dist` builds **this machine** with nothing but cargo, then
names each other target it could not build and the one command that supplies
what is missing. It writes `dist/MANIFEST`: the crate version, the commit —
and whether the tree was dirty — and each binary's size, linkage and SHA-256,
with no timestamp, because a manifest that changes when nothing changed cannot
be compared with the last one.

**The dist binaries are static.** Every target in this table is musl, and
Rust's `*-unknown-linux-musl` targets link statically already — but Alpine
patches its **own** triple to link musl dynamically, so the binary this
machine builds by default wants `/lib/ld-musl-aarch64.so.1` at the other end.
That is right for a machine inside Copal and wrong for the one thing a dist is
for, so the release builds carry `-C target-feature=+crt-static`. It costs
about 130 KB a binary, which is musl. `make build`, and what `copal-build`
installs, are left as Alpine has them.

The linkage is read back rather than assumed: a dynamically linked ELF names
its interpreter inside itself and a static one has no interpreter to name, so
`grep -a ld-musl` settles it without `file` or `ldd`, and a musl target that
came out dynamic is warned about rather than passed over.

**THE NATIVE TARGET IS NOT SPELLED THE WAY THIS TABLE SPELLS IT.** The table
says `aarch64-unknown-linux-musl`; Alpine's rustc calls the same machine
`aarch64-alpine-linux-musl`. They are one target with two names, and asking
cargo for the first on a machine that *is* the second sends it looking for a
standard library that is not installed — to cross-compile to where it already
is. The native build is therefore plain `cargo build --release`, labelled with
rustc's own host triple, and the cross set is this table's list less whichever
row this machine turns out to be.

Alpine packages `rustup` (1.29.0) as well as `zig`; an earlier note in the
Makefile said it did not, which is the kind of thing worth checking rather
than asserting.

### F. What the format library must do first

The Rust `staticstream` library is correct when it and `tools/copal-sstr.py`
agree:
- Python writes and Rust reads, and Rust writes and Python reads, both
  byte-identical.
- They agree across the whole damage battery of the Static Stream report:
  the same repairs, the same losses, the same exit statuses.

Two changes from the prototype belong in version 0 of the Rust library:
- **Empty input fails.** `record` given no bytes must exit non-zero. Path
  (a) produced a 3,840-byte "capture" of nothing and exit 0.
- **The outer code is stronger.** Replace the XOR parity with a
  Reed–Solomon erasure code over fixed-size stripes, the limit that report
  measured. That changes the format, so it is version 1, and the Python
  prototype stays version 0.

*As built.* Version 1 keeps the parity record's entry table and replaces its
single XOR row with **two, P and Q**, over the group's bodies read as columns.
P[j] is the XOR of every body's byte j — *which is exactly version 0's row,
unchanged* — and Q[j] is the XOR of `g^i · body_i[j]` in GF(256), i being the
record's place in the group. Two rows, two erasures; with one hole it is the
arithmetic version 0 already did, which is why a version 1 parity record that
lost its Q row still rebuilds one.

The field and the tables are `format::rs`'s, the inner RS(255,223)'s, so no
new mathematics entered the crate: there is one Galois field in it, not two.
And the number of rows is not a new field — every entry carries its
`plain_len`, so the padded width is the largest of them and the row count is
`blob.len() / n`. A parity record says how many rows it has without being
asked, which matters because after a resync it can be the first record a
reader meets, before any header and so before any version.

**Version 1 is what `sstr record` writes**, and `--format 0` asks for the
other. That decision was taken after the four steps, deliberately apart from
the one that first wrote a version 1 byte. `ytq` archives through the same
defaults, so its captures follow. `tests/crosscheck.sh` records at version 0
with a comment saying why: those 44 comparisons are comparisons *at version 0*
and they are the chain back to the prototype, and letting them follow the
default would have quietly turned them into something else.

### G. The Makefile, and where cargo-make fits

The Makefile is the front door, and it works with nothing but `cargo`
installed, because `copal-build` calls `cargo` directly.
`cargo make` was proposed for the release matrix only:

*As built, there is no cargo-make.* The matrix turned out to be three
`cargo zigbuild` lines and a loop, and requiring a task runner in order to
produce the binaries for the machine one is standing on is backwards —
especially one more thing to install before anything can be built at all. The
matrix is `tools/dist.sh`, in the shell the rest of the project's checks are
written in, and `make dist` calls it. The front-door rule did the arguing:
a Makefile that works with nothing but cargo should not have a target that
does not.

The Makefile, abridged, with the release's one-crate lines:

```make
CARGO ?= cargo
# cargo install writes binaries into $(ROOT)/bin; ~/.local/bin is on Copal's PATH.
ROOT ?= $(HOME)/.local
ARGS ?=

build: ## release build of all three binaries; also writes Cargo.lock the first time
	$(CARGO) build --release

run: ## the sstr command:  make run ARGS='paths'
	$(CARGO) run --release --quiet --bin sstr -- $(ARGS)

workspace: ## the terminal Workspace
	$(CARGO) run --release --quiet --bin sstr-workspace -- $(ARGS)

deps: ## prove Cargo.lock names no crate from outside this repository
	@if grep -q '^source = ' Cargo.lock; then echo 'error: external crates'; exit 1; fi

check: deps ## what a commit must pass: no external crates, the tests, an offline release build
	$(CARGO) test --offline --locked --quiet
	$(CARGO) build --release --offline --locked

# One crate, so one install, and it carries all three binaries. ytq is
# installed from here since step 2e, when it matched the Python one: $(ROOT)/bin
# comes before /usr/local/bin on Copal's PATH, and would have hidden it before.
install: ## sstr, ytq and sstr-workspace into ~/.local/bin (ROOT=DIR for DIR/bin)
	$(CARGO) install --locked --offline --root $(ROOT) --path .

package: check ## the crate tarball, and what is in it -- pushes nothing
	$(CARGO) package --locked

publish: check ## the one cargo publish call, gated on a clean check here, now
	$(CARGO) publish --locked

tools: ## what `make dist` needs for the targets that are not this machine
	@printf '...rustup target add ..., and apk add zig && cargo install cargo-zigbuild\n'

dist: check ## release binaries for this machine and the targets of V-E, into dist/
	@sh tools/dist.sh
```

The comment on `ROOT` is on its own line on purpose. An earlier draft
here wrote `ROOT ?= $(HOME)/.local   # comment`, and make keeps the spaces
before a trailing comment as part of the value, so `--root` would have been
given a path ending in spaces.

`tools/dist.sh` builds this machine's binaries with plain
`cargo build --release`, then, for each of V-E's other targets, checks for
rustup, for that target's standard library and for cargo-zigbuild, and either
runs `cargo zigbuild --release --target …` or prints which of the three is
missing and the command that supplies it. It writes `dist/TARGET/` and
`dist/MANIFEST`.

`make dist` needs nothing more than `cargo` for the machine it is run on, and
rustup and cargo-zigbuild only for the targets that are not that machine.
Neither it nor `make tools` writes inside a tracked file, so a checkout stays
pullable.

### H. The order to build it in

| Phase | Delivers | Done when |
|---|---|---|
| 0 | the repository, workspace, Makefile, README, and the constants each crate shares with the Python it replaces | `make check` passes on the guest and on the Mac. **Done on the guest**, commit `0ee5457`, on GitHub at `vonglurt/staticstream`; not yet run on the Mac |
| 1 | the `staticstream` library and `sstr` at parity with `copal-sstr.py` | the cross-check and damage battery of V-F agree byte for byte; `record` refuses empty input. **Done**: commit `d62aa88`, and `26027d7` for armor's speed. `make crosscheck`, 44 of 44 comparisons agree (VII) |
| 2 | ytq in Rust: the `ytq` module takes over the queue, settings, `OUTPUT` and `media.conf`, and drives yt-dlp as the Python ytq does | Rust and Python ytq run side by side on one `queue.json`; a queued video leaves a `.sstr` that verifies and plays back identical to the MP4; `OUTPUT=mp4` leaves today's files; only then is the binary `ytq` built. **Done**: `make check` passes with `ytq` in the Python one's place -- 76 unit tests, 44 + 32 + 50 comparisons, 34 checks and 133 comparisons, 293 in all. `copal-prep.sh` is 1,466 lines lighter and writes no ytq |
| — | the release: one crate, under its own name on crates.io | **Done**: the five packages became four modules of one package named after the repository. The 293 agree unchanged across the move, and `cargo install staticstream` fetches nothing but this crate |
| 3 | `sstr-workspace`: Browser, Inspector, Transcript, then Services, then Queue | every Service is a command line shown in the Transcript before it runs. **Done**: five steps, commits `d6826e1`, `55809be`, `fcfdb9a`, `ffd92c5` and `d8b052b`. `make check` is 356 -- the 293 of phase 2 and 63 checks of the Workspace -- with 118 unit tests. Section VIII, and `docs/phase-3.md` in staticstream for the step-by-step record |
| 4 | `make dist` for the targets of V-E, and version 1's stronger outer code | binaries run on the Pi 2B and the x86_64 VM; version 1 rebuilds two lost records per group. **Version 1 done**: commits `0f46afa` and `5cd86f3` — two records of one group rebuilt, byte-identical, where version 0 loses both; the second row measures 1.0643 of version 0 against a designed 1.0588. **`make dist` done as far as one machine can take it**: commit `bf88422`. **Not done**: the two hardware runs. Section IX |

## VI. Discussion

**Is this too much?** It would be if it meant a media library, with a
database that owns the files and has to be kept in step with them. It does
not.
- **The folders stay the structure.** A capture is a file, its transcript
  is the file beside it, and the archive folder is a folder the Mac also
  sees.
- **The Workspace is a way of looking.** The Browser reads the disk and the
  Inspector reads a file's own header and notes. There is nothing else to
  keep in step.

NeXTSTEP's Workspace Manager did the same: the File Viewer was a view onto
the UNIX file system underneath it, not a replacement for it [4]. Phased as
V-H, each step is useful alone. After phase 2, ytq archives to `.sstr` with
no new interface at all.

**Why Rust, and why ytq comes too.** The measured case is the inner code,
15× faster in Rust (IV-C). That is the difference between archiving a 1080p
download while the next one starts and waiting for it. A single binary per
target, and builds on each machine, suit a system that runs on a Pi 2B and
a Mac.

The first version of this report kept ytq in Python. Its owner overruled
that, and rightly: once ytq archives into Static Stream by default, the two
are one tool with two faces, and splitting them across two languages and
two repositories would make every change to the queue, the naming or the
notes a change in two places.

Moving ytq does not mean rewriting what makes it work. yt-dlp stays a Python
program, which ytq drives as a subprocess today [18], and a Rust ytq drives
it the same way. The risk is a working tool with a week of fixes in its
queue, cookie retry, naming and notes, so the move is made safe three ways:
- **The Rust ytq shares the Python ytq's queue file and locks,** so the two
  run side by side.
- **Phase 0 already checks** that the paths and states copied into Rust are
  still the Python ytq's.
- **The binary `ytq` is built only when phase 2's test passes,** so the
  Python ytq stays the one on PATH until then.

**No dependencies costs work, and buys the fleet.** A ratatui Workspace would
be quicker to write. It would also fail to build on every Copal node that
does what `copal-build` does, offline. orrery and ascitty have already paid
that price and shown it is payable. The one crate that would have saved the
most work, an error-correcting Reed–Solomon, is the one the research found
unmaintained.

**The vocabulary is more than decoration.** Smalltalk's lesson is that a
small set of words used consistently makes a large system learnable:
objects, messages, browse, inspect, the transcript. Here there are four
nouns (Browser, Shelf, Inspector, Transcript) and one plural of verbs
(Services). Every verb is also a command line, so the TUI and the shell
teach each other.

**What archiving by default does not change.** Making `.sstr` the default
changes the form downloads are kept in, not which downloads may be kept. The
notes, the license line and the `--source` field travel into every capture's
header, as the ytq report's review asked. The format records provenance; it
does not grant permission.

## VII. Phase 1, as built

Phase 1 set the hardest bar in the plan: a second implementation of the
whole format, in another language and with nothing borrowed from a
registry, that the first implementation cannot tell apart from itself. It
cleared it, and came out several times faster.

### A. What was built

In `~/code/staticstream`, commits `d62aa88` and `26027d7`, on GitHub:
- **The format library** (`staticstream`): the writer and the reader, the
  record layout, RS(255,223) decoding errors and erasures, the XOR parity,
  and checkpoints with their SSH signatures (still `ssh-keygen -Y`). It also
  holds everything the prototype took from Python's library, written here
  with no crates:
  - SHA-256, copied from orrery;
  - CRC-32;
  - JSON, orrery's parser with a writer added;
  - zlib, both compressor and decompressor, which reads everything Python's
    zlib writes and is smaller than it on `copal-prep.sh` (565,485 bytes
    against 565,895).
- **The armor** (`staticstream-tty`): lines, offsets, CRCs, and a receiver
  that turns lost lines into erasures.
- **The command** (`sstr`): every verb, option and report of the prototype,
  word for word. The one deliberate difference is that `record` given no
  bytes exits 1 and leaves no file.

### B. The acceptance test

`make crosscheck` runs the Rust `sstr` and `tools/copal-sstr.py` over the
same files and compares everything they print, play and return. `make
check` runs it on every commit.

| Comparison | Count | Result |
|---|---|---|
| each writes random (signed), deflated text and MPEG-TS captures; both play and verify all six | 12 | same bytes, same reports, same exits; every payload is the original |
| thirteen kinds of damage from the Static Stream report, on a capture from each writer | 26 | same repairs, losses, exit codes and played bytes, and the same outcomes the report measured: bursts, one wiped record, two wiped in different groups and a wiped stream header repaired; bit errors at 1e-2, a 200 KiB burst, two wiped in one group, truncation and tampering caught |
| armor, `recv` through a clean line, 3 % dropped with console noise, bit errors at 1e-4, and 10 % dropped; `unarmor`'s bytes and erasure ranges | 6 | identical lines, payloads, reports and ranges |

All 44 agree. Beside them, the Rust binary alone:
- **Recording while followed:** a live 10-second ffmpeg capture came back
  byte-identical to what ffmpeg sent, and the prototype verifies the Rust
  capture.
- **Replay:** `--paced` took 9.5 s for a 9.4-second capture. `--serve` gave
  curl an identical copy, and mpv decoded MPEG-2 video and MP2 audio from it.
- **Stopping:** SIGTERM mid-capture closed the file cleanly as
  "writer was interrupted".
- **Serial:** the armor crossed a socat pty at 115200 baud byte-identical.

### C. The speedup

Same files, same machine, median of three runs each:

| Task | Python prototype | Rust `sstr` | Speedup |
|---|---|---|---|
| **repair**: play 20 MB with bit errors at 1e-4 | 24.739 s | 1.706 s | **14.5×** |
| record 20 MB | 3.290 s | 0.558 s | **5.9×** |
| record 20 MB, signed | 3.321 s | 0.567 s | **5.9×** |
| armor a 20 MB capture | 1.274 s | 0.482 s | **2.6×** |
| record `copal-prep.sh` with `--deflate` | 0.210 s | 0.092 s | **2.3×** |
| `recv` a 20 MB capture from armor | 1.506 s | 0.927 s | **1.6×** |
| play 20 MB, undamaged | 0.180 s | 0.292 s | 0.6× |
| verify 20 MB, undamaged | 0.179 s | 0.300 s | 0.6× |

**Repair: 24.7 seconds to 1.7.** Repair is exactly what the format is for,
and exactly where the prototype was slowest. Every damaged codeword needs
syndromes, a Berlekamp–Massey locator, a Chien search and Forney's
magnitudes, all in GF(2⁸) arithmetic. In Python that is one interpreted
table lookup at a time; in Rust it is the same algorithm as tight compiled
loops. On a serial line or an old disk, where damage is the normal case,
that is the difference between waiting for a capture and watching it.

**Recording: 3.3 seconds to 0.56.** The encoder is the inner loop measured in
IV-C: 7.0 MB/s in Python even with its integer-register trick, and 105–120
MB/s in Rust.

**Where Python still wins, and why.** On an undamaged capture the reader does
little but check. It computes a CRC-32 and two SHA-256 passes, one per
record and one over the payload. Python hands both to C:

| Primitive | Python (C library) | Rust (portable code) |
|---|---|---|
| SHA-256 | 2,385 MB/s, OpenSSL on the CPU's SHA-2 instructions | 169–172 MB/s |
| CRC-32 | 3,287 MB/s, zlib | 862–982 MB/s |
| decoding clean codewords (de-interleave and CRC) | 273 MB/s | 298–348 MB/s |

Decoding is already faster in Rust. The 0.29 seconds are the portable
SHA-256 reading 40 MB. The CPU's own SHA-256 and CRC instructions are
reachable from Rust through `std::arch`, still with no crate, and that is the
next optimisation. The same hashing is the only thing between Rust and a
lead on every row.

### D. Found on the way

- **A capacity check.** A guard added in the port made the decoder refuse
  18 erasures and 5 errors, well within 2e + f ≤ 32. The prototype's own
  signed arithmetic was restored, and 2,000 random codewords within the
  bound are now all corrected.
- **A harness that agreed with itself.** The first cross-check reported 44
  agreements while its damage step was failing. A shell function had
  reused the caller's variable, so later cases compared stale files. The
  harness now fails when damage fails, and the real run agreed.
- **armor at 7.0 seconds.** The input pump drained each 45-byte line from
  the front of a 64 KiB buffer, 1,400 shifts per read. With chunks taken by
  index, it takes 0.48 seconds, and the output is byte-identical to before.
- **GitHub's initial commit.** The new repository held a generated LICENSE.
  It was merged, keeping the LICENSE text Copal and orrery use, and phase 0's
  commit kept its hash.

## VIII. Phase 3, as built

Phase 3 is the one part of the project with no prototype. Phases 1 and 2 each
ended in a crosscheck: run the Rust and the Python over the same input and
compare what they leave. There is no Python Workspace, so there was nothing to
put beside it.

### A. What was built

`sstr-workspace`, in five steps, each with its own commit and its own checks:

| Step | What it added |
|---|---|
| 3a | the frame and the **Browser**: Miller columns over folders, the keys that move |
| 3b | the **Inspector**: what `sstr verify` says about a capture, a folder's count, a transcript's first lines |
| 3c | the **Transcript**: `ytq.log` and sstr's own events in one pane, followed as they are written |
| 3d | **Services**: a verb sent with one key, printed as a command line before it runs |
| 3e | the **Shelf** and the **Queue** |

### B. What replaced the crosscheck

One bar for each part, and every one of them is something outside the
program:

| Part | Held to |
|---|---|
| Browser | **a column is exactly what `ls` would have shown**, in the same order, with the same selection after the same keys |
| Inspector | **what `sstr verify` says**, line for line, over a capture `sstr` itself recorded |
| Transcript | **the lines a real `ytq` wrote**, in the order `ytq.log` has them, across the rename that rotation is |
| Services | **the printed line, run in a shell** with a fresh HOME: same output, same bytes written, same exit |
| Queue | **the queue ytq leaves**, four ways -- the Workspace, `ytq retry` in a shell, `r` in ytq's window, and `r` in the **Python** ytq's window |

The fourth of those ways is the one that matters. The Workspace, the
command and the Rust window all call one function, so comparing them is
self-consistent: it would stay green if that function were wrong, because all
three would be wrong together. The Python ytq, frozen at
`tests/reference/ytq.py`, is the only one of the four that cannot change when
this crate does.

**That was tested rather than asserted.** `queue::retry` was altered to stop
clearing a retried entry's error. The three Rust comparisons stayed green.
Only the Python one went red.

### C. What was found

**A check being green is not the same as the screen being right.** Three
defects were found by capturing a pane with tmux and reading it, while every
check passed:

1. **Names were cut at the end**, so a capture and its transcript drew
   identically at 100 columns -- on exactly the names ytq makes. The
   Inspector's heading had it too: a `.sstr` read `.ss`.
2. **The Transcript's follower was quadratic.** It appended each block read to
   a buffer and took lines off the front, so every line shifted everything
   behind it. A rotated 4 MiB log is about 70,000 lines and some 200 GB of
   copying: on screen the Workspace simply stopped, mid-poll.
3. **A full timestamp left ten characters for the message** at 50 columns.
   The proposal's screen writes `10:03:36 done: ...` and was right to; the
   first attempt drew the log line whole and made the pane a column of clocks.

This is inherent to the shape of the test rather than bad luck. The harness
re-implements the drawing rules in shell, so the Browser compared against the
harness is a self-consistent comparison, and self-consistency cannot catch
both sides being wrong in the same direction. `ls` anchors what a column
*contains* to something outside the program; nothing outside it anchors how a
column is *drawn*.

**A check that cannot fail looks exactly like a check that passes.** One of
them -- "the command line is said before the outcome" -- asked whether the
first of two matches preceded the second, which is true however they are
ordered. It passed against a Workspace altered to say the line last. It was
found by breaking the program on purpose, which is now part of each step.

**Two traps in the harness**, both of which cost a run and neither of which is
visible in the code. `awk -v` runs escape processing over the value it is
given, so the `\'` in a quoted filename lost its backslash before the
comparison and the mark never matched. And ytq's window takes `run.lock` and
downloads whatever it is shown -- which is what it is for -- so the queue
comparison was measuring a retry followed by a finished download until the
check learnt to hold that lock itself.

## IX. Phase 4, so far

Two of the row's three pieces are done. The third needs two machines.

### A. Version 1, and what it is worth

| | version 0 | version 1 |
|---|---|---|
| parity rows per group | 1 (XOR) | 2 (P and Q) |
| records rebuildable per group | 1 | 2 |
| designed redundancy, full group | 1.2150 | 1.2864 |

The thirteen kinds of damage from the Static Stream report, run against a
capture at each version. **Version 1 recovers two payloads version 0 loses,
and loses none version 0 keeps**: *two records of one group wiped*, which is
the row's own done-condition, and *a 4 KiB burst mid-body*, which was not
expected and is the same cause — a burst that happens to fall across two
records of one group.

Measured on 4 MiB, where groups are full:

| chunk | records | version 0 | version 1 | ratio |
|---|---|---|---|---|
| 4 KiB | 1,108 | 1.3123 | 1.3847 | 1.0552 |
| 16 KiB | 280 | 1.2439 | 1.3198 | 1.0610 |
| 64 KiB | 73 | 1.2394 | 1.3287 | 1.0721 |

The ratios bracket the designed 1.0588. The overhead over the payload sits
above the designed 1.2150 and 1.2864 by the 136-byte record headers and the
small H, C and E records, which the design figure excludes and which cost
proportionally more at a small chunk.

**A capture smaller than one group pays the whole outer code**, and the first
measurement was one. At 400,000 bytes with 64 KiB chunks the ratio came out
1.1392 — not an error in the arithmetic but a group of six records paying for
sixteen, because the parity blob is one padded body per row however few bodies
there are. It is a property of the design and not of this implementation, and
it is worth knowing before choosing a chunk size for short streams.

### B. What anchors a version the prototype is not held to

Phases 1 and 2 were checked against `tools/copal-sstr.py`. V-F says the
prototype stays at version 0, so it cannot be *held to* a version 1 capture:
it does not write one, and it cannot use the second row. What the battery
compares instead is version 1 against version 0 **on the same damage**. That
is not self-consistency:
version 0 is held to the prototype by the 44 comparisons, so the chain is
prototype ↔ version 0 ↔ version 1, and version 0 is the bridge.

The check requires version 0 to **fail** on the two-in-a-group case, and
requires version 1 to win on at least two kinds of damage. A battery in which
the two versions always agree is a battery whose damage no longer reaches the
outer code, and it would pass in silence.

**And the measure is the recovered payload, not the `lost` counter.** On the
200 KiB burst version 0 reports *1 data record lost, 40 of unknown type* and
version 1 reports *14 lost, 26 unknown*. That reads as a regression and is the
opposite of one: `lost` means *known* to be missing, and a record is known to
be missing because a surviving parity record's entry table names it — version
1 could **name** thirteen more. Both recovered the same 248,448 bytes and
neither matched. The assertion was written on `lost` first, and it would have
failed the better program.

### C. Version 1 is backward compatible, which was not the plan

An earlier draft of this section said the prototype could not read a version 1
capture. It can, and the claim had been inferred from V-F rather than tried.
What it falls out of is **P being version 0's row, and first**: a version 0
reader takes the first padded width of the parity blob as the XOR and
truncates each rebuilt body to its own length, so the Q row sitting behind it
is bytes that reader never reaches.

So `tools/copal-sstr.py`, unchanged and frozen at version 0:

| given a version 1 capture | prototype | version 1's reader |
|---|---|---|
| undamaged | plays it, payload identical | identical |
| one record of a group lost | **rebuilds it**, payload identical | identical |
| two records of one group lost | loses both | rebuilds both |

It fails at exactly the thing version 1 added and nowhere else. That is worth
more than the tidiness of a clean version break: every reader already written
goes on working, and the ones that are rebuilt gain the second record.

`tests/outer-check.sh` holds it to this, because it is the kind of property
that is true by accident until somebody reorders two rows and then quietly is
not.

### D. `make dist`, and what it cannot do here

It builds this machine with nothing but cargo and names every other target it
could not build, with the command that supplies what is missing. V-E has the
triple-spelling finding and the manifest; V-G has why cargo-make is gone.

**The row's own done-condition is not met.** *Binaries run on the Pi 2B and
the x86_64 VM* needs a Pi 2B and an x86_64 VM. This guest has neither, and has
no rustup and no cargo-zigbuild with which to build for them, so the three
cross targets were not built and nothing has been run anywhere else. The path
this machine did exercise is the one every machine without the tooling will
take, which is the more common case and now the tested one.

The thing that had to be settled before those runs is settled: the binaries
`make dist` writes are statically linked, so what will be carried to a Pi 2B
or an x86_64 VM needs no loader when it gets there. V-E has the detail.

## X. Procedures

**Repeat the speed comparison:** the scratch crate is in Section III-5. Build
it with `cargo build --release`, and time Python with:

```sh
python3 -c "import importlib.util,os,time; s=importlib.util.spec_from_file_location('m','tools/copal-sstr.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); d=os.urandom(20_000_000); t=time.time(); [m.rs_parity(d[i:i+223]) for i in range(0,len(d),223)]; print(20/(time.time()-t),'MB/s')"
```

**Archive a download today, with the prototype:**

```sh
yt-dlp -f 'bv*[ext=mp4]+ba[ext=m4a]/b' -o video.mp4 URL
tools/copal-sstr.py record video.sstr --input video.mp4 --type video/mp4 --source URL --key ~/.ssh/id_ed25519
tools/copal-sstr.py verify video.sstr && tools/copal-sstr.py play video.sstr -o check.mp4 && cmp video.mp4 check.mp4
```

**Check the build machine:**

```sh
ls /usr/lib/rustlib; apk policy cargo-make cargo-zigbuild; cargo search sstr --limit 1
```

**Repeat phase 1's acceptance test and the speed table,** in `~/code/staticstream`:

```sh
make check                      # the tests, an offline build, and the 44-comparison crosscheck
make crosscheck                 # the crosscheck alone, comparison by comparison
python3 ../copal/tools/copal-sstr.py record a.sstr --input big.bin && target/release/sstr verify a.sstr
```

## XI. Files touched

| File | Change |
|---|---|
| `docs/staticstream-project-lab-report.md` | this report; no code changed here. Revised after phase 0, for ytq moving into the Rust project and the Makefile as committed. Revised after phase 1: Section VII, and phases 0 and 1 marked done. Revised after phase 2 and the release: V-A and V-G, one crate instead of five. Revised after phase 3: Section VIII, V-B's screen as built, and phase 3 marked done. Revised after phase 4's first three steps: Section IX, V-E's native-triple finding, V-F's outer code as built, and V-G losing cargo-make |

## References

[1] A. Goldberg and D. Robson, *Smalltalk-80: The Language and its Implementation*. Reading, MA: Addison-Wesley, 1983.

[2] A. Goldberg, *Smalltalk-80: The Interactive Programming Environment*. Reading, MA: Addison-Wesley, 1983.

[3] "Trygve Reenskaug." [Online]. Available: https://en.wikipedia.org/wiki/Trygve_Reenskaug

[4] D. Hanson, "NEXTSTEP computer system command key clicks," Univ. Illinois Chicago. [Online]. Available: http://homepages.math.uic.edu/~hanson/NextKeyClicks.html

[5] "Miller columns." [Online]. Available: https://en.wikipedia.org/wiki/Miller_columns

[6] Apple, "Services properties," Services Implementation Guide. [Online]. Available: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html

[7] GNUstep, "GNUstep Workspace Manager: GWorkspace." [Online]. Available: https://www.gnustep.org/experience/GWorkspace.html

[8] ratatui, crates.io, 2026. [Online]. Available: https://crates.io/crates/ratatui

[9] A. Trier, reed-solomon-simd README, 2025. [Online]. Available: https://github.com/AndersTrier/reed-solomon-simd

[10] C. Berner, raptorq, crates.io, 2026. [Online]. Available: https://crates.io/crates/raptorq

[11] RustCrypto, ssh-key documentation, 2026. [Online]. Available: https://docs.rs/ssh-key/latest/ssh_key/

[12] KillingSpark, ruzstd (zstd-rs) README, 2026. [Online]. Available: https://github.com/KillingSpark/zstd-rs

[13] S. Giegerich, cargo-make. [Online]. Available: https://github.com/sagiegurari/cargo-make

[14] cross-rs, cross; rust-cross, cargo-zigbuild. [Online]. Available: https://github.com/cross-rs/cross, https://github.com/rust-cross/cargo-zigbuild

[15] mpv, "JSON IPC," `DOCS/man/ipc.rst`. [Online]. Available: https://github.com/mpv-player/mpv/blob/master/DOCS/man/ipc.rst

[16] VideoLAN, "Documentation:Modules/http_intf." [Online]. Available: https://wiki.videolan.org/Documentation:Modules/http_intf

[17] The Rust Project, "Platform support," *The rustc book*, 2026. [Online]. Available: https://doc.rust-lang.org/rustc/platform-support.html

[18] yt-dlp README: output template, format selection to stdout, `--exec`, and "Embedding yt-dlp." [Online]. Available: https://github.com/yt-dlp/yt-dlp/blob/master/README.md
