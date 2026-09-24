# command:  racket
# purpose:  Racket: a Scheme descendant built for making languages -- and for teaching.
# why:      The catalogue's Racket, with raco for packages and builds. How to
#           Design Programs is taught in it, and its #lang line makes a file
#           any of many languages.
# see:      guile, csi, sbcl

## Use
Run a `.rkt` file, or start the REPL. The first line of a file,
`#lang racket`, says which language it is written in.

## Examples
    racket                               # the REPL; ,exit to leave
    racket hello.rkt                     # run a file
    racket -e '(displayln (* 6 7))'      # one expression
    raco make hello.rkt                  # compile it ahead of time
    raco pkg install gregor              # a package

## Options
-e EXPR      evaluate EXPR
-i           the REPL, after the other options
-l LIB       require LIB first
-t FILE      require FILE (runs it)

## Notes
- DrRacket, the teaching IDE, is a separate window program; this is the
  command line.
- Packages install per user under `~/.local/share/racket`.
