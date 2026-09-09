<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Paul Richeson -- copal-alpine-linux -->

# The console — an operator's guide to `copal fleet`

**Every command, what it does, and what it does when it goes wrong.**

Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`.

This is the reference for somebody running a fleet, not for somebody building
one. The architecture is [`fleet-plan.md`](fleet-plan.md); the interface design
and its prior art are [`fleet-lab-report.md`](fleet-lab-report.md); the current
milestone is [`fleet-m4-backlog.md`](fleet-m4-backlog.md); adding a
machine by copying one you already have is
[`cloning-a-node.md`](cloning-a-node.md).

**Each command below is marked with what is true of it today.** `works` has run
end to end on this machine or a VM. `written` exists and is syntax-checked and
has never met a Raspberry Pi. `designed` is a specification and no code.

---

## 0 · The shape of it

Three faces on one read model, and they are built in this order because the
order is what keeps the console from becoming the thing the fleet depends on:

| Face | For | State |
|---|---|---|
| `copal fleet …` | scripts, and the developer. **It is the API.** | the parts below |
| the TUI | the operator at a terminal | designed — M4 W7 |
| the web wall | the gallery screen, the phone in a pocket | designed — later |

Anything the TUI can do, `copal fleet` can do, because the TUI calls it. If a
thing can only be done in the wall, that is a bug in the wall.

Options most verbs take:

```
--fleet NAME   which fleet (default: the one named in answers.txt)
--via HOST     browse from HOST over ssh instead of here. A Mac has no
               avahi-browse, so this is how a Mac sees the fleet: it asks a
               node that can already see it. The Mac is the authority, not the
               eyes.
--tag T        only nodes carrying this tag
--node ID      only this node
--json         machine-readable, where the verb has it
--timeout N    seconds (default 120)
```

---

## 1 · Making a fleet

```
make answers                    # name a fleet; offers to make the authority
make answers-node N=2           # card 2, 3, … without another interview
make answers-node N=6 ROLE=warden TAGS=sdr,north
```
*works.* Both write into `answers.txt`; `copal-prep.sh` carries the values to
the card and stage 16 picks them up at the next install. A card written on a
different machine than the one that answered the interview needs `CFG_SSHKEY=`
naming a key that exists there — see [`cloning-a-node.md`](cloning-a-node.md)
§8, which is a warning rather than an error and produces a card with no key.

```
copal fleet ca --create         # this fleet's certificate authority, once
copal fleet ca                  # show it; says if the private half is here
```
*works.* **Back the private half up.** Losing it means re-enrolling every
machine by hand. It never goes on a card — `copal-prep.sh` refuses to write a
private key to one, and stage 16 refuses to install one it finds.

```
copal fleet trust               # one known_hosts line for the whole fleet
```
*works.* The payoff of having a CA at all. After it there is no
first-connection prompt for any node ever again, and a host key that *changes*
becomes an error the console can explain rather than a warning an operator
learns to press through.

```
copal fleet login               # an 8-hour operator certificate
copal fleet login --hours 2
```
*works.* Short on purpose: short lifetimes are what make revocation a rarity
rather than a fire drill.

---

## 2 · Admitting machines

```
copal fleet ls                  # what is out there, and what it has proved
copal fleet ls --all            # strangers too
```
*works.* The status column is the whole point:

| | Means |
|---|---|
| `✓` | enrolled — its host certificate validates against this fleet's CA |
| `?` | candidate — it answers, it is not signed yet |
| `!` | **foreign** — it is signed by somebody else's authority |
| `·` | announced, unreachable |

A beacon fills this list. **A certificate decides.** Discovery announces, it
never authorizes — mDNS has no authentication of any kind, so anything on the
segment can claim any name, and the `?` column is exactly as much trust as that
deserves.

```
copal fleet enrol               # sign every candidate carrying its token
copal fleet sign museum-03      # one machine, by name
```
*works.* Enrolment checks the single-use token written to that specific card.
A card that goes missing enrols zero further times than the once it was for. If
a warden is announcing, `enrol` also puts the node on the bus.

```
copal fleet status museum-03    # one node's facts
copal fleet inventory           # an Ansible inventory, out of discovery
```
*works.*

---

## 3 · The day

```
copal fleet wait                # block until the fleet has announced itself
copal fleet scene               # which scenes this fleet has
copal fleet scene wake          # the museum's morning, on every node at once
copal fleet run power off       # one verb, every node, a result each
copal fleet power on|off        # the machines a console can switch
```
*works.* Five scenes ship: `wake`, `show`, `reset`, `rest`, `sleep`. A scene is
a YAML file in the fleet's **git checkout**, not in a dotfile directory nobody
diffs — the fleet executes what the repository says, not what the network says.

The console reports a scene as **applied / partially applied / stale, per
node**, never as a global boolean. A room where six machines got the memo is
the normal case and the interface has to be able to say so.

> `copal fleet run` is the one that keeps working when everything above ssh is
> down. That is the layering rule, and it is why the demo that closes milestone
> 4 ends by stopping the bus entirely and requiring every verb to still work.

---

## 4 · The bus

```
copal fleet bus                 # put every enrolled node on the message bus
copal fleet bus --check         # what the warden says the bus is doing
```
*written.* `bus` asks each enrolled node for its public key — the node makes
one on first ask and keeps it — finds the warden, and hands it the list. **The
console never sends configuration text.** It sends ids and public keys; the
warden renders the permission list from its own idea of the fleet's name, so a
tampered console cannot widen an allow-list by sending a cleverer file.

```
make bus-test                   # prove a node cannot publish as another node
make bus-test V=1               # say what each check did
```
*works* — 23 checks against a real `nats-server`. It starts its own on the
loopback, so it needs a server but not the fleet, and **skips with status 77
rather than 0** when there is none: a run that proved nothing must not read as
a run that passed.

```
copal fleet logs                # every node, today
copal fleet logs museum-06      # one node
copal fleet logs museum-06 --since 3
copal fleet logs --follow
```
*written.* Read from the warden's collector. **The property that matters is
that this answers for a node that is not here.** Every other view in the
console shows live machines; this one deliberately does not, because the
failure a museum actually hits is a Pi that died at 11:00 and is asked about at
16:00.

`--follow` is a poll every three seconds and says so. A streaming subscription
would mean the console holding a bus connection open, and that would be the
first crack in "three faces on one read model".

### On a node

```
copal-fleet status              # what this machine thinks it is
copal-fleet bus-state           # role, members, store size, this node's identity
copal-fleet logs museum-06 2    # the collector, read directly (warden)
rc-service copal-fleet-agent status
rc-service nats status          # warden only; absent elsewhere, not stopped
```
*written.*

---

## 4a · Watching the room

```
copal fleet watch               # a live table, redrawn every 3 seconds
copal fleet watch --every 10    # slower
copal fleet watch --once        # one frame, for a script or a screenshot
copal fleet state               # the same picture, once
copal fleet state --json        # the whole fleet as one document
copal fleet notify --all-up     # exits 0 when every declared node is up
copal fleet browse              # what discovery actually said, unadorned
```
*written.* `watch` reads two sources and the second is allowed to be missing:
beacons always, and the bus when there is a warden and this console has been
enrolled onto it. **The bus is what makes it live** — a beacon is four minutes
old at worst.

With the bus off it still works and says so: the header reads
`bus off: <why>`, the glyphs drop from `●` to `◐` — *announced*, not
*confirmed live* — and temperature and agent age go blank rather than stale.
Nothing claims to know what it cannot know.

| | Means |
|---|---|
| `●` | up, and the bus heard from its agent |
| `◐` | announced, but nothing live confirms it |
| `○` | declared and never announced |

The **agent** column is separate from all three, because an agent that died
quietly is worse than no agent. `silent` means the node announced itself and
its agent is not talking — a fault somebody can act on. A node that is not
there at all is not silent, it is absent, and reporting that as silent sends an
operator to look at a machine that is switched off.

`notify` composes, which is the point of it:

```
copal fleet notify --all-up && copal fleet scene wake
```

---

## 4b · The wall

```
copal fleet console             # every node at once, in a terminal
copal fleet console --once      # one frame, for a script or a screenshot
```
*written.* A tile per node: status glyph, scene, temperature as a half-block
bar, agent age, and `W` on the warden. The header carries the fleet, the count,
whether the bus is reachable, and **the scene per node** — `show 5  rest 1
wake 1` — never as one word for the whole room.

| Key | |
|---|---|
| arrows or `hjkl` | move the cursor |
| `space` | select or deselect the node under it |
| `a` / `A` | select all / none |
| `S` `r` `p` `k` `n` `L` | Scene, Run, Power, Snapshot, Notify, Log |
| `c` `o` `e` `s` `m` | Control, Observe, Exchange, Send, Message — **L6, not built** |
| `?` | the keys, and which half is real |
| `Esc` | back to the wall, from anywhere, without asking |
| `q` | quit |

The verb bar is two lines because the split is honest: what works, then what
does not. The second line says *L6, not built* on its face — a menu that lies
about what it can do is worse than one that is honest and short.

**`Control` on a multi-selection is refused**, and the refusal is implemented
rather than documented. It names what you actually want instead. See §7.

**The wall calls `copal fleet` and never the network.** It runs
`copal fleet state --json` for its picture and the ordinary verbs for its
actions, so every screen is a rendering of a command you could have typed. That
is the property that keeps the console from becoming the thing the fleet
depends on, and it is why `watch` was built before the wall.

Where a thumbnail will go, each tile draws temperature as a bar. Thumbnails are
W5 and are not built; a bar is a real reading rather than a placeholder
pretending to be a picture, and thermal throttling is what actually goes wrong
in a gallery.

---

## 5 · Designed, not built

| | What it will do | Item |
|---|---|---|
| the seat | one node full size, with its log — `fleet-lab-report.md` §IV-B | M4 W8 |
| thumbnails | a picture per tile, adaptive rate | M4 W5 |
| `copal fleet gem …` | the work queue | M5 |

The wall is what remains. It will be a rendering of §4a's verbs and not a
second way of knowing things — that is §12's rule, and building `watch` first
is how it gets tested rather than merely stated.

---

## 6 · When it goes wrong

**`copal fleet ls` shows nothing.** Two different things wear this face, and
the console tells them apart. If it *errors*, this machine has no way to
browse: a node has `avahi-browse` already because stage 16 installed it, a Mac
has none and never will — use `--via HOST` — and a separate Linux console is
the case nothing installs for, so do it once:

```sh
doas apk add avahi-tools dbus
doas rc-service dbus start && doas rc-service avahi-daemon start
```

If instead it prints an **empty table**, browsing worked and nothing answered.
That is a real answer rather than a failure, and the next question is the
nodes: are they on, on this segment, and is `DISCOVERY` set to `mdns` on their
cards rather than `static` or `off`?

**A node shows `?` and `enrol` will not sign it.** The token check is refusing
to sign a machine that is not the one you made that card for. That is the check
working. Confirm the card, or re-run `make answers-node N=…` and rewrite it.

**A node shows `!`.** It carries a certificate from another authority. It is
not yours, or it is yours from a CA you have since replaced.

**`copal fleet bus` says no warden is announcing.** No card in the fleet was
given the warden role, or that machine is off. `copal fleet ls` shows the role
column, which is what this reads.

**The bus is down but the room still has to work.** It does. Every verb in
§1–§3 runs over ssh and does not touch NATS. This is the layering rule, and it
is tested rather than hoped for.

**`nats-server` will not start on the warden.** `rc-service nats status`, then
`tail /var/log/nats.log`. The config is rewritten on every start, so a stale
listen address is not the cause; a membership the server would not parse cannot
be installed, because `copal-fleet bus-users` runs `nats-server -t` against it
first and refuses.

**A node is on the wall but deaf.** An agent that dies quietly is worse than no
agent. The state a node publishes carries `agent=` with the agent's own uptime,
and the console shows *agent last seen* apart from *node last seen* — if they
disagree, `rc-service copal-fleet-agent status` on that node.

---

## 7 · What the console will not do

**Control on a multi-selection is refused**, and that is a design decision
rather than a missing feature. Broadcasting keystrokes to eight machines
produces divergent state nobody can see. The operation the operator actually
wants — "make them all do the same thing" — is `scene` or `run`, both
declarative and both reporting per-node results. An interface that offers
control-all offers a way to put the room into eight different broken states
with one gesture.

**A verb that arrives over the bus is not a wider doorway than one that arrives
over ssh.** The agent hands every command to `/usr/bin/copal-fleet-exec`,
exactly as sshd does, through the same variable. It parses no verbs of its own.
Adding a verb still means editing one file, and there is deliberately no raw
pass-through in it.

**Nothing here opens a port to the internet.** Stated again because it is the
invariant most likely to be violated by a well-meaning change.
