# command:  cbonsai
# purpose:  Grow a bonsai tree in the terminal, slowly, or print one.
# why:      One of the catalogue's toys: a different tree every time, as a
#           screensaver or as the first thing a new shell prints.
# see:      asciiquarium, cmatrix, fortune

## Use
With no options it draws a finished tree. `-l` shows it growing; `-S` is
the screensaver, growing tree after tree until a key is pressed.

## Examples
    cbonsai                              # a tree, finished
    cbonsai -l                           # watch it grow
    cbonsai -S                           # screensaver: one tree after another
    cbonsai -p -m "$(fortune -s)"        # print a tree with a saying beside it

## Options
-l, --live          show each step of growth
-t, --time=SECS     the delay between steps with -l
-i, --infinite      keep growing trees
-S, --screensaver   -l and -i together, quit on any key
-m, --message=STR   a message beside the tree
-p, --print         print the tree and leave it on the terminal
-L, --life=N        how big it grows (default 32)

## Notes
- `-p` makes it usable in a shell's start-up: the tree stays on screen
  above the prompt.
