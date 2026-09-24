# command:  lbu
# purpose:  Save a RAM-resident Alpine system's changes to disk (the apkovl).
# why:      Copal's first two stages run from RAM, the way Alpine boots from a
#           card, and anything they change is gone at the next boot unless
#           lbu commits it. Stage 3 moves the system onto the disk; after
#           that, lbu has nothing to do.
# see:      setup-alpine, apk

## Use
On a diskless Alpine system, every file lives in RAM. `lbu commit`
packs the changed configuration -- `/etc` and the list of installed
packages, by default -- into an `.apkovl.tar.gz` on the boot medium, and
the next boot unpacks it. On an installed Copal machine (every machine
past stage 3) you will not need it.

## Examples
    lbu status                           # what changed since the last commit
    lbu diff                             # the same, as a diff
    doas lbu commit -d                   # save, and delete the older archive
    doas lbu include /root/notes.txt     # track a file outside /etc
    lbu include -l                       # what has been added to the set
    lbu list                             # every file the next commit will pack

## Options
commit, ci        write the apkovl to the medium
-d                with commit: remove the old apkovl first
-n                with commit: dry run, show what would be packed
status, st        changes since the last commit (A added, U updated, D deleted)
diff              the changes as a diff
include, add      add a file or directory to what is saved
exclude, ex       leave one out
list, ls          the files that would be packed
list-backup, lb   the older timestamped archives
revert REV        go back to one of them

## Notes
- Only `/etc` and apk's world are saved unless you `lbu include`
  more. A home directory in RAM is lost at every reboot.
- The medium is `LBU_MEDIA` in `/etc/lbu/lbu.conf` -- the boot partition.
  Copal sets it from the partition it actually booted from (a Pi's
  mmcblk0p1, a PC's sda1, a VM's vda1).
- `df /` says which kind of system this is: a disk partition means
  installed, and lbu does not apply; `tmpfs` means diskless, and it does.
