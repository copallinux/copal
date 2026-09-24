# command:  meson
# purpose:  A build system: configure a project into a build folder, then build it with ninja.
# why:      Stage 7's Meson, for the many C, C++ and GNOME projects that build
#           with it -- several of Copal Apps' source builds among them.
# see:      ninja, cmake, make

## Use
Two steps, as with CMake: `meson setup` configures into a build folder,
`meson compile` (or `ninja -C build`) builds. Options are set at setup
and changed later with `meson configure`.

## Examples
    meson setup build                    # configure into ./build
    meson setup build --buildtype=release   # optimised
    meson compile -C build               # build (runs ninja)
    meson test -C build                  # the tests
    meson configure build                # every option and its value
    meson configure build -Dfoo=enabled  # change one

## Options
setup DIR          configure into DIR
compile -C DIR     build
test -C DIR        run the tests
install -C DIR     install (doas for /usr/local)
configure DIR      show or change options (-Dname=value)
setup --buildtype=T   debug, debugoptimized, release
setup --reconfigure   set up again in an existing folder

## Notes
- `meson setup` prints which optional dependencies it found and which
  it did not: that list says which features the build will have.
- It writes `compile_commands.json` in the build folder for clangd.
