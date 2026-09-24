# command:  copal-session
# purpose:  Start this machine's desktop -- Hyprland or X11, whichever /etc/copal/session names.
# why:      One front door for the graphical session. The console login, the
#           autologin and the documentation all say "run copal-session", and a
#           single word in /etc/copal/session decides what that means, so they
#           can never disagree.
# see:      copal-desktop, copal-startx, copal-autologin

## Use
Log in on a console as your own user and run it. With the word `wayland`
(and Hyprland installed) it starts Hyprland; otherwise it runs startx.

## Examples
    copal-session                        # the desktop
    cat /etc/copal/session               # which one it will start
    doas copal-desktop x11               # change it, safely

## Options
(none)

## Notes
- It refuses to run as root: the desktop belongs to the admin user.
- For Wayland it makes `XDG_RUNTIME_DIR` if nothing has (a private
  `/tmp/xdg-runtime-UID`, mode 700, refusing one someone else owns), then
  runs Hyprland through `start-hyprland` when present, inside
  `dbus-run-session` so the session's programs share one bus.
- On the X path, if X's setuid helper has been disarmed it stops and names
  the fix, `doas copal-desktop x11`, instead of letting startx fail with
  "Only console users are allowed to run the X server".
