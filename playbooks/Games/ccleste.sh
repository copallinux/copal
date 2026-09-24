# playbook: ccleste
# source:   github lemon32767/ccleste
# build:    build-base sdl2-dev sdl2_mixer-dev
# runs:     sdl2 sdl2_mixer
#
# program:  ccleste
# label:    Celeste Classic (PICO-8 platformer)
# shelf:    Games
# install:  ccleste@source
# mode:     x
# gate:     64
# home:     https://github.com/lemon32767/ccleste
# about:    The original Celeste, a precise little platformer from a 2015 game jam, in a C port.
#           Arrow keys, Z to jump, X to dash.

# Celeste Classic, the PICO-8 original of Celeste, in lemon32767's C port:
# the cart's logic transcribed to C over SDL2, its graphics and sounds in
# data/. It reads data/ from the working directory and writes its input
# settings there too, so the launcher runs it from the install directory
# and moves the settings file into the home directory.
CCLESTE_VER=1.4.0
ccleste_install() {
    _s=$(gh_source lemon32767/ccleste "v$CCLESTE_VER" \
         32dfd797f3c863201e0c19aa97974c56a8ed589a34c0522503f25f6e1399edd6) || return 1
    make -C "$_s" -j "$JOBS"
    _d="$DEST$PREFIX/lib/copal-store/ccleste"
    mkdir -p "$_d" "$DEST$PREFIX/share/icons/hicolor/128x128/apps"
    cp "$_s/ccleste" "$_d/" && cp -r "$_s/data" "$_s/gamecontrollerdb.txt" "$_d/"
    cp "$_s/icon.png" "$DEST$PREFIX/share/icons/hicolor/128x128/apps/ccleste.png"
    launcher ccleste <<EOF
mkdir -p "\$HOME/.local/share/ccleste"
export CCLESTE_INPUT_CFG_PATH="\$HOME/.local/share/ccleste/input-cfg.txt"
cd "$PREFIX/lib/copal-store/ccleste" && exec ./ccleste "\$@"
EOF
    desktop_entry ccleste "Celeste Classic" ccleste ccleste "Game;ActionGame;" \
        "The PICO-8 original of Celeste"
}
