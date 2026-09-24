# command:  copal-theme
# purpose:  One switch for the whole desktop's look: bar, borders, wallpaper, GTK, terminal, menus and editor together.
# why:      Copal's desktop is themed in a dozen places -- Hyprland, the bar,
#           wofi, GTK, the terminal, Neovim, mc. copal-theme changes all of
#           them at once, so nothing is left in the old colours.
# see:      copal-terminal-theme, copal-wallpaper, copal-gui

## Use
With no argument it lists the themes, the current one starred. A name
switches to it; `--toggle` swaps light and dark; `--pick` offers a menu
(Super+Shift+T, or Style in the menu).

## Examples
    copal-theme                          # the themes, * the current
    copal-theme tokyo-night              # switch everything to it
    copal-theme --toggle                 # light <-> dark (Super+Shift+N)
    copal-theme --pick                   # choose from a menu
    copal-theme --show antiquity         # a theme's colour tokens

## Options
NAME           switch to NAME
--toggle       the current theme's light or dark partner
--pick         choose from a menu (Super+Shift+T)
--show [NAME]  print a theme's tokens
-q, --quiet    say nothing but errors

## Notes
- The colours are written to `~/.config/copal/current/colors.css`,
  which the bar, wofi and the Super+A menu read: a running Neovim follows
  the change without restarting.
- Themes shipped: Antiquity (helios, light) and Tokyo Night (dark).
