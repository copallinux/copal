# command:  mkinitfs
# purpose:  Build the initramfs: the small first root that finds and mounts the real one.
# why:      Every kernel install and upgrade runs it, through apk's trigger:
#           setup-disk in stage 3, and each `apk upgrade` that brings a new
#           kernel. You call it by hand only after changing what it includes.
# see:      apk, lsblk

## Use
Pack the kernel modules and tools needed to reach the root filesystem --
the disk controller, the filesystem, USB -- into `/boot/initramfs-*`.
Which ones is set by `features=` in `/etc/mkinitfs/mkinitfs.conf`. Add
a feature, then rebuild.

## Examples
    cat /etc/mkinitfs/mkinitfs.conf      # the features this machine uses
    mkinitfs -L                          # every feature there is
    mkinitfs -l | less                   # dry run: the files it would pack
    doas mkinitfs                        # rebuild for the running kernel
    ls /lib/modules                      # the kernel versions installed

## Options
KERNELVERSION   build for that kernel (a name in /lib/modules); default the running one
-L              list the available features
-l              dry run: list the files it would include
-F FEATURES     use these features instead of the config's
-o FILE         write to FILE instead of /boot
-c FILE         read another config file
-C ALGORITHM    compress with gzip (default), xz, zstd, lz4 or none

## Notes
- A root on something the features do not name -- NVMe, LVM, an
  encrypted disk -- boots to "mounting root failed" and an emergency
  shell. Add `nvme`, `lvm` or `cryptsetup` to `features=` and rebuild
  before rebooting onto it.
- After a kernel upgrade, reboot soon: the running kernel's modules have
  been replaced, so loading a new module fails until you do.
- "WARNING: no kernel found" during stage 3 is expected: setup-disk runs
  on the RAM system, which has no kernel package of its own.
