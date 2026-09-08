<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Paul Richeson -- copal-alpine-linux -->

# The console — an operator's guide to `copal grove`

**Every command, what it does, and what it does when it goes wrong.**

Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`.

This is the reference for somebody running a grove, not for somebody building
one. The architecture is [`grove-plan.md`](grove-plan.md); the interface design
and its prior art are [`grove-lab-report.md`](grove-lab-report.md); the current
milestone is [`grove-m4-backlog.md`](grove-m4-backlog.md).

**Each command below is marked with what is true of it today.** `works` has run
end to end on this machine or a VM. `written` exists and is syntax-checked and
has never met a Raspberry Pi. `designed` is a specification and no code.

---

## 0 · The shape of it

Three faces on one read model, and they are built in this order because the
order is what keeps the console from becoming the thing the grove depends on:

| Face | For | State |
|---|---|---|
| `copal grove …` | scripts, and the developer. **It is the API.** | the parts below |
| the TUI | the operator at a terminal | designed — M4 W7 |
| the web wall | the gallery screen, the phone in a pocket | designed — later |

Anything the TUI can do, `copal grove` can do, because the TUI calls it. If a
thing can only be done in the wall, that is a bug in the wall.

Options most verbs take:

```
--grove NAME   which grove (default: the one named in answers.txt)
--via HOST     browse from HOST over ssh instead of here. A Mac has no
               avahi-browse, so this is how a Mac sees the grove: it asks a
               node that can already see it. The Mac is the authority, not the
               eyes.
--tag T        only nodes carrying this tag
--node ID      only this node
--json         machine-readable, where the verb has it
--timeout N    seconds (default 120)
```

---

## 1 · Making a grove

```
make answers                    # name a grove; offers to make the authority
make answers-node N=2           # card 2, 3, … without another interview
make answers-node N=6 ROLE=warden TAGS=sdr,north
```
*works.* Both write into `answers.txt`; `copal-prep.sh` carries the values to
the card and stage 16 picks them up at the next install.

```
copal grove ca --create         # this grove's certificate authority, once
copal grove ca                  # show it; says if the private half is here
```
*works.* **Back the private half up.** Losing it means re-enrolling every
machine by hand. It never goes on a card — `copal-prep.sh` refuses to write a
private key to one, and stage 16 refuses to install one it finds.

```
copal grove trust               # one known_hosts line for the whole grove
```
*works.* The payoff of having a CA at all. After it there is no
first-connection prompt for any node ever again, and a host key that *changes*
becomes an error the console can explain rather than a warning an operator
learns to press through.

```
copal grove login               # an 8-hour operator certificate
copal grove login --hours 2
```
*works.* Short on purpose: short lifetimes are what make revocation a rarity
rather than a fire drill.

---

## 2 · Admitting machines

```
copal grove ls                  # what is out there, and what it has proved
copal grove ls --all            # strangers too
```
*works.* The status column is the whole point:

| | Means |
|---|---|
| `✓` | enrolled — its host certificate validates against this grove's CA |
| `?` | candidate — it answers, it is not signed yet |
| `!` | **foreign** — it is signed by somebody else's authority |
| `·` | announced, unreachable |

A beacon fills this list. **A certificate decides.** Discovery announces, it
never authorizes — mDNS has no authentication of any kind, so anything on the
segment can claim any name, and the `?` column is exactly as much trust as that
deserves.

```
copal grove enrol               # sign every candidate carrying its token
copal grove sign museum-03      # one machine, by name
```
*works.* Enrolment checks the single-use token written to that specific card.
A card that goes missing enrols zero further times than the once it was for. If
a warden is announcing, `enrol` also puts the node on the bus.

```
copal grove status museum-03    # one node's facts
copal grove inventory           # an Ansible inventory, out of discovery
```
*works.*

---

## 3 · The day

```
copal grove wait                # block until the grove has announced itself
copal grove scene               # which scenes this grove has
copal grove scene wake          # the museum's morning, on every node at once
copal grove run power off       # one verb, every node, a result each
copal grove power on|off        # the machines a console can switch
```
*works.* Five scenes ship: `wake`, `show`, `reset`, `rest`, `sleep`. A scene is
a YAML file in the grove's **git checkout**, not in a dotfile directory nobody
diffs — the grove executes what the repository says, not what the network says.

The console reports a scene as **applied / partially applied / stale, per
node**, never as a global boolean. A room where six machines got the memo is
the normal case and the interface has to be able to say so.

> `copal grove run` is the one that keeps working when everything above ssh is
> down. That is the layering rule, and it is why the demo that closes milestone
> 4 ends by stopping the bus entirely and requiring every verb to still work.

---

## 4 · The bus

```
copal grove bus                 # put every enrolled node on the message bus
copal grove bus --check         # what the warden says the bus is doing
```
*written.* `bus` asks each enrolled node for its public key — the node makes
one on first ask and keeps it — finds the warden, and hands it the list. **The
console never sends configuration text.** It sends ids and public keys; the
warden renders the permission list from its own idea of the grove's name, so a
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
copal grove logs                # every node, today
copal grove logs museum-06      # one node
copal grove logs museum-06 --since 3
copal grove logs --follow
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
copal-grove status              # what this machine thinks it is
copal-grove bus-state           # role, members, store size, this node's identity
copal-grove logs museum-06 2    # the collector, read directly (warden)
rc-service copal-grove-agent status
rc-service nats status          # warden only; absent elsewhere, not stopped
```
*written.*

---

## 4a · Watching the room

```
copal grove watch               # a live table, redrawn every 3 seconds
copal grove watch --every 10    # slower
copal grove watch --once        # one frame, for a script or a screenshot
copal grove state               # the same picture, once
copal grove state --json        # the whole grove as one document
copal grove notify --all-up     # exits 0 when every declared node is up
copal grove browse              # what discovery actually said, unadorned
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
copal grove notify --all-up && copal grove scene wake
```

---

## 5 · Designed, not built

| | What it will do | Item |
|---|---|---|
| the wall, the seat | the TUI of `grove-lab-report.md` §IV-B | M4 W7–W8 |
| `copal grove gem …` | the work queue | M5 |

The wall is what remains. It will be a rendering of §4a's verbs and not a
second way of knowing things — that is §12's rule, and building `watch` first
is how it gets tested rather than merely stated.

---

## 6 · When it goes wrong

**`copal grove ls` shows nothing.** Is `avahi-daemon` running on the nodes, and
does this machine have `avahi-browse`? A Mac does not — use `--via` and ask a
node that can already see the grove.

**A node shows `?` and `enrol` will not sign it.** The token check is refusing
to sign a machine that is not the one you made that card for. That is the check
working. Confirm the card, or re-run `make answers-node N=…` and rewrite it.

**A node shows `!`.** It carries a certificate from another authority. It is
not yours, or it is yours from a CA you have since replaced.

**`copal grove bus` says no warden is announcing.** No card in the grove was
given the warden role, or that machine is off. `copal grove ls` shows the role
column, which is what this reads.

**The bus is down but the room still has to work.** It does. Every verb in
§1–§3 runs over ssh and does not touch NATS. This is the layering rule, and it
is tested rather than hoped for.

**`nats-server` will not start on the warden.** `rc-service nats status`, then
`tail /var/log/nats.log`. The config is rewritten on every start, so a stale
listen address is not the cause; a membership the server would not parse cannot
be installed, because `copal-grove bus-users` runs `nats-server -t` against it
first and refuses.

**A node is on the wall but deaf.** An agent that dies quietly is worse than no
agent. The state a node publishes carries `agent=` with the agent's own uptime,
and the console shows *agent last seen* apart from *node last seen* — if they
disagree, `rc-service copal-grove-agent status` on that node.

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
over ssh.** The agent hands every command to `/usr/bin/copal-grove-exec`,
exactly as sshd does, through the same variable. It parses no verbs of its own.
Adding a verb still means editing one file, and there is deliberately no raw
pass-through in it.

**Nothing here opens a port to the internet.** Stated again because it is the
invariant most likely to be violated by a well-meaning change.
