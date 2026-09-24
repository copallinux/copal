# command:  hlint
# purpose:  Suggest better Haskell: simpler expressions, library functions you missed.
# why:      The catalogue's Haskell linter, the usual companion to GHC: it
#           teaches idiomatic Haskell as it points things out.
# see:      ghc

## Use
Run it on a file or a folder; it prints each suggestion with the code as
it is and as it could be.

## Examples
    hlint Main.hs                        # suggestions for one file
    hlint src/                           # a whole folder
    hlint --report src/                  # an HTML report, report.html

## Options
--report      write an HTML report
--hint=FILE   use hints from FILE
-j            use several cores

## Notes
- A suggestion can be switched off for a project in `.hlint.yaml`:
  `- ignore: {name: "Use camelCase"}`.
- 64-bit only, like GHC.
