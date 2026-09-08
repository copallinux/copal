# Copal Grove · M4 — the bus and the wall

**Backlog and build order for milestone 4.** Written 2026-09-08, at the end of
the session that finished M3. Nothing in M4 is built yet; this file is the
whole of what is known before it is.

M1, M2 and M3 are committed on branch `gfx-lab` — cards, discovery,
the certificate authority, one verb fanned out, and five scenes. M4 is the
milestone that turns nine command-line verbs into **a console somebody can
stand in front of at 09:00**.

---

## 0 · How to resume this

Paste this into a fresh session, from the repository root:

```
Read docs/grove-m4-backlog.md and continue Copal Grove milestone 4 from the
first unchecked work item. The backlog is authoritative for scope and order;
docs/grove-plan.md is authoritative for design and invariants. Start with the
DECISIONS REQUIRED section — three of them block code and one of them is a
genuine hole in the plan (D1, the trust root). Work one item at a time, keep
`make lint` clean, and do not begin an item whose dependencies are unchecked.
```

Read in this order before writing anything:

| | Why |
|---|---|
| §0–§2 of this file | scope, and what is deliberately not in M4 |
| **DECISIONS REQUIRED** (§3) | D1 blocks every other item |
| `docs/grove-plan.md` §6, §7, §12 | the bus, the warden, the console's layering rule |
| `docs/grove-lab-report.md` §IV | the wall, the seat, the verbs, the notification model |
| `tools/copal-grove.sh` | the console today: nine verbs and the four scene ones |
| `copal-prep.sh`, `stage_grove` and the embedded `copal-grove` node tool | the node's half |

The state of the tree at the time of writing:

```
ce1018d  Copal Grove: a plan for a fleet, and an answers file that can name one
959a1b2  Stage 16: a card can join a grove, and a console can drive one    (M1+M2)
03e70c9  Milestone 3: a day is five files, and the room applies one        (M3)
```

Everything below is unbuilt. No file named in §5 exists yet unless it is marked
*(exists)*.

---

## 1 · What M4 is

> **M4 · The bus and the wall.** `nats-server` on the warden, telemetry, log
> collection, thumbnails, and the TUI. *This alone is the console.*
> — `docs/grove-plan.md` §14

Concretely, M4 is done when an operator can:

1. Open one window and see **all eight machines at once**, live, with a status
   glyph, a temperature, and what each one is doing.
2. See the scene the room is in, **per node**, including the six-of-eight case.
3. Be told when the last node comes up, without watching for it.
4. Read the log of a node **that died at 11:00, at 16:00, after it went away.**
5. Do all of the above with the bus switched off, degraded but working.

And one property that is not a feature but is the acceptance test for the whole
milestone: **the TUI must call `copal grove`, never the network directly.**
§12 of the plan states the rule and the reason — the console must not become
the thing the grove depends on. Every screen in the wall is a rendering of a
command that a person could have typed.

## 2 · What M4 is not

- **Not the gems.** The JetStream *work queue* is M5. M4 stands up JetStream
  and uses it for last-value state retention and the log stream, and stops
  there. `grove.<g>.work.>` stays unused.
- **Not Control or Observe.** VNC, screen sharing and input forwarding are L6
  and they are a milestone of their own. M4 delivers *thumbnails*, which are
  one-way, low-rate and lossy, and the seat view shows facts rather than a
  live screen. The lab report's Control/Exchange verbs are stubs that say so.
- **Not a web console.** TUI only. The web view is named in the plan as a
  future surface that would call the same commands.
- **Not high availability.** Warden handover is twenty seconds and loses the
  in-flight work of one job. That is stated in §7 and it stays true.

---

## 3 · DECISIONS REQUIRED — read before writing code

### D1 · The trust root for the bus. **This is a hole in the plan.**

§6 says: *"mTLS with certificates from the same grove CA, so there is one trust
root in the entire system."* **That cannot be built as written.** The grove CA
is an **SSH** certificate authority — `ssh-keygen -s` — and SSH certificates
are not X.509. An SSH CA key cannot sign a TLS certificate, and NATS mTLS wants
X.509. The sentence describes an intention, not a mechanism.

Three ways out, with a recommendation:

| | What it means | Cost |
|---|---|---|
| **A · NATS nkeys + account JWTs** *(recommended)* | NATS's own identity system. Each node gets an nkey seed and a signed user JWT whose `pub`/`sub` allow-lists are exactly invariant 5. The console holds the account signing key beside the SSH CA. | A second key type to explain. No X.509 anywhere. Native permission model — the ACL *is* the credential, which is what the invariant wants. |
| **B · A second, X.509 CA** | `openssl` CA in `~/.copal/ca/`, one leaf per node, mTLS as written. | Two CAs, two expiries, two revocation stories. Contradicts "one trust root" more than A does. |
| **C · No transport auth; rely on the LAN** | Nothing. | Fails invariant 5 outright. Named only to be rejected in writing. |

**Recommendation: A.** The SSH CA stays the identity root of the *grove* — it
is what proves a node is a node — and the NATS credential is *issued over that
proven channel* as one more step of enrolment. A node that cannot present a
valid SSH host certificate never receives bus credentials, so the SSH CA
remains the thing that decides, exactly as invariant 1 requires. Write the
correction into `docs/grove-plan.md` §6 as part of W2; do not leave the plan
saying something that cannot be done.

### D2 · Where `nats-server` comes from

Unresolved and cheap to resolve: **check whether `nats-server` is in Alpine's
community repository for aarch64.** If it is, `apk add nats-server` and this
decision costs nothing. If it is not, fetch the static binary from the GitHub
release and verify its published SHA256 — which is the pattern `copal-prep.sh`
already uses for the Alpine payload and for GRUB, so there is a house style to
follow and `fetch-minivmac.sh` is the worked example.

Do not vendor a binary. Repository policy, README §"Repository policy": no
binaries are tracked, ever.

### D3 · What the console is written in

The console today is POSIX `sh`. A wall of eight live tiles is not.

**Recommendation: Python 3, standard library only, `curses`.** Reasons: it is
already required on the console (Ansible), it is already on the nodes (stage 7),
the repository already ships Python tools (`tools/copal-app-plan.py`,
`copal-terminal-palettes.py`), and `curses` is stdlib. A Go TUI would be a
tracked binary or a build step; a shell TUI would be a re-implementation of
curses in `tput`.

**And a corollary worth deciding now: do not add `nats-py`.** The NATS client
protocol is a text protocol over TCP — `CONNECT`, `PUB`, `SUB`, `MSG`, `PING`,
`PONG`, newline-delimited, with a JSON options blob on connect. A stdlib socket
client is on the order of 200 lines and keeps the console dependency-free,
which matters more here than saving those lines: a museum console that needs
`pip install` at 08:45 is a console that is down. Write it as
`tools/copal_nats.py`, test it against a local `nats-server`, and keep it
small enough to read in one sitting.

### D4 · How a thumbnail reaches a terminal

The lab report's mock draws ASCII bars, which is honest about what a terminal
can do. Three tiers, and the console should degrade down them without being
told:

1. **Kitty graphics protocol / sixel** — real images, in terminals that support
   it (kitty, wezterm, foot, iTerm2). Detect with `$TERM` and the terminal's
   response to a device-attributes query.
2. **Half-block Unicode + 256 colour** — a recognisable 20×10 image. Works
   everywhere that is not a serial console.
3. **A glyph and a sparkline** — `●` and the node's recent activity. Works on
   the GPIO serial console, which is a supported way to run everything else in
   this repository and should not stop being one here.

Decide tier 2 is the *default* and tier 1 an enhancement. Do not block the
milestone on sixel.

---

## 4 · Work items

Sizes are relative: **S** an afternoon, **M** a day or two, **L** longer than
that. Every item names its acceptance test, because "done" on a fleet is a
claim about eight machines and not about a compiling program.

### W1 · `nats-server` on the warden — S — depends on D2

- [ ] Resolve D2. Package or verified download.
- [ ] `grove_warden_bus()` in `copal-prep.sh`, called by `stage_grove` **only
      when the node's role is warden**, and idempotent: a node that is demoted
      must stop and disable it.
- [ ] `/etc/nats/nats.conf` written by the stage: listen on the LAN only,
      **never `0.0.0.0` without an explicit `bind`**, JetStream on with a file
      store under `/var/lib/nats`, and a store limit that a 512 MB Zero 2 can
      survive — start at 64 MB and measure.
- [ ] OpenRC service `/etc/init.d/nats`, `rc-update add nats default`.
- [ ] The election already computes the role (`role_now`, `score`) — W1 makes
      the role *do* something for the first time.

**Acceptance:** on a warden, `rc-service nats status` is up and
`nats-server --version` runs; on a non-warden the service is absent, not merely
stopped. Stage 16 re-run on a demoted node removes it.

**Trap:** JetStream's file store on an SD card is the exact workload stage 15
spends a page warning about. The store limit and the sync interval are not
defaults to accept quietly.

### W2 · Bus credentials, issued over the enrolled channel — M — depends on D1

- [ ] Implement D1's option A. Account signing key beside the SSH CA in
      `~/.copal/ca/`, never on a node.
- [ ] `copal grove enrol` gains a step: after the host certificate is
      installed, generate the node's nkey **on the node** (invariant 2 — no
      private key crosses the network), receive its public half, sign a user
      JWT with the permissions below, push the JWT back.
- [ ] Permissions, from invariant 5, verbatim:
      - publish: `grove.<g>.node.<id>.>`, `grove.<g>.log.<id>`,
        `grove.<g>.ack.<id>.>`, `grove.<g>.gem.>`, `grove.<g>.hello`
      - subscribe: `grove.<g>.cmd.>`, `grove.<g>.work.>`
      - nothing else, and the console must have a test that proves a node
        **cannot** publish as another node.
- [ ] Correct `docs/grove-plan.md` §6's mTLS sentence.

**Acceptance:** a test that connects as `museum-02`'s credential, attempts
`PUB grove.museum.node.museum-01.state`, and is refused by the server. That
test is the invariant; without it invariant 5 is an aspiration.

### W3 · The node agent — M — depends on W1, W2

A long-running process on every node, `copal-grove-agent`, added to the
embedded node tool in `copal-prep.sh` and supervised by OpenRC.

- [ ] Publishes `hello` every 10 s and `node.<id>.state` on change, at most
      every 5 s. The payload is the same fields `copal-grove state` already
      prints — reuse it, do not invent a second telemetry vocabulary.
- [ ] Subscribes `cmd.>`; validates the envelope from §6 (`v`, `corr`, `verb`,
      `args`, `iss`, `exp`, `once`); **executes only through
      `/usr/bin/copal-grove-exec`**, the same forced-command verb list SSH
      uses. A verb that is not allowed over SSH must not become allowed by
      arriving over NATS. Publishes `ack.<id>.<corr>`.
- [ ] Honours `exp`: a command that sat in a stream while the node was off does
      not fire at four in the afternoon. Honours `once`: redelivery is safe.
- [ ] Reconnects with backoff, and **runs happily with no warden at all** —
      that is the normal state during a handover.

**Acceptance:** kill the warden mid-day; the agent reconnects to the new one
within 30 s without losing its state, and `copal grove run` over SSH keeps
working throughout — which is invariant 8 and the reason it is written down.

**Trap:** an agent that dies quietly is worse than no agent, because the wall
will show a node as fine while it is deaf. It must publish its own start and
the console must show "agent last seen" separately from "node last seen".

### W4 · The log collector — S — depends on W1

- [ ] Warden subscribes `grove.<g>.log.>` and writes **per-node dated files**
      under `/var/log/copal-grove/<id>/YYYY-MM-DD.log`. This is deliberately
      the same shape stage 10 already uses for the Geiger counter's per-counter
      logs — a pattern this repository has already tested on a Pi.
- [ ] Rotation and a cap, because /var/log is tmpfs on a node (stage 3) and the
      warden's is not. The warden's collector directory must be on the card,
      and it must have a ceiling.
- [ ] `copal grove logs [--node ID] [--since T] [--follow]`, the command the
      TUI's log view will call.

**Acceptance — and this is the one that matters:** a node is powered off at
11:00; at 16:00 `copal grove logs --node museum-06` still returns its lines.
A collector that only shows live machines answers the wrong question, and the
failure the museum will actually hit is exactly this one.

### W5 · Thumbnails — M — depends on W3, D4

- [ ] On the node: capture (`grim` under Wayland, `scrot`/`import` under X11 —
      the grove has both kinds and the console must not care), downscale to
      about 240×135, JPEG at low quality, publish on `node.<id>.thumb`.
- [ ] **Adaptive rate, not a fixed 1 Hz.** Full rate for the node the operator
      is looking at, a slow rate for the rest, and nothing at all for a node
      whose load average says it is busy being an exhibit.
- [ ] A hard rule: **the thumbnail must never be the reason the exhibit
      stutters.** If capture costs more than a small percentage of a frame
      budget on a Zero 2, the answer is a lower rate or no thumbnail, and the
      console shows the glyph tier instead.

**Acceptance:** measured, on a Zero 2 with a real card, while it renders — not
on the VM. The plan lists this as an open question and it stays open until
somebody has the number. Record it in `docs/grove-lab-report.md`.

### W6 · `copal grove watch` — the wall, without the TUI — M — depends on W3

**Build this before the TUI.** It is the layering rule made concrete: a
line-oriented command that subscribes to the bus and prints state changes.
Everything the wall will show, this prints first.

- [ ] `copal grove watch [--tag T]` — a live table, redrawn, no curses.
- [ ] `copal grove notify --all-up` — exits 0 when every declared node is up.
      This is the morning's real primitive: *tell me when all eight are up* is
      the difference between watching a screen for ten minutes and doing
      something else until it chimes.
- [ ] `copal grove state --json` — the whole grove as one JSON document, which
      is what the TUI will actually consume.

**Acceptance:** the demo in §6 can be performed with these three commands and
no TUI at all. If it cannot, the TUI is about to become load-bearing.

### W7 · The wall — L — depends on W6, D3, D4

`tools/copal-grove-console.py`, curses, stdlib only, invoked as
`copal grove console`.

- [ ] The wall: a tile per node, the layout in the lab report §IV-B. Status
      glyph, thumbnail (per D4's tiers), temperature, current job, warden
      marker, last-seen for the ones that are gone.
- [ ] The header: grove name, count up of count declared, **the scene and since
      when** — and the scene shown **per node**, never as a global boolean. Six
      machines got the memo is the normal case and the interface must be able
      to say so.
- [ ] The stranger line: machines on the segment that are not in the grove,
      seen and never contacted.
- [ ] Selection, and the verb bar. In M4, `Scene`, `Run`, `Power`, `Snapshot`,
      `Notify` and `Log` are live; `Control`, `Observe`, `Exchange`, `Send` and
      `Message` are present and say "L6, not built" when pressed — a menu that
      lies about what it can do is worse than one that is honest and short.
- [ ] **`Control` on a multi-selection is refused, and the refusal is
      implemented rather than merely documented.** Broadcasting keystrokes to
      eight machines is a way to reach eight different broken states with one
      gesture. The operation actually wanted is `Scene`, which is declarative
      and reports per node.
- [ ] **`Esc` returns to the wall from anywhere and never asks.** The one rule
      the interface must not break is that the operator cannot get stuck inside
      a machine.

### W8 · The seat — M — depends on W7

- [ ] One node, full size: the facts panel from the lab report §IV-B — uptime,
      build, Alpine version, RAM and zram, temperature and throttling, card
      usage, certificate expiry, mounts, scene, job, pending upgrades.
- [ ] The log view: `tail -f` over that node with a text filter, reading W4's
      collector so that **a dead node still has a seat**.
- [ ] No live screen. That is L6.

### W9 · Notifications — S — depends on W7

Three severities, distinguished by *what the operator must do*:

- [ ] **toast** — something changed, nothing to do. Corner, five seconds, then
      the event log.
- [ ] **chip** — a node needs attention; its tile turns amber and stays.
- [ ] **alarm** — the room is not in the state the scene says. A bar across the
      top that does not go away until acknowledged or fixed.

**Acceptance:** applying `rest` while one node is unreachable produces an
alarm, not a toast, and the alarm names the node.

### W10 · Degradation, tested on purpose — M — depends on all

Invariant 8 says the console works with every layer removed. M4 is where that
stops being a claim.

- [ ] Bus down → the console falls back to SSH fan-out and **says so in the
      header**. Not silently: the operator must know the wall is now polled
      rather than live.
- [ ] Warden unplugged → next-highest score takes the role within ~20 s; the
      console follows without a restart.
- [ ] Avahi off → addresses from `nodes` in `grove.toml`; everything else
      unchanged, because identity never depended on discovery.
- [ ] Console killed mid-command → nothing on any node is left half-applied
      that a re-run does not fix. Scenes are idempotent; verify that the bus
      path is too.

**Acceptance:** a written checklist in `docs/grove-lab-report.md`, each line
performed and dated. A layer that has become load-bearing is a bug, and this is
the item that finds it.

---

## 5 · Files this milestone touches

| File | Change | Item |
|---|---|---|
| `copal-prep.sh` · `stage_grove` | warden bus install, agent service, thumbnail capture, nkey generation | W1 W3 W5 |
| `copal-prep.sh` · embedded `copal-grove` | `agent`, `thumb`, `nkey` verbs | W3 W5 |
| `copal-prep.sh` · `copal-grove-exec` | unchanged on purpose — the bus executes through the **same** verb list | W3 |
| `tools/copal-grove.sh` *(exists)* | `watch`, `notify`, `logs`, `state --json`, `console` | W4 W6 W7 |
| `tools/copal_nats.py` | new — the stdlib NATS client | D3 |
| `tools/copal-grove-console.py` | new — the wall and the seat | W7 W8 |
| `groves/example/grove.toml` *(exists)* | a `[bus]` section: store limits, thumbnail rates | W1 W5 |
| `docs/grove-plan.md` *(exists)* | **correct §6's mTLS claim** | W2 |
| `docs/grove-lab-report.md` *(exists)* | the Zero 2 thumbnail measurement; the degradation checklist | W5 W10 |
| `README.md` *(exists)* | the console, and what it costs a node | end |

## 6 · The demo that closes the milestone

Performed on real hardware, in this order, out loud:

1. `copal grove console` — eight tiles, live, one of them marked warden.
2. Unplug the warden. Watch the role move. **The wall does not blink and no
   command is lost**, because commands do not go through the warden.
3. `copal grove scene rest` from inside the console. Screens go dark, one node
   at a time, and the header says `rest · 6 of 8` until it says `8 of 8`.
4. Pull the power on `museum-06`. Its tile goes grey with a last-seen time.
5. Open its seat and read its log **after it is gone**.
6. `copal grove notify --all-up`, plug it back in, and let it chime.
7. Stop `nats-server` entirely. The header says the wall is polled; every verb
   still works over SSH.

If step 7 fails, M4 is not done, whatever else works.

## 7 · Budget, per node

| | Cost | Note |
|---|---|---|
| `nats-server` | ~15–20 MB, warden only | one static binary |
| JetStream store | 64 MB cap, warden only | on the card — see W1's trap |
| the agent | a few MB resident | it is a socket and a loop |
| thumbnails | **unmeasured** | the open question of the whole milestone |
| the console | nothing on a node | it runs on the Mac, or on the warden |

## 8 · Risks, in the order they are likely to bite

1. **D1 is a real hole.** Anybody who starts at W3 without reading it will
   build a bus with no authorisation model and discover it at the end.
2. **Thumbnails on 512 MB.** The plan has said from the beginning that this
   needs measuring. If it costs the exhibit its frames, the answer is the glyph
   tier and no apology.
3. **The bus becoming load-bearing.** It will be tempting, once telemetry is
   live, to make a verb depend on it. W10 exists to catch that; the rule is in
   §12 of the plan and in the acceptance test of W6.
4. **JetStream on an SD card.** Stage 15 spends a page on what wears a card.
   A queue with a file store is exactly that workload.
5. **Scope creep into L6.** Control and Observe are the glamorous half and they
   are not this milestone. The stubs must stay stubs.

## 9 · Out of scope, recorded so it is not lost

- **M4½ · Nix** — `nix-store --serve` behind the forced command, and closures
  instead of `apk` for what must be identical on eight machines. Designed in
  `docs/grove-plan.md` §11. It owes a measurement before it owes code, and it
  excludes `zero` and `pi2b` outright.
- **M5 · Gems** — JetStream work queue, the runner directory, `smallpt`, the
  SDR job, decay seeding. M4 stands JetStream up; M5 is what uses it.
- **L6 · Presence** — VNC, Control, Observe, Exchange, banners.
