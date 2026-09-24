# command:  gcc
# purpose:  The GNU C and C++ compiler.
# why:      Stage 7 installs build-base -- gcc, make and the musl headers --
#           because most things built on a Copal machine start here: the
#           checkouts in ~/code, the store's source builds, your own programs.
# see:      clang, make, gdb, valgrind, cmake

## Use
Compile C (`gcc`) or C++ (`g++`) source into a program, or into object
files for a larger build. Warnings on and debug information in is the
right default while writing; optimisation for the version you keep.

## Examples
    gcc -Wall -Wextra -g hello.c -o hello    # compile, warnings on, debuggable
    ./hello                                  # run it
    gcc -O2 -o hello hello.c                 # optimised
    g++ -std=c++20 -Wall main.cpp -o main    # C++, a chosen standard
    gcc -c util.c                            # object file only, for linking later
    gcc main.o util.o -lm -o prog            # link, with the maths library
    gcc -static hello.c -o hello             # one file, no shared libraries
    cd ~/dev/hello && make run               # Copal's sample project

## Options
-o FILE          name the output
-c               compile only, make a .o
-g               debug information, for gdb
-O2              optimise; -O0 for none, -Os for size
-Wall -Wextra    the warnings worth having
-std=c17         the language standard: c89 c99 c11 c17 c23, c++17 c++20 c++23
-I DIR           another directory of headers
-L DIR -lNAME    link libNAME from DIR
-static          link everything in
-E               preprocess only

## Notes
- The C library is musl, not glibc. Code that uses glibc extensions
  (`execinfo.h`'s `backtrace`, some `_GNU_SOURCE` corners) will not find
  them. A binary built on Debian will not run here, nor the reverse.
- `-fsanitize=address` and `-fsanitize=undefined` fail to link: Alpine
  ships no sanitizer runtimes. Use `valgrind` for memory errors.
- `-static` is cheap and reliable on musl -- a static binary copies to
  another Copal machine of the same architecture and runs.
- Missing header? The library's `-dev` package has it:
  `apk add openssl-dev` for `openssl/ssl.h`.
