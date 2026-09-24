# command:  copal-logflush
# purpose:  Copy the logs kept in RAM down to the card, and back up at boot -- so they survive, with few writes.
# why:      An SD card wears with every small write. With /var/log in RAM,
#           this chooses when to write: one complete copy each hour and at
#           shutdown instead of a stream of appends. It is log2ram's design, in
#           a few lines of shell.
# see:      copal-logs, rsync

## Use
You do not run it by hand. It runs only if stage 15's "flush periodically"
was chosen: hourly from cron, at shutdown, and at boot to restore.

## Examples
    doas copal-logflush save             # copy the logs down now
    ls /var/log.persist                  # the copy on the card

## Options
save       /var/log (RAM) -> /var/log.persist, then sync (the default)
restore    /var/log.persist -> /var/log (at boot)

## Notes
- It does nothing unless `/var/log` is a tmpfs, so it cannot double the
  writes on a machine logging straight to the card.
- A power cut loses up to an hour of logs; a clean shutdown loses none.
- A log deleted from RAM is deleted from the copy too, by rsync's
  `--delete` where rsync is installed, and by a prune after `cp -a`
  where it is not.
- The hooks are `/etc/periodic/hourly/copal-logflush` and
  `/etc/local.d/copal-logflush.start` and `.stop`.
