# command:  ocaml
# purpose:  OCaml: a strict functional language with ML's type inference, and a fast native compiler.
# why:      The catalogue's ML on every port, the Zero included: where GHC is
#           not built, OCaml gives the same type system, pattern matching and
#           inference, with a native compiler small enough for the board.
# see:      ghc, racket

## Use
`ocaml` is the interactive toplevel: type an expression, end it with
`;;`. `ocamlopt` compiles to a native program, `ocamlc` to bytecode.

## Examples
    ocaml                                # the toplevel; #quit;; to leave
    ocaml script.ml                      # run a file
    ocamlopt -o hello hello.ml           # a native executable
    ocamlc -o hello.byte hello.ml        # bytecode, runs anywhere OCaml does

    let square x = x * x;;       (at the toplevel) define
    List.map square [1; 2; 3];;  use: - : int list = [1; 4; 9]

## Options
FILE          run it
-I DIR        search DIR for compiled modules
-init FILE    load FILE at start instead of ~/.ocamlinit

## Notes
- This is OCaml 4.14. opam and dune are not installed; libraries come
  from Alpine as `ocaml-*` packages (`apk search ocaml-`).
- Every toplevel input ends with `;;`, or nothing happens.
