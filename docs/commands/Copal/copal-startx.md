# command:  copal-startx
# purpose:  Start the X11 desktop as it should be started: not as root, with the right groups, and with a log kept.
# why:      When X fails to start, the reason scrolls off the console it just
#           took over. copal-startx is startx with that fixed: it refuses root,
#           warns about missing groups, and writes every session's output to a
#           file, printing the tail when the desktop exits with an error.
# see:      copal-session, copal-logs, copal-debug, startx

## Use
Run it from a console login instead of `startx`; arguments are passed on to
startx. On the Wayland desktop you want copal-session instead, which picks
the right path for this machine.

## Examples
    copal-startx                         # the X11 desktop, logged
    copal-logs x                         # read the last session's log afterwards
    COPAL_DEBUG=1 copal-startx           # one run with the debug collection

## Options
(none)         start X, passing any arguments on to startx

## Notes
- It refuses to run as root, and says which account to log in as. Plain
  `startx` still works for the day you need a root desktop on purpose.
- It warns if you are not in the `video`, `input` and `tty` groups, with
  the `doas adduser` line that fixes it.
- The log is `~/.local/state/copal/xsession-DATE.log`, with
  `xsession-latest.log` linked to the newest. Two are kept; with debug on
  (`doas copal-debug on`) ten are kept, and Xorg's own log is copied into
  each.
- The log header records the tty, groups and graphics devices -- the facts
  that decide whether X may start and that are gone afterwards.
