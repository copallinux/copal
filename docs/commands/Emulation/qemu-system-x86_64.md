# command:  qemu-system-x86_64
# purpose:  Emulate a whole 64-bit PC: boot another operating system inside a window on the Pi.
# why:      The store's PC emulator, on the 64-bit boards: run an x86 Linux,
#           a BSD or DOS inside Copal. On an ARM board it emulates the CPU in
#           software, so it works everywhere and fast nowhere.
# see:      waydroid, mednafen

## Use
Make a disk image with `qemu-img`, then boot an installer ISO with it
attached. `-m` sets the memory, `-smp` the CPUs; the display opens in a
window.

## Examples
    qemu-img create -f qcow2 disk.qcow2 20G                    # a 20 GB disk that grows as used
    qemu-system-x86_64 -m 2G -smp 2 -hda disk.qcow2 -cdrom install.iso -boot d   # install
    qemu-system-x86_64 -m 2G -smp 2 -hda disk.qcow2            # boot the installed system
    qemu-system-x86_64 -m 1G -nographic -hda disk.qcow2        # serial console, no window
    qemu-system-x86_64 -accel help                             # the accelerators this build has

## Options
-m SIZE          memory: 1G, 2048M
-smp N           CPUs
-hda FILE        the first disk
-cdrom FILE      an ISO in the CD drive
-boot d          boot from the CD (c for the disk)
-nographic       no window: the console on this terminal
-accel NAME      tcg (software) is what an ARM board has
-bios FILE       firmware: /usr/share/qemu/edk2-x86_64-code.fd for UEFI

## Notes
- On an ARM Pi there is no KVM for x86: every instruction is translated,
  so a guest runs at a small fraction of native speed. Small, text-mode
  systems are the good fit.
- `qemu-img` comes with it as an optional from 24 Sep 2026; before that,
  `doas apk add qemu-img`.
- 64-bit boards only: its row is gated to aarch64 and x86_64.
