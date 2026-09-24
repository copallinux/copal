# command:  cmake
# purpose:  Generate a project's build files -- for ninja or make -- from its CMakeLists.txt.
# why:      Stage 7 installs it because a large share of C and C++ projects
#           build only through it; several of the store's source builds do.
# see:      ninja, make, gcc, clang

## Use
Two steps, always in a separate build directory: configure (read
`CMakeLists.txt`, find the compiler and libraries, write the build files),
then build. Configure once; after that, only the build step.

## Examples
    cmake -B build -G Ninja              # configure into ./build, for ninja
    cmake --build build                  # build (runs ninja or make for you)
    cmake --build build -j4              # with four jobs
    cmake -B build -DCMAKE_BUILD_TYPE=Release   # optimised
    cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON  # for clangd in nvim
    doas cmake --install build           # install to /usr/local
    cmake -B build --fresh               # reconfigure from nothing

## Options
-B DIR                  the build directory (made if missing)
-S DIR                  the source directory (default: here)
-G NAME                 the generator: Ninja, or "Unix Makefiles"
-D VAR=VALUE            set a cache variable: CMAKE_BUILD_TYPE, CMAKE_INSTALL_PREFIX...
--build DIR             build a configured tree
--install DIR           install it
--fresh                 forget the cached configuration
-j N                    with --build: parallel jobs

## Notes
- The cache remembers. A changed compiler or a library installed after
  the first configure is not noticed until `--fresh` or
  `rm -rf build`.
- "Could NOT find Foo": install the library's `-dev` package
  (`apk search -e foo-dev`), then configure again with `--fresh`.
- `CMAKE_BUILD_TYPE` is empty by default: no optimisation and no debug
  information. Say `Debug` or `Release`.
