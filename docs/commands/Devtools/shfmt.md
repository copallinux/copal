# command:  shfmt
# purpose:  Format shell scripts consistently -- and parse them, which catches syntax errors.
# why:      The catalogue's shell formatter, shellcheck's partner: one style
#           for every script in a project, applied by a command, not by hand.
# see:      shellcheck

## Use
With no options it prints the script reformatted. `-d` shows the
changes as a diff, `-w` writes them back. Indentation and style are
options.

## Examples
    shfmt -d script.sh                   # what it would change
    shfmt -w script.sh                   # change it in place
    shfmt -i 4 -w *.sh                   # four spaces of indent
    shfmt -l .                           # list the files that are not formatted
    shfmt -p -d script.sh                # hold it to POSIX sh

## Options
-d           print a diff instead of the result
-w           write the result back to the file
-l           list files whose formatting differs
-i N         indent with N spaces (0 means tabs, the default)
-p           POSIX sh only (same as -ln posix)
-ln LANG     the dialect: bash, posix, mksh, bats
-ci          indent switch cases

## Notes
- A syntax error stops it with the line and column: `shfmt -d` doubles
  as a quick check that a script parses.
- It reads an `.editorconfig`, so a project's indentation can live
  there instead of in options.
