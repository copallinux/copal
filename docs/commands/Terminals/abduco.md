# command:  abduco
# purpose:  Detach and reattach any terminal program -- sessions without a multiplexer.
# why:      The catalogue's smallest session keeper: it does one thing tmux
#           does -- keep a program running when the terminal goes -- and
#           nothing else, so it pairs with dvtm or any single program.
# see:      dtach, dvtm, tmux

## Use
`-c NAME CMD` starts a program in a named session; Ctrl-\ detaches;
`-a NAME` reattaches. With no arguments it lists the sessions.

## Examples
    abduco -c build make -j4             # run a build in session "build"
    abduco                               # the sessions, and whether they are attached
    abduco -a build                      # back into it
    abduco -A work dvtm                  # attach, or create it running dvtm
    abduco -n logs tail -f /var/log/messages   # start one detached

## Options
-c NAME CMD   create a session running CMD and attach
-n NAME CMD   create it detached
-a NAME       attach to it
-A NAME CMD   attach, or create if it does not exist
-e KEY        the detach key (default ^\)
-r            read-only: watch without typing

## Notes
- Ctrl-\ is the detach key; the program keeps running.
- It keeps no screen contents: reattaching shows what the program
  draws next. A full-screen program redraws; a plain shell shows only
  new output.
