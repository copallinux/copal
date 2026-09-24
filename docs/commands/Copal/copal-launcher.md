# command:  copal-launcher
# purpose:  Open the program launcher -- whichever this machine has: Copal's menu, wofi, or dmenu.
# why:      What the theme's launcher key runs. Linux Antiquity names its own
#           launcher, which is not packaged for Alpine; this hands the key to
#           copal-menu, falling back to wofi or dmenu.
# see:      copal-menu, copal-gui

## Use
Press the launcher key (Super+Space) or run it; it opens the first
launcher it finds.

## Examples
    copal-launcher                       # the menu, as the key opens it

## Options
(none)

## Notes
- The order is copal-menu, then `wofi --show drun`, then `dmenu_run`; if
  none is installed it says so and exits.
