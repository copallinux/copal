# command:  valgrind
# purpose:  Run a program under a checker that catches memory errors and leaks.
# why:      On Alpine it is the memory checker: the compilers' AddressSanitizer
#           runtime is not packaged. Stage 7 installs it where it exists --
#           everywhere but 32-bit ARMv6 (armhf).
# see:      gdb, gcc, clang

## Use
Put `valgrind` in front of the command. The program runs perhaps
twenty times slower, and every invalid read or write, use of freed memory
and leak is reported with the line it came from -- if it was built with
`-g`.

## Examples
    valgrind ./prog                                  # memory errors as they happen
    valgrind --leak-check=full ./prog                # and every leak, with where it was allocated
    valgrind -q --leak-check=full --error-exitcode=1 ./prog   # quiet; fail a test on error
    valgrind --track-origins=yes ./prog              # where an uninitialised value came from
    valgrind --tool=callgrind ./prog                 # where the time goes, by function

## Options
--leak-check=full      report each leak in detail
--show-leak-kinds=all  include "still reachable" blocks
--track-origins=yes    trace uninitialised values to their source (slower)
--error-exitcode=N     exit N if errors were found
--tool=NAME            memcheck (default), massif, callgrind, cachegrind, helgrind
-q                     only the errors
--log-file=FILE        report to FILE instead of the terminal

## Notes
- Read the first error first. Later ones are often its consequences.
- "definitely lost" is a real leak; "still reachable" is memory held at
  exit, usually harmless.
- Build with `-g -O0` (or `-O1`) for readable reports; optimised code
  reports lines that do not match the source.
