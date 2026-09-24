# playbook: astromenace
# source:   github viewizard/astromenace
# build:    build-base cmake samurai sdl2-dev openal-soft-dev freealut-dev@testing libogg-dev
#           libvorbis-dev freetype-dev fontconfig-dev mesa-dev
# runs:     sdl2 openal-soft-libs freealut@testing libvorbis freetype fontconfig
#
# program:  astromenace
# label:    AstroMenace (3D space shooter)
# shelf:    Games
# install:  astromenace@source
# mode:     x
# gate:     64
# home:     https://github.com/viewizard/astromenace
# about:    A hardcore 3D shoot-'em-up: fifteen levels of enemies and bosses. The money you collect
#           buys weapons and armour between levels.

# AstroMenace: a 3D shoot-'em-up, CMake over SDL2, OpenAL and ALUT. The build
# packs the raw game data into gamedata.vfs by running the binary it just
# made (--pack), and the game looks for that file in DATADIR.
ASTROMENACE_VER=1.4.3
astromenace_install() {
    _s=$(gh_source viewizard/astromenace "v$ASTROMENACE_VER" \
         c16b56bfa91f0b1ac1520d09ead2a1fbb536cbd3d4f3a792a222d44bc708eab1) || return 1
    _d="$PREFIX/lib/copal-store/astromenace"
    cmake -S "$_s" -B "$W/build" -G Ninja -Wno-dev -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$_d" -DDATADIR="$_d" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    nice -n 10 ninja -C "$W/build" -j "$JOBS"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/128x128/apps"
    cp "$W/build/astromenace" "$W/build/gamedata.vfs" "$DEST$_d/"
    cp "$_s/share/astromenace_128.png" "$DEST$PREFIX/share/icons/hicolor/128x128/apps/astromenace.png"
    launcher astromenace <<EOF
exec "$_d/astromenace" "\$@"
EOF
    desktop_entry astromenace AstroMenace astromenace astromenace "Game;ActionGame;" \
        "3D space shoot-'em-up"
}
