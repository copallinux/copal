# The node's half of the control console

*What changes on a Copal node so that orrery's museum interface can observe it,
control it, open a shell on it and put a banner on its screen — and the one
thing that turns out to need no change at all.*

Companion to [`fleet-lab-report.md`](fleet-lab-report.md) §IV-C, which names the
verbs, and to §12 of [`fleet-plan.md`](fleet-plan.md), which says the console is
three faces on one read model. The console's own half is in the orrery checkout:
[`console.md`](../../orrery/docs/console.md) is the interface,
[`wire.md`](../../orrery/docs/wire.md) is the protocols,
[`media.md`](../../orrery/docs/media.md) is the card pane.

---

## 1 · The finding that came first: Terminal needs nothing

orrery's README has carried this since the seat was built:

> **Terminal is a fleet decision, not a console one.** A shell on a node needs a
> second credential with a wider door than the operator certificate has. The
> seat says so rather than offering a tab that cannot work.

**That credential was built in stage 16 and has been on every fleet card since.**
Three lines, already in `copal-prep.sh`:

```sh
# copal-prep.sh:28382-28384, in fleet_identity()
printf 'fleet-operator\n' > "/etc/ssh/principals/$FLEET_ACCT"
printf 'fleet-human\n'    > "/etc/ssh/principals/$PI_USER"
```

and, in `tools/copal-fleet.sh`'s `cmd_login()`, one flag:

```sh
ssh-keygen -q -s "$CA" … -n fleet-operator,fleet-human -V "+${HOURS}h" "$OPKEY.pub"
```

One certificate, two principals, two doors. `fleet-operator` lands on the
`copal-fleet` account and hits `ForceCommand /usr/bin/copal-fleet-exec` — the
verb list, no shell, no tty, no forwarding. `fleet-human` lands on the login
account, which the fleet's `Match` block never mentions and which therefore gets
an ordinary login shell with an ordinary tty.

`AllowUsers` already permits both (`fleet_sshd_policy()`, and `copal-ssh users`
before it). The door is open, it is CA-gated, it expires in eight hours, and
nothing in this repository has to change for Terminal, Exchange or Send.

**The wider door was a deliberate design and the README recorded it as a gap.**
Correcting that sentence is a change to orrery's README, not to a node.

---

## 2 · The session word, and the thing it finally resolves

`/etc/copal/session` holds one word. Stage 4 writes `x11`; `stage_hyprland()`
writes `wayland` at the full-monty level. `copal-session` reads it and starts
that desktop.

orrery's README records the consequence as unresolved:

> On the same nodes, `x11vnc` cannot capture Wayland and `wayvnc` is absent from
> Alpine — so the GUI and the seat's Control currently want opposite session
> types. Unresolved, and recorded here rather than discovered later.

It is resolvable, and the resolution is to stop treating the two as
alternatives. **The session word selects the remote-desktop server, and the
console reads the word.**

| `/etc/copal/session` | desktop | remote server | console speaks | port |
|---|---|---|---|---|
| `x11` | i3 / Xorg | `x11vnc` | RFB 3.8 — `src/rfb.rs`, already written | 5900 |
| `wayland` | Hyprland | `hypr-rdp` | RDP over TLS — `src/rdp.rs`, to be written | 3389 |

Neither is a fallback for the other and neither node type is second class. A
default node gets Observe and Control over RFB, which works today. A full-monty
node gets them over RDP, which is the better protocol and the one with a
clipboard.

**And orrery's `--gui` stops being the odd one out**, because a full-monty node
is a Wayland node, which is the only kind that can run it — so the console and
Control now want the *same* session type rather than opposite ones, on the
machines where both matter.

---

## 3 · The read model carries which one

The console must not probe ports to find out. `facts()` on the node already has
the right contract for this, stated in its own comment:

> ONE READING PER LINE, key then a tab then the value, and a key the console
> does not know is the console's to ignore — so a console older than a node
> keeps working and a node older than a console does not break it.

So: two new readings, and every reading degrades to a named unknown rather than
a blank, as W10's rule requires.

```sh
# copal-prep.sh, in the embedded copal-fleet, facts()
printf 'session\t%s\n'     "$(or_unknown "$(cat /etc/copal/session 2>/dev/null)")"
printf 'remote\t%s\n'      "$(remote_state)"

# remote_state prints one of:  off | vnc:5900 | rdp:3389 | not installed
```

`remote_state()` reports what is *installed and running*, not what is
configured — "there is an x11vnc on this machine" and "an x11vnc is listening
right now" are different claims and the console acts on the second.

**In `tools/copal-fleet-view`**, `assemble()` gains two keys beside the ones it
already lifts out of the beacon and the bus:

```python
"session": s.get("session") or b.get("session") or "",
"remote":  s.get("remote")  or b.get("remote")  or None,
```

and the demo fixture in orrery's `fleet.rs` grows them too, so the interface can
be drawn against the museum without a fleet. The web console's `wall.html`
already renders `n.vnc` the moment the read model carries one; `n.remote`
replaces that field and subsumes it.

---

## 4 · `copal-fleet-exec` gains two verbs, and refuses a third

`/usr/bin/copal-fleet-exec` is, in its own words, *the security boundary*, and
*a verb this file does not know is a refusal and a line in the log, not an
attempt.* Adding a verb is adding a case, and each one below is argued rather
than assumed.

### `remote start | stop | status` — the missing hatch

orrery's README:

> **Nothing on a node can start `x11vnc`.** The forced command in
> `copal-prep.sh` is a closed `case` over thirteen verbs with, in its own words,
> "no hatch, no raw, and no pass-through" — and no VNC verb among them. Until
> one is added there, Control works only against a node where someone started
> `x11vnc -nopw` by hand.

This is that verb, and it is the only genuinely new *authority* in this whole
design: it lets a certificate holder put a machine's screen on the network. So
it is bounded in four ways, all on the node, none of them the console's to
relax:

```sh
    remote)
        case "${2:-}" in
            start)  exec doas /usr/local/bin/copal-remote start ;;
            stop)   logline "REMOTE STOP"; exec doas /usr/local/bin/copal-remote stop ;;
            status) exec /usr/local/bin/copal-remote status ;;
            *) refuse "remote takes start, stop or status" ;;
        esac ;;
```

`copal-remote` is a new script installed beside `copal-snapshot`, and it:

1. **reads `/etc/copal/session`** and starts `x11vnc` or `hypr-rdp` accordingly.
   The console does not get to say which — it asks for a screen and the node
   decides how it gives one. A verb that took a server name would be a verb that
   took configuration text, which is what invariant 7 forbids.
2. **binds to the node's LAN address only**, never `0.0.0.0`, and never a
   loopback-plus-tunnel arrangement, since the fleet account has
   `AllowTcpForwarding no` and a tunnel would mean changing that.
3. **stops itself.** `COPAL_FLEET_REMOTE_MINUTES` (default 30) is a deadline
   armed at start and re-armed by each `start`. A screen that is on the network
   because somebody looked at it in March is the failure this prevents.
4. **logs both ends** to `/var/log/copal-fleet.log`, so `log tail` shows who
   asked and when it stopped.

And it refuses outright when `COPAL_FLEET_REMOTE=off` in the answers file, which
is the setting for a node in a public space that should never be viewable.

### `message TEXT…` — the banner

`verbs.rs` in orrery currently refuses to offer Message, with a comment that is
correct today: *"there is no message banner anywhere. `copal fleet notify` means
'tell me when all eight are up' and refuses anything else, so Message is not
offered rather than offered and broken."*

The lab report §IV-C wants it — *"banner on all; the museum's 'please stand
back'"* — so the node grows it:

```sh
    message)
        shift
        [ $# -gt 0 ] || refuse "message takes some text"
        _t="$*"
        [ ${#_t} -le 200 ] || refuse "a banner is 200 characters or fewer"
        case "$_t" in
            *[!\ A-Za-z0-9.,!?:\'\"()/-]*) refuse "a banner is plain text" ;;
        esac
        logline "MESSAGE $_t"
        exec /usr/local/bin/copal-notify "$_t" ;;
```

Three constraints and each is load-bearing. **Length**, because a banner is a
sentence. **Charset**, an allow-list rather than a deny-list, so that the string
cannot contain anything a rendering program might treat as markup or a shell
might treat as syntax. **`exec` with the text as one argument**, never a shell
string — the same discipline `verbs.rs` follows one layer up.

`copal-notify` draws it: `notify-send` where a notification daemon is running,
`hyprctl notify` on Hyprland, and a full-screen overlay where neither exists,
which is the museum case — "please stand back" wants the screen, not a corner.

### `send` — refused, and this one is worth explaining

There is no `send` verb and there will not be one. Send is SFTP, as
`$PI_USER`, over the `fleet-human` door, using OpenSSH's own `sftp-server`. A
file-transfer verb in the forced command would mean the `copal-fleet` account
growing the ability to write arbitrary paths, which is the boundary this file
exists to hold.

**Two doors, two jobs.** `fleet-operator` runs a closed list of verbs.
`fleet-human` is a person with a shell and a file transfer, with all of a
person's authority and none of a service account's. Collapsing them would make
the forced command decorative.

---

## 5 · `hypr-rdp` on the node

A new function, called from the tail of `stage_hyprland()` (copal-prep.sh:12250)
and guarded on the machine being in a fleet at all — a standalone full-monty
desktop gets Hyprland and no RDP server.

```sh
# copal-prep.sh, after the session word is claimed in stage_hyprland()
fleet_remote_rdp() {
    [ -n "${CFG_FLEET:-}" ] || { note "not a fleet card -- no RDP server"; return 0; }
    [ "$(cat /etc/copal/session 2>/dev/null)" = wayland ] || return 0
    …
}
```

It needs `ffmpeg`/`libavcodec`, `libva`, `pipewire` and `libxkbcommon` by
hypr-rdp's own account, plus Hyprland 0.54 or later — which is a real
constraint to check rather than assume, since Alpine's `hyprland` version moves.

### Two things that are not yet known, and are named rather than glossed

**H1 — hypr-rdp has not been located.** There is no reference to it anywhere in
this repository, it is not in Alpine's package index as far as this checkout
knows, and nothing here has run one. Everything in this section is written
against a description. The first task of the implementation phase is to find it,
build it, and read what it actually does — not to write a client against a
guess.

**H2 — whether it will talk to a client with no H.264 decoder.** orrery cannot
decode H.264 and will not learn to; [`wire.md`](../../orrery/docs/wire.md) §6
sets out the arithmetic and the decision to negotiate plain bitmap updates with
RLE instead. A server built around EGFX may simply not offer that path. If it
does not, there are three ways out in order of preference: configure it to offer
the legacy bitmap path; patch it upstream to fall back; or install `wayvnc`
beside it and let Control use `rfb.rs`, which is already written and already
tested. **The third is not a defeat** — it costs the clipboard and some
efficiency and keeps everything else — and it is the reason this design does not
depend on RDP succeeding.

### The certificate, and the better version of it

hypr-rdp will present a self-signed X.509 certificate and orrery will pin its
fingerprint, which is trust on first use — weaker than the SSH story, where the
fleet CA signs a host certificate and there is nothing for the operator to
decide.

The fleet already has a CA and already signs a per-node credential at enrolment.
**`sign_one()` in `tools/copal-fleet.sh` is the natural place to issue an X.509
host certificate too**, from the same authority, installed by the same
`copal-fleet install-cert` path, so that RDP gets exactly the check SSH has and
the pin file stops being needed. That is a genuinely good idea, it is more work
than it sounds — X.509 issuance from an SSH CA key means a small ASN.1 writer
somewhere — and it is **not in this plan's scope.** Recorded here so that the
pin file is understood as an interim rather than a design.

---

## 6 · `answers.txt` grows two keys

The existing three-step path — written by `tools/copal-answers.sh`, copied to
the card by `copal-prep.sh`, read once by `copal-init.sh` — takes them
unchanged. Both live under the fleet block and both are *different on every
card*, so they join the `--node N` path rather than the shared one:

```sh
# off | auto -- 'auto' means whatever /etc/copal/session implies.
# A node in a public space that must never be viewable is 'off'.
COPAL_FLEET_REMOTE='auto'
# How long a screen stays on the network after `remote start`. 0 means until
# stopped, and is not the default for a reason.
COPAL_FLEET_REMOTE_MINUTES='30'
```

---

## 7 · Everything else, as a list

| file | change | for |
|---|---|---|
| `copal-prep.sh` `facts()` | `session` and `remote` readings | §3 |
| `copal-prep.sh` `copal-fleet-exec` | `remote`, `message` cases | §4 |
| `copal-prep.sh` new `copal-remote` | starts/stops the screen, bounded | §4 |
| `copal-prep.sh` new `copal-notify` | draws a banner | §4 |
| `copal-prep.sh` `stage_hyprland()` | `fleet_remote_rdp()` at the tail | §5 |
| `copal-prep.sh` doas rules (≈28398) | `copal-fleet` may run `copal-remote` | §4 |
| `tools/copal-fleet-view` `assemble()` | pass `session` and `remote` through | §3 |
| `tools/copal-answers.sh` | two keys, on the `--node` path | §6 |
| `tools/copal-answers.sh --show` | `--json`, so orrery reads it through its owner | media.md §7 |
| `tools/copal-media.sh` **(new)** | append a manifest row after a write | media.md §5 |
| `Makefile` `img-%` | write a `.sha256` beside the image | media.md §5 |
| `Makefile` `vm` | take `MODEL=`, like `sd-%` and `img-%` | media.md §4 |
| `Makefile` `fleet-gui` **(new)** | build and run `orrery --gui` from `$(ORRERY_SRC)` | — |
| `bin/gui.sh` **(new)** | the shortcut, and `make lint` checks its target exists | — |
| `docs/fleet-plan.md` §12 | the table's third row is no longer only a web wall | — |

### What does **not** change

- **`fleet_sshd_policy()`.** The `Match` block, the forced command, `PermitTTY
  no`, `AllowTcpForwarding no` — all of it stays exactly as written. §1.
- **`fleet_identity()`'s principal files.** Already correct. §1.
- **`cmd_login()`.** Already signs both principals. §1.
- **The CA's location or handling.** orrery reads
  `~/.copal/ca/<fleet>_ca.pub` — the public half, to verify host certificates —
  and never touches the private half.
- **The bus.** Nothing here publishes, subscribes, or knows a subject name.
- **`copal-prep.sh`'s card-writing path.** See [`media.md`](../../orrery/docs/media.md) §1:
  the two typed `ERASE` confirmations are the safety model and the console is a
  front end to them, not a replacement for them.

---

## 8 · The acceptance test

Not "it compiles". The morning, from §V of the lab report, driven from the
window instead of the terminal:

1. `orrery --gui` on the operator's Mac. Eight tiles, one of them missing.
2. Click the `north` tag. Three selected. **Power → on** — the supply, not ssh.
3. **Notify → all up.** It chimes at 08:34.
4. Click `museum-03`. **Terminal.** A shell, as the login user, no password
   asked, the certificate's remaining hours in the status line.
5. **Send** an exhibit asset to the `wall` tag. Two nodes, two results.
6. **Control** `museum-06`, which is Wayland. Its Hyprland desktop, driveable,
   with a clipboard. `Ctrl-]` lets go and `remote stop` runs on the way out.
7. **Scene → show**, on all eight. Seven results and one refusal, drawn as
   seven and one rather than as a failure.
8. **Media.** Card 8 is the only `unused` token in the ledger. Write it, watch
   `copal-prep.sh` ask twice, and watch the manifest gain a row.
9. At 17:00, **Power → off** on all eight, and the certificate expires by itself
   an hour later.

Step 6 is the one that can fail for a reason nothing here controls — H2, above.
Every other step is built out of things that exist.

---

## 9 · What was built, and the one decision that changed

Written after the fact, because a design document that never records what
happened when the work was done is a document that stops being true quietly.

| §  | promised | built |
|---|---|---|
| 3 | `session` and `remote` readings | `facts()` prints both; `remote_state()` reports what is **running**, not what is installed |
| 3 | `assemble()` passes them through | done, with four new checks in `copal-fleet-view self-test` |
| 4 | `remote start\|stop\|status` | done, with the four bounds in `copal-remote` |
| 4 | `message TEXT…` | done — and the charset is six marks of punctuation rather than the ten in §4, because `(` inside a `case` pattern does not parse under dash and a banner does not need a bracket |
| 4 | `copal-notify` | done: `hyprctl notify`, then `notify-send`, then the console |
| 4 | doas rule for `copal-remote` | done, `args start` and `args stop` — `status` needs no privilege and is deliberately not listed |
| 5 | `fleet_remote_rdp()` | done, and it **installs nothing**: H1 is still open, so it looks, reports and writes down what it found |
| 6 | two answers keys | `COPAL_FLEET_REMOTE` and `COPAL_FLEET_REMOTE_MINUTES`, through all three files and asked for by `copal-answers.sh` |
| 7 | `tools/copal-media.sh` | done, with a self-test that proves the token does not survive into its own fingerprint |
| 7 | `Makefile img-%` writes `.sha256` | done, and records a manifest row while it is there |
| 7 | `make fleet-gui`, `bin/gui.sh` | done, and `make lint` checks the shortcut names a real target |

### The crypto profile, which was not in this plan and should have been

`orrery --profile-sshd` prints the whitelist in its `src/profile.rs`, and
`fleet_sshd_policy()` now writes exactly that into the node's `sshd_config`
before the `Match` block. `make lint` fails when the two have drifted and
`make sync-profile` is the fix — the same arrangement `copal_nkeys.py` and
`radbeeper` already have, for the same reason: **a whitelist that exists in a
Rust file and again in a shell heredoc is two whitelists.**

It costs something and the cost is written where the block is: after this, a
plain public key no longer opens a fleet node. Only a certificate the fleet CA
signed does. That is what "locked down to public keys" means when it is true
rather than aspirational, and deleting the block between the fleet's two
markers puts the node back the way it was.

### Observe, and why there is still no thumbnail

`console.md` §5 says Observe enlarges tiles and draws the read model's `thumb`
field. **Nothing anywhere produces a thumbnail, and this phase decided not to
add one.** A node that captured its screen every few seconds would be a
screen-capture daemon on every machine in the museum, running whether or not
anybody is looking — a larger standing authority than any verb in §4, and one
that cannot be bounded by a deadline the way `remote start` is.

So Observe stays absent, and the honest description of what the console can do
is: **one live screen at a time, through Control, with the node's own consent
and a deadline on it.** If Observe is ever wanted, the shape that fits this
design is a `remote thumb` verb that captures **once, on request** and returns
a small image over the same authenticated channel — no daemon, no cache, and
nothing running when nobody is asking.
