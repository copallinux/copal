# command:  sbcl
# purpose:  Steel Bank Common Lisp: a fast, native Common Lisp compiler with an interactive REPL.
# why:      The catalogue's Common Lisp: it compiles every expression to native
#           code as you type it, so the REPL is as fast as a built program.
# see:      guile, racket, csi

## Use
Start the REPL and type forms, or run a file with `--script`. Emacs and
Neovim plugins can talk to it for a full Lisp environment.

## Examples
    sbcl                                 # the REPL; (quit) to leave
    sbcl --script hello.lisp             # run a file and exit
    sbcl --eval '(print (expt 2 100))' --quit   # one expression
    sbcl --load project.lisp             # load a file, then the REPL

    (defun square (x) (* x x))   (at the REPL) define
    (square 12)                  => 144

## Options
--script FILE   run FILE non-interactively, then exit
--load FILE     load FILE, then continue
--eval FORM     evaluate FORM
--quit          exit after the --load and --eval options
--noinform      no banner

## Notes
- An error drops into the debugger, with numbered restarts: type the
  number of `ABORT` (usually 0) to get back to the prompt.
- Libraries come through Quicklisp, which is installed by loading its
  `quicklisp.lisp` from quicklisp.org once.
