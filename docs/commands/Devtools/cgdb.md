# command:  cgdb
# purpose:  gdb with a source window above it, in the terminal: see the code as you step.
# why:      The catalogue's lightweight debugging front end: gdb's commands,
#           with the current line shown in the source -- the simplest way to
#           see where a program is, over SSH or on a console.
# see:      gdb, lldb, pwndbg

## Use
Start it as you would gdb. The top half shows the source with the
current line marked; the bottom half is gdb itself. Escape moves to the
source window, `i` back to gdb.

## Examples
    cgdb ./prog                          # debug a program
    cgdb -- --args ./prog -v in.txt      # gdb options after --
    cgdb -d gdb-multiarch ./arm-binary   # with another gdb

    Esc            (in cgdb) to the source window: vi keys to move, / to search
    Space          (source window) set or clear a breakpoint on this line
    i              back to the gdb window
    break / run / next / step / print    (gdb window) as in gdb

## Options
-d DEBUGGER   the gdb to run
--            the rest goes to gdb

## Notes
- Build with `-g`: without debug information there is no source to show.
- Its settings go in `~/.config/cgdb/cgdbrc` (for example `set
  syntax=on`, or a colour scheme).
