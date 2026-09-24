# command:  nnn
# purpose:  A tiny, fast terminal file manager, driven from the keyboard.
# why:      The catalogue's lightest file manager: it starts at once even on a
#           Pi Zero, and stays out of the way.
# see:      mc, ranger

## Use
Move through folders with the arrows or h j k l, and open a file with
Enter. Space selects; the selection can then be copied or moved into the
folder you are in.

## Examples
    nnn                                  # the current folder
    nnn ~/Music                          # a folder
    nnn -d                               # with details: size, date, permissions
    nnn -H                               # show hidden files

    h j k l        (in nnn) back / down / up / open
    Space          select;  a  select all
    p  v           copy / move the selection here
    /              filter by name
    ?              every key;  q  quit

## Options
-d           detail mode
-H           show hidden files
-e           open text files in $EDITOR, in the terminal
-o           open files only on Enter

## Notes
- It opens files with `xdg-open`; without a desktop, `-e` keeps text
  files in `$EDITOR`.
- Quitting does not change the shell's folder: that takes the small
  `quitcd` shell function from nnn's documentation.
