# playbook: endlesssky
# source:   github endless-sky/endless-sky
# build:    build-base cmake samurai pkgconf sdl2-dev sdl2-compat-static libpng-dev
#           libjpeg-turbo-dev libavif-dev glew-dev openal-soft-dev flac-dev zlib-dev minizip-dev
#           util-linux-dev mesa-dev
# runs:
#
# program:  endless-sky
# label:    Endless Sky (space trading)
# shelf:    Games
# install:  endlesssky@source
# mode:     x
# gate:     64
# home:     https://github.com/endless-sky/endless-sky
# about:    Start with a small ship and a little money in a galaxy of trade routes, pirates and
#           alien empires: haul cargo, take jobs, fight, and follow the main story when you are
#           ready. In the spirit of Escape Velocity.

# Endless Sky: the 2D space trading game, CMake. Stage 12 has built it since
# before the store (build_endless_sky); this is the pinned, removable way. Its
# CMakeLists turns on link-time optimisation for Release, and GCC's LTO
# cannot inline the fortified vsnprintf on Alpine, so that line is patched
# off, as stage 12 does. SDL2 is found by its CMake package, which is
# sdl2-compat's and needs sdl2-compat-static (see DevilutionX). The binary
# installs to $PREFIX/games, which is not on Alpine's PATH; a launcher in bin
# runs it there. The game looks for its data only under /usr/local and /usr,
# so the launcher names it: under any other prefix it would stop at once,
# "Unable to find the resource directories!".
# Alpine's FLAC CMake package names /usr/bin/flac, the command-line program,
# and CMake stops when that file is absent -- which it is unless flac itself
# is installed. With the package skipped, the CMakeLists takes its own
# fallback, pkg-config's flac++, and needs nothing more.
ENDLESSSKY_VER=0.11.2
endlesssky_install() {
    _s=$(gh_source endless-sky/endless-sky "v$ENDLESSSKY_VER" \
         066b4c171fa7756b4c538a81e9926d4d7686cdbbe44fb5ab2c83e137a7493278) || return 1
    sed -i 's/^set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)/set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE FALSE)/' \
        "$_s/CMakeLists.txt"
    cmake_stage "$_s" -DES_USE_VCPKG=OFF -DBUILD_TESTING=OFF -DCMAKE_DISABLE_FIND_PACKAGE_FLAC=ON || return 1
    launcher endless-sky <<EOF
exec "$PREFIX/games/endless-sky" --resources "$PREFIX/share/games/endless-sky" "\$@"
EOF
}
