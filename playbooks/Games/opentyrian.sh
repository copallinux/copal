# playbook: opentyrian
# source:   github opentyrian/opentyrian
# build:    build-base pkgconf sdl2-dev sdl2_net-dev
# runs:     sdl2 sdl2_net
#
# program:  opentyrian
# label:    OpenTyrian (Tyrian 2000)
# shelf:    Games
# install:  opentyrian@source
# mode:     x
# gate:     64
# home:     https://github.com/opentyrian/opentyrian
# about:    The 1995 vertical shooter Tyrian, freeware since 2004, on its open-source engine: a
#           story campaign, an arcade mode, and ship upgrades bought between levels. Arrow keys to
#           fly, Space to fire.

# OpenTyrian: the 1995 shooter Tyrian 2000's engine, ported to C over SDL2.
# The engine is compiled from the tagged source; the game's data -- freeware
# since 2004 -- comes from the same release's Linux archive, which is the only
# copy on GitHub (the README's other link is camanis.net). Only its data/
# directory is used, and it is the same for every architecture, so the arm64
# archive is fetched on all of them.
OPENTYRIAN_VER=v2.1.20260913
opentyrian_install() {
    _s=$(gh_source opentyrian/opentyrian "$OPENTYRIAN_VER" \
         dbcd96383d4fa571137242c36bd7eca054cf5a08a9bf2eec15ef230d6e60680d) || return 1
    _a=$(gh_asset opentyrian/opentyrian "$OPENTYRIAN_VER" "opentyrian-$OPENTYRIAN_VER-linux-arm64.tar.gz" \
         8608e68622edcabd30eb62fcbdfd8106982c13e29fb775ccccf56956dccd90fb) || return 1
    # VCS_IDREV: the tarball is not a git checkout, so the version is given.
    make -C "$_s" -j "$JOBS" prefix="$PREFIX" VCS_IDREV="echo $OPENTYRIAN_VER" \
        && make -C "$_s" prefix="$PREFIX" VCS_IDREV="echo $OPENTYRIAN_VER" DESTDIR="$DEST" install \
        || return 1
    _g="$DEST$PREFIX/share/games/tyrian"
    mkdir -p "$_g"
    tar -xzf "$_a" -C "$W" opentyrian/data && cp "$W"/opentyrian/data/* "$_g/"
}
