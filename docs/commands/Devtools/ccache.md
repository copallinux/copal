# command:  ccache
# purpose:  A compiler cache: a rebuild of unchanged code takes seconds instead of minutes.
# why:      The catalogue's rebuild accelerator -- worth most on a Pi, where
#           compiling is slow and the same sources are often built again after
#           a `make clean` or a branch switch.
# see:      gcc, clang, make, cmake

## Use
Put it in front of the compiler. It remembers each compilation's result
by its inputs; the same file with the same flags later comes from the
cache. It is not switched on by default.

## Examples
    CC="ccache gcc" make                 # one build, through the cache
    export PATH=/usr/lib/ccache/bin:$PATH   # every gcc/cc call, from now on
    cmake -B build -DCMAKE_C_COMPILER_LAUNCHER=ccache   # for a CMake project
    ccache -s                            # hits, misses and cache size
    ccache -C                            # empty the cache

## Options
-s, --show-stats     statistics: hits, misses, size
-z, --zero-stats     reset the statistics
-C, --clear          empty the cache
-M, --max-size SIZE  set the cache limit, e.g. 5G
-p, --show-config    the settings in force

## Notes
- The cache is `~/.cache/ccache`, 5 GB at most by default; on a small
  card, `ccache -M 1G`.
- `/usr/lib/ccache/bin` holds links named gcc, cc, g++ and the rest,
  which is what makes the PATH method cover everything.
