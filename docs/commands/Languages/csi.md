# command:  csi
# purpose:  CHICKEN Scheme's interpreter -- and csc, which compiles Scheme to C and to programs.
# why:      The catalogue's compiling Scheme: try code in csi, then turn it into
#           a small native program with csc, through C.
# see:      guile, racket, gcc

## Use
`csi` is the interactive interpreter and runs scripts; `csc` compiles a
file to an executable. Libraries ("eggs") install with chicken-install.

## Examples
    csi                                  # the REPL; ,q to leave
    csi -s script.scm                    # run a file as a script
    csi -e '(print (* 6 7))'             # one expression
    csc hello.scm                        # compile to ./hello
    chicken-install -s srfi-1            # an egg, system-wide (as root)

## Options
-s FILE     run FILE as a script, then exit
-e EXPR     evaluate EXPR and exit
-q          no banner
-n          do not load ~/.csirc

## Notes
- The command names are CHICKEN's own: `csi` interprets, `csc`
  compiles; there is no `chicken` command to run.
- `csc` needs a C compiler; stage 7's gcc is it.
