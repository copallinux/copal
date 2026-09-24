# command:  copal-remote
# purpose:  Share this machine's screen on the local network for a limited time: VNC on X11, RDP on Wayland.
# why:      For looking at a fleet machine's screen from the console. The
#           machine decides how -- the server that matches its desktop -- and
#           the limits are set on the machine, not by whoever asks: its LAN
#           address only, a deadline, a switch to forbid it, and a log line at
#           each end.
# see:      copal-fleet-exec, x11vnc, hyprctl

## Use
`start` shares the screen until the deadline (30 minutes unless set
otherwise), `stop` ends it now, `status` says what is running. Starting
again while it runs restarts the clock.

## Examples
    copal-remote status                  # is the screen shared?
    doas copal-remote start              # share it
    doas copal-remote stop               # stop now

## Options
start     share the screen on the LAN address, until the deadline
stop      stop sharing
status    session, server, mode, minutes and address (the default)

## Notes
- On X11 it runs x11vnc on port 5900; on Wayland, hypr-rdp on 3389 with
  the node's certificate. Neither is part of a normal install.
- VNC asks for the fleet's screen password: `COPAL_FLEET_REMOTE_PASSWORD`,
  set by `make answers` and kept on the node in
  `/etc/copal/remote/passwd` (root only). The console's seat answers with
  the same one. With no password set, stage 16 turns sharing off
  altogether, and `start` says why.
- Classic VNC encrypts the login but not the screen, so keep it to a
  network you trust.
- `/etc/copal/remote/mode` set to `off` forbids it -- the setting for a
  machine in a public place. `/etc/copal/remote/minutes` sets the
  deadline; `0` means none.
- Wired interfaces are tried before wireless. Starts and stops go to
  `/var/log/copal-fleet.log`.
