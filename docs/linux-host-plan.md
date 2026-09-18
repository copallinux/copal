<!-- SPDX-License-Identifier: MIT — Copyright (c) 2026 Paul Richeson -->

# Writing a card from Linux

**Copal builds Copal machines, and cannot be built on one.** That is the
oddity this plan removes. `copal-prep.sh` is 31,035 lines of portable shell
with a macOS-shaped hole in exactly one place — the twenty minutes where it
touches a block device — and everything before and after that hole is already
platform-neutral. The payload is *copied*, never executed, so nothing about
the build depends on the host being a Mac except the three programs that find,
partition and mount the card.

## The bar

1. **`tools/copal-disk.sh` owns every call to `diskutil`, `hdiutil` and
   `shasum`.** After this, `grep -c 'diskutil\|hdiutil' copal-prep.sh` counts
   only prose.
2. **Both backends implement every verb.** Not "Linux implements what it
   got to"; a verb missing on one platform is a build that dies at the
   point of no return. The check proves totality and fails on a gap.
3. **The safety promise is unchanged on both.** Nothing erased without the
   device being named; two typed confirmations; the fingerprint re-read
   immediately before the erase. A Linux path that is *easier* to say yes to
   than the macOS one is a regression, not a port.
4. **`make lint` passes on a Copal guest**, and grows the new checks.
5. **`./copal --check` tells a Linux host what it can build**, rather than
   what it is not.

## Why a shim, and what nearly went wrong

The obvious shape is `if macos; then diskutil ...; else lsblk ...; fi` at each
of the twenty-five call sites. That is twenty-five chances to port one branch
and forget the other, in a file where the cost of forgetting is somebody's
external drive.

So: one file, one verb per operation, two backends chosen once at the top.

**The trap this must not repeat is radbeeper's.** A shim whose Linux side can
quietly no-op a verb it does not implement is worse than no shim: the build
walks past `disk_bootflag` doing nothing and the failure surfaces as a card
that does not boot, three steps and ten minutes later, pointing at the
firmware. Therefore every verb is dispatched through a table, an unimplemented
verb is a hard `die`, and `copal-disk.sh verbs` prints the table so the check
can compare the two backends verb for verb.

## The verbs

Fifteen, which is the whole macOS surface and nothing invented:

| verb | macOS | Linux |
|---|---|---|
| `list` | `diskutil list external physical` | `lsblk` on the removable block devices |
| `show DISK` | `diskutil list /dev/DISK` | `lsblk /dev/DISK` |
| `probe DISK` | `diskutil info` → key=value | `lsblk -b` + `/sys/block` → the same keys |
| `part DISK N` | `DISKsN` | `DISKN`, or `DISKpN` when the name ends in a digit |
| `unmount-all DISK` | `diskutil unmountDisk` | `umount` every mounted partition |
| `unmount DISK N` | `diskutil unmount` | `umount` |
| `mount DISK N` | `diskutil mount`, prints `/Volumes/LABEL` | `mount` at a path it makes, prints it |
| `partition DISK ...` | `diskutil partitionDisk MBRFormat` | `sfdisk` + `mkfs.vfat` |
| `type DISK N HEX` | `fdisk -e` heredoc | `sfdisk --part-type` |
| `bootflag DISK N` | `fdisk -e` heredoc | `sfdisk --activate` |
| `eject DISK` | `diskutil eject` | `sync` + `umount` + power-off if available |
| `image-attach PATH` | `hdiutil attach -imagekey CRawDiskImage` | `losetup --partscan --find --show` |
| `image-detach DEV` | `hdiutil detach` | `losetup -d` |
| `image-attached PATH` | `hdiutil info` | `losetup -j` |
| `sha256-check SUMFILE` | `shasum -a 256 -c` | `sha256sum -c` |

`probe` is the load-bearing one. The safety checks in `copal-prep.sh` read
eleven facts about a device, and they must not fork per platform, so `probe`
emits the same eleven keys on both:

```
media_name  size_bytes  size_human  removable  ejectable  internal
virtual     whole       protocol    os_installable        uuid
```

**Where Linux cannot answer, the answer is `unknown` and never a guess.**
`os_installable` has no Linux equivalent, and a port that mapped it to `No`
would silently retire one of the four soft signals. `unknown` is read as *no
signal*, and the check counts how many signals each platform actually
supplies, so the difference is visible rather than absorbed.

## Two things that stop being true

**The mount point is no longer `/Volumes/$BOOT_LABEL`.** macOS mounts by
label, wherever it likes; Linux mounts where told. `mount` therefore *prints*
the path and the caller uses what it gets, which also removes the hardcoded
`/Volumes/...` that `assert_mount_is` compares against.

**`sudo` is no longer the escalator.** Alpine ships `doas`. The shim resolves
one at load and names it; neither is assumed.

## What this plan does NOT claim

**No card has been written from Linux.** There is no reader on this guest, and
`losetup`, `sfdisk` and `mount` all need root, so the ported path cannot be
exercised end to end from a test run. What *is* provable without hardware, and
is what the check does:

- every verb exists on both backends, compared name for name;
- the Linux backend's parsing is correct against **recorded `lsblk`, `losetup`
  and `/sys` output** — fixtures, in the phase-4 sense: not a second
  implementation, a recording and an expected answer;
- `part` names partitions correctly for `sda`, `mmcblk0`, `nvme0n1` and
  `loop0` — the one rule most likely to be got wrong, and the one whose
  failure writes to the wrong node;
- every safety refusal still fires, driven by fixture devices that are an
  internal disk, a 2 TB drive, a non-whole device and a real card.

A first real write, on a card, from a Copal guest, is a hardware run — the
same deferred shape as staticstream phase 4's Pi 2B. It goes on the list; it
is not claimed here.

## Steps

| | |
|---|---|
| **a** | `tools/copal-disk.sh`: the table, both backends, `verbs`, `self-test`. Wired into `make lint`. |
| **b** | `./copal --check` and `REQUIRED_TOOLS` learn that a host can be Linux. |
| **c** | `copal-prep.sh` call sites move to the shim — image path first, then the card path. |
| **d** | The mount point comes from `mount`, and `assert_mount_is` asks the shim which node it should be. |
| **e** | README and handbook say a card can be written from either, and which is better tested. |


---

# What was built

**Done 2026-09-17.** `make lint` passes on a Copal guest and `make configure`
says **Ready** on one for the first time.

| | |
|---|---|
| `tools/copal-disk.sh` | 15 verbs, 2 backends, **59 self-test checks** |
| `copal-prep.sh` | **0** remaining mentions of `diskutil`, `hdiutil` or `shasum` — was 37 |
| `make lint` | passes on Linux, and grew 2 checks |
| `make check` (copal) | still macOS + qemu; unchanged by this work |

**Both new checks were proved to fail before they were believed.**
Renaming `linux_bootflag` gives `SELF-TEST FAILED: verb 'bootflag' has no
linux implementation`; appending `diskutil list` to `copal-prep.sh` gives
`copal-prep.sh reaches a macOS disk program directly` and names the line. A
check that has never failed is a check nobody has read.

## Deviations from the plan above

- **Fifteen verbs, not fourteen.** `sha256-check` was not in the plan. Four
  call sites verify a downloaded tarball with `shasum`, which is macOS's
  spelling of a program the rest of the world calls `sha256sum`; leaving them
  alone would have left the Linux path failing at the *download*, long before
  it reached a disk.
- **`partition` does not set the type bytes, even though `sfdisk` could do it
  in the same script.** It formats both partitions FAT exactly as
  `diskutil partitionDisk MS-DOS MS-DOS` does, and `type` changes p2 to 0x83
  afterwards. Collapsing the two would have made `type` a no-op on Linux and
  load-bearing on macOS — the precise shape of the failure this design exists
  to prevent.
- **The soft-signal gap is announced on screen.** `os_installable` has no
  Linux answer, so a Linux host judges a device on three signals where a Mac
  uses four. The build now says `One signal fewer on this host` rather than
  leaving it in a comment.
- **`priv` has three cases, not two.** Already root is the third, because
  `make redeploy` runs as root and a `doas` inside it is a password prompt for
  nothing.
- **Linux `partition` waits for udev.** `sfdisk` returns before the partition
  nodes exist, and `mkfs` on a node that is not there yet is the classic flake
  on this path. It polls for up to five seconds.
- **`assert_mount_is` changed meaning.** It compared against `/dev/${DISK}s1`,
  a spelling that can only ever be right on macOS; on Linux it would have
  fired on every build. It now asks the disk layer what partition 1 of this
  device is called.

## Still outstanding

**No card has been written from Linux.** There is no reader on this guest and
the write path needs root, so the port is proved by fixtures, totality and
`sh -n` — not by a card that boots. That first real write is a hardware run,
the same deferred shape as staticstream phase 4's Pi 2B, and it is the one
thing between this and "Linux is a supported host" without a footnote.
