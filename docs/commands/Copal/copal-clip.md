# command:  copal-clip
# purpose:  One clipboard, one set of keys, every window -- with a history, and a bridge to the VM host.
# why:      Super+C, Super+X and Super+V copy, cut and paste in every program,
#           terminal included, the way Cmd-C does on a Mac. It keeps a
#           clipboard history, and in a VM shares the clipboard with the host.
# see:      wl-copy, ytq

## Use
The desktop binds the keys; you rarely run it by name. From a shell,
`store` puts text on the clipboard and `show` prints it, which makes it
the pipe between the clipboard and commands.

## Examples
    echo hello | copal-clip store        # put text on the clipboard
    copal-clip show                      # print the clipboard
    copal-clip show | wc -w              # use it in a pipeline
    copal-clip history                   # pick an earlier entry (Super+Ctrl+V)

## Options
copy / cut / paste   the Super+C / Super+X / Super+V actions
history              choose from the clipboard history
store                put stdin on the clipboard
show                 print the clipboard
watch                record the history (the session starts this)
bridge               share the clipboard with the VM host (the session starts this)

## Notes
- In a UTM or QEMU guest, copy and paste with the Mac works only while
  `copal-clip bridge` and `spice-vdagent` are running; both are started
  from `hyprland.conf`. If it stops working, check those two first.
- The history keeps the last 100 entries, in `~/.cache/copal/clipboard`;
  delete that folder to clear it.
