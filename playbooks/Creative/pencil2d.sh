# playbook: pencil2d
# source:   github pencil2d/pencil
# build:    build-base qt6-qtbase-dev qt6-qtsvg-dev qt6-qtmultimedia-dev qt6-qttools-dev
# runs:     ffmpeg
#
# program:  pencil2d
# label:    Pencil2D (hand-drawn animation)
# shelf:    Creative
# install:  pencil2d@source
# mode:     x
# gate:     64
# home:     https://github.com/pencil2d/pencil
# about:    Traditional frame-by-frame animation with onion skins, in bitmap or vector layers, with
#           sound, exported to video or GIF. Simple enough to start in five minutes.

# Pencil2D: frame-by-frame 2D animation, qmake over Qt 6. Its movie export
# runs ffmpeg by name, so ffmpeg is a runtime dependency no ELF header shows.
PENCIL2D_VER=0.7.2
pencil2d_install() {
    _s=$(gh_source pencil2d/pencil "v$PENCIL2D_VER" \
         22af8bf304cd18ae5d7a84e66d80ea2a21a53963476ffabb60d1d5f37f091a0c) || return 1
    mkdir -p "$W/build"
    (cd "$W/build" && qmake6 "$_s/pencil2d.pro" PREFIX="$PREFIX" CONFIG+=release CONFIG+=NO_TESTS \
         QMAKE_LFLAGS+="-Wl,-z,stack-size=8388608" \
       && nice -n 10 make -j "$JOBS" && make INSTALL_ROOT="$DEST" install) || return 1
}
