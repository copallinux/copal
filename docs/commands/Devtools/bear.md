# command:  bear
# purpose:  Record a build's compiler calls into compile_commands.json, for clangd and other tools.
# why:      The catalogue's bridge between a Makefile and the editor: clangd
#           needs each file's flags, and a plain make build does not write them
#           down. Bear watches the build and does.
# see:      clangd, make, cmake

## Use
Put `bear --` in front of the build command. Afterwards
`compile_commands.json` sits in the current folder, and clangd -- in
Neovim, Helix or Geany -- understands the project.

## Examples
    bear -- make                         # record a make build
    make clean && bear -- make -j4       # a full rebuild, so every file is seen
    bear --append -- make extra          # add to an existing file
    bear --output build/cc.json -- make  # write it somewhere else

## Options
--                 everything after is the build command
--output FILE      where to write (default compile_commands.json)
--append           add to the file instead of replacing it

## Notes
- Only files that are compiled during the run are recorded: after a
  `make` that had nothing to do, the file is empty. Clean first.
- CMake and Meson write the same file themselves; Bear is for builds
  that do not.
