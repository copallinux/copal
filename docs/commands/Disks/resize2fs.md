# command:  resize2fs
# purpose:  Grow or shrink an ext4 filesystem to fit its partition.
# why:      The second half of stage 8: after sfdisk makes the root partition
#           fill the disk, resize2fs makes the filesystem fill the partition --
#           while it is mounted as /.
# see:      sfdisk, lsblk

## Use
Given only a device, grow its ext2/3/4 filesystem to the size of the
partition. Growing works while mounted; shrinking needs the filesystem
unmounted and checked first.

## Examples
    doas resize2fs /dev/sda2             # grow to fill the partition (mounted is fine)
    doas resize2fs -P /dev/sdb2          # the smallest it could shrink to
    doas e2fsck -f /dev/sdb2             # before a shrink: check, unmounted
    doas resize2fs /dev/sdb2 20G         # then shrink to 20 GiB
    df -h /                              # the new size, as the system sees it

## Options
SIZE     the new size: 20G, 500M; none means the partition's size
-P       print the minimum size and change nothing
-M       shrink to that minimum
-p       show progress
-f       force: skip the safety checks

## Notes
- Order matters. To grow: partition first (`sfdisk`), then `resize2fs`.
  To shrink: `resize2fs` first, then the partition -- the other way round
  cuts the end off the filesystem.
- "Please run 'e2fsck -f' first" before a shrink is not optional: it
  needs a clean check since the last mount. That means from another
  system, or another card, for the root.
- ext4 only. The FAT boot partition (p1) is not resized by this.
