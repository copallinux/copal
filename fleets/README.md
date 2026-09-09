# `fleets/` — what a day looks like, written down

One directory per fleet. `fleets/example/` is the template; `copal fleet init`
copies it to `fleets/<name>/` with the fleet's name, its login account and its
certificate authority's fingerprint filled in.

**These files are meant to be committed.** That is not tidiness, it is
invariant 7: *the fleet executes what the console's repository says, not what
the network says.* A scene is a thing that runs on eight machines at once, so
it has to be reviewable, diffable and — for the pull half — signed. Nothing
secret lives here. The private half of the CA, the operator key and the token
ledger are in `~/.copal/`, which is not a git checkout and never becomes one.

```
fleets/<name>/
  fleet.toml          the room: which nodes, how their power switches,
                      what each scene needs before it can run
  ansible.cfg         doas as the become method, host key checking ON
  requirements.yml    two collections, on the console only
  inventory/
    copal_fleet.py    the host list, out of discovery. Never edited by hand
    static.ini        the fallback when discovery is off
  group_vars/all.yml  attachments, packages, the pull repo, the display
  scenes/             wake · show · reset · rest · sleep
  roles/
    copal_node/       what is true of every node
    copal_display/    the screen, and today's program
```

## The day

```
copal fleet scene            what scenes exist
copal fleet scene wake       power on, wait for beacons, mount, ready
copal fleet scene show       screens on, today's program up
copal fleet scene reset      between visitors: restore home, start clean
copal fleet scene rest       screens dark, machines up
copal fleet scene sleep      flush logs, halt, and confirm each one went
```

`--check` reports what would change and changes nothing. `--node museum-03`
and `--tag front` narrow it. `--pass` asks for the doas password once and
reuses it for every host, which is what the two scenes that become root need.

## What the console does, and what Ansible does

The console does the three things a playbook cannot. **Power**, because a
machine that is off has no SSH port to connect to. **Waiting**, because an
inventory cannot wait for itself to fill. **Recording** what the fleet is now
doing. Everything that happens *on* a node is Ansible's, because a playbook is
reviewable and a shell loop over `ssh` is not.

Ansible logs in as the **human account** with the 8-hour operator certificate —
not as `copal-fleet`, which has a forced command by design, and a forced
command cannot run a module. Host key checking stays **on**: `copal fleet
trust` put one `@cert-authority` line in `known_hosts`, so every node in the
fleet validates with no prompt, and a host key that *changes* is an error
somebody can explain rather than a warning an operator has learned to click
through.

## What you need on the console

`ansible-core`, plus `community.general` (the `apk` module and the `doas`
become plugin) and `ansible.posix` (`mount`). The `ansible` package bundles
both; with `ansible-core` alone:

```sh
ansible-galaxy collection install -r fleets/<name>/requirements.yml
```

Plus **eyes**, if this console is a Linux machine that is not itself a node:

```sh
doas apk add avahi-tools dbus
doas rc-service dbus start && doas rc-service avahi-daemon start
```

This is the one prerequisite nothing installs for you, and the asymmetry is
worth naming. A **node** gets it from stage 16 whenever its card says
`DISCOVERY=mdns`. A **Mac** never gets it, by design — it browses `--via` a
node, because the Mac is the certificate authority, not the eyes. A separate
Linux console falls between the two and has to be told once. Without it every
verb that reads a beacon stops with the command above; `--via HOST` and a
written `nodes` list are the two ways round it.

On a **node**: `python3`, which stage 7 installs, and nothing else. A node
without it is still fully drivable by `copal fleet run`, which needs nothing
but sshd — invariant 8, in the one place it is most likely to be needed.

## Push and pull

Push is the console pressing a button: immediate, and it reports which nodes
were unreachable. Pull is `ansible-pull` under `crond` with a randomised delay,
and it exists for the machine that was switched off during the push — a Pi
unplugged all week comes back, pulls, and converges without anybody
remembering it existed. Set `copal_pull_repo` in `group_vars/all.yml` to turn
it on; it is off by default because `ansible-core` on the node costs about
50 MB of a card that has other uses.

The pull job runs `ansible-pull --verify-commit`, so **the repository it pulls
from has to have signed commits**. An unsigned repo makes the job fail every
hour, quietly, in `/var/log/copal-pull.log`. That is the correct failure —
invariant 7 again — but it is a surprising one if nobody told you, so this did.
