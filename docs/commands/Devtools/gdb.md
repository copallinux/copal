# command:  gdb
# purpose:  The GNU debugger: stop a program, step through it, look at its state.
# why:      Stage 7 installs it for C, C++, Rust and Go, and Neovim's F4
#           (Termdebug) is gdb in a split window. When a program crashes,
#           gdb says where and why.
# see:      gcc, valgrind, nvim, cgdb, lldb

## Use
Start the program under gdb, set a breakpoint, run, and when it stops,
look: the call stack, the variables, the next line. Build with `-g` first,
or there is nothing to see but addresses.

## Examples
    gdb ./prog                           # load it, then type commands
    gdb --args ./prog -v input.txt       # with its arguments
    gdb -q -ex run -ex bt ./prog         # run, and on a crash show the stack
    gdb --tui ./prog                     # source in a pane above the prompt
    doas gdb -p $(pidof prog)            # attach to a running process

    break main          # (inside gdb) stop at a function, or file.c:42
    run                 # start it
    next / step         # the next line / into the call
    print x             # a variable's value
    bt                  # the call stack
    continue            # run on to the next stop

## Options
--args PROG ARGS   pass arguments to the program
-p, --pid PID      attach to a running process
--core FILE        examine a core dump
--tui              the text interface: source, prompt, registers
-q                 no banner
-ex CMD            run a gdb command at start; repeatable

## Notes
- Attaching to a process needs `doas`: ptrace is limited to a process's
  own children here (`kernel.yama.ptrace_scope` is 1).
- Core dumps are off (`ulimit -c` is 0). `ulimit -c unlimited` in the
  shell first, and a crash leaves `core` beside the program.
- In Neovim: F9 sets a breakpoint on the current line, F4 opens
  Termdebug, F8 / F10 / F11 continue, step over, step into.
- For Rust, `rust-gdb` prints Rust types properly; Go is better served
  by `dlv`.
