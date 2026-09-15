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
- a terminal *Workspace* named in the manner of NeXTSTEP and Smalltalk:
  a *Browser* of folders, an *Inspector*, a *Transcript*, a *Shelf*, and
  *Services* sent to the selection;
- ytq's downloads archived as `.sstr` by default.

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
  dependencies.
- **Configuration:** a shared `~/.config/copal/media.conf` that ytq also
  reads.
- **Build:** a Makefile as the front door, with cargo-make for the
  multi-target release builds only.
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

### A. One project, five crates, no external dependencies

Start it as a repository beside orrery, `github.com/vonglurt/staticstream`,
checked out at `~/code/staticstream`. That is where `copal-build` will find it and
build it on every node without being told. An organisation can come later;
yodacon shows the shape, and moving a repository to one is a transfer, not
a rewrite. Creating either is a public act, and is left to the owner.

```
staticstream/
├─ Cargo.toml                    workspace: members, shared version, release profile
├─ Makefile                      the front door (Section V-G)
├─ Makefile.toml                 cargo-make tasks for multi-target release builds
├─ README.md  LICENSE  docs/
└─ crates/
   ├─ staticstream/              the .sstr format as a library: records, RS(255,223),
   │                             parity, checkpoints, SHA-256, CRC-32; no I/O policy
   ├─ staticstream-tty/          the armor: lines, offsets, CRCs, erasure maps
   ├─ staticstream-cli/          the command, binary `sstr`: record, play, verify,
   │                             armor, recv, serve
   ├─ staticstream-queue/        ytq's queue.json and its locks, read and written
   │                             exactly as ytq does, so both see one queue
   └─ staticstream-workspace/    the terminal Workspace, binary `sstr-workspace` (V-B)
```

**Names.** The project, repository and packages are `staticstream`, which
is free on crates.io (IV-B), so the library can be published under the
format's own name. The things people type stay short: the binaries are
`sstr` and `sstr-workspace`, and captures are `.sstr` files. The format
keeps its name, Static Stream.

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
| **Services** | verbs sent to the selection: Record, Play, Play Paced, Serve, Verify, Armor, Export MP4, Open as Text, Queue | NeXTSTEP Services [6] |
| **Queue** | ytq's queue as one more object: browse it, inspect an entry, send it Retry or Forget | the `status` states ytq already has |

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

**How.** ytq keeps downloading to a file, as now, and then runs:

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

**One queue.** `staticstream-queue` reads and writes `queue.json` under the same
`queue.lock` protocol ytq uses. The Workspace's Queue and ytq's window then
show one queue, and Super+Shift+Y keeps working unchanged.

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

### G. The Makefile, and where cargo-make fits

The Makefile is the front door, and it works with nothing but `cargo`
installed, because `copal-build` calls `cargo` directly.
`cargo make` is for the release matrix only:

```make
# staticstream -- Static Stream, the sstr command and its Workspace.   make help
CARGO ?= cargo
ROOT  ?= $(HOME)/.local          # cargo install puts binaries in $(ROOT)/bin, on PATH
ARGS  ?=

.PHONY: help build run workspace test check install tools dist clean

help:        ## this list
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

build:       ## release build of every crate
	$(CARGO) build --release --workspace

run:         ## the command: make run ARGS='play cap.sstr --paced'
	$(CARGO) run --release -p staticstream-cli -- $(ARGS)

workspace:   ## the terminal Workspace
	$(CARGO) run --release -p staticstream-workspace -- $(ARGS)

test:        ## unit tests, and the cross-check against tools/copal-sstr.py
	$(CARGO) test --workspace

check: test  ## what a commit must pass
	$(CARGO) build --release --workspace

install:     ## sstr and sstr-workspace into ~/.local/bin
	$(CARGO) install --locked --root $(ROOT) --path crates/staticstream-cli
	$(CARGO) install --locked --root $(ROOT) --path crates/staticstream-workspace

tools:       ## cargo-make and cargo-zigbuild: from apk on Alpine, else from crates.io
	@if command -v apk >/dev/null; then doas apk add cargo-make cargo-zigbuild; \
	 else $(CARGO) install --locked cargo-make cargo-zigbuild; fi

dist:        ## every target in Makefile.toml, into dist/
	$(CARGO) make dist

clean:
	$(CARGO) clean
```

```toml
# Makefile.toml -- the release matrix. Needs rustup targets and cargo-zigbuild.
[tasks.dist-aarch64]
command = "cargo"
args = ["zigbuild", "--release", "--target", "aarch64-unknown-linux-musl"]

[tasks.dist-armv7]
command = "cargo"
args = ["zigbuild", "--release", "--target", "armv7-unknown-linux-musleabihf"]

[tasks.dist-x86_64]
command = "cargo"
args = ["zigbuild", "--release", "--target", "x86_64-unknown-linux-musl"]

[tasks.dist]
dependencies = ["dist-aarch64", "dist-armv7", "dist-x86_64"]
```

`make dist` and `make tools` are the only targets that need anything more
than `cargo`. None writes inside a tracked file, so a checkout stays
pullable.

### H. The order to build it in

| Phase | Delivers | Done when |
|---|---|---|
| 0 | the repository, workspace, Makefile, README | `make check` passes on the guest and on the Mac |
| 1 | the `staticstream` library and `sstr` at parity with `copal-sstr.py` | the cross-check and damage battery of V-F agree byte for byte; `record` refuses empty input |
| 2 | ytq's `OUTPUT` and `media.conf`, calling `sstr` | a queued video leaves a `.sstr` that `sstr verify` passes and that plays back identical to the MP4 it replaced; `OUTPUT=mp4` leaves today's files |
| 3 | `sstr-workspace`: Browser, Inspector, Transcript, then Services, then Queue | every Service is a command line shown in the Transcript before it runs |
| 4 | `make dist` for the targets of V-E, and version 1's stronger outer code | binaries run on the Pi 2B and the x86_64 VM; version 1 rebuilds two lost records per group |

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

**Why Rust, and why not all at once.** The measured case is the inner code,
15× faster in Rust (IV-C). That is the difference between archiving a
1080p download while the next one starts and waiting for it. A single
binary per target, and builds on each machine, suit a system that runs on a
Pi 2B and a Mac. ytq itself is not rewritten:
- **It works:** its queue, cookie retry and naming carry a week of fixes.
- **Its engine is Python:** yt-dlp is a Python program, which ytq drives
  as a subprocess and could embed [18].

The seam between them is a command line, `sstr record`, and a file that
both lock the same way, `queue.json`. Either side can change behind that.

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

## VII. Procedures

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

## VIII. Files touched

| File | Change |
|---|---|
| `docs/staticstream-project-lab-report.md` | this report; no code changed |

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
