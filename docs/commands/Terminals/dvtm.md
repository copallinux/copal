# command:  dvtm
# purpose:  A tiling window manager for the terminal: several shells arranged side by side, dwm-style.
# why:      The catalogue's smallest way to split a terminal: panes laid out
#           automatically, as dwm lays out windows. It does not detach by
#           itself; with abduco, it does.
# see:      abduco, tmux, zellij

## Use
Start it; Ctrl-g is the prefix. Ctrl-g c opens another shell, and the
layout tiles them: one large on the left, the rest stacked on the right.

## Examples
    dvtm                                 # start, with one shell
    dvtm htop 'watch -n2 df -h'          # start with these programs in panes
    abduco -c work dvtm                  # a detachable dvtm session

    Ctrl-g c       (inside) a new shell
    Ctrl-g j / k   next / previous pane
    Ctrl-g Space   the next layout
    Ctrl-g q q     quit

## Options
-m MOD       another prefix key: -m ^b for Ctrl-b
-M           mouse support on
-d DELAY     Escape delay, in milliseconds
-h LINES     scrollback lines per pane
-t TITLE     the terminal title
CMD...       start with these commands in panes

## Notes
- To keep a session when the terminal closes, run it inside abduco (as
  above) and reattach with `abduco -a work`.
- Ctrl-g is also a key some programs want; `-m` moves the prefix.
