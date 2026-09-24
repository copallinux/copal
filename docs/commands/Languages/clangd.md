# command:  clangd
# purpose:  The C and C++ language server: completion, go-to-definition, errors as you type.
# why:      Stage 7 installs it with clang-format (clang22-extra-tools), and
#           Neovim, Helix and Geany talk to it: it is what makes gd, gr and K
#           work in C and C++.
# see:      clang, nvim, hx, bear

## Use
You rarely run it yourself: the editor starts it. What it needs from you
is the project's build flags, in a `compile_commands.json` at the root
of the project; without one it guesses, and gets includes wrong.

## Examples
    bear -- make                         # record compile_commands.json from a make build
    cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON   # or have cmake write it
    ln -s build/compile_commands.json .  # where clangd looks for it
    clangd --check=src/main.c            # try it on one file, from the shell
    clang-format -i src/*.c              # its companion: reformat in place

## Options
--check=FILE           parse FILE and report what clangd sees
--compile-commands-dir=DIR   where compile_commands.json is
--background-index     index the whole project in the background
--log=verbose          more detail in the editor's log

## Notes
- A `.clangd` file in the project sets flags without a build system:
  `CompileFlags: { Add: [-std=c17, -Iinclude] }`.
- In Neovim, `:Lsp` says whether it is running for the current file.
