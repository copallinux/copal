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

## 3 · DECISIONS — resolved 2026-09-08

All four are decided. D1 was the hole in the plan and it is now filled; the
answer is a refinement of the recommendation rather than the recommendation as
written, and the difference is set out below because it removes machinery.

| | Decided | In one line |
|---|---|---|
| **D1** | nkeys, **and no JWTs** | the SSH CA decides membership; the bus credential is a scoped capability issued as a consequence of it |
| **D2** | `apk add nats-server` | it is in Alpine v3.24 community for `aarch64`; nothing to download and nothing to verify |
| **D3** | Python 3, stdlib, `curses`, own client | and `nats-py` stays out — the console runs on a Mac, where `apk` cannot rescue it |
| **D4** | half-blocks are the default | sixel is an enhancement; a glyph is the floor |

### D1 · The trust root for the bus. **Resolved: nkeys, without JWTs.**

The diagnosis stands. §6 said *"mTLS with certificates from the same grove
CA"*, the grove CA is an **SSH** CA (`ssh-keygen -s`), SSH certificates are not
X.509, and no amount of care makes one sign the other. Option C fails invariant
5 outright and option B contradicts "one trust root" more than it fixes. The
answer is A: **NATS's own nkey identity**.

But A as written said *"nkeys + account JWTs"*, and the JWTs are not wanted.
NATS has two authentication worlds built on the same nkey primitive:

- **Decentralized** — an operator signs accounts, an account signs user JWTs,
  and the server runs a resolver to fetch them. The permission list travels
  inside a signed token.
- **Static** — `authorization { users = [ { nkey: U…, permissions: {…} } ] }`
  in the server's own config. The permission list lives in a file on the
  warden.

Both prove identity identically: the server sends a nonce, the client signs it
with its ed25519 seed, the server checks the signature against the public nkey
it already has. The **only** difference is where the permission list is kept.

**Keep it in the config file.** Four reasons, in the order they matter:

1. **§15 already ruled out what JWTs are for.** *"Not multi-tenant. One grove,
   one operator, one CA."* Operator/account/resolver is the machinery
   multi-tenancy needs. This grove is eight machines and one person.
2. **Invariant 5 becomes readable.** It is a claim about who may publish what.
   In a config file a person can open `nats.conf` at nine in the morning and
   check it against the invariant. Nobody can read a JWT.
3. **It deletes four things** — the account signing key, the resolver
   configuration, a JWT encoder, and a second expiry story running beside the
   90-day host certificate. W2's acceptance test does not get weaker for any of
   it; it gets easier to write.
4. **It is the shape the console already has.** Write a file, push it over
   SSH, reload a service. That is every other thing `copal grove` does.

What survives from A unchanged, and is the whole point of choosing it:

- The **SSH CA stays the identity root of the grove.** It is what decides that
  a machine is a node. A node that cannot present a valid host certificate is
  never handed bus credentials, so invariant 1 holds exactly as written.
- The **seed is generated on the node** and never leaves it. Only the public
  nkey travels. Invariant 2 holds.
- The credential is **issued over the already-proven channel**, as one more
  step of enrolment, after the host certificate is installed.

**The cost, stated plainly:** the warden's config names every node, so
enrolling a node now edits the warden and reloads it. Two consequences, both
accepted: `copal grove enrol` gains a step that touches a second machine, and a
grove whose warden is down cannot issue bus credentials. Neither is a real
loss — enrolment already requires the console to be present, and a grove with
no warden has no bus for a credential to be good on. Revocation gets *simpler*
rather than harder: delete the stanza, reload, and the node is off the bus in
under a second, with no revocation list to distribute.

`nats-server --signal reload` re-reads authorization without dropping
connections that are still permitted, which is what makes the reload cheap
enough to do on every enrolment.

### D2 · Where `nats-server` comes from. **Resolved: `apk add nats-server`.**

Checked rather than assumed:

```
$ apk --print-arch
aarch64
$ apk search -x nats-server
nats-server-2.14.0-r2
```

It is in **Alpine v3.24 community for `aarch64`**, which is the repository
`copal-prep.sh` already enables. So there is no download, no SHA256 to pin, no
release URL to rot, and no argument to have with the "no binaries are tracked,
ever" policy in README §*Repository policy*. W1 loses its first checkbox.

The version matters slightly: 2.14 has JetStream, which M5 needs, so nothing
here has to be revisited when the gems arrive.

### D3 · What the console is written in. **Resolved: Python 3, stdlib, `curses`.**

As recommended, and the corollary — **no `nats-py`** — is confirmed with a
reason the original note did not have. Alpine does ship `py3-nats-2.12.0-r0`,
so on a node the dependency would be one `apk add`. But **the console's home is
the operator's Mac**, where `apk` does not exist and the fallback is
`pip install` into whatever environment happens to be current. A museum console
that needs `pip` at 08:45 is a console that is down, and a dependency that is
easy on seven of eight machines is not easy.

So: `tools/copal_nats.py`, a stdlib socket client for the text protocol —
`CONNECT`, `PUB`, `SUB`, `MSG`, `PING`, `PONG`, newline-delimited, a JSON blob
on connect. It needs one thing the original estimate missed: **the nonce
signature from D1**, which is ed25519 over a 32-byte seed. That goes in
`tools/copal_nkeys.py` beside it, is pure stdlib, and is shared with the node
so that there is exactly one implementation of the grove's key format.

### D4 · How a thumbnail reaches a terminal. **Resolved: tier 2 is the default.**

Unchanged from the recommendation. Half-block Unicode with 256 colour is what
the wall draws unless it is told otherwise; kitty/sixel is detected and used
when it is there; the glyph-and-sparkline tier is what a GPIO serial console
gets, because running everything in this repository over that console is
supported and W7 does not get to be the thing that ends it.

**Not blocking the milestone on sixel** is the operative half of this. W5 and
W7 are written against tier 2.

---

## 4 · Work items

Sizes are relative: **S** an afternoon, **M** a day or two, **L** longer than
that. Every item names its acceptance test, because "done" on a fleet is a
claim about eight machines and not about a compiling program.

### W1 · `nats-server` on the warden — S — depends on D2 — **written**

- [x] Resolve D2. `apk add nats-server`; 2.14.0-r2, Alpine v3.24 community.
- [x] `grove_warden_bus()` in `copal-prep.sh`, called by `stage_grove` **only
      when the node's role is warden**, and idempotent: a node that is demoted
      must stop and disable it. Demotion removes the init script as well as the
      runlevel entry, because a stopped service starts again at the next boot.
- [x] `/etc/nats/nats.conf` written by the stage: listen on the LAN only,
      **never `0.0.0.0` without an explicit `bind`**, JetStream on with a file
      store under `/var/lib/nats`, and a store limit that a 512 MB Zero 2 can
      survive — start at 64 MB and measure. Written by `copal-grove bus-config`
      and rewritten by `start_pre` on **every** start, because the address is
      the one field that cannot be known when the card is written.
      `sync_interval` is set to 2m rather than left at its default, per the trap.
- [x] OpenRC service `/etc/init.d/nats`, `rc-update add nats default`. Its
      `start_pre` refuses to start on a node whose role is not warden — two
      wardens on one segment is the muddle this design has no answer for.
- [x] The election already computes the role (`role_now`, `score`) — W1 makes
      the role *do* something for the first time.

**Not yet done: the acceptance test.** It is a claim about a warden and a
demoted node, and there is no hardware here to make it on. Everything above is
written and syntax-checked; none of it has run on a Pi.

**Acceptance:** on a warden, `rc-service nats status` is up and
`nats-server --version` runs; on a non-warden the service is absent, not merely
stopped. Stage 16 re-run on a demoted node removes it.

**Trap:** JetStream's file store on an SD card is the exact workload stage 15
spends a page warning about. The store limit and the sync interval are not
defaults to accept quietly.

### W2 · Bus credentials, issued over the enrolled channel — M — depends on D1 — **done**

- [x] Implement D1. No account signing key, because the resolved D1 has no
      JWTs: the console's **own** bus identity lives beside the SSH CA at
      `~/.copal/ca/console.nk`, and nothing of the console's goes on a node.
- [x] `copal grove enrol` gains a step: after the host certificate is
      installed, generate the node's nkey **on the node** (invariant 2 — no
      private key crosses the network) and receive its public half. There is no
      JWT to sign and push back; instead the console collects the public halves
      and hands the **warden** a list, which the warden renders into its own
      `grove-users.conf`. `copal grove bus` is that step, and `enrol` calls it
      when a warden is announcing.
- [x] Permissions, from invariant 5, verbatim:
      - publish: `grove.<g>.node.<id>.>`, `grove.<g>.log.<id>`,
        `grove.<g>.ack.<id>.>`, `grove.<g>.gem.>`, `grove.<g>.hello`
      - subscribe: `grove.<g>.cmd.>`, `grove.<g>.work.>`
      - nothing else. Rendered by `copal-grove bus-users` on the warden, from
        the warden's own grove name — the console never sends config text, so
        a tampered console cannot widen an allow-list.
- [x] **The test that proves a node cannot publish as another node.**
      `tools/copal-bus-test.py`, and `make bus-test`. It starts its own
      `nats-server` on the loopback with a membership rendered by the same
      `render_users()` the warden uses, so it needs a server but not the fleet.
      Skips with status **77**, never 0, when there is no `nats-server` — a run
      that proved nothing must not read as a run that passed.
- [x] Correct `docs/grove-plan.md` §6's mTLS sentence. It is now a subsection,
      "How the bus is authenticated", and it says what was wrong with what it
      replaced.

**Acceptance: met.** Against `nats-server` v2.14.0, seventeen checks, every one
of them a real server's answer:

```
As museum-01, holding museum-01's seed:
  ✓ may publish its own state / its own log / hello
  ✓ MAY NOT publish as museum-02          ← the invariant
  ✓ MAY NOT write museum-02's log
  ✓ MAY NOT acknowledge for museum-02
  ✓ MAY NOT issue a command
  ✓ MAY NOT reach another grove
  ✓ may subscribe to commands
  ✓ MAY NOT subscribe to the whole grove
As the console:      may command, may hear everything, MAY NOT impersonate a node
Never enrolled:      MAY NOT connect at all
Before enrolment:    an unenrolled grove admits nobody
```

**And the test was checked for teeth.** Widening one allow-list to the
console's wildcard — the exact mistake invariant 5 exists to prevent — makes
six of those checks fail. A test that cannot fail proves nothing, and that
negative control is what found the client bug recorded in `copal_nats.py`'s
regression note.

`nats-server -t` still parses the rendered config before the warden installs
it, and `parse_members()` still refuses bad checksums, duplicate ids, ids that
are not ids, roles that are not roles, an empty list, and a grove name carrying
a quote.

### W3 · The node agent — M — depends on W1, W2 — **written**

`tools/copal-grove-agent`, embedded in `copal-prep.sh` and supervised by
OpenRC. It runs as the **`copal-grove` service account and not as root**: it is
a second doorway to the same verb list the forced command guards, so it must
not be a wider doorway. That is also why the node's bus seed is owned by that
account rather than by root.

- [x] Publishes `hello` every 10 s and `node.<id>.state` on change, at most
      every 5 s. The payload is the line `copal-grove state` already prints,
      verbatim, with `agent=` appended — no second telemetry vocabulary.
- [x] Subscribes `cmd.>`; validates the envelope from §6 (`v`, `corr`, `verb`,
      `args`, `iss`, `exp`, `once`); **executes only through
      `/usr/bin/copal-grove-exec`**, by setting `SSH_ORIGINAL_COMMAND` exactly
      as sshd does. The agent parses no verbs of its own and holds no list of
      its own to fall out of date. Publishes `ack.<id>.<corr>`.
- [x] Honours `exp`, and `once` — the seen-list is on disk, so redelivery is
      safe across a restart and not only within one. Capped at 500 and
      rewritten rather than grown.
- [x] Reconnects with backoff (2s → 60s), and **runs happily with no warden at
      all**. No warden is not an error and never exits; `copal_nats` grew a
      `peer_closed` flag so that "the warden went away" cannot be mistaken for
      "nothing arrived", which would have been a tight loop.

**Not yet done: the acceptance test.** Killing a warden mid-day and watching
the agent find the new one within 30 s is a claim about two machines. The pure
logic — addressing, the envelope, idempotence across a restart, the tail — has
30 checks in `copal-grove-agent --self-test`, which `make lint` runs.

**Acceptance:** kill the warden mid-day; the agent reconnects to the new one
within 30 s without losing its state, and `copal grove run` over SSH keeps
working throughout — which is invariant 8 and the reason it is written down.

**Trap:** an agent that dies quietly is worse than no agent, because the wall
will show a node as fine while it is deaf. It must publish its own start and
the console must show "agent last seen" separately from "node last seen".

### W4 · The log collector — S — depends on W1 — **written**

- [x] The warden subscribes `grove.<g>.log.>` and writes **per-node dated
      files** under `/var/log/copal-grove/<id>/YYYY-MM-DD.log`, the same shape
      stage 10 uses for the counter's per-counter logs. It is a branch of the
      agent's dispatch loop rather than a second process: one connection, one
      service, and the warden is a node like the others.
- [x] **This needed a third role in the permission model.** Invariant 5 gives a
      node `subscribe` on `cmd.>` and `work.>` only, so a warden could not read
      what it was supposed to collect. `perms_for()` now knows `warden`, whose
      one extra grant is `subscribe grove.<g>.log.>` — a subscribe and never a
      publish, so the warden can read the grove and still cannot say anything
      in another node's name. §7 calls it a convenience rather than an
      authority; this is that sentence in the config file. `bus-test` checks
      both edges of the exception.
- [x] A cap of 64 MB across every node, oldest whole files first and never
      today's, because the warden's `/var/log` is on the card. The node's own
      is tmpfs, which is exactly why the warden's copy has to survive a reboot.
- [x] `copal grove logs [NODE] [--since DAYS] [--follow]`. `--follow` is a
      three-second poll and says so: streaming would mean the console holding a
      bus connection open, which is the first crack in §12's one read model.
      Dates come from filenames rather than date arithmetic, so it stays right
      for a node that was off for a week.

**Not yet done: the acceptance test**, which is a node powered off at 11:00 and
asked about at 16:00 — two machines and five hours.

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

### W6 · `copal grove watch` — the wall, without the TUI — M — depends on W3 — **written**

Built before the wall on purpose, and the reason is §12: anything the TUI can
do, `copal grove` can do, because the TUI calls it. A rule like that is only
worth having if it is tested, and the test is that the closing demo can be
performed with these verbs and no TUI at all.

- [x] `copal grove watch [--every N] [--once]` — a live table, redrawn, no
      curses. Two sources: beacons always, and the bus when there is a warden
      and this console has been enrolled onto it. The bus is what makes it live
      — a beacon is four minutes old at worst.
- [x] `copal grove notify --all-up` — exits 0 when every declared node is up,
      non-zero on timeout, one line of output, so it composes:
      `copal grove notify --all-up && copal grove scene wake`.
- [x] `copal grove state --json` — the whole grove as one JSON document:
      counts, the warden, bus reachability, per-node facts, strangers, and
      `scenes` as a **mapping of scene to node ids** rather than a global
      boolean, because a room where six machines got the memo is the normal
      case and the document has to be able to say so.
- [x] `copal grove browse` — the beacon lines, unadorned. Exposed because the
      live views re-run it to refresh, which keeps one parser for that format,
      and because "what did discovery actually say" is worth asking directly.
- [x] **Degraded with the bus off, which is milestone requirement 5.** The
      header says `bus off: <why>`, glyphs drop from `●` to `◐` — announced,
      not confirmed live — and temperature and agent age go blank rather than
      stale. Nothing claims to know what it cannot know.

**Acceptance: met for the commands.** Run against a fixture grove of eight and
a real `nats-server` with seven agents publishing on it, then again with the
bus switched off. 38 checks in `copal-grove-view self-test`, which `make lint`
runs.

**Four bugs, and every one of them was found by running it rather than by
reading it:**

1. A beacon with no `g=` fell through as a member of this grove, which put a
   networked printer in the table *and in the count*. Strangers are now a
   separate list in the document — shown, never contacted, never counted.
2. `7 of 8` read as `8 of 8`, a direct consequence of (1).
3. The glyph/colour table was a module-level dict built at import, so it
   captured the colour constants before `--plain` could blank them: every row
   came out painted and unterminated when piped.
4. The bus says `up=372m` and the beacon says `372`. Only a live bus could
   show that, and it showed it as a traceback. Both shapes are normalised in
   one place now.

And one distinction that was wrong rather than crashing: a node that never
announced was being reported as having a *silent agent*, which sends an
operator to inspect a machine that is switched off. `silent` now means "it
announced and its agent is not talking"; a node that is not there is `absent`.


### W7 · The wall — L — depends on W6, D3, D4 — **written**

`tools/copal-grove-console.py`, curses, stdlib only, invoked as
`copal grove console`.

**The milestone's architectural acceptance test is met, and it is the one that
mattered:** the TUI calls `copal grove`, never the network. It runs
`copal grove state --json` for its picture and `copal grove scene|run|logs|
notify` for its verbs. It opens no socket, holds no credential and knows no
subject names — it is handed `"$0"` and re-enters the console rather than
reaching past it. Every screen is a rendering of a command a person could have
typed.

- [x] A tile per node: status glyph, scene, temperature, agent age, warden
      marker, and *not announced* for the ones that are gone.
- [x] Where the thumbnail will go (W5), each tile draws the one continuous
      quantity the grove already publishes — temperature — as a half-block bar,
      D4's default tier. A real reading rather than a placeholder pretending to
      be a picture, and thermal throttling is the museum's actual failure.
- [x] The header: grove, count up of count declared, bus reachability, and
      **the scene per node** — `show 5  rest 1  wake 1  since 14m` — never a
      global boolean.
- [x] The stranger line. Seen, never contacted.
- [x] Selection and the verb bar. `Scene`, `Run`, `Power`, `Snapshot`,
      `Notify`, `Log` are live; `Control`, `Observe`, `Exchange`, `Send`,
      `Message` are present, dimmed, and say **"L6, not built"** in the bar
      itself and again when pressed. A menu that lies about what it can do is
      worse than one that is honest and short.
- [x] **`Control` on a multi-selection is refused, and the refusal is
      implemented rather than documented.** It names what to do instead —
      `Scene`, which is declarative and reports per node — and it is checked
      before the not-built notice, because the refusal is a property of the
      design and the notice is a property of today.
- [x] **`Esc` returns to the wall from anywhere and never asks.** Tested from
      every overlay, with an assertion that `Esc` can never quit.

**Rendering is a pure function.** `frame()` turns a state document into styled
lines; curses paints them and `--once` prints them with ANSI. That is what lets
the wall be tested and screenshotted without a terminal, and it is why there is
not one curses call in the layout code. 58 checks in
`copal-grove-console.py --self-test`.

**Two layout bugs, both caught by assertions rather than by looking:**

1. Eleven verbs on one line overflowed 80 columns. A wall that wraps is a wall
   that scrolls, which is the one thing a wall is for not doing. The bar is two
   lines now, split into what works and what does not — which is the honest
   split rather than a way of fitting. `clip()` now enforces the width for
   every line, because the next person will add a verb.
2. A node with no temperature rendered a "no reading" cell narrower than a
   drawn bar, which shifted every tile to its right. Tile rows are now pinned
   to `TILE_W` by a check that walks a node with no reading, a node that never
   announced, an over-long id and an over-long scene name.

**Not yet done: on hardware.** It has been run against a fixture grove of eight
and a real `nats-server` with seven agents publishing, and again with the bus
off. No Pi.


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

### W10 · Degradation, tested on purpose — M — depends on all — **performed**

Invariant 8 says the console works with every layer removed. M4 is where that
stops being a claim. `tools/copal-degrade-test.py`, or `make degrade-test`.

Run 2026-09-08: **18 passed, 1 failed, 1 not performed.** The dated checklist
is [`grove-lab-report.md` Appendix A](grove-lab-report.md#appendix-a--degradation-performed).

- [x] Bus down → the console falls back and **says so in the header**. It said
      `bus off: timed out`, which names a missing component without telling
      anybody that the tiles are now four-minute-old beacons. It now reads
      `bus off — polled, not live`. Nothing is called live or silent with no
      bus to prove it, because both would be guesses.
- [ ] **Warden unplugged → FAILS, and this is what W10 was for.** A node never
      changes its role: `role_now()` returns the field written to its card and
      nothing computes the election. `score()` is correct and published, and
      nothing reads it to decide. §7 describes a sort; the code has a constant.
      The console *does* follow a warden that moves — but no warden ever moves.
      **W1's checklist asserted the opposite** ("the election already computes
      the role"), and building on that sentence is how this survived W1, W3
      and W7.
- [x] Avahi off → addresses from the written list at
      `~/.copal/groves/<grove>/nodes`; everything else unchanged, because
      identity never depended on discovery. *(Until W10 was performed this
      line named the grove file's `nodes` key instead. That key is a list of
      **ids** for `copal grove wait` and carries no addresses; the file that
      can is the one named above. The mechanism was right and the sentence was
      not, which is the sort of thing only performing a checklist finds.)*
- [x] Console killed mid-command → nothing left half-applied. Verified against
      a real `nats-server` and the real agent: a redelivered command runs
      exactly once, still exactly once **after the agent restarts** — which is
      what proves the seen-list is on disk — an expired command does not fire
      at four in the afternoon, a fresh one still runs, and every one of them
      goes through `copal-grove-exec` as a verb. **This is also W3's acceptance
      test, which had not been made until now.**

**Acceptance: met, and the finding is the point.** A layer that has become
load-bearing is a bug, and this is the item that finds it. It found the
election.

**What remains not performed:** the twenty-second failover timed on hardware,
and a node powered off at 11:00 read back at 16:00. Both need two machines and
a power switch, and both are marked *not performed* rather than reworded into
something a workstation can do.


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
