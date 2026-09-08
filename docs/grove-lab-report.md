# One Console for a Room of Machines: What Timbuktu, Veyon and Xen Orchestra Each Got Right, and the Interface a Copal Grove Should Have

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

Companion document: **[`grove-plan.md`](grove-plan.md)** — the architecture,
the security invariants and the build order. This report is the survey and the
interface.

---

## Abstract

A museum wants eight Raspberry Pis switched on each morning, given a different
task each day, watched during opening hours, reset between visitors, and
switched off at night — from one console, by one person, without a login on
each machine. Four families of existing software each solve part of that and
none solves all of it: remote-control products in the Timbuktu lineage own the
*session* (control, observe, file exchange, chat, remote install); classroom
managers in the Veyon and Epoptes lineage own the *room* (a wall of
thumbnails, lock, broadcast, power); imaging systems in the FOG lineage own the
*fleet's software state*; and virtualisation consoles in the Xen Orchestra
lineage own the *object model* (a pool, a tree, a host dashboard, filter and
bulk action). This report reads all four against the museum requirement, states
what each contributes and what each would cost to adopt whole, and designs the
Copal Grove console from the parts that survive. The central finding is a
division that none of the four makes cleanly and that the museum case makes
unavoidable: **a fleet console has two audiences with opposite needs — the
operator who must see every machine at once and act on all of them, and the
technician who must be inside exactly one machine — and an interface that
optimises for either one alone becomes unusable for the other.** The design
answer is a single object model with two views over it, the wall and the seat,
with one keystroke between them and no mode the operator can be stranded in.
Two further findings are recorded: a Raspberry Pi cannot be woken by
Wake-on-LAN, which invalidates the obvious morning automation and is stated
here so it is discovered in a document rather than in a gallery; and a fleet
interface must show machines it does *not* manage, because the question "what
appeared on my network today" is asked by the same person at the same screen.

## I. Objective

1. Establish what the museum day actually requires, in operations rather than
   in features.
2. Survey the prior art the brief names — Timbuktu, XCP-ng/Xen Orchestra — and
   the open-source work in the same shape that the brief did not name, and
   record what each contributes.
3. Design the console: its object model, its two views, its verbs, its
   notification behaviour, and the morning walkthrough end to end.
4. Record the constraints that kill obvious designs, before they are built.

## II. Materials

| Item | Value |
|---|---|
| Target fleet | 8 × Raspberry Pi, Zero 2 W / Pi 3 class, 512 MB–1 GB, one unmanaged switch, wired where possible |
| Node software | Copal Linux — Alpine 3.24, OpenRC, i3 on X11 or Hyprland on Wayland, stage 1–15 installed |
| Present today | `gnuradio`, `rtl-sdr`, `rtl_power_fftw`, `gqrx`, `x11vnc`, `grim`, `hyprctl`, stage-11 rsync snapshots, stage-10 Geiger counter and spectrum |
| Absent today | `avahi`, `nats-server`, `ansible`, `wayvnc`, `uhubctl` |
| Bench | VMs under UTM on Apple Silicon — aarch64 and x86_64 — standing in for boards, as in `integration-lab-report.md` |
| Storage | a FreeNAS/TrueNAS ZFS host on the same segment, NFS and iSCSI both available |
| Operator | one person, not a systems administrator, at 08:30, with a gallery opening at 10:00 |

The last row is the specification. Everything in section V is downstream of it.

## III. Background — prior art

### A. Timbuktu (1988–2013) — the session

Timbuktu is the ancestor the brief names, and its vocabulary is worth taking
almost intact because it was arrived at over twenty-five years of people using
it. Its operations, in the terms the product used:

| Timbuktu | What it is |
|---|---|
| **New Connection** | pick a target by IP, by hostname, or by Bonjour discovery on the local network |
| **Control** | drive the remote machine — your mouse, your keyboard, its screen |
| **Observe** | watch without touching; the monitoring and training mode |
| **Exchange** | a two-pane browser between local and remote disks |
| **Send** | push specific files to a destination folder, without browsing |
| **Chat / Intercom** | text and voice to whoever is sitting there |
| **Install** | deploy or upgrade Timbuktu itself onto a target, over SSH |
| **Connection documents** | a saved, reopenable, shareable definition of a host |
| **Notify** | tell me when that machine becomes active |

Four of those are load-bearing for the museum and are adopted in section V
under their own names.

**Control and Observe as separate verbs** is the first. Modern remote-desktop
tools default to control and offer view-only as a checkbox. Timbuktu made them
two things you choose between at connection time, and for a room of machines
that is the correct emphasis: the operator's normal state is *observing eight*,
and *controlling one* is the exception that should require a decision.

**Discovery as a peer of the address field** is the second — Bonjour listed
beside "type an IP" rather than hidden in a scan dialog. That is precisely the
relationship §4 of the plan gives mDNS: an accelerator for the address field,
never an authority.

**Connection documents** is the third, and it is the most underrated. A saved
file that *is* the host, that can be put on a desktop, mailed to a colleague and
double-clicked, is a better abstraction than a row in an application's private
database. The grove file in the plan is a connection document for eight
machines, and putting it in git is the natural extension.

**Install-over-SSH** is the fourth, and it is quietly the whole configuration
management story in embryo: the console can put itself onto a machine that does
not have it yet, provided the machine already has SSH. Copal's stage 16 is that
idea with a certificate authority behind it.

What does *not* carry over: the transport (UDP then TCP on port 407, with SSH
tunnelling bolted on later — a grove is certificate-authenticated from the
first packet), the user-database integration (OpenDirectory, Active Directory —
a grove has one CA and no directory), and the assumption of one operator to one
target. The brief states no compatibility is required, and none is attempted.

### B. Veyon, Epoptes — the room

Veyon is the closest living open-source relative of what the museum needs, and
it is the direct answer to "is there something that already does this":

- **Monitoring mode** — every computer as a live thumbnail, updated near
  real-time. This is the wall, and Veyon shipped it.
- **Demonstration mode** — one screen broadcast to all the others.
- **Lock** — input devices disabled, a blocking image shown.
- **Remote view / remote control** — Observe and Control, again.
- **Power on, restart, shut down** — administrative preparation and follow-up
  of a session, which is the museum's morning and evening in the product's own
  words.
- Cross-platform, GPL, and **the Ubuntu packages run on ARM boards including
  Raspberry Pi**.

Epoptes is the lighter, Linux-only equivalent — screen broadcast, monitoring,
remote command execution, message sending, screen lock, sound muting, and
grouping of clients for targeted action.

Both were evaluated for adoption whole. Both were declined, for one reason and
one only: **they are Debian/Ubuntu software with a Qt or GTK client and a
per-node daemon, and Copal is Alpine with musl.** Veyon on Alpine is a build
project, not an `apk add`, and the museum's console would then be a Veyon
window sitting beside a Copal window with two different node lists, two
different notions of identity, and no shared idea of what a scene is.

What is taken instead is the *interaction design*, which is free, plus a
specific engineering observation: **Copal can already produce the wall.** The
app-probe work in `integration-lab-report.md` left behind `grim` for screenshots
and `hyprctl` for window state on every guest. A thumbnail stream is a
screenshot, a downscale and a publish — no new daemon, no new protocol, and
`x11vnc` or `wayvnc` is needed only for the one node being controlled, not for
the seven being watched. That asymmetry is the single biggest saving in the
design and it comes directly from reading Veyon's monitoring mode and asking
what it costs.

### C. FOG Project — the fleet's software state

FOG turns a spare server into a network imaging and deployment engine: capture,
deploy, task scheduling, inventory, remote package installation, disk wipe,
memory test. It is the right tool for "make fifty identical Windows machines"
and it is the wrong shape here for a reason that is interesting rather than
incidental.

FOG's unit of change is **the disk image**. A grove's is **the scene** — and
below that, the stage-11 rsync snapshot, which restores a user's home in seconds
where an image restores a machine in minutes. "Quit all programs and get ready
for the next user" happens between visitors, possibly every fifteen minutes,
and the imaging model is two orders of magnitude too heavy for it. FOG is
recorded here as the correct answer to a question the museum is not asking:
rebuilding a node from nothing, which in a grove is done by writing a card.

### D. Xen Orchestra and XCP-ng — the object model

XO is not remote control at all, and that is why it is the most useful of the
four. It is the reference implementation of *managing many machines as
objects*, and the museum's console is an object browser far more than it is a
screen-sharing tool.

What XO does that is worth copying exactly:

1. **The pool as the first-class object.** XO opens one connection to a pool
   master and manages every host through it. The grove's warden is a
   deliberately weakened version of this — §7 of the plan — and the weakening is
   the point: XO *must* reach the pool coordinator, whereas a grove console
   falls back to talking to nodes directly. Adopting XO's model without adopting
   its single point of dependency is the main architectural borrowing in this
   design.
2. **The type selector.** A header that switches the whole view between VMs,
   hosts and pools. The grove's equivalent is **Nodes · Jobs · Scenes · Logs**,
   and having it be a selector rather than a navigation tree is what keeps the
   window from growing a sidebar of sidebars.
3. **Assisted filters, and the count.** A list header showing "6 of 8" with
   filters by pool, host and tag. In a grove this is the mechanism for every
   bulk operation: filter to a set, see how many you have, act on the set. "Quit
   all programs" is not a special command — it is `reset` applied to a
   selection, and the selection is visible before it is acted on.
4. **The host dashboard.** Version, hardware model, sockets and RAM, whether it
   is the primary, alarms, missing patches. The grove's node dashboard is that
   list with the Pi's words substituted: `COPAL_BUILD_ID`, Alpine version, arch,
   RAM and zram, SoC temperature, the firmware throttle flags, card wear, uptime,
   last beacon, whether it is warden, pending `apk` upgrades.
5. **A live console on the object itself**, full-screen, openable in its own
   tab. The grove's is the SSH session and the VNC session, and "openable in its
   own window" is not a small detail — it is what lets an operator leave a
   machine open while going back to the wall.

XO 6's addition of a tree view and dashboards is the confirmation that the type
selector alone stops scaling; a grove of eight does not need the tree yet, and
the design leaves room for it rather than building it.

### E. BOINC — the work model, and the display

BOINC is the survey's fifth entry and it is here for two things.

The first is **the superhost pattern**: a site running many machines promotes
one host to superhost, all others talk only to it, and only it needs internet
access. That is the grove's warden and the grove's egress node arrived at
independently by a project with twenty years of deployment behind it, which is
reassuring.

The second is the *screen saver*, which is the most successful piece of
scientific-computing interface design ever shipped: a machine doing invisible
arithmetic made visible, with a progress bar, a work unit name, and something
moving. The museum exhibit in §10 of the plan is that idea with the arithmetic
chosen so that the picture *is* the progress bar — a path-traced image
assembling itself tile by tile, each tile tinted by the node that produced it.
BOINC had to invent a visualisation for work that had none. A raytracer does not.

### F. What none of them do

No surveyed system has a **scene**: a named, declarative, idempotent state of
the whole room that changes what runs, what is displayed and what the console
shows, in one press. Veyon has modes but they are transient and operator-held;
Ansible has plays but no notion of what is on screen; XO has no opinion about a
session at all. The museum requirement — *each day the task will be different* —
is a scene requirement, and it is the one part of the design with no prior art
to copy. It is therefore the part most likely to be wrong, and §IV-D builds it
smallest.

## IV. Method — the console's design

### A. The object model, first

Everything the console shows is one of six things. Keeping this list short is
what keeps the interface small.

```
grove ── node ── session      (a login, a display, what is on screen)
      │       └─ attachment   (a mount, an endpoint, present or not)
      ├─ scene                (a declared state; applied or not)
      ├─ job  ── gem          (work; queued, running, done, redelivered)
      └─ stranger             (seen, not managed, never contacted)
```

A node is not "a connection". This is the first departure from Timbuktu and the
one that everything else depends on. In Timbuktu a machine exists in the
interface because you opened a document for it; in a grove a node exists because
it announced itself and its certificate checked out, and the connection is a
thing you may or may not currently have to it. The console is therefore a
*monitor* that can open connections, rather than a *connection manager* that
happens to show status — and at eight machines that difference is the whole
experience.

### B. Two views, one keystroke apart

**The wall** — the operator's home. Every node as a live thumbnail with a status
chip. This is Veyon's monitoring mode with XO's filter header on top of it.

```
┌─ COPAL GROVE · museum ─────────────────────── 8 of 8 ·  ⌂ wall ─┐
│ scene: show · since 09:58        tags: [all] [wall] [sdr] [north]│
├─────────────────┬─────────────────┬─────────────────┬───────────┤
│ museum-01  ●    │ museum-02  ●    │ museum-03  ●    │ museum-04 ●│
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │ ┌────────┐ │
│ │ raytrace    │ │ │ raytrace    │ │ │  waterfall  │ │ │raytrace│ │
│ │ ▓▓▓▓▓▓░░░░  │ │ │ ▓▓▓▓▓▓▓░░░  │ │ │ ▂▃▅▇▅▃▂▁▂▃  │ │ │▓▓▓░░░░ │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │ └────────┘ │
│ 47°C  gem 118   │ 44°C  gem 121   │ 51°C  SDR src   │ 46°C  g 96 │
├─────────────────┼─────────────────┼─────────────────┼───────────┤
│ museum-05  ●    │ museum-06  ◐    │ museum-07  ○    │ museum-08 ●│
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │ ┌────────┐ │
│ │ raytrace    │ │ │  starting…  │ │ │             │ │ │raytrace│ │
│ │ ▓▓▓▓▓░░░░░  │ │ │             │ │ │   offline   │ │ │▓▓▓▓▓░░ │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │ └────────┘ │
│ 45°C  gem 103   │ warden · 12s    │ last seen 08:12 │ 48°C  g 88 │
├─────────────────┴─────────────────┴─────────────────┴───────────┤
│ ! one stranger on this network: 10.0.0.44 (epson-XY10)          │
│ [c]ontrol  [o]bserve  [e]xchange  [s]end  [n]otify  [S]cene ▸   │
└──────────────────────────────────────────────────────────────────┘
```

**The seat** — one node, full size. Timbuktu's Control window with XO's host
dashboard folded into a side panel, so that being inside a machine does not mean
losing what the console knows about it.

```
┌─ museum-03 ── Control ───────────────────────────── ⌂ back to wall ─┐
│                                          │ ● up 6d 04h · warden: no │
│                                          │ build   2026-09-04.3      │
│                                          │ alpine  3.24.1 aarch64    │
│         (the node's screen)              │ ram     1024 MB · zram 42%│
│                                          │ temp    51°C · no throttle│
│                                          │ card    12% used · ok     │
│                                          │ cert    valid 87d         │
│                                          │ mounts  treasure ✓  media ✗│
│                                          │ scene   show (applied)    │
│                                          │ job     sdr-source        │
│                                          │ apk     3 upgrades pending│
├──────────────────────────────────────────┴───────────────────────────┤
│ Observe ⇄ Control   ·   Exchange   ·   Send…   ·   Message…   ·  Log │
└──────────────────────────────────────────────────────────────────────┘
```

`Esc` is always the way back to the wall, from anywhere, and it never asks. The
one rule the interface must not break is that **the operator cannot get stuck
inside a machine**.

### C. The verbs

Timbuktu's, adopted by name where the meaning is unchanged, and extended where
the fleet needs it. Each has a keystroke, each works on the current selection —
one node or forty — and each names its scope in the confirmation.

| Verb | On one node | On a selection |
|---|---|---|
| **Observe** `o` | view-only session | the wall *is* observe-many; enlarge a subset |
| **Control** `c` | full input | refused, deliberately — see below |
| **Exchange** `e` | two-pane SFTP browser | refused |
| **Send** `s` | push a file to a folder | push to all — the exhibit's assets, at once |
| **Message** `m` | banner on the node's screen | banner on all; the museum's "please stand back" |
| **Run** `r` | one verb through `copal-grove-exec` | fan-out with a per-node result column |
| **Scene** `S` | — | apply a scene; the only way to change what the room is doing |
| **Snapshot** `k` | restore the home from stage 11 | the reset, per selection |
| **Power** `p` | off / reboot / on, if capable | the end of the day |
| **Notify** `n` | tell me when this becomes active | tell me when *all eight* are up — the morning |

**Control on a multi-selection is refused and this is a design decision, not a
missing feature.** Broadcasting keystrokes to eight machines is Veyon's
demonstration mode inverted, it produces divergent state that nobody can see,
and the operation the operator actually wants — "make them all do the same
thing" — is `Scene` or `Run`, both of which are declarative and both of which
report per-node results. An interface that offers control-all offers a way to
put the room into eight different broken states with one gesture.

**Notify on the whole grove is the morning's real primitive.** "Tell me when all
eight are up" is what the operator wants at 08:31, and it is the difference
between watching a screen for ten minutes and doing something else until it
chimes.

### D. Scenes, built smallest

Because §III-F found no prior art, the scene system is built as thin as it can
be and no thinner:

- A scene is a YAML file in the grove's git checkout. Five ship: `wake`, `show`,
  `reset`, `rest`, `sleep`.
- Applying a scene publishes one command and runs one Ansible play. Both paths
  exist because both fail differently — the bus is fast and lossy, the play is
  slow and reports.
- The console shows a scene as **applied / partially applied / stale**, per
  node, and never as a global boolean. A room where six machines got the memo is
  the normal case and the interface must be able to say so.
- "Today's task is different" is one line of one file: `show.yml` names the job.
  The operator edits it, or picks from a list the console populates from
  `scenes/jobs/`.

### E. Notifications and the log collector

Three severities, and they are distinguished by *what the operator must do*
rather than by how bad they sound:

| | Means | Where it goes |
|---|---|---|
| **toast** | something changed; nothing to do | corner of the wall, 5 s, then the event log |
| **chip** | a node needs attention and the wall can show which | the node's tile turns amber and stays |
| **alarm** | the room is not in the state the scene says | a bar across the top that does not go away until acknowledged or fixed |

The log collector is the warden subscribing to `grove.museum.log.>` and writing
per-node dated files — the same shape stage 10 already uses for the Geiger
counter's per-counter logs, which is a pattern this repository has already
tested. The console's log view is `tail -f` over the grove with a node filter
and a text filter, and its single most important property is that **it keeps the
logs of a node that has gone away**. The failure the museum will actually hit is
a Pi that dies at 11:00 and is asked about at 16:00, and a log collector that
only shows live machines answers the wrong question.

## V. Results — the morning, end to end

The design above, walked through as the operator experiences it. This is the
acceptance test for the whole plan.

**08:30 — arrival.** The operator opens the console. Six tiles are grey: the
nodes are in `rest`, screens dark, machines up. Two are dark grey — 06 and 07
were powered off. The header says `scene: rest · since 17:34 yesterday`.

**08:31 — one press.** `S` → `wake`. The console publishes the scene and starts
the play. For nodes that are up this is instant. For 06 and 07 the console shows
what it can actually do: 06 is on a switched USB port and the console cuts and
restores it; 07 is on a plain supply and the tile says **"needs a human — the
plug by the north door"**, because a Pi cannot be woken by Wake-on-LAN and
pretending otherwise would have the operator staring at a spinner. The
distinction was in the plan (§9.1) and it surfaces here as one sentence on one
tile.

**08:33 — the checklist.** The wall becomes a checklist while `wake` runs: beacon
in, certificate valid, attachments mounted, display up, job started. Each node's
tile fills left to right. The NAS is slow this morning and three tiles sit on
`mounting treasure…` for twenty seconds; because the mount is `soft` and
`require = false`, nothing hangs, and had it failed the tiles would say
`treasure ✗` and the room would still open.

**08:41 — the chime.** All eight are green. `Notify: all up` fires. The operator
has been making coffee.

**08:42 — today's task.** Yesterday was the raytracer. Today is the radio. The
operator presses `S`, picks `show`, and the job list offers `smallpt`,
`sdr-waterfall`, `decay-seeded-render`. Picking `sdr-waterfall` edits one line
of `show.yml`, commits it, and applies. Node 03 has the dongle — it is tagged
`sdr` and the scene assigns the source role by tag, not by hostname, so the
dongle can move to another board tomorrow and nothing else changes.

**09:58 — open.** The wall is eight thumbnails, one of them a waterfall and
seven of them contributing FFT bands to it. A visitor asks what happens if you
unplug one. The operator unplugs one. The waterfall keeps going; the tile goes
grey; ZMQ PUSH re-balances across the remaining pullers; the exhibit's own
display shows the worker count drop from 7 to 6. This is the demonstration, and
it required no special mode.

**11:15 — a technician moment.** Node 05's audio is wrong. The operator selects
its tile, presses `c`, is inside the machine with the dashboard beside them,
fixes it, presses `Esc`, and is back at the wall. No window was lost and no
other machine was touched.

**12:00 — between visitors.** `k` on the whole selection: stage-11 snapshot
restore, session restart. Eleven seconds. The room is clean.

**17:30 — closing.** `S` → `sleep`. Logs flush to the warden, then to the NAS.
Nodes go grey one at a time and the console holds a red bar for any that did
not confirm — because "I told eight machines to shut down" and "eight machines
shut down" are different claims and the console must only ever make the second
one when it is true.

## VI. Discussion

### A. The two audiences, and why the wall and the seat are both required

The finding stated in the abstract is worth expanding because it explains every
interface decision above. Remote-control software is built for a person who
wants to be *inside one machine*; fleet software is built for a person who wants
to *never be inside any machine*. The museum operator is the same person in both
roles, minutes apart, and the transition between them happens under time
pressure with visitors present.

Timbuktu optimised for the seat and grew a fleet story late and awkwardly —
connection documents in a list. Veyon optimised for the wall and its remote
control is a window that opens over the top of it. XO optimised for the object
model and has no seat at all in the interactive sense; its console is a terminal
in a tab. The Copal console's commitment is that **the wall is home, the seat is
one keystroke away, and `Esc` always returns** — and that commitment is what
forces the object model in §IV-A, because a node has to keep existing while you
are not connected to it.

### B. Discovery is a user-interface feature that is also a security boundary

The plan's invariant 1 — *discovery announces, it never authorizes* — was
written for security reasons, and it turns out to pay for itself in the
interface. Because a discovered machine is only a candidate, the console has a
natural place to put things that are not nodes: the stranger row. An operator
who can see that a printer, a phone and an unknown laptop are on the gallery
network has been given something genuinely useful in exchange for a design
constraint. Systems that conflate "found" with "trusted" cannot show this,
because in them a found machine is either managed or invisible.

The mDNS literature is blunt: there is no authentication of any kind, any device
can answer any query, and Avahi's own transaction-ID handling has been a spoofing
CVE. Every one of those facts is survivable here for one reason — nothing in the
grove believes a beacon. The beacon fills a list. A certificate decides.

### C. The tempting designs that were rejected, and why

**Wake-on-LAN at 08:30.** Rejected because it is impossible on the hardware. The
value of writing it down is that a museum will otherwise buy a managed switch
expecting it to help.

**Kubernetes as the substrate.** k3s runs on a Pi and would give a scheduler for
free. It was rejected in the plan (§11) on the grounds that the objects the
museum manipulates — a screen, a session, a visitor, a day — are objects
Kubernetes has no words for, and translating them into Deployments loses the
operator. A batch queue is the smaller half of the problem.

**Full remote desktop for the wall.** Eight VNC sessions at full frame rate on
512 MB boards that are also computing would be a wall that costs more than the
exhibit. The asymmetry in §III-B — screenshots for the seven, VNC for the one —
is the design that fits the hardware, and it was found by asking what Veyon's
monitoring mode costs rather than by admiring what it does.

**A central database of nodes.** Rejected in favour of the beacon plus the
certificate, because a database is a thing that goes stale and a beacon cannot.
The grove file holds intent — names, tags, attachments — and the network holds
fact. Keeping those apart is what makes "6 of 8" a truthful header.

**Voice intercom.** Timbuktu had it and it is charming. In a gallery it is a
speaker that startles visitors. Deferred, not declined.

### D. What this design owes to each source

| Source | Taken |
|---|---|
| Timbuktu | Control/Observe as separate verbs · Exchange and Send as separate verbs · discovery beside the address field · connection documents (→ the grove file) · install-over-SSH (→ stage 16) · notify-on-active (→ notify-all-up) |
| Veyon | the wall of live thumbnails · lock and broadcast · power operations framed as session preparation and follow-up · the finding that ARM boards can host it, and the measurement of what it would cost |
| Epoptes | grouping clients for targeted action (→ tags) · remote command execution as a first-class operation |
| FOG | the counter-example that fixed the reset mechanism at snapshots rather than images |
| Xen Orchestra | the pool object · the type selector · assisted filters and the visible count before a bulk action · the host dashboard's field list · a live console openable in its own window |
| BOINC | the superhost pattern (→ warden, egress node) · the screensaver's lesson that invisible work must be made visible |

### E. Limitations of this report

No measurement was taken. Every quantity in section V — twenty seconds to
mount, eleven seconds to reset, 1 Hz thumbnails — is an estimate from the
hardware's known behaviour and from this repository's earlier reports, not an
observation. Three of them are load-bearing and must be measured on a Zero 2
before M4 of the build order is committed to:

1. the CPU cost of a downscaled screenshot at 1 Hz on a node that is also
   rendering, which decides whether the wall is live or polled;
2. the wall-clock time of a stage-11 snapshot restore of a real user home,
   which decides whether `reset` is a between-visitors operation or an
   end-of-day one;
3. `nats-server`'s resident memory on the warden with eight publishers and a
   JetStream work queue, which decides whether the warden can also be a
   worker.

## VII. Conclusion

The museum's requirement is not a remote-control problem and it is not a cluster
problem; it is an *object model* problem wearing both costumes. Once a node is
a persistent object that announces itself, proves itself with a certificate, and
carries a scene, a job and a session, the two interfaces the operator needs fall
out of it: a wall that shows all the objects, and a seat inside one of them.
Timbuktu supplies the verbs, Veyon supplies the wall, Xen Orchestra supplies the
object model and the bulk-action discipline, BOINC supplies the warden and the
lesson about making work visible, and the scene — the one piece with no prior
art — supplies the answer to *each day the task will be different*.

Three things should be built before anything else, and none of them is the
console: the beacon, the certificate authority, and one fanned-out verb. With
those, `copal grove run power off` ends the day, which is the operation the
museum performs most reliably and enjoys least. The wall can wait; it is the
part everyone will want to build first and the part that is worth nothing
without the three below it.

## Appendix A — Degradation, performed

**W10 of milestone 4.** Invariant 8 says the console works with every layer
above the first removed. This is the checklist, each line performed and dated,
and it is reproducible rather than a claim: `tools/copal-degrade-test.py`, or
`make degrade-test`.

Run **2026-09-08** on a workstation, against a fixture grove of eight, a real
`nats-server` 2.14.0 and the real `copal-grove-agent`. **18 passed, 1 failed,
1 not performed.** A layer that has become load-bearing is a bug, and this item
exists to find it. It found one.

### 1. Bus down — the console falls back, and says so · **PASS** · 2026-09-08

| | |
|---|---|
| ✓ | `copal grove state --json` still answers, and still returns JSON |
| ✓ | the document says the bus is unreachable, and why |
| ✓ | all seven announced nodes are still listed — the list does not shrink |
| ✓ | **no node is called live.** They are `announced`, which is all a beacon can prove |
| ✓ | **no agent is called silent.** With no bus that is unknowable, and guessing would send somebody to a machine that is fine |
| ✓ | the wall draws, and its header says the bus is off |
| ✓ | the header says the picture is **polled rather than live** |

The last line failed on the first run and was fixed. The header said
`bus off: timed out`, which reports a missing component but does not tell an
operator that the tiles in front of them are four-minute-old beacons rather
than agents. It now reads `bus off — polled, not live (timed out)`. A fallback
that is labelled but not explained is still a quiet fallback.

### 2. Warden unplugged — the next-highest score takes the role · **FAIL** · 2026-09-08

| | |
|---|---|
| ✓ | the console follows a warden that has moved, without a restart |
| ✗ | **a node never changes its role** |
| – | the twenty-second failover, timed on hardware — not performed |

**This is the finding.** `role_now()` on a node returns the `role` field that
was written to its card. Nothing computes an election. `score()` exists, is
correct, and is published in every beacon — and nothing reads it to decide
anything. The console uses it only to break ties between machines that already
*claim* to be the warden.

So §7's description — "every node computes this, publishes it, and the highest
score that is currently announcing takes the role" — is not implemented. Pull
the warden's plug and the grove has no warden until somebody rewrites a card.

It is worth being precise about what does and does not break, because it is
less than it sounds: **the bus is a convenience and every verb over ssh is
unaffected.** `ls`, `enrol`, `run`, `scene`, `power` and `logs` on the surviving
nodes keep working. What is lost is the wall going live, telemetry, and the log
sink — until a warden is named by hand.

W1's checklist said "the election already computes the role (`role_now`,
`score`) — W1 makes the role *do* something for the first time." The first
half of that sentence was untrue when it was written, and building on it is how
this went unnoticed through W1, W3 and W7.

### 3. Avahi off — addresses from a written list · **PASS** · 2026-09-08

| | |
|---|---|
| ✓ | the written list is read when there is nothing to browse with |
| ✓ | the console works from it, with identity untouched |
| ✓ | the nodes absent from the list are reported **missing, not forgotten** |
| ✓ | the backlog names the file the static path actually reads |

Performed with a `PATH` carrying every command except avahi's, rather than with
an empty `PATH` — emptying it proves only that a shell without `sh` cannot run,
which is not the question.

The last line also failed first. The backlog said addresses come from the grove
file's `nodes` key; that key is a list of **ids** for `copal grove wait` and
carries no addresses at all. The mechanism was right and the sentence was not,
and a checklist naming the wrong file is one somebody follows into a wall at
nine in the morning. The document is corrected and the suite now checks it.

### 4. Console killed mid-command — a re-run is safe · **PASS** · 2026-09-08

Performed against a real `nats-server` and the real `copal-grove-agent`, driven
by the real client. **This is also W3's acceptance test, which had not been
made until now.**

| | |
|---|---|
| ✓ | the agent connected to a real bus and said hello |
| ✓ | a redelivered command — same `once` — ran **exactly once** |
| ✓ | still exactly once **after the agent was restarted**, which is what proves the seen-list is on disk and not in memory |
| ✓ | a command that expired while the node was off **did not fire** |
| ✓ | a fresh command still ran — the node is idempotent, not deaf |
| ✓ | every command went through `copal-grove-exec`, as a verb |

The last line is the one that matters for the security boundary: a command
arriving over NATS is executed by the same forced command sshd uses, so a verb
that is not allowed over ssh cannot become allowed by arriving over the bus.

### What this appendix is not

It is one machine. The two lines that need two machines and a power switch —
the timed failover, and a node powered off at 11:00 read back at 16:00 — are
marked *not performed* rather than reworded into something a workstation can
do. **None of milestone 4 has run on a Raspberry Pi.**


## References

Surveyed 2026-09-08.

1. Timbuktu — product history and operation set, Wikipedia and Arris
   discontinued-products documentation; usage summary supplied with the brief.
2. Veyon — <https://veyon.io/en/> · source <https://github.com/veyon/veyon> ·
   review <https://www.linuxlinks.com/veyon-computer-monitoring-classroom-management/>
   · Raspberry Pi client notes
   <https://www.moreware.org/wp/blog/2023/07/14/veyon-monitoraggio-studenti-con-client-raspberry/>
3. Epoptes — <https://epoptes.org/> · Linux Magazine 252,
   <https://www.linux-magazine.com/Issues/2021/252/Epoptes>
4. FOG Project — <https://fogproject.org/> ·
   <https://github.com/FOGProject/fogproject>
5. Xen Orchestra — management in XO 6,
   <https://docs.xen-orchestra.com/xo6/management> · XO 5,
   <https://docs.xen-orchestra.com/xo5/manage_infrastructure> · architecture,
   <https://docs.xen-orchestra.com/architecture>
6. XCP-ng — hosts and pools, <https://docs.xcp-ng.org/management/hosts-pools/>
   · XO web UI, <https://docs.xcp-ng.org/management/manage-at-scale/xo-web-ui/>
7. BOINC — <https://boinc.berkeley.edu/> · superhost,
   <https://github.com/BOINC/boinc/wiki/SuperHost> · Anderson, "BOINC: A
   Platform for Volunteer Computing", <https://arxiv.org/pdf/1903.01699>
8. mDNS/DNS-SD trust assumptions —
   <https://hacktricks.wiki/en/network-services-pentesting/5353-udp-multicast-dns-mdns.html>
   · <https://hackmag.com/security/multicast-dns-pentest>
9. Avahi transaction-ID spoofing, CVE-2024-52616 —
   <https://vulert.com/vuln-db/debian-11-avahi-179248>
10. SSH certificate authorities — <https://www.systemshardening.com/articles/linux/ssh-certificate-authority/>
    · with Ansible, <https://jpmens.net/2026/04/07/deploying-ssh-host-keys-and-certificates-with-ansible/>
    · step-ca, <https://smallstep.com/docs/ssh/hosts-step-by-step/>
11. NATS and MQTT for fleets —
    <https://www.synadia.com/blog/nats-vs-mqtt-technical-comparison-iot-fleet-management>
12. GNU Radio ZMQ blocks —
    <https://wiki.gnuradio.org/index.php/Understanding_ZMQ_Blocks>
13. smallpt — <https://openbenchmarking.org/test/pts/smallpt>
14. Raspberry Pi fleet management —
    <https://pip.raspberrypi.com/categories/685-whitepapers-app-notes/documents/RP-003609-WP/Fleet-management-A-brief-introduction.pdf>
15. Prior Copal reports — `lab-report.md`, `integration-lab-report.md`,
    `visual-debugging-lab-report.md`, `app-integration-plan.md`
