# Writing a Card from Linux: Three Stops, Two Causes Found, and a Build That Keeps Its Own Log

*Lab Report — IEEE Format · 27 October 2026 · interim: one stop unexplained*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

---

## Abstract

`make sd-pc` had only ever been run on the Mac. Run on saskatchewan (Copal on
Alpine, as an ordinary user, through `doas`), it stopped three times with a
stick partitioned but incomplete, and asked for the password about ten
times. Two causes were found and fixed: the stick's FAT partition was mounted
by root, so the build could not write to it; and OpenDoas remembers a
password per parent process, while every disk step was a new process. The
third stop, after the payload had been copied in full, is not yet
explained. One cause proposed for it, `cp -Rp` failing on FAT, was put
forward and then disproved by a test, and is recorded as such. Since the
evidence had been on a terminal and was gone, the build now keeps its own
log of every run and names the line of any failed command that ends it.

## I. Objective

Write a Copal PC stick from a Linux machine, as the Mac does, and record
where Linux differs.

## II. Materials

| Item | Detail |
| --- | --- |
| Host | saskatchewan: Copal on Alpine 3.24.3, x86_64, user `user` in `wheel`; `doas` with `permit persist :wheel`; GNU coreutils `cp` |
| Stick | SanDisk Ultra USB 3.0, 28.6 GB (`sde`) |
| Checkout | `~/code/copal`, at `f87d68e`, then `cb1a363`, `8016993`, `36dece9` as the fixes landed |
| Watching | the Mac, over SSH: `pgrep`, `/proc/mounts`, `df`, the cache folder, every 10 s |

## III. The runs

| Run | Time | What was seen | Cause |
| --- | --- | --- | --- |
| 1 | about 15:40 | the stick partitioned, `sde1` mounted at `~/.copal/mnt/sde1`, **empty**; no `copal-prep` running | 1 |
| 2 | 15:44:39 to 15:46:09 | the same, again | 1 |
| 3 | 15:50:17 to 15:52:17, at `36dece9` | the payload copied in full (`EFI`, `apks`, `boot`, 399 MB, mounted `uid=1000`); then nothing the build writes itself: no `answers.txt`, `copal-init.sh`, `tools/`, netboot.xyz or Ubuntu; ended about 10 s after the copy. Paul saw "Partition contains vfat signature" | **unexplained** |

And in every run, the password about ten times: cause 2.

## IV. Causes found

**1. The FAT partition belonged to root.** `linux_mount` in
`tools/copal-disk.sh` ran `doas mount /dev/sde1 ...` with no options. FAT
stores no owners, so the mounted tree belongs to whoever mounted it:
`drwxr-xr-x root root`, `vfat rw,...,fmask=0022,dmask=0022`, and
`touch` as `user` answered "Permission denied". The build copies the
payload as the person running it, so it was refused before the first file.
On macOS, `diskutil` mounts a card as the person who plugged it in, which is
why this never showed there.

*Fix* (`cb1a363`, `8016993`): mount with `uid=` and `gid=` of the person,
and if the filesystem refuses those options (not FAT), mount plainly. The
type is not asked for first, because `lsblk` reports no `FSTYPE` to a
non-root user on Alpine, which has no udev. *Checked* in run 3: mounted
`uid=1000,gid=1000`, writable, and the payload copied.

**2. The password, about ten times.** Copal sets `permit persist :wheel`,
but OpenDoas keeps a successful password per *parent process* (its
timestamp is keyed by the parent's PID and session), not per terminal. The
build runs `sh tools/copal-disk.sh VERB` for each disk step, a new process
each time, so each `doas` inside it asked again.

*Fix* (`36dece9`): on Linux, `copal-prep.sh` runs each disk step through
`doas` from its own process, the same for the whole build, so `persist`
covers them all. Inside, the disk layer runs as root, so the person's
`uid:gid` and mount folder are handed in (`COPAL_OWNER`,
`COPAL_MOUNT_ROOT`), or the stick would be root's and under `/root`.
macOS is unchanged: `sudo` remembers per terminal there. *Not yet seen in
a run.*

## V. The third stop, unexplained

After a full copy the build reaches, in order: removing macOS metadata
(`dot_clean` if present, then `rm -rf` and `find -delete`, each with `||
true`), the step gate "Write the answer file...", which waits for Enter on
`/dev/tty`, then `cat > "$MNT/answers.txt"`. `answers.txt` was never
written, so it stopped in those few lines.

**A wrong cause, put forward and disproved.** Claude first said that `cp
-Rp`, the payload copy, fails on Linux because FAT cannot hold owners and
modes, and that its error ended the build. A test disproved it before any
change was made: `cp -Rp` of a file onto the mounted stick, by GNU
coreutils' `cp`, exited 0 (the mount belongs to the user, and `vfat`
accepts the `chmod` silently). It also could not explain the evidence, as
`cp` had copied all 399 MB. The claim is recorded because it was said to
Paul as a finding, and was not one.

**"Partition contains vfat signature."** That warning is `sfdisk`'s or
`fdisk`'s, from the partitioning step much earlier, when the new partition
starts where the previous attempt's FAT was. On its own it is harmless (the
partition is formatted next). Whether it was a question waiting for an
answer, and whether a keystroke meant for a later gate was taken by it, is
not known.

**Why it is still open:** the build's output was on Paul's terminal and the
stop was `set -e`'s, which prints nothing. So the next change was to keep
the evidence.

## VI. The build keeps its own log (`copal-prep.sh`, `Makefile`)

| Change | What it gives |
| --- | --- |
| every run copies all it prints to `build/copal-prep-STAMP.log`; `build/copal-prep-last.log` points to the newest | the output survives the terminal, and can be read over SSH |
| the exit trap prints `Log: <path>   (make lastlog)` | the path is the last thing on screen |
| an `ERR` trap (with `set -E`): `copal-prep.sh: STOPPED at line N (exit X): <command>`, at the top level only (`BASH_SUBSHELL = 0`), since inside `$(...)` a failing command does not end the build | a `set -e` stop names itself |
| `make lastlog [N=40]` | the newest log's path and its last N lines |

The step gates read `/dev/tty`, not standard input, so they are not
affected by the copy. A caller that already logs sets `COPAL_PREP_LOG`.

*Checked* on the Mac: a full `./copal build pc --auto` wrote
`build/copal-prep-20261027-155522.log`, `copal-prep-last.log` pointed to
it, its last line was the `Log:` line, `make lastlog N=6` showed it, and it
had no `STOPPED` line (a complete build must have none). The trap, in a test
script: silent for failures that do not stop the build (`$(false ||
true)`, `if false`, `false && true`, a failing `grep` inside `$(...)`), and
for `cp /nonexistent` inside a function, `STOPPED at line 4 (exit 1)`, the
right line.

## VII. Next

Run 4 on saskatchewan, at the current commit, with the log. Expect one
password; if it stops, `make lastlog` and the `STOPPED` line say where.

## VIII. Discussion

Every one of these is a difference between macOS and Linux that the Mac
could not show: who owns a mounted FAT partition, how the privilege tool
remembers a password, and what the person can see afterwards. The first two
were found by reading the machine's state over SSH; the third needs the
output that was lost, which is why the build now keeps it. A cause said
aloud should be tested before it is called found, and this one was tested
only after it had been.
