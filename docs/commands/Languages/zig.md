# command:  zig
# purpose:  The Zig language and toolchain -- and a C compiler that cross-compiles anywhere.
# why:      The catalogue's Zig, on the 64-bit boards. Beside the language,
#           `zig cc` compiles C for any target from this machine, a Zero or a
#           Mac included.
# see:      gcc, clang, go

## Use
`zig run` compiles and runs a file; `zig build-exe` makes a program;
`zig init` starts a project that `zig build` builds.

## Examples
    zig run hello.zig                    # compile and run
    zig build-exe hello.zig -O ReleaseSmall   # a small, optimised program
    zig init && zig build run            # a new project, built and run
    zig test sum.zig                     # run a file's tests
    zig cc -o hello hello.c -target arm-linux-musleabihf   # C, for a 32-bit Pi

## Options
run FILE        compile and run
build-exe FILE  make an executable
init            start a project here
build           build the project (build.zig)
test FILE       run the tests
fmt FILE        reformat the source
cc              act as a C compiler (with -target for another machine)

## Notes
- The language is not at 1.0: code written for another Zig version may
  need changes. `zig version` says which this is.
- 64-bit only: its catalogue row is gated to aarch64 and x86_64.
