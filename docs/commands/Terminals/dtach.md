# command:  dtach
# purpose:  Keep a program running detached from the terminal, reached through a socket file.
# why:      The catalogue's oldest and smallest session keeper, abduco's
#           ancestor: a program behind a socket you can leave and come back to.
# see:      abduco, screen, tmux

## Use
Name a socket file and a command. `-c` creates the session and attaches,
`-a` reattaches, and Ctrl-\ detaches.

## Examples
    dtach -c /tmp/build.sock make -j4    # start, attached
    dtach -a /tmp/build.sock             # reattach later
    dtach -A /tmp/ed.sock nvim notes.md  # attach, or start it if not running
    dtach -n /tmp/srv.sock ./server      # start detached

## Options
-c SOCK CMD   create a session and attach
-n SOCK CMD   create it detached
-a SOCK       attach
-A SOCK CMD   attach, or create if it does not exist
-e CHAR       the detach character (default ^\)
-E            no detach character at all
-r METHOD     how to redraw on attach: none, ctrl_l or winch

## Notes
- The socket is an ordinary file path: anyone who can open it can attach,
  so keep it in a folder only you can read, not a shared /tmp in a
  multi-user machine.
- Like abduco, it keeps no screen: `-r winch` asks a full-screen
  program to redraw when you attach.
