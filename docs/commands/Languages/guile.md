# command:  guile
# purpose:  GNU Guile: a Scheme for scripting, extending programs, and learning Lisp.
# why:      The catalogue's Scheme from the GNU project -- the extension
#           language of GNU programs, and a good first Lisp with a helpful REPL.
# see:      csi, racket, sbcl

## Use
Start the REPL and type expressions, or run a file of Scheme. Commands
to the REPL itself start with a comma.

## Examples
    guile                                # the REPL; ,q to leave
    guile script.scm                     # run a file
    guile -c '(display (* 6 7)) (newline)'   # one expression
    guile -L . -l lib.scm                # load a file, with this folder on the path

    (define (square x) (* x x))  (at the REPL) define
    (map square '(1 2 3))        => (1 4 9)
    ,help                        the REPL's own commands

## Options
-c EXPR      evaluate EXPR and exit
-l FILE      load FILE
-L DIR       add DIR to the module search path
-s FILE      run FILE as a script
--no-auto-compile   do not cache compiled files

## Notes
- The first run of a file compiles it and caches the result under
  `~/.cache/guile`; later runs start faster.
- `guile-readline` gives the REPL history and line editing:
  `(use-modules (ice-9 readline)) (activate-readline)` in `~/.guile`.
