# The Console on a Screen That Is Not There: a Two-GPU Laptop, and Reaching It over SSH

*Lab Report — IEEE Format · 27 October 2026*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

Companion: `docs/legacy-bios-lab-report.md` (the install that led here).

---

## Abstract

After the first install to its own disk, an Acer Aspire 5750G booted Copal
to a blank laptop screen, in the normal entry and, after `exit`, in single
user mode. The machine was running: it answered ping and SSH at
192.168.8.121. It has two graphics processors. The NVIDIA one's driver,
`nouveau`, registers the first framebuffer, and reports its VGA port
connected although nothing is plugged in (an empty EDID). The kernel's text
console attaches to the first framebuffer, so the console was drawn on a
monitor that does not exist, while the laptop panel, on the Intel GPU, stayed
dark. Paul had seen it before: "it uses the old VGA screen before the laptop
screen". It is recorded as a known bug. The workaround is to reach the
machine over SSH from another Copal machine (the fleet's way of working), and
it is enough to finish the install: the resume ran in the SSH session.

## I. Objective

1. Find why the screen goes blank on this laptop while the system runs.
2. Record a workaround that lets the install finish.
3. Name the fixes to try, for later.

## II. Materials

| Item | Detail |
| --- | --- |
| Laptop | Acer Aspire 5750G (`/sys/class/dmi/id`) |
| GPUs | Intel HD Graphics 3000, `8086:0116`, driver `i915`; NVIDIA GeForce GT 520M, `10de:1050`, driver `nouveau` (an Optimus pair) |
| System | Copal on Alpine 3.24.3, kernel 6.18.59-lts, installed to `/dev/sda` by stage 3, booted by legacy BIOS |
| Reached from | the iMac (M1), on the same LAN |

## III. Method

Everything was read over SSH, as `user`, without root and without changing
anything: `/sys/class/drm/*/status`, `enabled`, `modes` and `edid`;
`/proc/fb`; the driver behind each PCI display device; `/proc/cmdline`.
`dmesg` is restricted to root and was not read.

## IV. Results

| Connector | GPU (card) | Status | EDID | Mode |
| --- | --- | --- | --- | --- |
| `VGA-1` | nouveau (card0) | connected, enabled | **0 bytes** | 1024x768 |
| `LVDS-1` (the panel) | i915 (card1) | connected, enabled | 128 bytes | 1366x768 |
| `DP-1`, `HDMI-A-1`, `VGA-2` | i915 (card1) | disconnected | — | — |

`/proc/fb`: `0 nouveaudrmfb`, `1 i915drmfb`. Console: `tty0`. Command
line: `... console=tty0 single` (the single-user entry; the normal entry
behaves the same).

**The cause, as far as reading can take it.** `nouveau` claimed card0 and
fb0 first. Its VGA connector says "connected" with an empty EDID: no monitor
answered, so the connection is a guess (analogue VGA has no reliable way to
say whether a monitor is there). The framebuffer console (`fbcon`) takes fb0
by default, so every console line went to a 1024x768 picture on a VGA port
with nothing on it. The panel belongs to `i915`'s fb1, which has no console.
The screen is "blank" only in that nothing is drawn on it; the system behind
it is up, on the network and running `sshd`.

## V. The workaround: reach it over SSH

The machine was on the network from its first boot (DHCP, 192.168.8.121), and
`sshd` was running. From the Mac:

```
ssh-copy-id user@192.168.8.121     # once, with the account's password
ssh user@192.168.8.121
```

The login ran `~/.profile`, and the install's auto-resume block in it started
the install where stage 3 had left it ("resuming the automatic install in 10
seconds"), in the SSH session, with `doas`. So the install does not need the
screen at all. This is the Copal fleet's way of working
(`docs/fleet-plan.md`): machines on one LAN, reached and driven from another;
here, one machine and plain SSH.

Two things made this harder than it should be, and both are worth fixing:

1. **No key until stage 6.** The card carries `authorized_keys`
   (`ssh-ed25519 paulr@sdf.org`), but it is installed for `user` only at the
   SSH-key stage, so the first connection needed the password and
   `ssh-copy-id`. Installing the card's key at stage 1 would make a machine
   reachable from the Mac from its first boot.
2. **Finding it.** The address came from the console, before the screen
   went. The router's lease table, or the fleet's discovery, is the way when
   there is no screen at all.

## VI. Fixes to try (not made)

| Fix | How | For | Against |
| --- | --- | --- | --- |
| Intel first | add `i915` before the storage modules in `modules=` and the `kms` feature to the installed system's initramfs, so `i915drmfb` is fb0 | the console goes where the panel is, on any Intel+NVIDIA laptop; NVIDIA still works | the installed initramfs grows; needs a test on this laptop |
| map the console | `fbcon=map:1` | one word on the command line | depends on probe order, which is the thing that is unreliable |
| no NVIDIA | `modprobe.blacklist=nouveau` on a laptop whose panel is on Intel | certain, and simple | loses the NVIDIA GPU (and the VGA port) entirely |
| switch the phantom off | `video=VGA-1:d` | stops the false "connected" | the console stays on nouveau's fb0, now with no output: still blank |

The first is the one to try: it puts the console on the panel without giving
up the second GPU. The test is this laptop booting to a visible login.

## VII. Discussion

The bug shows only on two-GPU laptops where the GPU without the panel
registers first and guesses a monitor on an empty port. It is invisible in
QEMU (one GPU) and on the desktop PCs of `pc-install-lab-report.md`. What
saved the session was not a fix but a design choice: a Copal machine is on
the network with `sshd` from stage 1, so it can be driven without its
screen.

## VIII. Open items

Backlog B-07 (the console on the panel) and B-08 (the card's SSH key at
stage 1).
