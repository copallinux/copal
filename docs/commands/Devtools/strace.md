# command:  strace
# purpose:  Watch the system calls a program makes: which files it opens, what fails, and why.
# why:      The catalogue's answer to "it just says error": strace shows the
#           file a program could not find, the permission it was refused, the
#           address it could not reach.
# see:      ltrace, gdb, valgrind

## Use
Run a program under it, or attach to one running. Each system call
prints as a line: the call, its arguments, and its result -- a failure
shows its error name, such as ENOENT (no such file).

## Examples
    strace -f -e trace=openat ./prog 2>&1 | grep ENOENT   # files it looked for and missed
    strace -c ls /                       # a summary: which calls, how often, how long
    strace -o trace.txt -f ./prog        # everything, into a file
    strace -e trace=network curl -s example.com >/dev/null   # its network calls
    doas strace -p $(pidof prog)         # attach to a running process

## Options
-f             follow child processes too
-e trace=SET   only these calls: openat, network, file, process...
-o FILE        write the trace to FILE
-c             count calls and time instead of printing them
-p PID         attach to a running process
-s N           show strings up to N characters (default 32)
-t / -T        timestamps / time spent in each call

## Notes
- Attaching to a process needs root (`ptrace_scope` is 1); tracing a
  program you start yourself does not.
- `strace-tui`, one of its optionals, browses a saved trace file
  interactively.
