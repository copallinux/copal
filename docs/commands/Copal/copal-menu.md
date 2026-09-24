# command:  copal-menu
# purpose:  The keyboard menu: every program in one searchable list, and a second pane of categories, settings, Install and the session.
# why:      Super+Space (and Super+D, and the bar's button) open its left pane;
#           Super+Z its right. Unlike a plain launcher it lists the terminal
#           programs, the tools you would have to know the names of, and what
#           you could install but have not.
# see:      copal-gui, copal-install, copal-apps

## Use
The left pane is every program, flat and sorted: type to filter, Enter to
run. The right pane is the same programs by category, then Settings,
Style, Install and the session (lock, log out, reboot, shut down). Left
and Right cross between the panes; nothing is more than two levels deep.

## Examples
    copal-menu                           # the left pane (Super+Space)
    copal-menu --system                  # the right pane (Super+Z)
    copal-menu --at-pointer              # open where the mouse is
    copal-menu --rebuild                 # rebuild its list now
    copal-menu --rebuild-all             # both desktops' lists

## Options
--system         open on the right pane
--at-pointer     open at the mouse pointer
--rebuild        rebuild the cached list for this desktop
--rebuild-all    rebuild it for both sessions (Hyprland and i3)

## Notes
- The list is cached in `~/.cache/copal` so the menu opens in a fraction
  of a second; it rebuilds itself when programs change, and copal-install
  rebuilds it after every install. A program missing from the menu:
  `copal-menu --rebuild`.
- It draws with wofi. Its scrolling is wofi's own: with the mouse, keep
  to the middle rows and use the wheel; the arrow keys always work.
- The Install branch lists the catalogue's programs not yet installed;
  choosing one runs copal-install in a terminal.
