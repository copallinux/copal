<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Paul Richeson -- copal-alpine-linux -->

# Cloning a VM into a fleet node

**A second machine in twenty minutes, without building an image — and the five
things that must stop being identical before it is safe to boot.**

Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`.

The supported way to add a machine to a fleet is `make answers-node N=2` and a
fresh image. This file is the other way: copy a VM that already works, then
take its identity away. It exists because the three items M4 leaves *not
performed* — the twenty-second failover, two wardens at once, and a node
powered off at 11:00 read back at 16:00 — need two machines and a power switch,
and cloning a VM is the cheapest two machines available. Killing a VM is the
power switch.

**A clone is not a node until its identity is new.** Everything below is one
idea: a fleet proves who a machine is, and a clone arrives claiming to be
somebody who already exists.

---

## 0 · Shut the source VM down first

Not a suggestion. UTM copies the qcow2 as a file, and a copy of a mounted ext4
taken mid-write is a filesystem with a journal describing work that never
finished. It usually mounts. *Usually* is the wrong standard for the machine
every later clone comes from.

UTM also will not let you edit the network settings of a running VM, and the
MAC has to change before the clone's first boot — see §2.

```
poweroff        # in the guest, or: utm/utm-vm.sh stop --target aarch64
```

## 1 · Take the console's secrets off the clone

**Do this first, because it is the one that is not merely untidy.**

If the machine you are cloning is the console — the one that ran `make answers`
or `copal fleet ca --create` — then `~/.copal` holds the **private half of the
fleet's certificate authority**, plus the operator key and the token ledger.
Cloning it puts the authority that signs every machine in the fleet onto every
machine in the fleet. That is the "CA private key on an SD card in a museum"
failure `tools/copal-answers.sh` spends a paragraph warning about, moved
somewhere it is easier to forget.

```sh
rm -rf ~/.copal                 # ON THE CLONE, never on the console
```

There is exactly one console. A node never needs `~/.copal`; it carries the CA's
**public** half in `/etc/copal/fleet/`, which is all it needs to verify.

## 2 · The MAC address

Change it in UTM (Network → MAC address) or in the bundle's `config.plist` at
`Network.0.MacAddress`, **before the clone's first boot**. vmnet keys its DHCP
leases on the MAC: two guests with one MAC get one lease and both flap.

Keep the `16:` prefix — locally administered, unicast, and the prefix
`utm/utm-vm.sh` generates. On the Mac:

```sh
printf '16:%02X:%02X:%02X:%02X:%02X\n' \
    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
```

`utm-vm.sh ip` reads that plist key and matches it against
`/var/db/dhcpd_leases`, so the plist must be the truth rather than a leftover:
a stale MAC there does not error, it reports the wrong address or none.

## 3 · The hostname, in three places

`/etc/hostname` is the one everybody changes. The other two are why a clone
still answers to its old name:

| File | What it is |
|---|---|
| `/etc/hostname` | the name the system sets at boot |
| `/etc/hosts` | the `127.0.0.1` line, which names the host and `<host>.lan` |
| `/etc/network/interfaces` | `hostname <name>` inside the `eth0` stanza — **the name sent to DHCP** |

Miss the third and the lease table, and anything reading it, still says the old
name. Avahi publishes from the hostname too, so two machines called `neagh` on
one segment become `neagh` and `neagh-2` silently, which is a beacon carrying a
name nobody chose.

## 4 · The SSH host keys — the one that breaks the fleet

```sh
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
```

This is not hygiene. `copal fleet` proves a node by a **host certificate over
its host key**: `copal fleet trust` writes one `@cert-authority` line, and
`cert_state` is what turns a `?` into a `✓`. Two clones sharing a host key are
one identity to the console — indistinguishable, both validating, and invariant
5 broken *below* the bus, where `copal-bus-test.py` cannot see it.

## 5 · The machine ID

```sh
head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > /etc/machine-id
echo >> /etc/machine-id
```

Avahi can be configured to publish from it, and dbus keys off it.

## 6 · All of it, on the clone's first boot

As root, before the clone has anything to be confused with:

```sh
NEW=museum-02
rm -rf ~/.copal
printf '%s\n' "$NEW" > /etc/hostname
sed -i "s/neagh/$NEW/g" /etc/hosts /etc/network/interfaces
hostname -F /etc/hostname
rm -f /etc/ssh/ssh_host_*; ssh-keygen -A
head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > /etc/machine-id; echo >> /etc/machine-id
rc-service sshd restart
```

Substitute the source VM's own hostname for `neagh`.

## 7 · Turning the clone into an actual fleet node

A clone of a machine built without a fleet is not a node: `stage_fleet` is a
no-op on a card with no fleet on it, so there is no `copal-fleet`, no beacon and
no agent. The boot partition still carries the installer, which means the stage
can be run in place — no image, no card, no Mac:

1. On the console, generate this card's answers: `make answers-node N=2`.
2. Copy the seven `COPAL_FLEET_*` values from the console's `answers.txt` into
   the clone's `/boot/answers.txt`, and the CA's public half to
   `/boot/fleet_ca.pub` — `fleet_install_ca` looks for it there.
3. On the clone: `sh /boot/copal-init.sh`, then choose `16) The fleet`.

**This path is written, not proved.** The stage menu offers 16 on its own and
`fleet_joined()` gates on the answers file, but running stage 16 on an
already-installed system has not been performed here. The failure mode is a
stage that declines to run, which costs nothing.

Every card needs its **own** `COPAL_FLEET_INDEX` and its **own**
`COPAL_FLEET_TOKEN`. The token is single-use and burned at enrolment; two
machines sharing one means the second cannot enrol. `COPAL_FLEET`,
`_SIZE`, `_CA`, `_PSK` and `_DISCOVERY` are properties of the fleet and are
identical on every card by design.

## 8 · answers.txt does not travel between machines

`answers.txt` records **absolute paths belonging to the machine that answered
the interview**. `COPAL_SSH_KEY` is the one that bites: `copal-prep.sh` sets
`CFG_SSHKEY` from it *in preference to* its own `~/.ssh` search, so an
answers.txt written on a VM and used to write an SD card on the Mac names a key
path that does not exist there. The build does not stop — it warns "no such key
file … continuing without one" and produces a card with **no authorised key**.

So when the card is written on a different machine than the interview was run
on, either re-run `make answers` there, or set the path explicitly:

```sh
CFG_SSHKEY=~/.ssh/id_ed25519.pub make image MODEL=pi4
```

The git identity in the file has the same property, with a smaller cost.

**The installer already gets this right once.** `COPAL_FLEET_CA` is an absolute
path too, and a missing one is `die "fleet CA not found: …"` — the build stops
and says so. A missing `CFG_SSHKEY` is `warn "… continuing without one"` and a
finished card. Same class of mistake, one machine apart, and only one of them
costs you a card you have to write again.

## 9 · A Pi is not a VM, in one way that matters

`MODEL=pi4` covers the Pi 4, the 400 and the CM4 — aarch64, BCM2711, the same
payload cache the `vm` target uses, so nothing is downloaded twice. A clone is
a fair proxy for a Pi in architecture and in software, and not in timing: a
killed VM drops its link instantly, and how fast a real card stops answering is
the thing the twenty-second failover measurement is actually about.

One real difference is worth knowing before buying anything. §9.1 of
[`fleet-plan.md`](fleet-plan.md) says a **Pi Zero 2 cannot be woken by
Wake-on-LAN** — no standby rail feeds the NIC. A **Pi 4 or CM4 can be woken
from the `GLOBAL_EN` / power-button header**, so a fleet built on Pi 4s has a
morning-automation option that a fleet of Zero 2s does not.

---

**See also** — [`fleet-console.md`](fleet-console.md) for the verbs,
[`fleet-plan.md`](fleet-plan.md) for the invariants, and
[`fleet-m4-backlog.md`](fleet-m4-backlog.md) §4 W10 for what two machines are
still needed to prove.
