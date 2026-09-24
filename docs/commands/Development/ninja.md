# command:  ninja
# purpose:  Run a build that cmake or meson generated, fast and in parallel.
# why:      The builder behind cmake -G Ninja and every meson project. On
#           Alpine the command is samurai, a small compatible reimplementation
#           (/usr/bin/samu); what it lacks, few builds use.
# see:      cmake, make, meson

## Use
Run it in (or point it at) a build directory that has a `build.ninja`.
You rarely write that file yourself: cmake or meson writes it, and
`ninja` builds from it, running as many jobs as there are cores.

## Examples
    ninja -C build                       # build in ./build
    ninja -C build -j2                   # two jobs (a small board's RAM)
    ninja -C build -v                    # show every command
    ninja -C build -t clean              # remove what it built
    ninja -C build -t targets            # what can be built
    ninja -C build -t compdb > compile_commands.json   # for clangd

## Options
-C DIR          change to DIR first
-j N            N jobs at once (default: cores + 2)
-k N            keep going until N failures
-n              dry run
-v              print each full command
-t TOOL         a subtool: clean, targets, commands, compdb, query

## Notes
- It is samurai: `-t graph` and a few other ninja subtools are not
  there ("unknown tool"). Builds themselves behave the same.
- The default job count assumes enough memory for each. On a 512 MB
  Pi, a C++ build at `-j3` swaps hard; pass `-j1` or `-j2`.
- Do not edit `build.ninja`: the next cmake or meson run rewrites it.
