# command:  cmatrix
# purpose:  The falling green characters of The Matrix, in the terminal.
# why:      One of the catalogue's toys, and a screensaver for a console with
#           nothing else to show.
# see:      asciiquarium, cbonsai

## Use
Run it and watch; `q` quits. Keys change it while it runs: speed,
colour, boldness.

## Examples
    cmatrix                              # watch
    cmatrix -s                           # screensaver: any key ends it
    cmatrix -b -C blue                   # bold, in blue
    cmatrix -u 2                         # faster (0 fastest, 9 slowest)
    cmatrix -a                           # smooth, asynchronous columns

    0-9        (while running) speed
    ! @ # $ % ^ & )   red, green, yellow, blue, magenta, cyan, white, ...
    q          quit

## Options
-s          screensaver mode: exit on the first key
-b / -B     some / all characters bold
-C COLOR    green, red, blue, white, yellow, cyan, magenta, black
-u N        the delay, 0 to 9
-a          asynchronous scroll
-l          Linux console mode, with the matrix font
-m          lambda mode: every character is a lambda

## Notes
- `-l` changes the console font and only makes sense on a text console,
  not in a terminal window.
