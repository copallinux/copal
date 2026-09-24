# command:  zellij
# purpose:  A terminal workspace: panes, tabs and floating windows, with its keys shown on screen.
# why:      The catalogue's modern multiplexer: tmux's detachable sessions, but
#           every key it takes is listed at the bottom, so nothing needs to be
#           learned first.
# see:      tmux, screen, byobu

## Use
Start it and work in panes and tabs. The bar at the bottom shows the
modes -- Ctrl-p for panes, Ctrl-t for tabs, and so on -- and inside each
mode the keys it offers. Sessions survive a detach and reattach by name.

## Examples
    zellij                               # a new session
    zellij -s work                       # a named one
    zellij ls                            # the sessions
    zellij attach work                   # back into it
    zellij kill-session work             # end it

    Ctrl-p n       (inside) a new pane;  Ctrl-p d  one below
    Ctrl-t n       a new tab
    Ctrl-o d       detach
    Ctrl-q         quit, ending the session

## Options
-s, --session NAME   name the new session
attach NAME          attach to a session (a)
list-sessions        list them (ls)
kill-session NAME    end one (k)
options              change behaviour for this run

## Notes
- Its Ctrl keys can clash with programs inside it (Ctrl-p in a shell's
  history, Ctrl-o in nano); Ctrl-g locks them so everything passes
  through, and Ctrl-g again unlocks.
- Configuration is `~/.config/zellij/config.kdl`; `zellij setup
  --dump-config` prints the default to start from.
