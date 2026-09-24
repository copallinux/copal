# command:  rsync
# purpose:  Copy and synchronise files, locally or over SSH, sending only differences.
# why:      Stage 11's snapshots are rsync, and so is moving a home directory to
#           a new card or a backup to another machine; the catalogue carries it
#           for copying trees between machines.
# see:      ssh, lftp

## Use
Keep one tree identical to another. Only changed files cross, and only the
changed parts of them, so the second run over a large tree takes seconds.

## Examples
    rsync -av ~/Photos/ /media/usb/Photos/     # copy a tree, keeping times and modes
    rsync -avz --delete ~/code/ pi:code/       # mirror to another machine over SSH
    rsync -avn --delete src/ dst/              # dry run: what would change
    rsync -aP big.iso pi:/tmp/                 # resumable, with a progress bar
    rsync -aHAX / /media/snapshots/today/      # a whole system: links, ACLs, attributes

## Options
-a                archive: recursive, keeps symlinks, modes, times, owner, group
-v                name each file
-z                compress in transit (for a slow link, not a LAN)
-n                dry run
-P                --partial --progress: keep partial files, show progress
--delete          remove files in the destination that the source lacks
-e 'ssh -p 2222'  the remote shell, with its options
--exclude=PATTERN skip matching paths
-H -A -X          keep hard links, ACLs and extended attributes

## Notes
- The trailing slash is the whole question. `src/` copies the contents of
  src; `src` copies the directory itself, into the destination.
- `--delete` with the wrong direction or a missing slash deletes the wrong
  files. Run it with `-n` first.
- `-a` does not keep hard links, ACLs or extended attributes; add `-HAX`
  for a system copy, as the snapshot stage does.
