# command:  copal-logs
# purpose:  Find the logs that matter on a Copal machine, read them, and clear out the old ones.
# why:      The evidence for a desktop that will not start is in a file most
#           people never find. This lists the desktop sessions, the install
#           transcript and the system logs with their sizes, opens the one you
#           want in a pager, and cleans up only what is safe to lose.
# see:      copal-startx, copal-debug, copal-logflush, less

## Use
With no argument it shows what exists and what it costs. `x` opens the
newest desktop session log, `errors` picks out its error lines, `install`
opens the install transcript.

## Examples
    copal-logs                           # what logs there are
    copal-logs x                         # the last desktop session, in less
    copal-logs x 2                       # the one before it
    copal-logs errors                    # (EE), (WW) and error lines only
    copal-logs install                   # what the install stages did
    copal-logs clean                     # remove old sessions and stale .bak files

## Options
status          what exists, and its size (the default)
x [N], session [N]   a desktop session log; N counts back, 1 the newest
list            every desktop session log, newest first
errors          the error and warning lines from the newest session
install         the install transcript (copal.log on the boot partition)
clean           delete old session logs and stale .bak files
clean --all     the same, and rotate the install transcript to .1

## Notes
- The session logs are the X11 desktop's, written by copal-startx into
  `~/.local/state/copal`; a Hyprland session keeps its own log under
  `$XDG_RUNTIME_DIR/hypr`, which this does not read.
- `clean` removes `/etc/inittab.bak`, `/boot/copal-init.sh.bak` and
  `/etc/apk/world.bak`, but only where the original is beside them. Run it
  with doas for those.
- `status` says whether `/var/log` is in RAM (lost at reboot unless the
  flush is on) or on disk.
