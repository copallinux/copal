# command:  clang
# purpose:  The LLVM C and C++ compiler: gcc's rival, with clearer errors.
# why:      Stage 7's second compiler, and it brings clangd -- the language
#           server that gives Neovim go-to-definition, references and the
#           call hierarchy in C and C++.
# see:      gcc, make, cmake, nvim, gdb

## Use
Compile C (`clang`) or C++ (`clang++`) with the same flags as gcc. Worth
running a program through both: each warns about things the other
misses, and clang's messages point at the exact column.

## Examples
    clang -Wall -Wextra -g hello.c -o hello  # compile, like gcc
    clang++ -std=c++20 main.cpp -o main      # C++
    clang -fsyntax-only -Wall file.c         # check, produce nothing
    CC=clang make                            # a Makefile's build, with clang
    clang --version                          # which LLVM
    clang-format -i file.c                   # reformat in place

## Options
-o FILE           name the output
-g                debug information
-O2               optimise
-Wall -Wextra     warnings
-Weverything      every warning clang has (noisy, but thorough)
-std=c17          the language standard, as gcc
-fsyntax-only     parse and check, write nothing

## Notes
- `clangd` needs to know the flags: a `compile_commands.json` at the
  project root. `bear -- make` records one from a Makefile build, and
  cmake writes one with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`.
- Sanitizers: as with gcc, the ASan and UBSan runtimes are missing;
  `-fsanitize=undefined -fsanitize-trap=undefined` needs none, and stops
  the program at the first undefined behaviour.
- Clang links with the system's gcc toolchain and musl, so its programs
  and gcc's mix freely.
