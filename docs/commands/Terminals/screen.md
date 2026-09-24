# command:  screen
# purpose:  GNU Screen: terminal sessions that survive disconnection, with windows inside one terminal.
# why:      The catalogue's original multiplexer, beside tmux: on nearly every
#           Unix, and still the one many guides and serial-console recipes use
#           -- `screen /dev/ttyUSB0 115200` is a serial terminal.
# see:      tmux, byobu, abduco

## Use
Start a session, run programs in its windows, detach with Ctrl-a d, and
reattach later -- from this machine or over SSH. Every key starts with the
prefix Ctrl-a.

## Examples
    screen -S build                      # a named session
    screen -ls                           # the sessions running
    screen -r build                      # reattach
    screen -d -r build                   # reattach, detaching it elsewhere first
    screen /dev/ttyUSB0 115200           # a serial console at 115200 baud

    Ctrl-a d       (inside) detach
    Ctrl-a c       a new window;  Ctrl-a n / p  next / previous
    Ctrl-a [       scrollback: move with the arrows, Esc to leave
    Ctrl-a ?       every key

## Options
-S NAME      name the new session
-ls          list sessions
-r [NAME]    reattach
-d -r        detach elsewhere, then reattach here
-x           attach without detaching (share the session)
-L           log the window to screenlog.0

## Notes
- A serial device needs the group `dialout`; leave a serial session with
  Ctrl-a k.
- tmux is Copal's default multiplexer (stage 7); screen is here for the
  habits and recipes that name it.
