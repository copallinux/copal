# command:  lsblk
# purpose:  List the disks and partitions, as a tree, with sizes and mount points.
# why:      The answer to "which device is the card" before anything that
#           writes to one -- sfdisk, dd, mkfs. Stage 5 installs util-linux,
#           which brings it; BusyBox has no lsblk.
# see:      sfdisk, resize2fs, zramctl, dmesg

## Use
Show every block device: whole disks, their partitions beneath them, and
where each is mounted. Run it before and after plugging something in and
the new line is the new device.

## Examples
    lsblk                                # the tree: disks, partitions, mounts
    doas lsblk -f                        # filesystems: type, label, UUID, free space
    lsblk -o NAME,SIZE,TYPE,TRAN,MODEL   # with the bus (usb, sata...) and model
    lsblk -p                             # full paths, /dev/sda1 not sda1
    lsblk -d                             # the disks only, no partitions
    lsblk -J /dev/sda                    # one disk, as JSON for a script

## Options
-f, --fs            filesystem type, label, UUID, available space, use
-o, --output LIST   choose the columns; -H lists them all
-p, --paths         full device paths
-d, --nodeps        whole disks only
-l, --list          a flat list instead of the tree
-J, --json          JSON output
-b, --bytes         sizes in bytes

## Notes
- The names say the bus: `mmcblk0` is an SD card (partitions `mmcblk0p1`),
  `sda` a USB or SATA disk (`sda1`), `nvme0n1` an NVMe drive (`nvme0n1p1`),
  `vda` a virtual machine's disk. A Pi booting from USB has its root on
  `sda`, not `mmcblk0`.
- `-f` without root shows blank FSTYPE and UUID columns: reading them
  means reading the device. Use `doas lsblk -f`.
- `zram0` with `[SWAP]` is Copal's compressed swap in RAM (stage 5), not
  a disk.
