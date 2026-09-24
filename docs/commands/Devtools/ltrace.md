# command:  ltrace
# purpose:  Watch the library calls a program makes: what it asks of libc and other libraries.
# why:      strace's companion one level up: where strace shows the kernel
#           calls, ltrace shows `malloc`, `strcmp`, `getenv` and the rest --
#           which settings a program reads and what it compares.
# see:      strace, gdb

## Use
Run a program under it; each call into a shared library prints with its
arguments and return value. `-c` counts them instead.

## Examples
    ltrace ./prog                        # every library call
    ltrace -c ./prog                     # a count of calls, and their time
    ltrace -e getenv ./prog              # which environment variables it reads
    ltrace -f -o calls.txt ./prog        # children too, into a file

## Options
-c           count calls instead of printing them
-e FILTER    only these calls
-f           follow child processes
-o FILE      write to FILE
-p PID       attach to a running process
-S           system calls too

## Notes
- It sees calls into shared libraries only: a statically linked program
  shows nothing.
- Attaching with `-p` needs root, like strace.
