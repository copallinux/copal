# command:  copal-build
# purpose:  Compile the checkouts in ~/code and install what they make into ~/.local/bin, by the shape of each project.
# why:      "Built" should mean "installed": on PATH, in the menus, with a man
#           page. copal-build reads each checkout's shape -- CMake, Cargo, Go,
#           npm, or a cc65 Makefile -- and builds it the way that shape builds,
#           so a fork or a project it has never heard of works the same.
# see:      copal-code, copal-readme-man, cargo, cmake

## Use
With no argument it builds every checkout in `~/code`; name some to build
only those. `list` shows each checkout's shape and whether what it made
is on PATH.

## Examples
    copal-build                          # everything in ~/code
    copal-build staticstream ascitty     # just these
    copal-build list                     # shapes, and what each made
    copal-build clean birdshot           # delete its build directory

## Options
(none)          build every checkout
NAME...         build only these (directory names under ~/code)
list            each checkout, its shape, and the programs it made
clean NAME...   delete build/, native/build/ and target/; keep the checkout
-h, --help      the usage

## Notes
- Programs go to `~/.local/bin`, which is on PATH from `~/.profile`. Each
  gets a menu entry, and, from its README, a man page in
  `~/.local/share/man` (`man ytq`), by copal-readme-man.
- It never modifies a tracked file, because that would make every later
  `git pull` fail: npm uses `ci` where there is a lockfile, and a Plus/4
  program uses its committed .prg and .d64 instead of recompiling.
  `COPAL_BUILD_PLUS4=1` recompiles anyway (needs cc65).
- Parallel jobs are the CPU count, capped at one per 512 MB of memory, so
  a small board does not swap.
- `copal` itself is not built: it is a script (`make redeploy` in
  `~/code/copal`). A checkout with none of the shapes is left alone.
- `COPAL_CODE` and `COPAL_PREFIX` change `~/code` and `~/.local`.
