# command:  mc
# purpose:  Midnight Commander: a two-panel file manager for the terminal, with a viewer and an editor.
# why:      The catalogue's terminal file manager, and the first one Copal's
#           menus open for files when there is no desktop. Its skin follows
#           Copal's theme.
# see:      nnn, ranger, rsync

## Use
Two panels, a folder in each. Select files on one side and copy or move
them to the other with a function key; the keys are listed along the
bottom. The command line under the panels still works as a shell.

## Examples
    mc                                   # the two panels
    mc ~/Downloads /media/usb            # open these two folders
    mcedit notes.txt                     # its editor on its own
    mcview big.log                       # its viewer on its own

    Tab            (in mc) switch panels
    Insert         select a file
    F5  F6  F8     copy / move / delete the selection
    F3  F4         view / edit
    F10            quit

## Options
-b           monochrome
-d           no mouse
-u           no subshell (a faster start)
-e FILE      edit FILE, as mcedit
-v FILE      view FILE, as mcview

## Notes
- A function key the terminal keeps for itself has an Esc equivalent:
  Esc then 0 is F10, Esc then 5 is F5.
- Ctrl-O hides the panels to show the shell underneath, and brings them
  back.
- Settings are in `~/.config/mc/ini`; Copal writes only its `skin=` line.
