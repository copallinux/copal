# command:  sfdisk
# purpose:  Read, save, restore and change a disk's partition table, from a script.
# why:      Stage 8 grows the root partition into the rest of the disk with
#           it, while that partition is mounted -- which parted refuses to do.
#           The same one line claims the space after a VM's disk is enlarged.
# see:      lsblk, resize2fs

## Use
Print a partition table, dump it to a file you can restore, or rewrite it
from lines of input. It never prompts, which is what makes it the tool
for a script -- and the one to run with `-n` first.

## Examples
    doas sfdisk -l /dev/sda              # the partitions, in sectors and sizes
    doas sfdisk -F /dev/sda              # unpartitioned space
    doas sfdisk -d /dev/sda > sda.dump   # save the table as text
    doas sfdisk /dev/sda < sda.dump      # put it back
    echo ', +' | doas sfdisk -n -N 2 /dev/sda  # dry run: grow partition 2 to the end
    echo ', +' | doas sfdisk --no-reread -N 2 /dev/sda  # do it, mounted (stage 8's line)
    doas partx -u /dev/sda                     # tell the kernel the new size

## Options
-l, --list          list the partitions
-F, --list-free     list the free areas
-d, --dump          the table as sfdisk input, to save
-N, --partno N      change partition N only
-n, --no-act        do everything but write
--no-reread         do not refuse because the disk is in use
-X, --label TYPE    create a new table: dos or gpt
--delete DEV [N]    delete partitions
-q, --quiet         fewer messages

## Notes
- `', +'` means: keep the start, make it as large as possible. Changing
  the table does not change the filesystem inside: grow that with
  `resize2fs` afterwards.
- On a disk in use -- the one you booted from -- sfdisk refuses unless
  given `--no-reread`, and the kernel keeps the old sizes until told:
  `partx -u DISK`, as stage 8 does, or a reboot. That refusal is about the
  kernel's copy of the table, not a danger to the data.
- Keep a dump before any change. A table restored from `sfdisk -d`
  output gives back every partition, data included, as long as nothing
  has been formatted in the meantime.
