# command:  asciiquarium
# purpose:  An aquarium in the terminal: fish, sharks, a castle and bubbles, animated.
# why:      One of the catalogue's toys: something alive in a spare terminal or
#           a tmux pane, and a quick test of a terminal's colours and speed.
# see:      cmatrix, cbonsai

## Use
Run it, watch, press `q` to leave. It fills the terminal at whatever
size it is, and redraws when the window changes.

## Examples
    asciiquarium                         # watch

    q          (while running) quit
    p          pause
    r          redraw

## Options
(none: it takes no arguments)

## Notes
- It is a Perl program: the first frame takes a moment on a Pi.
- It ignores `--help` and simply starts.
