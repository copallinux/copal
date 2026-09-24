# command:  byobu
# purpose:  A friendlier face on tmux: function-key shortcuts and a status bar of system facts.
# why:      The catalogue's easy multiplexer: tmux underneath, but F2 for a new
#           window and F6 to detach, with no prefix key to learn.
# see:      tmux, screen

## Use
Run `byobu` and work as in tmux; the function keys do the common things,
and the status line along the bottom shows load, memory and the clock.
Sessions persist and reattach, as tmux's do.

## Examples
    byobu                                # start or reattach
    byobu new -s work                    # a named session (tmux's options pass through)
    byobu ls                             # the sessions

    F2             (inside) a new window
    F3  F4         previous / next window
    F6             detach
    F8             rename the window
    F9             the configuration menu

## Options
(byobu passes its arguments on to tmux: `new`, `ls`, `attach` and the rest)

## Notes
- "locale: not found" at start is harmless: byobu asks for the
  character map with a `locale` command that musl systems do not have.
- Function keys that the terminal or desktop keeps for itself (F11 for
  full screen, F10 in some terminals) do not reach it; F9 lets you switch
  to Ctrl-a keys instead.
- Its settings live in `~/.byobu`.
