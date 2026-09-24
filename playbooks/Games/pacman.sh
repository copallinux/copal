# playbook: pacman
# source:   github ebuc99/pacman
# build:    build-base sdl2-dev sdl2_image-dev sdl2_ttf-dev sdl2_mixer-dev
# runs:     sdl2 sdl2_image sdl2_ttf sdl2_mixer
#
# program:  pacman-game
# label:    Pac-Man (SDL clone)
# shelf:    Games
# install:  pacman@source
# mode:     x
# gate:     64
# home:     https://github.com/ebuc99/pacman
# about:    A faithful Pac-Man for the desktop: eat the dots, dodge the four ghosts. Arrow keys.

# Pac-Man, ebuc99's SDL2 clone, autotools with the configure script shipped.
# Installed as pacman-game: /usr/local/bin/pacman would shadow Arch's package
# manager, which Alpine also packages as 'pacman'.
PACMAN_VER=0.9
pacman_install() {
    _s=$(gh_source ebuc99/pacman "v$PACMAN_VER" \
         e0a8fd6d9919b16a539e06c7d3c12bc1bfd41f867366bf8dad72b49f37f8422b) || return 1
    # The data directory is written into platform.cpp as /usr/local/share,
    # beside the PACKAGE_DATA_DIR that Makefile.am already passes in.
    sed -i 's|"/usr/local/share/pacman/"|PACKAGE_DATA_DIR "/"|' "$_s/src/platform.cpp"
    (cd "$_s" && ./configure --prefix="$PREFIX" && make -j "$JOBS" && make DESTDIR="$DEST" install)
    mv "$DEST$PREFIX/bin/pacman" "$DEST$PREFIX/bin/pacman-game"
}
