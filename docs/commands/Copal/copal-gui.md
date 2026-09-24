# command:  copal-gui
# purpose:  The other menu, Linux Mint's Cinnamon style: favourites, categories, icons and search, for the mouse.
# why:      Super+A. The mouse's menu beside copal-menu's keyboard one: hover a
#           category to switch to it, hover a program to read about it, click
#           to run. It sits over the screen as a layer, on the theme's own
#           menu colours.
# see:      copal-menu, copal-apps

## Use
Press Super+A (again to close). Categories on the left switch on hover,
after a short pause; programs on the right describe themselves at the
foot as you hover them; a click runs one. Type to search. Right-click a
program to add or remove it from the favourites column.

## Examples
    copal-gui                            # open the menu, or close it if open
    copal-gui --list                     # every entry: section|name|desktop id

## Options
--list      print section|name|desktop-id for every entry, and exit

## Notes
- Scrolling by the edges: rest the pointer in the strip at the top or
  the bottom of the list and it scrolls at a steady pace; the rows in
  between stay still, so a click lands on what you aimed at. The wheel
  works as usual.
- The favourites are kept in `~/.config/copal/gui-favourites`, one per
  line: edit it, or right-click in the menu.
- A click anywhere outside the menu closes it.
