# command:  copal-desk
# purpose:  Put the workspaces into a known shape in one step: editor, terminal, browser, each where it belongs.
# why:      Super+Shift+D. Muscle memory needs things in the same place, so a
#           layout file names what opens on which workspace, and one key lays
#           the desk out. Deliberately not an autostart: you can decline it on
#           the morning you want an empty machine.
# see:      copal-camera, hyprctl

## Use
Run it (or press Super+Shift+D) and it opens what the layout names on the
workspaces it names, without pulling your eyes along. The default layout
is `code`; others are files you can write.

## Examples
    copal-desk                           # the 'code' layout
    copal-desk --list                    # the layouts on this machine
    copal-desk --show code               # what a layout does, without running it
    copal-desk music                     # a layout of your own

## Options
NAME           lay out that layout (default: code)
--list         the layouts available
--show NAME    print a layout without running it

## Notes
- Layouts are `NAME.layout` files in `/usr/local/share/copal/layouts`
  (Copal's) and `~/.config/copal/layouts` (yours, which wins over a
  system one of the same name).
- The `code` layout: the editor and a terminal on 2, an agent on 3, the
  browser on 5, and an empty 1 to start from.
- It works on both desktops: Hyprland places each window as it opens;
  i3 switches workspace first.
