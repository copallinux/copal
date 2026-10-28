# Two Machines Called Saskatchewan: Renaming a Copal Machine over SSH

*Lab Report — IEEE Format · 27 October 2026*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

Companion: `docs/legacy-bios-lab-report.md`, section III.A (why the hostname
never changed).

---

## Abstract

A new Copal machine came onto the LAN at 192.168.8.224 named `saskatchewan`,
the name of the census machine at 192.168.8.235. It had been installed from
a card written before the hostname fix of 27 October, when `answers.txt`
pinned every install to the first river drawn. Two machines with one name
confuse anything that goes by name (mDNS, the router's table, a person). It
was renamed `columbia` over SSH, from the Mac, with one `doas` command. A
hostname lives in three files on Copal; the first attempt reached two of
them, because the Terminal wrapped the one long command line and the shell
read the wrapped part as a second command. The rename survives a reboot (the
root is ext4 on the NVMe) and does not touch the machine's SSH host key or
the Mac's login key.

## I. Objective

Give the new machine a name of its own, persistently, without a screen, and
record what a rename has to change.

## II. Materials

| Item | Detail |
| --- | --- |
| Machine | MINIX NEO Z300-0dB, Intel Core i3-N300 (8 cores), 32 GB, 467 GB NVMe; Copal on Alpine 3.24.3, kernel 6.18.59-lts; root ext4 on `/dev/nvme0n1p2`; 192.168.8.224 by DHCP |
| Reached from | the iMac, `ssh user@192.168.8.224` with Paul's key |
| The other `saskatchewan` | the census machine, 192.168.8.235 |

## III. Where the name lives

Read over SSH before the change:

| File | Line | What reads it |
| --- | --- | --- |
| `/etc/hostname` | `saskatchewan` | the `hostname` service at boot |
| `/etc/hosts` | `127.0.0.1 saskatchewan.lan saskatchewan localhost.localdomain localhost` | name lookups on the machine itself (`sudo`/`doas` pause without it) |
| `/etc/network/interfaces` | `hostname saskatchewan` (under `iface eth0 inet dhcp`) | `udhcpc`, which sends it to the router with each lease |

`copal-prep.sh` writes all three from the card's `answers.txt` through
`setup-alpine`. A rename that changes only the first leaves the machine
answering to its old name in its own lookups and on the router.

## IV. Method and what happened

The command given (one line, from the Mac's Terminal):

```
ssh -t user@192.168.8.224 "doas sh -c 'setup-hostname columbia && hostname columbia && sed -i s/saskatchewan/columbia/g /etc/hosts /etc/network/interfaces'"
```

`setup-hostname` is Alpine's own (writes `/etc/hostname`); `hostname` sets
the running name at once; `sed` fixes the other two files.

**What ran.** Pasted into the Terminal, the line arrived broken before
`/etc/network/interfaces`. Inside the quotes a newline ends a command, so
the shell under `doas` ran `setup-hostname`, `hostname` and the `sed` on
`/etc/hosts`, then took `/etc/network/interfaces` as a command and tried to
execute the file: `sh: /etc/network/interfaces: Permission denied` (it is
`-rw-r--r--`, not executable). Nothing was damaged. A second run, of the
first two commands alone, was harmless. The prompt then read
`doas (user@columbia) password:` and the login banner `user@columbia`.

**Read back over SSH:**

| | After |
| --- | --- |
| running name | `columbia` |
| `/etc/hostname` | `columbia` |
| `/etc/hosts` | `127.0.0.1 columbia.lan columbia localhost.localdomain localhost` |
| `/etc/network/interfaces` | **`hostname saskatchewan`**: not reached |

**The last file**, with a command too short to wrap:

```
ssh -t user@192.168.8.224 "doas sed -i s/saskatchewan/columbia/ /etc/network/interfaces"
```

The router learns the new name at the next lease or reboot.

## V. What survives what

| | Changed by the rename? |
| --- | --- |
| a reboot | no: `/etc` is on the ext4 root (a diskless Copal would also need `lbu commit`) |
| the machine's SSH host key | no: `/etc/ssh/ssh_host_*` do not depend on the name |
| the Mac's `known_hosts` entry | no: it is keyed by the address, 192.168.8.224 |
| the login key in `~/.ssh/authorized_keys` | no |

## VI. Discussion

**The cause was upstream.** The duplicate came from a card written before the
hostname fix (`legacy-bios-lab-report.md` III.A): the old `answers.txt` named
every install `saskatchewan`. Cards written since draw a river on each
machine, so this is the last duplicate of its kind; machines installed from
the old cards should be checked and renamed the same way.

**A command for a person to paste should not depend on staying on one
line.** The long line was correct and still went wrong, because the Terminal
wrapped it and the paste carried the break into the quotes. Two ways to make
it safe: give short commands, one per line, each complete on its own; or give
the machine a command of its own. Copal should have a `copal rename NAME`:
check the name (letters, digits, dashes), change all three files, set the
running name, `lbu commit` when the root is diskless, and print the three
lines back (backlog B-11).

## VII. Open items

1. The `/etc/network/interfaces` line on `columbia` (the command in IV).
2. B-11: `copal rename NAME`.
3. Any other machine installed from a card written before 27 October:
   check its name.
