# Writing a Card from Linux: Three Causes, a Wrong Test, and a Build That Keeps Its Own Log

*Lab Report — IEEE Format · 27 October 2026 · a whole card at run 6*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

---

## Abstract

`make sd-pc` had only ever been run on the Mac. Run on saskatchewan (Copal on
Alpine, as an ordinary user, through `doas`), it stopped three times with a
stick partitioned but incomplete, and asked for the password about ten
times. Three causes, all fixed: the stick's FAT partition was mounted by
root, so the build could not write to it; OpenDoas remembers a password per
parent process, while every disk step was a new process; and `cp -Rp`
exits 1 on Linux after copying everything, because the source folders carry
the setgid bit (inherited from `~/code`), which FAT cannot store. The third
was first named correctly, then wrongly "disproved" by a test that left out
the one property that mattered, and found for certain only once the build
kept its own log, which it now does for every run, naming the line of any
failed command that ends it.

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

## V. The third stop: setgid folders and `cp -Rp`

After a full copy the build reaches, in order: removing macOS metadata
(`dot_clean` if present, then `rm -rf` and `find -delete`, each with `||
true`), the step gate "Write the answer file...", which waits for Enter on
`/dev/tty`, then `cat > "$MNT/answers.txt"`. `answers.txt` was never
written, so it stopped in those few lines.

**A right cause, a wrong test.** Claude first said that `cp -Rp`, the
payload copy, fails on Linux because FAT cannot hold what `-p` keeps, and
that its error ended the build. Then a test seemed to disprove it: `cp -Rp`
of a file in a new folder onto the mounted stick exited 0, as did a folder
of mode `700`; and a copy that had finished all 399 MB seemed unlikely to
have failed. The claim was withdrawn and the cause called unexplained. The
test was wrong, not the claim: it was made in `/tmp`, whose folders carry
no setgid bit.

**Found, with the log** (section VI), on the fourth run:

```
cp: preserving permissions for '.../COPALBOOT/./boot/dtbs-virt': Operation not permitted
cp: preserving permissions for '.../COPALBOOT/./boot/dtbs-lts': Operation not permitted
cp: preserving permissions for '.../COPALBOOT/./boot': Operation not permitted
cp: preserving permissions for '.../COPALBOOT/./EFI/BOOT': Operation not permitted
cp: preserving permissions for '.../COPALBOOT/./EFI': Operation not permitted
cp: preserving permissions for '.../COPALBOOT/.': Operation not permitted
copal-prep.sh: STOPPED at line 2067 (exit 1): ( cd "$SRC" && cp -Rp . "$MNT/" )
```

Only folders, every one of them. On saskatchewan every folder under
`~/code` is `drwxr-sr-x`: the setgid bit, inherited from `~/code` itself,
and so carried by every folder of the cached payload. `cp -p` copies every
file and only afterwards sets each folder's mode, setgid included, which
FAT cannot store: `Operation not permitted`, exit 1, and `set -e` ended the
build after a complete copy. That is the evidence of all three runs. The
Mac's folders have no setgid, which is why it never showed there.

*Reproduced* on the stick: a folder of mode `2755` copied with `cp -Rp`:
the same message, exit 1; with `cp -R`: exit 0.

*Fix:* on Linux the payload is copied with `cp -R`; macOS keeps `cp -Rp`.
Modes and times mean nothing on a FAT boot partition.

**"Partition contains vfat signature."** That warning is `sfdisk`'s or
`fdisk`'s, from the partitioning step much earlier, when the new partition
starts where the previous attempt's FAT was. On its own it is harmless (the
partition is formatted next). Whether it was a question waiting for an
answer, and whether a keystroke meant for a later gate was taken by it, is
not known.

**Why it took a log to find:** the build's output was on Paul's terminal
and the stop was `set -e`'s, which prints nothing; and the test made in its
place had left out the condition that mattered. The log's `STOPPED` line
named the command on the first run that had it.

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

## VI-A. Run 5: two more, found by the log

With `cp -R` the payload copied and the build reached the files it writes
itself, then stopped, by name:

```
tar: unrecognized option '--uid'
error: could not write copal-first.apkovl.tar.gz
```

**4. `--uid 0 --gid 0` is bsdtar's.** The starter overlay was packed with
macOS's tar syntax; GNU tar spells it `--owner=0 --group=0`. Now chosen by
`tar --version`: GNU gets `--owner=0 --group=0 --numeric-owner`, others
`--uid 0 --gid 0`. Checked: both archives list `etc/motd` owned by root
(`root` from bsdtar, `0/0` from GNU tar 1.35).

**5. A good download dropped by its check.** "Ubuntu 26.04 netboot did not
download or did not match its pinned sums", while 24.04 matched. Downloaded
again on saskatchewan by hand, both 26.04 files matched the pins exactly
(and `Last-Modified` was 26 August), so the files were right and the check
was wrong. Since `36dece9` every disk-layer verb had gone through `doas`,
the checksum one included; a `doas` prompt in the middle of the downloads,
unanswered or past `persist`'s window, made the check fail with its output
discarded. Now only the verbs that touch a device go through `doas`
(unmount, mount, partition, type, bootflag, biosboot and its check, eject,
image attach and detach); a checksum, a listing or a probe runs as the
person.

A scan of the host-side build for other macOS-only commands (`sed -i ''`,
`stat -f`, `diskutil`, `hdiutil`, `date -j`, `xattr`, ...) found only
`bsdtar` for reading ISOs, which saskatchewan has (the Extract step passed).

## VI-B. More passwords than ever: `$(...)` is a new parent

After `36dece9` Paul typed the password more often, not less. Alpine's
`doas` (OpenDoas 6.8.2) does support `persist`, and its strings show the key
it remembers a password by: `/run/doas/%d-%d-%d-%llu-%d`, the parent's
PID, session, tty, start time and user. `36dece9` ran every verb through
`doas` from `copal-prep.sh`, but several were called as `VAR=$(disk ...)`
(`mount`, twice; `image-attach`; the boot-code read-back), and a command
substitution is a subshell: a new parent each time, so a new prompt each
time, and more verbs than before went through `doas`. Two changes:

- **Only device verbs through `doas`** (`a480dbc`, VI-A).
- **`disk_to VAR VERB ...`**: the verb runs in the build's own process and
  its output comes back through a temporary file, so the four that need
  root and return output share the build's PID with the rest. Checked on
  the Mac: an image build attached, mounted, wrote and read back the boot
  code through it.

What one run should now ask for: one password, again only if more than
`persist`'s five minutes pass between device verbs.

## VI-C. Run 6: a whole card

At `cc2bee3`, 16:46, 56 s: the first complete Copal card written from
Linux. From its log (`build/copal-prep-20261027-164608.log` on
saskatchewan): netboot.xyz 3.0.3, Ubuntu 26.04 and 24.04 netboot, each "sums
checked"; the starter overlay written; the verifier's `grub.cfg ->` lines
for both kernels and both netboot.xyz files; `ok legacy BIOS: sector 0, p1
active, core.img`; "It is safe to remove /dev/sde"; no `STOPPED`, no
`MISSING`, no error. How many passwords it asked for is Paul's to report.

## VII. Next

Boot the card (the 1080 Ti machine, "Install Ubuntu 24.04 LTS Server"), and
confirm the password count of a Linux write.

## VIII. Discussion

Every one of these is a difference between macOS and Linux that the Mac
could not show: who owns a mounted FAT partition, how the privilege tool
remembers a password, and what the person can see afterwards. The first two
were found by reading the machine's state over SSH; the third needed the
output that had been lost, which is why the build now keeps it. Two lessons
from the third: a cause said aloud should be tested before it is called
found; and a test that disproves a cause must reproduce the conditions of
the failure, here the source folders' setgid bit, or it disproves nothing.
A test made in `/tmp` was not a test of `~/code`.
