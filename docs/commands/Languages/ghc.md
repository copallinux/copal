# command:  ghc
# purpose:  The Glasgow Haskell Compiler, with ghci for trying things and cabal for projects.
# why:      The catalogue's Haskell, on the 64-bit Pis and PCs. GHC is not
#           built for 32-bit ARM at all -- it bootstraps from an earlier GHC --
#           so on a Zero the nearest in spirit is OCaml.
# see:      hlint, ocaml

## Use
`ghci` is the interactive prompt, where most learning happens. `ghc`
compiles a file to a program. `cabal` makes, builds and runs projects
with their dependencies.

## Examples
    ghci                                 # the prompt: :t for a type, :q to leave
    runghc Main.hs                       # run a file without compiling it
    ghc -O2 Main.hs -o main              # compile a program
    cabal init                           # start a project here
    cabal update && cabal run            # fetch the package list, build and run

## Options
-o FILE        the output
-O             optimise (-O2 for more)
-Wall          warnings
--make         build a program and its modules (the default)
-i DIR         search DIR for modules

## Notes
- `cabal update` is needed once before any package can be installed.
- A first `cabal build` of a project with dependencies compiles them all:
  on a Pi, that is a long wait and a lot of memory -- zram helps.
