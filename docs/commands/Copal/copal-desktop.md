# command:  copal-desktop
# purpose:  Choose which desktop takes the screen at the next login: Hyprland (Wayland) or X11.
# why:      The choice is two settings that must agree: the word in
#           /etc/copal/session, and whether X's setuid server is armed. Setting
#           them in one command means they can never disagree -- and Wayland
#           gets to disarm a root-privileged binary nothing is using.
# see:      copal-session, copal-startx

## Use
`status` (or no argument) shows what is set. `wayland` and `x11` change
it, and need doas; the change takes effect at the next login.

## Examples
    copal-desktop                        # what is set, and whether X is armed
    doas copal-desktop wayland           # Hyprland next time
    doas copal-desktop x11               # back to X11

## Options
status     the session word, and the X server's state (the default)
wayland    Hyprland at the next login; X's setuid server disarmed
x11        startx at the next login; X's setuid server re-armed

## Notes
- `wayland` refuses, changing nothing, if Hyprland is not installed.
- Disarming removes the setuid bit from `/usr/libexec/Xorg.wrap`.
  Xwayland, which runs X programs inside Hyprland, is a separate binary
  and is not affected.
