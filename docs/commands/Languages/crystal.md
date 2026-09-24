# command:  crystal
# purpose:  Crystal: Ruby-like syntax, static types inferred, compiled to fast native code.
# why:      The catalogue's Crystal, on the 64-bit boards: for people who like
#           writing Ruby and want a compiled, typed program at the end.
# see:      ruby, nim, go

## Use
`crystal run` compiles and runs a file; `crystal build --release` makes
an optimised program. `crystal init app NAME` starts a project with its
`shard.yml`.

## Examples
    crystal run hello.cr                 # compile and run
    crystal hello.cr                     # the same: run is the default
    crystal build --release hello.cr     # an optimised program, ./hello
    crystal eval 'puts 6 * 7'            # one line
    crystal init app myapp               # a new project

## Options
run FILE         build and run (the default)
build FILE       build an executable; --release to optimise
eval CODE        evaluate CODE
init app NAME    start a project
spec             run the tests in spec/

## Notes
- shards, its dependency manager, is not installed here.
- A release build of anything sizeable is slow and memory-hungry on a
  Pi; develop without `--release`, release at the end.
- 64-bit only: its catalogue row is gated to aarch64 and x86_64.
