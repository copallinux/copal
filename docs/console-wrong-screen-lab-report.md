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

**The install ran to the Desktop phase this way** (Paul's screenshot,
14:06): the progress screen in the Mac's Terminal over SSH, "37% 6 of 16
stages done", System, Memory and Access ticked, Desktop under way
("Installing the X server", "Installing a file manager and a task manager":
pcmanfm, htop, ncdu, mc, jgmenu). The screen itself drew stray text down its
right edge in a 120x33 window ("100Execut", a wrapped mirror address); the
install was not affected, but the progress screen's redraw over SSH at that
size is a defect of its own (backlog B-09).

### The workarounds, all of them

| Workaround | How | State |
| --- | --- | --- |
| **SSH from another machine** | `ssh-copy-id user@<ip>` once, then `ssh user@<ip>`; the auto-resume continues the install in that session | **works**: the install ran to the Desktop phase this way |
| **A VGA monitor** | plug one into the laptop's VGA port: the console is drawn there (it is the screen `nouveau` thinks it has) | should work; not tried |
| **The display-switch key** | Fn plus the key with the two-screens icon (on Acer laptops usually F5) | **does not work**: tried on the 5750G, 27 October; some Fn keys responded, the display switch did not move the console to the panel. The key reaches the kernel as an ACPI video event, and nothing on a text console acts on it |
| **The BIOS** | a graphics setting such as "integrated only" or a switchable-graphics option, if this BIOS has one | unlikely: many laptops of this age have none |

Two things made the SSH route harder than it should be, and both are worth
fixing:

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

## VI-A. Every port is the Intel GPU's: why no monitor shows the console

Paul plugged in a VGA monitor (inconclusive without a power cycle), an HDMI
monitor (blank) and a USB-powered VGA-to-HDMI converter (blank). Read again
over SSH with the converter in:

| Connector | GPU | Before | With the converter |
| --- | --- | --- | --- |
| `card0-VGA-1` | nouveau | connected, EDID 0 bytes | connected, EDID 0 bytes |
| `card1-VGA-2` | i915 | disconnected | **connected**, 1024x768 |
| `card1-HDMI-A-1` | i915 | disconnected | disconnected |
| `card1-LVDS-1` (panel) | i915 | connected, EDID 128 | connected, EDID 128 |

The physical VGA port is `VGA-2`, on the Intel GPU, and so are HDMI and the
panel. `nouveau`'s `VGA-1` answers "connected" whatever is plugged in: a
connector that exists in the NVIDIA VBIOS's tables and is wired to nothing.
This is a "muxless" Optimus laptop: under Windows the GT 520M renders and
hands its frames to the Intel GPU, which owns every output. So **no monitor
on any port can show the console**: all of them are fb1's, and the console
is on fb0, which reaches no glass at all. That is why the VGA monitor, HDMI
and the converter all stayed blank. Reports of the same family agree:
nouveau does not do Optimus output switching, and on Acer Optimus models of
this generation the NVIDIA card drives nothing unless a BIOS
discrete-graphics option exists and is set (sources in section X).

## VI-B. Development: force a choice

Copal leaves the kernel to pick the console's GPU, and on this class of
laptop the kernel picks the one with no outputs. Copal should choose, and
let the person override it.

1. **A boot entry, now, on every PC stick and installed disk:** "Copal
   Linux (Intel graphics only: two-GPU laptops)", the same entry with
   `modprobe.blacklist=nouveau`. Cheap, harmless on machines without
   NVIDIA, and a way through the menu on a 5750G today. Its test is the
   first experiment below.
2. **Detect the pair at install.** Two PCI display devices, one Intel
   (`0x8086`) and one NVIDIA (`0x10de`), with the internal panel (`LVDS` or
   `eDP`) on the Intel one: a muxless Optimus laptop. Then stage 3 makes the
   panel's GPU the console's:
   - **default:** load `i915` first (in `modules=` ahead of the storage
     drivers, and the `kms` feature in the installed initramfs), so
     `i915drmfb` is fb0 and the console is on the panel, while `nouveau`
     still loads for whoever wants the GT 520M (PRIME offload);
   - **if that does not hold:** `modprobe.blacklist=nouveau` as the
     installed default, with the NVIDIA entry kept in the menu.
3. **A question, asked once, in the guided install,** when the pair is
   found: "This laptop has two graphics chips; the screen is on the Intel
   one. Use only it (recommended), or keep the NVIDIA one too?" The answer
   goes in `answers.txt` like the rest (`COPAL_GPU=intel|both`), so an
   unattended install never stops to ask.
4. **The desktop phases** use the same choice: X and Hyprland on the
   Intel GPU, with the NVIDIA one as an offload GPU or not at all, so the
   phantom `VGA-1` does not appear as a second screen.

**Experiments on the 5750G, in order, each one boot:**

| # | What | How | Expect |
| --- | --- | --- | --- |
| 1 | no nouveau | at GRUB, `e` on "Copal Linux", add `modprobe.blacklist=nouveau` to the `linux` line, Ctrl+X | the console on the panel |
| 2 | Intel first | the same, with `i915` added at the front of `modules=` | the console on the panel, and nouveau loaded (`/proc/fb` lists both, i915 first) |
| 3 | the BIOS | F2 at power-on; look for a graphics, switchable or Optimus setting | probably none on this model |

## VII. Discussion

The bug shows only on two-GPU laptops where the GPU without the panel
registers first and guesses a monitor on an empty port. It is invisible in
QEMU (one GPU) and on the desktop PCs of `pc-install-lab-report.md`. What
saved the session was not a fix but a design choice: a Copal machine is on
the network with `sshd` from stage 1, so it can be driven without its
screen.

## IX. Open items

Backlog B-07 (the console on the panel), B-08 (the card's SSH key at
stage 1) and B-09 (the progress screen's redraw over SSH). Tried on the
5750G: the display-switch key, without effect. Still to try: a VGA monitor.

## X. Sources

- [Avoiding NVIDIA Optimus? (CLUG list, 2011)](https://lists.samba.org/archive/linux/2011-July/030397.html): an Acer Optimus laptop of this generation; the NVIDIA card never shows up under Linux with Optimus on.
- [Avoiding NVIDIA Optimus? (follow-up)](https://lists.samba.org/archive/linux/2011-July/030394.html)
- [linux.org.ru: nouveau and Optimus](https://www.linux.org.ru/forum/linux-hardware/5970793): nouveau does not implement Optimus switching; use a discrete-only BIOS setting where there is one.
- [Arch forum: nouveau and a GT 520M](https://bbs.archlinux.org/viewtopic.php?id=143198)
- [freedesktop bug 33445: blank internal panel with nouveau](https://bugs.freedesktop.org/show_bug.cgi?id=33445)
- [LKML: KMS picks the wrong output on a laptop](https://lkml.iu.edu/hypermail/linux/kernel/0910.3/00826.html)
- [LKML: blank screen on boot with i915 and fbdev emulation](https://lkml.iu.edu/hypermail/linux/kernel/1603.3/01088.html): where `fbcon=map:` was tried.
