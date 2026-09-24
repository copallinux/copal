# command:  make
# purpose:  Rebuild what is out of date, by the rules in a Makefile.
# why:      The build tool behind Neovim's F5 (:make) and stage 7's sample
#           project in ~/dev/hello, and the front door of most checkouts --
#           Copal's own repository included (make lint, make commands).
# see:      gcc, cmake, ninja, nvim

## Use
Run in a directory with a `Makefile`: `make` builds its first target,
`make NAME` a named one. It compares file times, so only what changed is
rebuilt.

## Examples
    make                                 # build the default target
    make -j4                             # four jobs at once (a Pi 4 has four cores)
    make run                             # a named target: build, then run
    make clean                           # remove what was built
    make -n                              # print the commands, run none
    make -C ~/dev/hello                  # run it in another directory
    make CC=clang CFLAGS='-O2 -g'        # override a variable for this run

## Options
-j N         run N jobs in parallel
-n           dry run: show the commands
-C DIR       change to DIR first
-B           rebuild everything, dated or not
-k           keep going after an error
-s           silent: do not echo the commands
VAR=VALUE    set a variable, overriding the Makefile's

## Notes
- Recipe lines start with a TAB, not spaces. "missing separator" means
  an editor put spaces there.
- `-j` with more jobs than RAM can hold: on a 512 MB board, `make -j1`
  and zram are safer than a build killed halfway.
- In Neovim, F5 saves and runs `:make`; the errors land in the quickfix
  list, and `]q` and `[q` walk them.
