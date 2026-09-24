# command:  copal-terminal-theme
# purpose:  Write a colour theme into the terminal emulators' configs: foot, kitty, alacritty and the rest.
# why:      The terminal part of the desktop's look, on its own: copal-theme
#           calls it, and it can be run by hand for a different terminal
#           palette or opacity.
# see:      copal-theme, foot

## Use
Name a theme and it writes it into every terminal configuration in your
home; with no name it follows the desktop's current theme. Open terminals
pick it up when they next start.

## Examples
    copal-terminal-theme                 # follow the desktop's theme
    copal-terminal-theme --list          # the palettes there are
    copal-terminal-theme sand            # Copal's own light palette
    copal-terminal-theme night --alpha 1 # Tokyo Night, fully opaque
    copal-terminal-theme --show eris     # print a palette, change nothing

## Options
THEME        helios, eris, priapus, eros, hades (Linux Antiquity), night, sand
--list       the theme names
--show THEME print the palette and stop
--alpha A    window opacity, 0.5 to 1 (default 0.9)

## Notes
- `$COPAL_TERMINAL_THEME` overrides what "follow the desktop" means.
- Only terminals already configured in your home are rewritten; a
  terminal installed later gets the theme the next time this runs.
