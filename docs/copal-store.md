# The Copal Store: Pi-Apps on Alpine, Compiled From GitHub Where Alpine Stops

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences, and so does every program the store
builds.

---

## Abstract

Pi-Apps is a shelf of about 260 desktop programs for Raspberry Pi OS, each
with a sentence saying what it is. Its installers are Debian packages and
glibc binaries, so almost none of them can run on Alpine as written. This
report ports the *idea* to Copal as stage 18, the Copal Store. It is a yad
window over two tables: the existing catalogue, and a new table of programs
that nothing installs until somebody picks one. Every Pi-Apps entry was
traced to its source. **20 are compiled on the machine from their GitHub
source by 19 recipes, 58 come from Alpine packages, 36 were already in Copal,
and 146 are not ported, each with a stated reason.** OpenShot, which is not in
Pi-Apps, was requested by name and is the first recipe: libopenshot-audio,
libopenshot and openshot-qt, built from their tagged releases. Every recipe
was built on the aarch64 bench and its program launched, and a window was
seen; then all nineteen were rebuilt and relaunched with the finished kit.
Getting there took twelve kinds of repair, and seven of them are the same
fault: code written on glibc meeting musl. The general ones are now handled
once in the recipe kit rather than per program. Flathub is not a source, at the owner's
request: "i do not like flathub … i really prefer github."

## I. Objective

1. Reconsider the graphical half of the full monty: after the desktop, offer
   a store rather than install more by default.
2. Port Pi-Apps' list entry by entry to what Alpine can actually run, taking
   a program's GitHub source first and an Alpine package second.
3. Fix every compilation problem on the way, in Copal's recipe, never
   upstream (see `upstream-policy.md`).
4. Compile OpenShot.
5. Allow an unattended install to take a small starter set automatically.

## II. The design

**Two tables, one window.** The catalogue (`copal-prep.sh`, `catalogue()`) is
what a Copal machine *has*: stage 12 installs from it and `copal-menu` is
built from it. The store's table (`tools/copal-store`, `store_table()`) is
what a machine *could have*: nothing installs from it until it is asked to.
The window shows both, section by section, and marks what is installed. The
two never list the same program; `make lint` fails if they do.

**The row.** It uses the catalogue's fields plus two:
`section|label|install|bin|mode|gate|description|home`. `install` may be apk
names, `name@testing` for edge/testing, or `recipe@source`. The gate uses the
catalogue's architecture vocabulary (`*`, `64`, `!v6`, …). The description is
the sentence that lets a half-remembered name be found by what it does.

**A recipe** is four shell functions: `NAME_bdeps` (build dependencies,
removed afterwards), `NAME_rdeps` (what it needs at run time that no ELF
header says), `NAME_build`, and optionally `NAME_seed`. The kit around them
does the rest:

- `gh_source` / `gh_asset`: a tagged release or pinned commit from GitHub,
  verified by SHA-256 before it is unpacked.
- The build runs in a **fresh `sh`**, with `set -e`, in a scratch directory,
  and installs into a staging tree (`DESTDIR`).
- Everything staged must lie under `$PREFIX` (`/usr/local`), or nothing is
  installed. That rule is what makes the file list complete.
- Nothing staged may overwrite a file the recipe did not put there last time.
- The file list is kept in `/var/lib/copal/store/NAME.files`, and `remove`
  deletes exactly those files, then their empty directories.
- **Runtime dependencies are read from the binaries.** Every `NEEDED`
  library of every staged ELF file becomes an apk `so:` dependency of a
  virtual package `copal-store-NAME`, which is abuild's own method. A
  hand-kept list goes stale: Boost's runtime package is `boost1.84-filesystem`
  today and will have another name next year.
- `NAME_seed` writes first-run settings into each home, only where none
  exist, so a program opens on itself rather than on a wizard.

**Stage 18** installs yad and dialog, writes `copal-store` and its menu
entry, and offers the starter set: OpenShot, Fastfetch, btop and KeePassXC.
An unattended install takes it. A board a row is gated away from simply skips
that row (OpenShot is 64-bit only). The stage runs at the medium and full
levels, not at server. Super+Shift+C opens the store on both desktops:
`copal-center` hands over to it when it is present.

**The program** lives in `tools/copal-store` and is copied into stage 18 by
`make sync-store`, the way `copal-fleet-agent` is. `make lint` checks that
the embedded copy matches, and runs `copal-store self-test`: fields,
sections, modes and gates; unique ids; every `@source` names a recipe with its
functions and every recipe has a row; no placeholder checksums; nothing listed
twice against the catalogue. Both the drift check and the self-test were made
to fail on purpose before they were believed.

## III. Method

The bench is the aarch64 Alpine 3.24 guest: four cores, 6 GB of RAM, and
about 2–4 GB of free disk throughout. `doas` needs a password there, so
`tools/copal-store-bench.sh` runs the store's *own* install code with apk
switched off (`COPAL_STORE_NODEPS=1`) and the prefix under `~/.cache`. It
fetches what apk would have installed (`apk fetch -R`) into a user sysroot and
unpacks only the packages the machine lacks. It re-prefixes their `.pc` files
and aims their library links at `/usr/lib`, as the wxMaxima build first did
(`integration-lab-report.md`, B). The recipe that ships is the recipe that
was tested.

Each program was then launched with `tools/copal-app-probe.sh`, and the
screenshot looked at. "Works" in this report means that the program built,
installed, opened a window that is the program and not an error, and that
its libraries resolved without the bench's `LD_LIBRARY_PATH` where that
applies.

## IV. Results: the nineteen recipes

Each was built, installed, and launched on the bench. The times are the
final regression run's: every recipe rebuilt from its cached source with the
finished kit, on four cores, wall clock including the bench's dependency
fetch. ccache was already warm for Amiberry, whose first build took about six
minutes. A Pi 4 should be expected to take three to five times as long. "Seeded" names the first-run dialog a `_seed` spares.

| Recipe | Program(s) | Upstream, pinned | Build | What it needed |
|---|---|---|---|---|
| `openshot` | OpenShot | OpenShot/libopenshot-audio + libopenshot v1.0.0, openshot-qt v4.0.0 | 4 min 38 s | patches 1, 2, 4, 11; seeded |
| `ccleste` | Celeste Classic | lemon32767/ccleste v1.4.0 | 6 s | input settings moved into the home |
| `pacman` | Pac-Man | ebuc99/pacman v0.9 | 51 s | data path (12); installed as pacman-game |
| `astromenace` | AstroMenace | viewizard/astromenace v1.4.3 | 1 min 24 s | CMake policy (9) |
| `amiberry` | Amiberry | BlitterStudio/amiberry v8.3.0 | 1 min 19 s | 3, 5, 6; SDL3 and two edge/testing libraries |
| `alephone` | Marathon 1, 2, Infinity | Aleph-One-Marathon/alephone release-20250829 + its data | 5 min 14 s | nothing; the first run of the so: dependency record |
| `dxx` | Descent 1 and 2 | dxx-rebirth/dxx-rebirth @ e016525 + shareware and demo data | 4 min 13 s | an in-tree build directory |
| `pychess` | PyChess | pychess/pychess 1.2.0 | 1 min 10 s | runs from its tree; seeded |
| `bleachbit` | BleachBit | bleachbit/bleachbit v6.0.4 | 4 s | locale and module paths (12); seeded |
| `persepolis` | Persepolis | persepolisdm/persepolis 5.2.0 | 1 min 01 s | meson python.purelibdir |
| `ffconverter` | FF Multi Converter | l-koehler/FF-converter v2.4.6 | 12 s | presets path (12); pip --target, --no-deps |
| `smc` | System Monitoring Center | hakandundar34coding/system-monitoring-center v3.4.1 | 12 s | Tk, which the 3.4 series moved to |
| `funkin` | Friday Night Funkin' Rewritten | HTV04/funkin-rewritten v1.1.0-beta.2-1 | 39 s | zipped into a .love |
| `librecad` | LibreCAD | LibreCAD/LibreCAD v2.2.1.5 | 4 min 09 s | 1; seeded |
| `veracrypt` | VeraCrypt | veracrypt/VeraCrypt VeraCrypt_1.26.29 | 1 min 33 s | 8; FUSE 3 |
| `ohmyposh` | Oh My Posh | JanDeDobbeleer/oh-my-posh v30.9.0 | 17 s | 10 (Go 1.26) |
| `ddnet` | DDNet | ddnet/ddnet 20.0 | 2 min 28 s | 7, the thread stack; DATA_DIR (12) |
| `pixelorama` | Pixelorama | Orama-Interactive/Pixelorama v1.2 | 29 s | 10 (Godot 4.6); imported at build time |
| `browsh` | Browsh | browsh-org/browsh v1.8.3 + its release .xpi | 10 s | the extension built in |

Everything opened a window that was the program. Four programs start on their
own welcome or setup page (AstroMenace's language choice, Pixelorama's
splash, DDNet's language list, Funkin's settings notice). Those were left
alone: they are one-time and harmless. Three first-run dialogs were designed
away with seeds, each proved on a fresh home before it was kept: OpenShot's
tutorial and metrics question, PyChess's tip of the day and its request to
download two glibc helpers, and LibreCAD's unit-and-language wizard.
BleachBit's first start reported a write error; a settings file marked as
past the first start removes it.

The store's own window, a section page, a program page and remove followed by
reinstall were exercised on the same bench: `remove ccleste` deleted all 35
files and the directories they made, and reinstalling put them back.

## V. What had to be repaired, by kind

Twelve kinds of repair, and one lesson about the harness. Seven of the kinds
are the same story: code written on glibc, compiled against musl. Those
repairs now live in the kit, so the next recipe gets them without asking.

| # | Fault | Met in | Repair |
|---|---|---|---|
| 1 | `<execinfo.h>` (`backtrace`) is glibc's | JUCE (libopenshot-audio), libopenshot, LibreCAD | `__has_include` guard; stubs that report zero frames, which every caller already handles |
| 2 | `_NL_ADDRESS_LANG_AB`, `_NL_ADDRESS_COUNTRY_AB2` are glibc `nl_langinfo` items | JUCE | take JUCE's own BSD branch, which reads `$LANG` |
| 3 | musl 1.2.4 declares `stat64`, `fopen64` … only on request | JUCE, capsimage in Amiberry | `-D_LARGEFILE64_SOURCE` for every CMake recipe |
| 4 | glibc headers bring in `<cstdint>` in passing | libopenshot | include it |
| 5 | aarch64 `mcontext_t.regs` is `unsigned long` on musl, `unsigned long long` on glibc | Amiberry | a cast: both are 64 bits there |
| 6 | C++ `NULL` is `nullptr` on musl, an integer on glibc | Amiberry | `static_cast<uaecptr>(0)` |
| 7 | **a thread gets 128 KB of stack on musl, 8 MB on glibc** | DDNet's renderer: SIGSEGV on the first store into its frame, found with gdb | `-Wl,-z,stack-size=8388608` for every CMake recipe, since musl reads its default from that header field |
| 8 | busybox `awk` cannot run VeraCrypt's date parser | VeraCrypt | pass `SOURCE_DATE_EPOCH` (8 June 2026) |
| 9 | CMake 4 refuses a declared minimum below 3.5 | AstroMenace | `CMAKE_POLICY_VERSION_MINIMUM=3.5` for every CMake recipe |
| 10 | a toolchain newer than Alpine's | Oh My Posh 31 (Go 1.27), Pixelorama 1.2.1+ (Godot 4.7) | pin the last release that fits: 30.9.0 and 1.2 |
| 11 | a build broken by an option upstream does not test | libopenshot 1.0.0 without OpenCV fails to link | guard the one function with `#ifndef USE_OPENCV` |
| 12 | paths written in as `/usr/…` | Pac-Man data, BleachBit's locale and its `/usr/share` lookup, FF Multi Converter's presets, DDNet's data | use the build's own prefix, which the store's staging check exposes at once |

**The harness lesson.** The first driver ran a recipe as
`if ! ( set -e; … )`, and later as a plain subshell inside a function that
was called as `build_recipe … || _rc=1`. In both cases a failed `cmake` did
not stop the recipe. It went on to install a launcher for a binary that was
never built, and reported success. POSIX turns `set -e` off for everything to
the left of `||` and inside an `if` condition, subshells included, however
deep. A recipe now runs as `sh copal-store __build NAME`, a new process, where
`set -e` starts in force. That is the only arrangement that survives being
called from anywhere.

The regression run found one more driver fault. Upgrading over an earlier
build copied files onto their predecessors, and a file installed read-only
(meson installs scripts 0555) could not be overwritten by the non-root bench.
Root could have, but an upgrade should not depend on that. The old build's
files are now all removed first; the check before it has already proved they
are the recipe's own.

Three bench findings belong here too. The regression filled the guest's disk:
`apk fetch -R` downloads the installed dependencies as well, 1.4 GB after
nineteen recipes. The bench now deletes each download once it is unpacked.
`/tmp` on the guest is a 1.2 GB tmpfs, so unpacking source trees there fills
it (the root disk was never at risk). And `apk fetch` wants a testing package named with its tag when fetching
recursively, and without it otherwise.

## VI. Why the rest is not ported

The 146 entries that are not ported fall into a few groups. Appendix A gives
the reason for each.

- **No source to compile**: proprietary programs (Chrome, Vivaldi, Obsidian,
  Sublime, Zoom, TeamViewer, Steam, Reaper …) and Windows programs (VARA,
  Winlink, WACUP).
- **Electron and NW.js applications.** Alpine does package Electron (in
  edge/testing), but each of these would pull a node_modules tree of hundreds
  of megabytes onto a card, and several are packaged by Alpine already:
  Caprine, Signal and FreeTube are in the store, VSCodium in the catalogue.
- **Pi OS or Botspot tools** that manage apt, Pi OS settings or Pi-Apps
  itself.
- **Binaries built for glibc**, tested where the question was open.
  Shattered Pixel Dungeon and Unciv are GitHub jars whose LWJGL natives are
  glibc builds: they fail to load on musl and crash even under `gcompat`.
  Angry IP Scanner needs SWT, which Alpine does not package.
- **Not attempted yet**, meaning worth doing but large: Azahar, Celeste64,
  Ruffle, Stunt Rally, LibrePCB, Fritzing, Mission Center, En Croissant,
  Sonic Pi, iDescriptor, Open-Typer. Each is a bigger build than the free
  disk on this bench allowed in one session.
- **Deferred with a reason**: Linux Wifi Hotspot builds, but its root
  handling is polkit, whose policy files must live in `/usr/share` (outside
  the store's prefix rule), and it cannot be tested on a VM with no Wi-Fi
  adapter.
- **Flathub-only**, by choice: Zen, Floorp, Legcord, WebCord, OnlyOffice,
  PeaZip, Packet, Notejot, Dot Matrix, Bambu Studio.

## VII. Using it

    copal-store                     the window (or menus under dialog, in a terminal)
    copal-store list [SECTION]      status, section, id, name
    copal-store info openshot       what it is, where it comes from
    doas copal-store install openshot
    doas copal-store remove openshot
    copal-store show pixelorama     open one program's page -- a link target

In the window: pick a section, double-click a program, then Install, Remove,
Open or Website. Install and Remove run in a terminal window so the apk or
compiler output can be read, and the list is redrawn afterwards.

**Adding a recipe.** Write the four functions beside the others in
`tools/copal-store` and add the name to `RECIPES`. Add one table row whose
`install` field is `NAME@source`. Then run `tools/copal-store-bench.sh NAME`
on the bench and launch the program with `copal-app-probe.sh`. If it opens,
run `make sync-store`, which also runs lint. A row goes into the table only
after its recipe has built and run.

## VIII. Open items

1. **No build has yet run as root on a real card.** Everything above ran
   through the bench, with apk replaced by a sysroot. The `apk add -t`
   virtual packages, the `so:` dependency record, `apk del` of the build
   dependencies, and the doas-driven Install and Remove buttons have not run
   for real. That run is the next hardware session, like the Linux card writer
   before it (`linux-host-plan.md`).
2. **x86_64 is gated in but unbuilt.** The `64` gate admits x86_64 on the
   strength of every dependency being in its index, not on a build.
3. The guest's sound card has no playback stream, so every game here reports
   "no audio device". That is the UTM setting in `integration-lab-report.md`,
   C, not a build fault.
4. The "not attempted yet" list in VI.

## Appendix A. Every Pi-Apps entry

The entries under the categories of Pi-Apps' own list, plus three that are in its repository but not in the list (Gnome Software, Hyper, Stunt Rally), plus OpenShot. 260 entries: **20** compiled here from GitHub, **58** Alpine packages in the store, **36** already in Copal, **146** not ported.

### Appearance

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Caskaydia Cove NF | Alpine package, in the store | font-cascadia-code-nerd |
| Colored Man Pages | not ported | a shell setting (LESS_TERMCAP), not a program |
| Color Emoji font | Alpine package, in the store | font-noto-emoji |
| Command Not Found | not ported | Alpine has no command-not-found index |
| Conky | not ported | Pi-Apps installs Botspot's Pi-specific configuration (vcgencmd); plain conky is `apk add conky` |
| Conky Rings | not ported | as Conky |
| Geany Dark Mode | not ported | colour schemes for ~/.config/geany; Geany itself is in the catalogue |
| Lightpad | not ported | not on GitHub (SourceForge), unmaintained |
| Oh My Posh | GitHub, compiled here | JanDeDobbeleer/oh-my-posh 30.9.0 (31.x needs Go 1.27; Alpine has 1.26) |
| Oomox Theme Designer | not ported | GTK2/3 theme generator with a large Python and GTK2 build; X11-era |
| Powerline-Shell | Alpine package, in the store | its maintained successor Starship (`starship`) |
| Ulauncher | not ported | X11 launcher; Copal's launcher is copal-menu / wofi |
| Windows Screensavers | not ported | Windows programs under Wine; no source |
| XSnow | not ported | draws on the X root window; nothing to see under Hyprland, and not on GitHub |

### Creative Arts

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| BlockBench | not ported | Electron; its Linux build is an x86_64 AppImage |
| Boxy SVG | not ported | proprietary |
| Dot Matrix | not ported | GTK4 + libhelium (not packaged); Flathub only |
| Drawing | already in Copal | catalogue (Design) |
| GIMP | already in Copal | catalogue (Design) |
| Inkscape | already in Copal | catalogue (Design) |
| Kolourpaint | Alpine package, in the store | kolourpaint |
| Krita | already in Copal | catalogue (Design) |
| Lego Digital Designer | not ported | Windows program under Wine |
| Pinta | already in Copal | catalogue (Design) |
| Pixelorama | GitHub, compiled here | Orama-Interactive/Pixelorama 1.2, run by Alpine's Godot 4.6 (1.2.1+ want 4.7) |
| Shotwell | Alpine package, in the store | shotwell |

### Engineering

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Bambu Studio | not ported | vendor slicer; Flathub only |
| Cura | already in Copal | catalogue (Engineering), from edge/testing |
| Eagle CAD | not ported | proprietary, discontinued by Autodesk |
| FreeCAD | already in Copal | catalogue (Engineering) |
| Fritzing | not ported | Qt 6 with a bundled ngspice and libgit2 stack; not attempted yet |
| INAV Configurator | not ported | NW.js application, x86_64 glibc binary |
| KiCad | already in Copal | catalogue (Engineering) |
| LibreCAD | GitHub, compiled here | LibreCAD/LibreCAD 2.2.1.5 (musl patch: execinfo) |
| LibrePCB | not ported | Qt 6 + Rust; not attempted yet |
| MatterControl | not ported | .NET/Mono, x86 binaries |
| Mission Planner | not ported | Windows .NET program under Mono |
| OpenSCAD | Alpine package, in the store | openscad on x86 and x86_64 only; no aarch64 package and the last release is 2021 |
| OrcaSlicer | not ported | wxWidgets + OCCT + CGAL build that assumes glibc; not attempted |
| PrusaSlicer | not ported | as OrcaSlicer |
| SolveSpace | already in Copal | catalogue (Engineering) |
| VARA FM | not ported | Windows program |
| VARA HF | not ported | Windows program |
| Winlink Express | not ported | Windows program |

### Games

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Amiberry | GitHub, compiled here | BlitterStudio/amiberry 8.3.0, SDL3 (musl: mcontext regs, NULL cast) |
| AstroMenace | GitHub, compiled here | viewizard/astromenace 1.4.3 |
| Azahar | not ported | 3DS emulator, large Qt 6 build with submodules; not attempted yet |
| Celeste64 | not ported | .NET 8 game; not attempted yet |
| Celeste Classic | GitHub, compiled here | lemon32767/ccleste 1.4.0 |
| CrazyCattle3D | not ported | itch.io binary, no source |
| DDNet | GitHub, compiled here | ddnet/ddnet 20.0 (musl: thread stack size) |
| Descent 1 | GitHub, compiled here | dxx-rebirth at e016525, with the shareware data |
| Descent 2 | GitHub, compiled here | dxx-rebirth, the same build, with the demo data |
| Doom 3 | Alpine package, in the store | dhewm3 (edge/testing); bring base/ from the game |
| En Croissant | not ported | Tauri (Rust + WebKitGTK) build; not attempted yet |
| Friday Night Funkin' Rewritten | GitHub, compiled here | HTV04/funkin-rewritten, run by LOVE |
| Friday Night Funkin' Shadow Engine | not ported | Haxe/HaxeFlixel toolchain not packaged |
| GB Studio | not ported | Electron |
| Godot | Alpine package, in the store | godot (edge/testing) |
| Heroes 2 | Alpine package, in the store | fheroes2 (edge/testing) |
| LineRider | not ported | .NET/Mono project, unmaintained |
| Marathon | GitHub, compiled here | Aleph-One-Marathon/alephone 20250829, with all three games' data |
| Minecraft Bedrock | not ported | proprietary Android build under a launcher; glibc |
| Minecraft Java GDLauncher | not ported | Electron |
| Minecraft Java Prism Launcher | Alpine package, in the store | prismlauncher |
| Minecraft Java Server | not ported | a headless server; outside Pi-Apps' own rules |
| Minecraft Pi (Modded) | not ported | ARM glibc binary of an old Pi edition |
| Pac-Man | GitHub, compiled here | ebuc99/pacman 0.9, installed as pacman-game |
| PPSSPP (PSP emulator) | Alpine package, in the store | ppsspp (64-bit and x86) |
| Project OutFox | not ported | binary releases only |
| PyChess | GitHub, compiled here | pychess/pychess 1.2.0, with Stockfish |
| Ruffle | not ported | Rust + wgpu, a very large build; not attempted yet |
| Shattered Pixel Dungeon | not ported | tested: its LWJGL natives are glibc builds and crash on musl, even under gcompat |
| Steam | not ported | x86 glibc; no source |
| Steam Link | not ported | Pi-only binary |
| Stunt Rally | not ported | Ogre 3D engine and a large asset build; not attempted yet |
| StepMania | not ported | bundles an FFmpeg too old for current compilers; not attempted |
| Tetris CLI | not ported | its repository is gone (Pi-Apps links the Wayback Machine) |
| Unciv | not ported | tested: LWJGL glibc natives crash on musl, even under gcompat |
| WorldPainter | not ported | not on GitHub releases; Java with native launchers |

### Internet

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Angry IP scanner | not ported | needs SWT, which Alpine does not package; its jars carry glibc SWT |
| AnyDesk | not ported | proprietary |
| Deskreen | not ported | Electron |
| Ethernet Hotspot | not ported | Botspot's Pi-specific script |
| Linux Wifi Hotspot | not ported | deferred: needs polkit rules in /usr/share and a Wi-Fi adapter to test |
| RiiTag-RPC | not ported | Discord/Wii niche tool, Electron |
| RustDesk | not ported | Flutter build; Alpine packages only the server |
| SpeedTest-CLI | Alpine package, in the store | speedtest-cli |
| TeamViewer | not ported | proprietary |
| Web Apps | not ported | Linux Mint's webapp-manager; Epiphany does this ('Install as app') |

### Internet/Browsers

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Better Chromium | not ported | Pi OS Chromium settings |
| Brave | already in Copal | catalogue (Internet) and stage 4 -- the one Flathub program, kept |
| Browsh | GitHub, compiled here | browsh-org/browsh 1.8.3 built with its release extension; drives Firefox ESR |
| Chrome | not ported | proprietary, no aarch64 Linux build |
| Chromium | already in Copal | catalogue (Internet) |
| Downgrade Chromium | not ported | Pi OS specific |
| Epiphany | Alpine package, in the store | epiphany |
| Firefox Rapid Release | Alpine package, in the store | firefox (the catalogue has Firefox ESR) |
| Floorp | not ported | Flathub only |
| Flow | not ported | proprietary |
| LibreWolf | Alpine package, in the store | librewolf |
| Min | not ported | Electron |
| Mullvad | not ported | x86_64 only |
| Puffin | not ported | proprietary |
| Tor | not ported | Tor Browser has no aarch64 Linux build; the tor daemon is `apk add tor` |
| Vivaldi | not ported | proprietary |
| Zen | not ported | Flathub only |

### Internet/Communication

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Caprine | Alpine package, in the store | caprine (edge/testing) |
| Legcord | not ported | Electron; Flathub only |
| Microsoft Teams | not ported | Electron wrapper; Flathub only |
| Signal | Alpine package, in the store | signal-desktop (edge/testing) |
| Telegram | Alpine package, in the store | telegram-desktop |
| Thunderbird | already in Copal | catalogue (Mail) |
| Webcord | not ported | Electron; Flathub only |
| Wechat | not ported | proprietary |
| WhatsApp | not ported | a web page in a wrapper |
| Zoom | not ported | proprietary |
| Zoom PWA | not ported | a web page in a wrapper |

### Internet/Download & Upload

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| CloudBuddy | not ported | Botspot's yad front end to rclone; rclone is `apk add rclone` |
| Deluge | Alpine package, in the store | deluge |
| Filezilla | already in Copal | catalogue (Internet) |
| Https File Server | not ported | a server, outside Pi-Apps' own rules |
| HTTrack Website Copier | Alpine package, in the store | httrack (edge/testing) |
| OnionShare | Alpine package, in the store | onionshare (edge/testing; command-line) |
| Persepolis Download Manager | GitHub, compiled here | persepolisdm/persepolis 5.2.0 over aria2 |
| qBittorrent | already in Copal | catalogue (Internet) |
| Snapdrop | not ported | a web service |
| Transmission | already in Copal | catalogue (Internet) |
| Xtreme Download Manager | not ported | binary releases (.NET) |

### Multimedia

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Audacious | already in Copal | catalogue (Media) |
| Audacity | already in Copal | catalogue (Audio) |
| Bongo Cam | not ported | reads the global mouse through X11; nothing to follow under Hyprland |
| Botspot Screen Recorder | not ported | Botspot's script |
| Easy Effects | Alpine package, in the store | easyeffects |
| FreeTube | Alpine package, in the store | freetube (edge/testing) |
| Kdenlive | Alpine package, in the store | kdenlive |
| Kodi | Alpine package, in the store | kodi |
| LMMS | already in Copal | catalogue (Audio) |
| MuseScore | already in Copal | catalogue (Audio) |
| OBS Studio | Alpine package, in the store | obs-studio |
| Reaper | not ported | proprietary |
| Renoise (Demo) | not ported | proprietary |
| Shellbeats | not ported | closed |
| SimpleScreenRecorder | Alpine package, in the store | simplescreenrecorder on x86 and x86_64; it records X only |
| Sonic Pi | not ported | Ruby + Erlang + SuperCollider + Qt; not attempted yet |
| Sound Recorder | Alpine package, in the store | gnome-sound-recorder |
| WACUP (new WinAmp) | not ported | Windows program |
| Waveform | not ported | proprietary |
| YouTube Player | Alpine package, in the store | pipe-viewer |
| OpenShot (not in Pi-Apps) | GitHub, compiled here | OpenShot/libopenshot-audio + libopenshot 1.0.0, openshot-qt 4.0.0 -- asked for by name |

### Office

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| AbiWord | already in Copal | catalogue (Documents) |
| Gnumeric | already in Copal | catalogue (Documents) |
| Libreoffice MS theme | not ported | an icon theme for Pi OS's LibreOffice |
| LibreOffice | already in Copal | catalogue (Documents) |
| NixNote2 | not ported | needs QtWebKit, which Alpine dropped |
| Notejot | not ported | GTK4 + libhelium; Flathub only |
| Obsidian | not ported | proprietary |
| OnlyOffice | not ported | Flathub only |
| Open-Typer | not ported | needs two forked submodules; last release 2023; not attempted yet |
| ProjectLibre | not ported | SourceForge jar, not GitHub |
| WPS Office | not ported | proprietary |

### Programming

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Antigravity | not ported | proprietary |
| Arduino | Alpine package, in the store | arduino-cli (edge/testing); the IDE 2 is Electron |
| BlueJ Java IDE | not ported | Java with bundled JavaFX natives; not attempted |
| Codex | not ported | not identified as an open project |
| Electron Fiddle | not ported | Electron |
| Github-CLI | Alpine package, in the store | github-cli (`gh`) |
| Github Desktop | not ported | Electron |
| Gnome Builder IDE | Alpine package, in the store | gnome-builder |
| Intellij IDEA | not ported | bundles a glibc JRE |
| jGRASP IDE | not ported | not on GitHub |
| Mu | not ported | pins old PyQt5 wheels from PyPI |
| Notepad ++ | already in Copal | stage 14 runs it in a Wine box (winebox) |
| Processing IDE | not ported | bundles a glibc JDK |
| Pycharm CE | not ported | bundles a glibc JRE |
| Scratch 2 | not ported | Adobe AIR |
| Scratch 3 | not ported | Electron |
| Sphero SDK | not ported | Pi-specific |
| StackEdit | not ported | a web application |
| Sublime Merge | not ported | proprietary |
| Sublime Text | not ported | proprietary |
| Thonny | Alpine package, in the store | thonny |
| Turbowarp | not ported | Electron |
| Visual Studio Code | not ported | proprietary; VSCodium is in the catalogue |
| VSCodium | already in Copal | catalogue (Devtools) |

### System Management

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| All Is Well | not ported | Pi-Apps' own |
| Autostar | not ported | Botspot's |
| BleachBit | GitHub, compiled here | bleachbit/bleachbit 6.0.4 |
| btop++ | Alpine package, in the store | btop |
| Clam Antivirus | already in Copal | catalogue (ClamAV); ClamTk's Perl GTK bindings are not packaged |
| CommanderPi | not ported | Pi OS specific |
| Disk Usage Analyzer | already in Copal | catalogue (Baobab) |
| Fastfetch | Alpine package, in the store | fastfetch |
| GParted | already in Copal | catalogue |
| Mission Center | not ported | Rust + GTK4 with a large crate tree; Flathub otherwise |
| Neofetch | Alpine package, in the store | neofetch (edge/testing) |
| Pika Backup | Alpine package, in the store | pika-backup (edge/testing) |
| Pi Power Tools | not ported | Pi OS specific |
| Plasma Discover | not ported | a front end for apt/Flatpak |
| Gnome Software | not ported | a front end for PackageKit and Flatpak; the Copal Store is the front end here |
| Snap Store | not ported | Snap |
| Synaptic | not ported | apt |
| Syncthing | already in Copal | catalogue; its GTK window is in the store (syncthing-gtk) |
| SysMonTask | not ported | archived upstream |
| Systemd Pilot | not ported | Alpine has no systemd |
| System Monitoring Center | GitHub, compiled here | hakandundar34coding/system-monitoring-center 3.4.1 |
| Timeshift | Alpine package, in the store | timeshift (edge/testing); stage 11 offers it too |
| Update Buddy | not ported | apt |

### Terminals

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Alacritty Terminal | already in Copal | catalogue |
| Cool Retro Term | already in Copal | catalogue |
| Guake Terminal | already in Copal | catalogue |
| kitty | already in Copal | catalogue |
| Microsoft PowerShell | Alpine package, in the store | powershell (`pwsh`) |
| Hyper | not ported | Electron |
| Tabby | not ported | Electron |

### Tools

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| AndroidBuddy | not ported | Botspot's |
| AntiMicroX | Alpine package, in the store | antimicrox (edge/testing) |
| BalenaEtcher | not ported | Electron; Raspberry Pi Imager does the job |
| ckb-next | Alpine package, in the store | ckb-next (edge/testing) |
| FF Multi Converter | GitHub, compiled here | l-koehler/FF-converter 2.4.6 |
| Flameshot | Alpine package, in the store | flameshot |
| Geekbench 5 | not ported | proprietary |
| Geekbench 6 | not ported | proprietary |
| Gnome Maps | Alpine package, in the store | gnome-maps |
| iDescriptor | not ported | Qt 6 over libimobiledevice; not attempted yet |
| Imager | Alpine package, in the store | rpi-imager (edge/testing) |
| KeePassXC | Alpine package, in the store | keepassxc |
| More RAM | already in Copal | stage 5 (zram) |
| Nautilus | Alpine package, in the store | nautilus |
| Nemo | Alpine package, in the store | nemo |
| Node.js | Alpine package, in the store | nodejs, npm |
| Ollama GUI | Alpine package, in the store | ollama (command line) |
| Organic Maps | Alpine package, in the store | organicmaps (edge/testing) |
| Packet | not ported | Rust + GTK4; Flathub only |
| PeaZip | not ported | Lazarus/Free Pascal; Flathub only |
| Pi-Apps Terminal Plugin (bash) | not ported | Pi-Apps' own |
| PiGro | not ported | Pi OS specific |
| PiSafe | not ported | Pi OS specific |
| QR Code Reader | not ported | CoBang, GTK4 + zbar; Flathub only |
| Scrcpy | Alpine package, in the store | scrcpy |
| Screenshot | Alpine package, in the store | gnome-screenshot |
| TiLP | not ported | GTK2-era TI calculator link; not attempted |
| tldr | Alpine package, in the store | tealdeer (edge/testing) |
| USBImager | not ported | not on GitHub (GitLab); Raspberry Pi Imager does the job |
| VeraCrypt | GitHub, compiled here | veracrypt/VeraCrypt 1.26.29 on FUSE 3 |
| VMware Horizon Client | not ported | proprietary |
| Windows Flasher | not ported | Botspot's |
| Xfburn | already in Copal | catalogue (Discs) |

### Tools/Crypto

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Ducopanel | not ported | Duino-Coin panel, glibc binaries |
| Feather Wallet | Alpine package, in the store | feather-wallet (edge/testing) |
| Monero GUI | Alpine package, in the store | monero-gui (edge/testing) |
| XMRig | Alpine package, in the store | xmrig |

### Tools/Emulation

| Pi-Apps name | Where it went | Detail |
|---|---|---|
| Botspot Virtual Machine | not ported | Botspot's |
| Box64 | not ported | runs x86_64 glibc programs; does not support musl |
| Box86 | not ported | as Box64, and 32-bit ARM only |
| Hangover | not ported | Wine on ARM with FEX; very large; not attempted |
| QEMU | Alpine package, in the store | qemu-system-x86_64, qemu-ui-gtk |
| Waydroid | Alpine package, in the store | waydroid |
| Wine (x64) | already in Copal | stage 14 (winebox) |
| Wine (x86) | already in Copal | stage 14 (winebox) |
