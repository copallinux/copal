# Playbooks: the Installer Cut Along Its Projects

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`.

---

## Why

`copal-prep.sh` is 34,347 lines: eighteen stages, 278 heredocs, and a
329-row catalogue with no descriptions. Everything works, and nothing can be
found. A program's install is spread across three places — its catalogue
row, a seed in stage 12, sometimes a fix-up in stage 4 or 17 — and the
automatic install shows a stage number and a scrolling log, not what is
being put on the machine.

The store already has the shape the rest should have. A recipe is one
program: its build prerequisites, its runtime ones, its build, its
first-run settings. This plan gives every graphical program that shape,
cuts the stages along their projects, and shows the install as what it is:
a sequence of programs arriving, each with two sentences saying what it is.

Decided on 23 Sep 2026:

1. **Authored split, shipped as one file.** The playbooks are separate files
   in the repository; `make` assembles them into `copal-prep.sh`, as
   `make sync-store` does today. `copal -U`, the card writer and
   `/boot/copal-init.sh` do not change.
2. **Every graphical program is a playbook** — the 146 catalogue rows in
   mode `x` and the store's. Terminal and command-line tools (183 rows) stay
   as catalogue lists installed in bulk.
3. **The progress window runs in the guest** once a display exists; the
   console keeps the text screen until then.

## Phase 1, done (23 Sep 2026)

What the plan below became in its first phase, where it differs:

- The store's 112 programs are 111 playbooks in `playbooks/<shelf>/`: 28
  built from source, 83 from apk (DXX's two programs share one). The
  directories are the store's shelves for now; aligning them with
  copal-gui's sections is phase 3's, when the catalogue joins.
- The header is the one in `tools/copal-playbooks.py`: `playbook`,
  `source`, `build`, `runs`, `needs`, then a block per program (`program`,
  `label`, `shelf`, `install`, `mode`, `gate`, `home`, `about`). The steps
  are `NAME_pre`, `NAME_install`, `NAME_post`; the store's old `_build`
  and `_seed` are those, renamed. Every name a body defines is its own.
- **The runner is `copal-store`**, not a new program: `install` runs the
  steps, batches the prerequisites and writes the events. Phase 2 renames
  it Copal Apps when the window arrives.
- Every event names its `program` (the id being installed) and its
  `playbook`. The automatic install writes a `stage` event at each stage's
  start and end into the same file.
- New verbs for the window to use: `copal-store playbook ID` (about,
  source, prerequisites, steps, status, last build), `events [N]`,
  `bundle [NAME]`. Stage 18 reads its sets from `playbooks/bundles/`.
- Every store program has two sentences now.
- Crosschecked before anything was built: the generated table identical to
  the old one (112 rows), every recipe's dependency lists identical (28),
  every recipe function and variable identical but for the renames (67).
  Then built on the bench: Celeste Classic, Pac-Man, PyChess (its `post`
  step) and OpenTyrian, each launched.

## I. A playbook

One file per project, `playbooks/<category>/<project>.sh`, named after the
project and nothing else. Its header is data; its body is up to five shell
functions, each optional, named after the project:

```sh
# name:     darktable
# label:    darktable (raw photo developer)
# category: Graphics
# source:   github darktable-org/darktable release-5.6.1   # or: apk darktable | clone vonglurt/radbeeper
# gate:     64
# about:    A darkroom for camera raw files: exposure, colour, lens correction
#           and masks, edited without touching the original. A lighttable
#           sorts and rates the shoot.
# needs:    lensfun exiftool                              # other playbooks, run first

darktable_pre()     { ... }   # prerequisites and preconfiguration: apk build deps, users, groups, paths
darktable_install() { ... }   # apk add, or fetch-verify-build-stage, or clone into ~/code
darktable_post()    { ... }   # postconfiguration: seeds, menu entry, services, the check that it runs
darktable_remove()  { ... }   # optional: what post did, undone
darktable_check()   { ... }   # optional: is it installed and whole? (default: its command resolves)
```

`about` is two short sentences: what it is, then what makes it worth
having. It is what the slideshow shows and what Copal Apps lists.

**Source policy**, as the store already practises it: `apk` when Alpine's
package is current and stable; `github` (a pinned release, SHA-256 checked,
built in the store's kit) when the program is newer upstream or not
packaged; `clone` for projects that live in `~/code` and are worked on
there. A playbook names one, and may name a fallback.

**Grouping.** Categories are the directories (Graphics, Games, Office,
Audio, Internet, Development, System, …, matching copal-gui's sections so the
menu and the manager agree). A **bundle** is a named list of playbooks: the
eighteen stages become bundles — `desktop-x`, `desktop-hyprland`, `dev`,
`workshop`, `store-full` — and a level (server, medium, full) is a list of
bundles, as today it is a list of stages.

Stages that are not programs — partitioning, moving root, zram, ssh keys,
locking root, the fleet — stay as they are, as system playbooks with the
same five functions, so the runner and the progress window treat them alike.

## II. The runner

`copal-run BUNDLE|PLAYBOOK...` resolves `needs:` into an order, then for
each playbook runs `pre`, `install`, `post`, stopping that playbook (not
the run) at the first failure. Across a bundle, `pre` steps' apk
prerequisites are collected and installed once before the first `install`,
as `copal-store install` does now with `.copal-store-build-batch`.

Every step reports through the existing `say` / `note` / `warn`, which also
append one line per event to `/var/log/copal/events` — JSON, one object per
line:

    {"t":1790212000,"bundle":"store-full","playbook":"darktable","step":"install","n":4,"of":16,"state":"start"}
    {"t":1790212260,"playbook":"darktable","step":"install","state":"ok","secs":260}

The store's `summary.txt` becomes one view of that file; the stage log
(`/boot/copal.log`) keeps its transcript.

## III. What shows it

Two front ends read the same event file, so neither drives anything:

- **The console**: today's text screen (`tui_*`), its bar now per playbook.
- **The window**, `copal-apps --progress`, GTK like copal-gui, once X or
  Hyprland is up: three nested bars (the level, the bundle, the playbook's
  steps) under a slide for the program being installed — its name, its
  gallery picture, its two sentences, its source. It is a slideshow of what
  is arriving, and afterwards the list of what arrived and what did not.

**Copal Apps** (the store, renamed and widened) is the same window without a
run in progress: every graphical playbook with its status (installed,
available, not for this board), its source, its two sentences, and Install
and Remove, which run the playbook.

## IV. Assembly

`playbooks/` is assembled into `copal-prep.sh` by `make sync-playbooks`,
between markers, the way sync-store and sync-gui work; `make lint` fails if
the assembled copy has drifted, and checks every playbook has its header,
two sentences, a known category and source, and resolvable `needs:`.

## V. Phases

Each phase is crosschecked against the install as it is before anything is
replaced, and ends with the bench build and `tools/copal-menu-audit.py`.

1. **Format and runner.** The playbook format, `copal-run`, the event file,
   `make sync-playbooks` and its lint. The store's recipes become playbooks
   (they nearly are); `copal-store` becomes a front end to the runner. Check:
   every recipe builds on the bench exactly as before.
2. **The window.** `copal-apps --progress` and the Copal Apps list, reading
   events. Check: a full store-set run shows each program's slide and nested
   bars, and the text screen still works on a console.
3. **The graphical catalogue.** The 146 `x` rows become playbooks with two
   sentences each; stage 12's seeds and stage 4/17 fix-ups move into their
   `post`. Check: stage 12 installs the same package set; the menu audit is
   unchanged.
4. **The stages as bundles.** Desktop, dev, workshop, emulators, extras;
   `~/code` projects (radbeeper, urfinkel, gonex, yodacon…) as `clone`
   playbooks. Check: a full-monty VM built from the assembled script matches
   today's (package list, `/usr/local` file list, menu audit).
5. **Retire the duplicates**, update the handbook and README.

## VI. Risks

- **Size.** The assembled `copal-prep.sh` must not grow much; playbooks
  replace code rather than wrap it.
- **Order.** Stages have implicit order today (stage 4 before 12, 17 after
  4). `needs:` makes it explicit; phase 4's check is what proves it.
- **Resume.** The automatic install resumes across the stage 3 reboot by
  stage; it must resume by playbook, from the event file.
- **Root.** Nothing in the store has yet run as root on a real install; the
  first full-monty VM after phase 1 is that test.
