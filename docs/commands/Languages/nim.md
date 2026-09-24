# command:  nim
# purpose:  Nim: a compiled language that reads like Python and runs like C.
# why:      The catalogue's Nim: small, fast programs from code as terse as a
#           script, on every port the Pi runs.
# see:      python3, gcc, crystal

## Use
`nim c` compiles a file through C; `-r` runs the result. `-d:release`
turns on the optimisations for the version you keep.

## Examples
    nim c -r hello.nim                   # compile and run
    nim c -d:release -o:hello hello.nim  # an optimised program called hello
    nim r hello.nim                      # compile and run, no binary kept
    nim check hello.nim                  # check it without building

## Options
c / compile       compile to C, then to a program
r                 compile and run, leaving no binary behind
-r, --run         run after compiling
-d:release        optimised build
-o:FILE           the output name
check             check the file for errors only

## Notes
- nimble, Nim's package manager, is not installed here; a few libraries
  come from Alpine as `nim-*` packages.
- The build cache is `~/.cache/nim`; delete it if builds behave oddly.
