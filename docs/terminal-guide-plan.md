# The Terminal Guide: Every Command on a Copal Machine, Firehose Edition

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`.

---

## Why

A Copal machine carries about three hundred terminal commands that it put
there on purpose: 183 catalogue rows, Copal's own 35, the store's 32, and the
Alpine and toolchain core its stages install. None of them can be read about
on the machine itself: Alpine ships no `man`. The menus show a terminal
program as a name and nothing more. A graphical program has a picture in the
gallery; a terminal program has nothing.

The guide is one hyperlinked reference to every one of them: what it is, why
it is on this system, the package and dependency chain it came in by, its
common use, a good example, the options that matter, and the parts people
get wrong — the things that fill forum threads. No fluff: nouns first,
direct words, the important sections of the man page and not all of it.

Decided on 23 Sep 2026:

1. **Two layers, one page.** Facts are **generated** from the files and the
   machine: the inventory, packages, versions, descriptions, dependencies,
   the stage that installs it, the man page's NAME and SYNOPSIS. The
   **editorial** layer is written and reviewed by hand: purpose, why it is
   here, use, examples, options, notes, links. Each complements the other; a
   command with no editorial yet still has its facts.
2. **A template first**, filled for a handful of commands and reviewed,
   before the rest are written in it.
3. **`man` is implemented on Copal**, and the man pages are built to HTML
   for the site, so every entry links to the full page.
4. **All work in this terminal**, in reviewed batches. No background agents.

## I. The two layers

| Field | Layer | Source |
|---|---|---|
| command, label, section, mode (t/h/x) | generated | catalogue row, store table, `cat > /usr/local/bin/NAME` markers, `man_core_commands` in `copal-prep.sh` |
| origin and the stage that installs it | generated | which of those it came from; the stage playbook containing the install |
| package, version, description, webpage | generated | `apk info -W`, `-d`, `-w` on a Copal machine |
| dependency chain | generated | `apk info -R`, `so:` names resolved to packages, one level; the catalogue row's other packages |
| NAME line, SYNOPSIS | generated | the man page (`mandoc`), else the `Usage:` line of `--help` |
| full man page | generated | `mandoc -T html`, to `docs/man/NAME.html` |
| gallery picture | generated | `docs/img/gallery/NAME.jpg`, when the program has one |
| purpose (one noun phrase) | editorial | written |
| why it is on Copal | editorial | written, from the installer's own comments where they say |
| use, examples, options, notes | editorial | written, checked against `--help` and the man page on the machine |
| see also (links) | editorial | written; a link to a command in the guide becomes an anchor |

Facts override nothing written, and writing overrides no fact: the renderer
shows both, and flags a note that names an option the man page does not have.

## II. The template

One file per command, `docs/commands/<section>/<cmd>.md`: a header of keys,
then four fixed sections. The same shape as a playbook: data at the top,
body below, one file per thing, reviewable as a diff.

```markdown
# command:  rsync
# purpose:  Copy and synchronise files, locally or over SSH, sending only differences.
# why:      Stage 11's snapshots are rsync; so is moving a home directory to a
#           new card, and the backup the snapshot stage suggests.
# see:      scp, snapshot, lftp

## Use
Keep one tree identical to another. Only changed files cross, only changed
parts of them, so the second run over a large tree takes seconds.

## Examples
    rsync -av ~/Photos/ /media/usb/Photos/      # copy a tree, keep times and modes
    rsync -avz --delete ~/code/ pi:code/        # mirror to another machine over SSH
    rsync -avn --delete src/ dst/               # dry run: what would change
    rsync -aP big.iso pi:/tmp/                  # resumable, with progress

## Options
-a                archive: recursive, keeps links, modes, times, owner, group
-v                name each file
-z                compress in transit (worth it over a slow link, not a LAN)
-n                dry run
-P                --partial --progress: keep partial files, show a bar
--delete          remove files in the destination that the source lacks
-e 'ssh -p 2222'  the remote shell, with its options
--exclude=PATTERN skip matching paths

## Notes
- The trailing slash is the whole question. `src/` copies the contents of
  src; `src` copies the directory itself into the destination.
- `--delete` with the wrong direction or a missing slash deletes the wrong
  things. Run it with `-n` first.
- `-a` does not keep hard links, ACLs or extended attributes: add `-HAX`.
```

Rendered, the entry leads with the generated facts:

    rsync — Copy and synchronise files, locally or over SSH, sending only differences.
    Core · rsync 3.5.0 (package rsync) · installed by stage 11
    needs: acl-libs, lz4-libs, popt, libxxhash, zlib, zstd-libs
    rsync [OPTION]... SRC [SRC]... DEST            ← SYNOPSIS, from the man page
    full man page →                               ← docs/man/rsync.html

and a command that has no file yet shows the facts alone, under "no notes
yet", so the inventory is complete on the first build.

**The review checklist**, applied to every entry before it is accepted:

1. Every option in *Options* and every flag in *Examples* exists in the
   installed version (`--help` or the man page on a Copal machine).
2. Every example runs as written, or is marked as needing a host, a file
   or root.
3. *Why* is Copal's reason, not the program's advertisement.
4. *Notes* hold only the hard, surprising or much-asked parts; none is
   better than a filler note.
5. BusyBox, musl and OpenRC differences from the GNU/glibc/systemd answers
   people find online are stated where they bite.
6. No sentence without a noun doing work.

## III. `man` on Copal

Alpine has everything: `mandoc` (the `man` command), `mandoc-apropos`
(`apropos` and `whatis`, via `makewhatis`), `man-pages` (the C library and
system call pages), and `docs`, a meta package that makes every installed
package pull in its `-doc` subpackage from then on.

Measured on the bench, a full monty: `apk add --simulate` of those four
brings in **812 doc packages, 2.0 GiB installed**. Five packages are 62% of it:
`ghc-doc` 753 MiB, `gnuradio-doc` 309 MiB, `libmedc-doc` 102 MiB,
`gtkmm4-doc` 90 MiB, `gtk4.0-doc` 87 MiB. They are HTML API manuals, not
man pages.

Three ways to do it, a decision to make:

| | What | Cost on the full monty |
|---|---|---|
| **a** | `mandoc mandoc-apropos man-pages docs` at every level | 2.0 GiB; too much for an 8 GB card |
| **b** | `mandoc mandoc-apropos man-pages` at every level, and the `-doc` package of each program in the guide | man pages for every command documented; to be measured, expected a small fraction of (a) |
| **c** | (b), plus `docs` at the full level only | man pages for everything on the full monty's larger disks |

**Decided, 23 Sep 2026: (b).** (c) stays open for later, if the full level's disk allows it. Stage 1
installs the three `mandoc` packages (every level, including server); stage
12 and the store add `NAME-doc` with each program, which is one more
package name per catalogue row, generated from the guide's inventory; then
`makewhatis` so `apropos` works.

**The site's copies.** The collector runs `mandoc -T html` over each page
and writes `docs/man/NAME.html` in the site's style; each guide entry links
to it. The bench guest needs `doas apk add mandoc man-pages` plus the
`-doc` packages once for the collector to see them.

## IV. The pipeline

    tools/copal-command-ref.py collect   on a Copal machine: inventory + facts + man pages
        -> docs/commands/facts.json          (committed, so rendering needs no guest)
        -> docs/man/*.html
    tools/copal-command-ref.py render    anywhere
        docs/commands/facts.json + docs/commands/*/*.md
        -> docs/commands.html                the guide: index A–Z and by section, every entry
        -> docs/commands-index.json          command -> purpose, for the menus' links
    tools/copal-command-ref.py check     lint: every inventory command has facts; every
                                         .md names a command in the inventory; every
                                         option in a note exists in the man page or --help

`make commands` runs render and check; `make commands-facts` runs collect
and refuses to run anywhere but a Copal machine. `make lint` runs check.

**The page** is one HTML file in the site's style: a search box that
filters as you type, the index by section and A–Z, and an entry per
command with the anchor `#c-NAME` — the anchor the menus already link to.

## V. The menus link to it

Done and uncommitted, awaiting review (section VIII): the home page's
section 01 is live. The Mint-style menu (`copal-gui`) and the keyboard menu
(`copal-menu`) are both simulated from the real menus' data
(`tools/copal-menu-sim.py`). Hovering shows the gallery picture of what a
program opens to; clicking puts that picture on the screen. A program with no picture
shows **"terminal command — see man NAME"**, linking to `commands.html#c-NAME`.
The keyboard menu plays itself until it is touched. Once the guide exists,
`copal-menu-sim.py` reads `docs/commands-index.json` instead of the
placeholder it reads now.

## VI. Phases

Each ends with a review of what it produced before the next begins.

1. **`man` on Copal**, option (b). *Built 23 Sep 2026*, below.
2. **The collector.** Inventory from the four sources, facts from apk, NAME
   and SYNOPSIS from mandoc, `docs/man/*.html`. Check: 292 commands, each
   with a package and a version or a reason it has none (`copal-*`: "copal,
   stage N").
3. **The template and the renderer**, with five entries written in full
   for review: `apk`, `doas`, `rsync`, `tmux`, `links`, one of each kind
   of hard. The page, the search, the anchors.
4. **The editorial passes**, in batches of about twenty, in this terminal,
   each reviewed against the checklist before the next: core first (the
   most-asked: apk, doas, OpenRC, lbu, BusyBox), then Copal's own, then the
   catalogue by section, then the store's shelf.
5. **Joined up.** The menus read the index; the handbook's *Commands on the
   Pi* and the README link to the guide; `make lint` runs check; the site's
   Software page links it.

### Phase 1, as built

- **`install_manuals`** in `copal-prep.sh`: `mandoc`, `mandoc-apropos` and
  `man-pages`, then the `-doc` of every package that owns a guide command
  on the machine -- `man_core_commands` (the core list, the one source the
  collector will also read) and the catalogue's `t` and `h` rows -- less
  those already installed, those the index lacks, and any over
  `MAN_DOC_CAP_KB` (32 MiB), each named in the log. A -doc only edge/testing
  carries is asked for as `NAME@testing` (from `apk policy`): the first real
  run on the bench failed whole because eight untagged testing names were
  in one transaction. Then `makewhatis`.
  Three batched apk queries: 6.6 s on the bench.
- **Called from six stages**: 2 (after the apk cache is on p2, before its
  `lbu commit`, so every level has `man`), 7, 10, 12, 14 and 17, each
  after it installs commands. Not stage 1: the root is still in RAM there
  and a package would not outlive it.
- **The store**: `copal-store install` of an apk row whose mode is `t` or
  `h` adds that package's `-doc` the same way (`man_pages_for`).
- **Measured on the bench** (dry run, the full monty): `mandoc`,
  `mandoc-apropos`, `man-pages`, and 152 doc packages, 146 MiB; `ghc-doc`
  (753 MiB) skipped by the cap. Option (a) would have been 2.0 GiB.

### Phase 2, as built

- **`tools/copal-command-ref.py`**: `inventory` (from the repository),
  `collect` and `man-html` (on a Copal machine); `make commands-facts`
  runs the last two and refuses to run anywhere else.
- **The inventory is 289**, not 292: a program in two catalogue rows is one
  entry (`python3` is three rows), and nine core commands share a
  catalogue row (`rsync`, `tmux`, `gdb`...), kept as one entry with both
  origins. `iwctl` and `nmcli` left the core list — Copal installs neither;
  its wifi is `wpa_supplicant` (stage 10), so `wpa_cli`, `wpa_passphrase`
  and `iw` joined it.
- **Copal's own 41** are found by the lines that write them (`cat >`,
  `install -m`, and `cp` for `copal` itself) and placed in a stage through
  copal-init.sh's call graph — heredoc-aware, since the whole of
  copal-init.sh is one heredoc in copal-prep.sh and copal-store's own
  functions are text inside it. Three run on every start (stage 0).
- **Facts**, batched: one `apk info -W` for every path, one `apk query`
  for every package (version, description, URL, origin, dependencies), one
  for every library's provider. 21 s for all 289, from 9 min 19 s one at a
  time. The man page is the one named exactly after the command, section
  1, 8, 6, 7 then 5 (`man -w apk` answers apk-package(5)); a BusyBox applet
  gets BusyBox's page and says so; no page, the `--help` usage.
- **A phase 1 fix it found**: a page is in the `-doc` of the package's
  ORIGIN — `ssh` is `openssh-client-default`'s, its page `openssh-doc`;
  `lsblk` is `util-linux-misc`'s, its page `util-linux-doc`. install_manuals
  and the store now resolve origins (`apk query --fields origin`); 12 more
  pages on the full monty.
- **`docs/man/`**: 168 pages, mandoc's HTML in the site's type, a
  cross-reference a link when its page is here. 9.0 MB, 2.3 MB compressed
  as GitHub Pages serves it.

## VII. Risks

- **Stale options.** An option written from memory rather than checked.
  The review checklist's first item, and `check` reading the man page, are
  the guard.
- **Size of the page.** Three hundred entries at a screen each is a large
  HTML file; if it passes about 1.5 MB, split it into one page per section
  with the same anchors.
- **Man pages missing.** Some programs ship none (Copal's own, several
  from the store). Their SYNOPSIS comes from `--help`, and for Copal's
  tools from the usage text in their source.
- **Space on small cards**, if option (a) or (c) is chosen.

## VIII. State of the working tree, 23 Sep 2026

Uncommitted, ready for review:

- **Playbooks phase 5 (begun).** Endless Sky's unpinned stage 12 build is
  retired for the store recipe (the one real duplicate found; it made the
  store skip its pinned build), moved from the full monty's queue into the
  starter set, so medium keeps it and 32-bit ARM loses it (the recipe is
  64-bit only). `make sync-store`, `sync-apps` and `sync-gui` now write into
  the stage playbooks — written into `copal-prep.sh`, the next
  `sync-playbooks` put the old copy back. Counts corrected: thirteen, not
  sixteen, at first login; eighteen stages, not fifteen or sixteen, in the
  handbook and README, which gain *Playbooks* sections. Lint clean.
- **The live menus** on the home page (section V): `docs/menu-sim.*`,
  `docs/textmenu-sim.js`, `docs/menu-data.js`, `docs/img/menu/`,
  `tools/copal-menu-sim.py`. The Mint-style menu was checked in headless
  Firefox (sections, hover, search, launch); the keyboard menu is not
  yet screenshot-checked.

Stopped: the eight background agents that had begun drafting entries. One
partial draft is in the session's scratch directory, unreviewed and not
used; the guide's text is written here, in phase 4.

## Appendix: the inventory, 292 commands

Mode is shown where the command is an interactive terminal program (t) or
graphical (x); unmarked ones are command-line tools.

### Core: Alpine and the toolchain — 42

- `apk`, `doas`, `rc-service`, `rc-update`, `rc-status`, `openrc`, `lbu`, `setup-alpine`, `busybox`, `mkinitfs`, `sfdisk`, `resize2fs`, `zramctl`, `flatpak`, `git`, `gcc`, `clang`, `make`, `cmake`, `ninja`, `gdb`, `valgrind`, `nvim`, `tmux`, `ssh`, `ssh-keygen`, `rsync`, `curl`, `cargo`, `go`, `python3`, `pip`, `hyprctl`, `wpctl`, `pactl`, `bluetoothctl`, `iwctl`, `nmcli`, `dmesg`, `logread`, `lsblk`, `ip`

### Copal's own — 35

- `copal`, `copal-audio-start`, `copal-autologin`, `copal-bar`, `copal-build`, `copal-camera`, `copal-center`, `copal-clip`, `copal-code`, `copal-config`, `copal-debug`, `copal-desk`, `copal-desktop`, `copal-fonts`, `copal-gpu`, `copal-gui`, `copal-guide`, `copal-halt`, `copal-install`, `copal-launcher`, `copal-logs`, `copal-menu`, `copal-morse`, `copal-session`, `copal-shot`, `copal-splash`, `copal-ssh`, `copal-startx`, `copal-store`, `copal-terminal-theme`, `copal-theme`, `copal-times`, `copal-wallpaper`, `copal-widgets`, `copal-apps` (x)

### Catalogue (stage 12) — 183

- **Internet** (6): `links` (t), `elinks` (t), `w3m` (t), `lynx` (t), `retawq` (t), `lftp` (t)
- **Mail** (7): `alpine` (t), `mutt` (t), `aerc` (t), `mail`, `irssi` (t), `weechat` (t), `profanity` (t)
- **News** (4): `newsboat` (t), `newsraft` (t), `sfeed`, `ticker` (t)
- **Notes** (6): `vim` (t), `hunspell`, `aspell`, `mdbook`, `hugo`, `zola`
- **Documents** (3): `sc-im` (t), `pdftotext`, `qpdf`
- **Editors** (4): `micro` (t), `hx` (t), `vis` (t), `nano` (t)
- **Design** (2): `plantuml`, `dot`
- **Media** (3): `cmus` (t), `ncmpcpp` (t), `alsamixer` (t)
- **Audio** (3): `openmpt123`, `xmp`, `fluidsynth`
- **Graphics** (1): `tesseract`
- **Games** (18): `nethack` (t), `brogue` (t), `angband` (t), `zangband` (t), `adventure` (t), `robots` (t), `hangman` (t), `snake` (t), `klondike` (t), `atc` (t), `frotz`, `ttysolitaire` (t), `asciiquarium` (t), `cmatrix` (t), `cbonsai`, `fortune`, `figlet`, `sl`
- **Retro** (1): `mednafen`
- **Engineering** (3): `ngspice`, `admesh`, `solvespace-cli`
- **Science** (9): `pdflatex`, `octave` (t), `maxima` (t), `python3`, `python3`, `gnuplot`, `gp` (t), `Singular` (t), `R` (t)
- **Security** (11): `tshark`, `termshark` (t), `tcpdump`, `clamscan`, `lynis`, `nmap`, `suricata`, `fail2ban-client`, `ufw`, `john`, `aircrack-ng`
- **Sharing** (7): `syncthing`, `croc`, `darkhttpd`, `smbd`, `sshfs`, `rsync`, `unison`
- **Files** (3): `mc` (t), `nnn` (t), `ranger` (t)
- **Tools** (3): `tmux` (t), `scrot`, `x11vnc` (t)
- **System** (6): `htop` (t), `sha224sum`, `lazygit` (t), `gitui` (t), `tig` (t), `delta`
- **Discs** (12): `cdw` (t), `xorriso`, `cdrdao`, `cdparanoia`, `abcde`, `zip`, `7z`, `unarj`, `rpm`, `dpkg`, `bsdtar`, `mksquashfs`
- **Smallweb** (7): `bombadillo` (t), `amfora` (t), `clagrange` (t), `gmnlm` (t), `gmni`, `gemget`, `gmnisrv`
- **Languages** (27): `cargo`, `rust-analyzer`, `go`, `dlv`, `ghc`, `hlint`, `gfortran`, `retro` (t), `composer`, `clang`, `clangd`, `ocaml` (t), `zig`, `fpc`, `lua5.4` (t), `tcc`, `guile` (t), `csi` (t), `sbcl` (t), `racket` (t), `nim`, `elixir` (t), `ruby` (t), `perl`, `crystal`, `java`, `dotnet`
- **Devtools** (20): `gdb` (t), `cgdb` (t), `lldb` (t), `pwndbg`, `valgrind`, `strace`, `ltrace`, `cppcheck`, `shellcheck`, `shfmt`, `cmake`, `cl65`, `meson`, `ccache`, `bear`, `just`, `ctags`, `doxygen`, `lua-language-server`, `pylsp`
- **Terminals** (6): `screen` (t), `byobu` (t), `zellij` (t), `dvtm` (t), `abduco`, `dtach`
- **Radio** (6): `rtl_test`, `rtl_power_fftw`, `hackrf_info`, `dump1090`, `direwolf`, `rigctl`
- **Instruments** (2): `sigrok-cli`, `fftw-wisdom`
- **Learn** (1): `gtypist` (t)
- **Control** (2): `redshift`, `udiskie`

### Copal Store shelf — 32

- **Appearance** (2): `oh-my-posh`, `starship`
- **Browsers** (1): `browsh` (t)
- **Code** (8): `ascitty` (t), `birdshot`, `copal-tm` (t), `orrery` (t), `radbeeper` (t), `sstr`, `sstr-workspace` (t), `ytq` (t)
- **Crypto** (1): `xmrig`
- **Emulation** (2): `qemu-system-x86_64`, `waydroid`
- **Files** (3): `fdupes`, `jdupes`, `rdfind`
- **Games** (1): `moon-buggy` (t)
- **Internet** (1): `speedtest-cli`
- **Multimedia** (1): `pipe-viewer` (t)
- **Programming** (3): `arduino-cli`, `gh`, `node` (t)
- **System** (3): `btop` (t), `fastfetch`, `neofetch`
- **Terminals** (1): `pwsh` (t)
- **Tools** (3): `ollama`, `scrcpy`, `tldr`
- **Transfer** (2): `httrack`, `onionshare-cli`

