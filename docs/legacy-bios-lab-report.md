# Legacy BIOS from a Mac, a Hostname That Never Changed, and a First Login That Says What to Do

*Lab Report — IEEE Format · 27 October 2026*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences. The two GRUB files in
`vendor/grub-i386-pc/` are GRUB's, under the GNU GPL version 3 or later (see
`vendor/grub-i386-pc/SOURCE`).

---

## Abstract

Three changes to how a Copal card is written, each with its cause:

1. **The hostname.** Four machines in a row were called `saskatchewan`. The
   random picker was uniform and correct; it never ran. `make answers` saved
   the first river it offered into `answers.txt`, every later run offered the
   saved name back, and the name was fixed on the card at write time, so one
   card named every machine installed from it alike. The hostname is now
   `random` unless a name is typed: stage 1 draws a river from `waters.txt` on
   the card, on the machine, with `/dev/urandom`.
2. **Legacy BIOS.** Copal was UEFI-only, for a stated reason: a BIOS boot needs
   boot code written into sector 0 and the sectors before partition 1, and the
   tools that write it are Linux tools, while cards are written on a Mac. But
   for an MBR disk whose partition 1 starts at sector 2048, what `grub-install`
   writes is the same bytes on every card. They are now built once on Alpine
   (`tools/grub-bios-build.sh`), kept in `vendor/grub-i386-pc/`, and written by
   `dd` (`copal-disk.sh biosboot`). One PC card now boots both ways.
3. **The first login.** A fresh card booted to Alpine's stock "Welcome to
   Alpine!". It now carries a starter overlay, `copal-first.apkovl.tar.gz`,
   whose `/etc/issue` says to log in as root and whose login message says to
   look at `answers.txt` and run `copal-init.sh`; after stage 1 the same
   message says how to carry on, at every login until the install is done.

Tested in QEMU on the Mac: SeaBIOS (a legacy BIOS) boots a freshly written
card as a USB stick through the new boot code to Copal's login prompt, with
the new message. The results are in section IV.

## I. Objective

1. Find why the random hostname kept coming out the same, and make it change
   on every install.
2. Boot a Copal USB stick on a PC set to legacy (CSM, MBR) boot, written on the
   Mac as before, with no Linux tool on the Mac.
3. Make the first login, and every login until the install finishes, say what
   to do next.

## II. Materials

| Item | Detail |
| --- | --- |
| Writing machine | Apple M1 Mac, macOS (Darwin 25.6), the repository at `164ebd5` plus this work |
| Alpine machine | `saskatchewan`, a Copal (Alpine 3.24.3) x86_64 PC, used as an ordinary user, nothing installed |
| GRUB | Alpine `grub` and `grub-bios` 2.14-r0, fetched with `apk fetch`, run from the unpacked package |
| Emulator | QEMU (Homebrew) `qemu-system-x86_64`: `-machine pc` with its default SeaBIOS for legacy; `-machine q35` with `edk2-x86_64-code.fd` for UEFI |
| Test images | `build/copal-pc.img` from 10 September (a copy); a fresh `./copal build pc --auto` image |
| Alpine initramfs source | `/usr/share/mkinitfs/initramfs-init` on saskatchewan, read for the overlay rules |

## III. Techniques

### A. Finding why the hostname never changed

The pool and the picker were read first (`copal-prep.sh`, `hostname_pool` and
`random_hostname`): 298 names, `$RANDOM` with the short tail rejected, so the
pick is uniform. That ruled out the picker and pointed at its callers:

- `copal-prep.sh` takes `CFG_HOSTNAME` from `COPAL_HOSTNAME` in `answers.txt`
  before falling back to `random_hostname`, and `answers.txt` held
  `COPAL_HOSTNAME='saskatchewan'`.
- `tools/copal-answers.sh` offered `${COPAL_HOSTNAME:-$(random_hostname)}`,
  and its own note said why the name stuck: "Once answers.txt exists its own
  hostname is the default, not a new one."
- The name went onto the card as `HOSTNAMEOPTS="-n saskatchewan"` in the
  card's `answers.txt`, which setup-alpine reads on the machine. So even a new
  draw per card would give every machine installed from one card the same
  name.

**The fix moves the draw to where the install happens.**

| Where | Before | After |
| --- | --- | --- |
| `make answers` | offers a drawn river, saves it | offers `random`, saves `random` unless a name is typed |
| `copal-prep.sh` | writes the name into the card's `answers.txt` | for `random` (or unset) writes `COPAL_RANDOM_WATER` there, and the 298 names to `waters.txt` |
| stage 1, on the machine | setup-alpine reads the card's file | `setup_answers` draws a river, writes a copy in `/tmp` with it filled in, and setup-alpine reads the copy; the card keeps saying `random` |
| a machine set up before | — | keeps its own hostname when stage 1 is re-run |
| a fleet card | `fleet-NN` | unchanged |

The draw (`draw_water`): 16 bits from `/dev/urandom` with `od`, the tail that
would favour the front of the list drawn again, the line picked with `sed`.
No pool on the card (an older card) gives `copal-XXXX`. Busybox has every
tool it uses.

**Tested** in a shell harness on the Mac with the real pool: four runs of
`setup_answers` gave `zapata`, `winnebago`, `columbia`, `xingu`; 600 draws
covered 254 of the 298 names (chance predicts about 258); an empty pool and a
missing pool both gave `copal-XXXX`; the card's `answers.txt` still read
`COPAL_RANDOM_WATER` afterwards. The harness also caught a bug before it
shipped: `grep -c . file || echo 0` prints `0` twice on an empty file, since
`grep -c` prints the count *and* fails.

Paul's own `answers.txt` was changed to `COPAL_HOSTNAME='random'` (it is
gitignored).

### B. Legacy BIOS boot, written from a Mac

**1. What a BIOS needs.** A BIOS loads sector 0 and runs its first 440 bytes.
GRUB's `boot.img` fits there; it loads `core.img` from the sectors between the
partition table and partition 1 (the "MBR gap"), and `core.img` reads
`grub.cfg` from a filesystem. On an MBR disk, `grub-install` does exactly two
writes: `boot.img` into sector 0 (keeping the partition table), and `core.img`
from sector 1 onward.

**2. Why those bytes are the same on every card.** Both layouts Copal writes,
`diskutil partitionDisk ... MBRFormat` on the Mac (read with `fdisk` from two
images it wrote) and the `sfdisk` script on Linux (which aligns to 1 MiB by
default), put partition 1 at sector 2048, leaving 2047 free sectors.
`biosboot` checks this on every card rather than trusting it. The bytes were then read out of the files:

| Field | Where | Value as built | What it means |
| --- | --- | --- | --- |
| kernel sector | `boot.img` 0x5C, 8 bytes | 1 | load `core.img` from sector 1 |
| boot drive | `boot.img` 0x64 | 0xFF | use the drive the BIOS booted from |
| drive check | `boot.img` 0x66, 2 bytes | `EB 05` (a jump) | `grub-bios-setup` writes `90 90` here for a hard disk |
| blocklist | `core.img` bytes 500 to 511 | start 2, length 298, segment 0x0820 | the rest of `core.img` is sectors 2 to 299 |

`grub-mkimage` already ends the first sector of `core.img` with the blocklist
for "embedded at sector 1". So the only patch `grub-bios-setup` would make is
the drive-check NOP, which lets a BIOS that passes a wrong drive number (some
do, for USB) still boot. The prefix is built in as `(,msdos1)/boot/grub`:
partition 1 of whichever disk the BIOS booted, with no UUID and no label, so
one `core.img` serves every card.

**3. Building them without installing anything.** On saskatchewan, as an
ordinary user: `apk fetch grub grub-bios` downloads the packages without
installing them, `tar -xzf` unpacks each `.apk` (gzipped tar segments; the
signature segment's complaint is harmless), and `grub-mkimage` runs from the
unpacked tree (`ldd` showed its libraries already present). Every module
`grub.cfg` needs is built into `core.img` (`biosdisk part_msdos fat normal
linux echo test search search_label search_fs_uuid configfile ls minicmd cat
halt reboot`, 152,900 bytes, 299 sectors), because the card carries no
`i386-pc/` module directory. `tools/grub-bios-build.sh` does all of this and
checks the two facts above, so a GRUB that ever changes them fails at build
time instead of at a black screen.

**Not taken:** `grub-bios-setup` on a disk image file. GRUB 2.14 guesses the
root device from the directory holding `core.img`, found the Alpine
machine's own NVMe partition, and failed; 2.14 has no option to name it. A
loop device would work but needs root on the census machine. Reading the
format and writing the bytes was smaller, and every byte is checked.

**4. Writing them: `copal-disk.sh biosboot DISK DIR`.** A new verb in the disk
layer, with both backends, so the self-test's totality check covers it (61
checks pass). It is host-independent; each backend only names the raw device
(`/dev/rdiskN` on macOS, `/dev/sdX` on Linux). In order, it:

1. reads sector 0 and refuses a disk with no `0x55AA` signature;
2. reads partition 1's start (offset 454) and refuses if it is not past
   `core.img` (an old 63-sector layout);
3. builds the new sector 0: `boot.img`'s first 440 bytes, then the disk's own
   bytes 440 to 511 (disk signature and partition table), the drive-check NOP,
   and partition 1 marked active (0x80 at 446, the other three cleared);
4. writes `core.img`, padded to whole sectors (a raw device refuses part of
   one), from sector 1, then the new sector 0.

The active flag is set here, not by the existing `bootflag` verb, because
`bootflag`'s macOS form is `fdisk -e` behind sudo, which rewrites sector 0
itself; and the write is placed after the build's boot-flag step for the same
reason. Some BIOSes will not offer a USB stick with no active partition;
UEFI ignores the flag.

Two details came from testing:

- The first write to sector 0 of a just-attached image was refused once and
  accepted at once when repeated; macOS's Disk Arbitration was still probing
  the disk. Each write is tried five times, a second apart.
- **On the first real stick, every write to sector 0 was refused.** `make
  sd-pc` printed `could not write the boot sector to /dev/rdisk4`, and `mount`
  showed both partitions back under `/Volumes` (FSKit, macOS's FAT driver
  since macOS 15): Disk Arbitration mounts them again within seconds of an
  unmount, and macOS refuses a write to the partition table of a disk with a
  partition mounted. Sectors 1 onward are not refused, so `core.img` was
  written and sector 0 was not. Each try now unmounts the whole disk
  immediately before it writes, and a refusal prints `dd`'s own message.
  Tested on an image with both volumes mounted on purpose: written, p1
  active. (The QEMU image builds had not shown it: an attached image is not
  remounted the same way.)
- An image attached by the user has a device node the user can write, so
  `dd` runs without sudo when the device is writable and through `priv` when
  it is not (a real card). That keeps `./copal build --auto`, which has no
  sudo password, able to write the boot code.

**5. Testing without the target PC.** QEMU's `-machine pc` firmware is
SeaBIOS, a legacy BIOS, and `-device qemu-xhci -device usb-storage` presents
the image as a USB stick, as on the target. `-snapshot` keeps the image
unchanged. With no display (`-display none`), screens were taken through the
QEMU monitor on a Unix socket (`screendump`, a PPM, converted with `sips`),
and keys sent the same way (`sendkey`).

A control isolates what is new: the same image under UEFI (`-machine q35`
with EDK2). On the 10 September image both stopped at the same line,
`Mounting boot media: failed`, so that stop was not the BIOS path. It is
fault 4 of `pc-install-lab-report.md` (the netboot initramfs has no
`sd_mod`), fixed after that image was built; a fresh image was built for the
real test (section IV).

### C. The first login's message

**1. Where the message can live.** A fresh card has no saved configuration
(apkovl), so the machine boots a stock Alpine root and nothing Copal writes
into `/etc` exists yet. Alpine's initramfs unpacks an apkovl from the boot
medium over `/` at boot, so the message travels as one:
`copal-first.apkovl.tar.gz`, written by `copal-prep.sh`, owned by root
(`tar --uid 0 --gid 0`), with no macOS metadata (`COPYFILE_DISABLE=1`).

| File | Shown | Says |
| --- | --- | --- |
| `etc/issue` | before the login prompt | not set up yet; log in as root, no password until setup |
| `etc/motd` | after login | a one-line Copal banner |
| `etc/profile.d/copal-setup.sh` | after login, every login | before stage 1: look at `answers.txt` (`less /media/usb/answers.txt`), then `sh /media/usb/copal-init.sh`; after stage 1: how to carry on (`doas` for the user); silent while the auto-resume block in `.profile` is doing the same job |
| `etc/.default_boot_services` | — | empty; see below |

The path is not written in: the script finds the medium (`/boot` after stage
3, `/media/*` before) by the `copal-init.sh` on it, so the same message is
right on a stick (`/media/usb`), an SD card and an installed disk.

**2. Two rules from Alpine's initramfs source**, read on saskatchewan
(`/usr/share/mkinitfs/initramfs-init`, mkinitfs 3.24):

- Line 972: the default boot services (devfs, dmesg, mdev, hwdrivers,
  modloop, networking and the rest) are added only if there is no overlay
  *or* the overlay contains `etc/.default_boot_services`. An overlay without
  it boots a machine with no device manager and no network. The starter
  carries the empty file; the initramfs deletes it after use.
- Line 941: with more than one overlay on the medium it loads only the first
  it finds (`head -n 1`). So stage 1 deletes the starter before its `lbu
  commit`, or the next boot could load the starter and pass over the saved
  configuration. What the starter put in `/etc` is part of the running system
  by then, so the commit carries the message forward.

**3. Where it ends.** `copal-init.sh` removes `copal-setup.sh` when the menu's
next suggestion is `v` (every stage done), and `auto_finish` removes it when
an automatic install completes. `apkovl_exists` now ignores the starter, so
every check that asks "has stage 1 run?" still answers correctly.

## IV. Results

| Test | Result |
| --- | --- |
| `copal-disk.sh self-test` | 61 checks pass, 16 verbs, both backends |
| `bash -n` on `copal-prep.sh`, `copal-answers.sh`; `sh -n` on `copal-disk.sh` | pass |
| `biosboot` on a copy of the 10 September image | `core.img` read back identical; kernel sector 1, drive check `90 90`; partition table bytes unchanged |
| SeaBIOS, that image as a USB stick | GRUB ran from sector 0 and read the card's `grub.cfg`: "Booting `Copal Linux (lts -- real hardware)'"; the kernel and initramfs started; then `Mounting boot media: failed` |
| EDK2 (UEFI), the same image | the same stop at the same line: the old image's fault, not the BIOS path |
| hostname draw harness | a different river each run; 254 of 298 names in 600 draws; fallbacks work; the card's file unchanged |
| fresh `./copal build pc --auto` | built; `fdisk` shows partition 1 active (`*`) at 2048; `core.img` read back identical; `copal-first.apkovl.tar.gz` holds the four files, root-owned; `waters.txt` 298 lines; the card's `answers.txt` reads `COPAL_RANDOM_WATER` |
| SeaBIOS, the fresh image as a USB stick | **boots to the login prompt.** GRUB from sector 0, its menu, the kernel, "Mounting boot media" ok, modloop, mdev, hardware drivers and every default service started (so `.default_boot_services` worked), then the starter's `/etc/issue`: "Copal Linux on Alpine 6.18.35-0-lts (/dev/tty1) / Not set up yet. Log in as root -- there is no password until setup." |
| the message after logging in as root | the banner, then "Copal: this machine is not set up yet. ... Look at them first: `less /media/sda1/answers.txt` ... Then start the install (as root): `sh /media/sda1/copal-init.sh`". QEMU's initramfs mounted the stick as `/media/sda1`; on the PCs of `pc-install-lab-report.md` it was `/media/usb`, which is why the script finds the path rather than naming it. (A first run's monitor socket stopped answering after the key presses; the second, sending every command over one connection, worked.) |

`shellcheck` was not run: it is not installed on this Mac (`make shell-lint`
needs it).

## V. Discussion

**What "legacy" covers so far.** The stick boots under a BIOS. Installing to
the PC's internal disk on a BIOS machine does not yet: stage 3
(`prepare_root_disk`) lays out GPT with an EFI partition and puts GRUB at
`\EFI\BOOT\`, which a BIOS cannot run. The installer already detects the
firmware (`firmware_mode`). On a BIOS machine it should lay the disk out as
MBR (or add the 1 MiB `bios_grub` partition GPT needs) and run `grub-install
--target=i386-pc`, which is easy there because stage 3 runs on Linux. Until
then, a BIOS machine runs Copal from the stick, diskless, which is how the Pi
runs it.

**A DVD.** A hybrid ISO (El Torito for BIOS and UEFI, and an MBR so the same
file copied to a stick boots) is how Alpine ships its own; `xorriso` builds
one, on the Mac or on Copal. A DVD is read-only, so `lbu commit` cannot save
the configuration to it: it would be an installer or a live disc, saving to a
stick or a disk.

**The GPL.** `vendor/grub-i386-pc/` is the first GRUB code kept in the
repository; the UEFI GRUB is still taken from Alpine's ISO at build time.
`SOURCE` names the Alpine packages and their corresponding source. If the
project would rather keep no GPL binaries, the alternative is to run
`tools/grub-bios-build.sh` on a Copal machine or the VM at build time.

**Why not syslinux.** Alpine's own ISO boots BIOS through isolinux. Copal
already reads one `grub.cfg` for UEFI; a second boot loader with a second
configuration is two menus to keep in step. GRUB for both keeps one.

## VI. Trying it on the target PC

1. `git pull`, then write the stick as before (`make sd-pc` or `./copal build
   pc`). The build log says "Writing GRUB's legacy-BIOS boot code".
2. In the PC's firmware setup: enable CSM / Legacy boot (sometimes "Launch
   CSM", "Legacy Support" or "Boot Mode: Legacy"). Secure Boot has to be off
   for CSM on most boards.
3. In the boot menu, choose the stick's entry *without* "UEFI:" in front of
   it. Many menus list one stick twice, once per mode; the plain one is the
   BIOS boot.
4. Expect the GRUB menu ("Copal Linux (lts -- real hardware)"), then the
   login prompt with the Copal message. Log in as root.

If it stops before the GRUB menu, a photo of the screen says where: a blinking
cursor means sector 0 ran but `core.img` did not load; "GRUB" and an error
means `core.img` ran but could not read partition 1.

## VII. Open items

1. Stage 3 on a BIOS machine: MBR or `bios_grub`, and `grub-install
   --target=i386-pc`.
2. A hybrid ISO for DVD and stick (`xorriso`).
3. `shellcheck` over the changed scripts on a machine that has it.
4. The first test on Paul's target PC.
