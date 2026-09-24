# command:  copal-bar
# purpose:  Start the desktop's bar and widgets with whichever shell the machine has: quickshell, else waybar.
# why:      The theme's bar is written for quickshell, which Alpine does not
#           package, so waybar stands in. copal-bar is the one place that
#           decides, and prefers quickshell: install it and the next login uses
#           the real thing, with nothing else changed.
# see:      copal-widgets, copal-theme

## Use
The session starts it; you run it by hand only to restart a bar that has
gone. It starts the bar and the desktop widgets.

## Examples
    copal-bar &                          # start the bar again, after it crashed
    pkill -x waybar; copal-bar &         # restart it after editing its config

## Options
(none)

## Notes
- The waybar configuration is in `~/.config/waybar`; copal-theme
  rewrites its colours, so keep your own changes to layout and modules.
- If neither shell is installed it says so where it will be seen,
  rather than leaving a desktop with no bar and no explanation.
