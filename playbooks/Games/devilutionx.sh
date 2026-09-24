# playbook: devilutionx
# source:   github diasurgical/devilutionX
# build:    build-base cmake samurai pkgconf sdl2-dev sdl2-compat-static sdl2_image-dev zlib-dev
#           bzip2-dev libpng-dev libsodium-dev gettext-dev
# runs:     sdl2 sdl2_image libsodium libbz2 zlib libpng
#
# program:  devilutionx
# label:    DevilutionX (Diablo)
# shelf:    Games
# install:  devilutionx@source
# mode:     x
# gate:     64
# home:     https://github.com/diasurgical/devilutionX
# about:    Diablo, the 1996 dungeon crawler, on its reconstructed engine: widescreen, controller
#           support and quality-of-life fixes. Plays the free shareware episode as installed; copy
#           DIABDAT.MPQ from the CD or GOG into ~/.local/share/diasurgical/devilution for the whole
#           game.

# DevilutionX: Diablo (1996), its engine reconstructed from the original and
# carried on as free software. Built from the release's fully-vendored source
# -- the libraries it fetches at build time are already in its dist/, so the
# build reaches nothing but this tarball. Alpine supplies SDL2, SDL2_image,
# zlib, bzip2, libpng and libsodium, each named ON below: a source
# distribution defaults every library to its dist/ copy, and dist/'s SDL2
# 2.30 no longer compiles against Alpine's PipeWire headers. SDL_audiolib
# (not packaged) and fmt (it wants its own major version) come from dist/.
#
# THE GAME'S DATA. The engine is free; Diablo is not. What is free is the
# 1997 shareware episode, spawn.mpq, which DevilutionX's own assets
# repository hosts on GitHub, so it plays the first two dungeon levels out
# of the box. A copied DIABDAT.MPQ (the CD or GOG) in
# ~/.local/share/diasurgical/devilution/ is found first and plays the whole
# game. The launcher puts the store's share/ at the head of XDG_DATA_DIRS,
# which is where the engine looks beyond the home directory, so spawn.mpq is
# found under any prefix.
#
# Left out: ZeroTier online play (a large vendored build; TCP multiplayer
# over a LAN stays), Discord presence, the tests, and the Hellfire menu entry,
# which needs Hellfire's own files.
DEVILUTIONX_VER=1.5.5
# sdl2-compat-static: SDL2's CMake package (sdl2-compat's, in 3.24)
# imports SDL2::SDL2main from libSDL2main.a, which only the -static
# subpackage ships, and find_package fails outright without it.
devilutionx_install() {
    _t=$(gh_asset diasurgical/devilutionX "$DEVILUTIONX_VER" devilutionx-src-fully-vendored.tar.xz \
         f42379cdf098a351a2020d9e6de1840c76e09113c792f73c6df34dec26818b04) || return 1
    _m=$(gh_asset diasurgical/devilutionx-assets v2 spawn.mpq \
         64427cd7c1ba904eaa2e0031c16a6b136d0ecef9abc888c5ff8344b459356e38) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/devilutionx-src-full-$DEVILUTIONX_VER"
    cmake_stage "$_s" -DBUILD_TESTING=OFF -DDISABLE_ZERO_TIER=ON -DDISCORD_INTEGRATION=OFF \
        -DDEVILUTIONX_SYSTEM_LIBFMT=OFF -DDEVILUTIONX_SYSTEM_SDL_AUDIOLIB=OFF \
        -DDEVILUTIONX_SYSTEM_SDL2=ON -DDEVILUTIONX_SYSTEM_SDL_IMAGE=ON -DDEVILUTIONX_SYSTEM_ZLIB=ON \
        -DDEVILUTIONX_SYSTEM_BZIP2=ON -DDEVILUTIONX_SYSTEM_LIBPNG=ON -DDEVILUTIONX_SYSTEM_LIBSODIUM=ON \
        -DDISABLE_LTO=ON || return 1
    _d="$DEST$PREFIX/share/diasurgical/devilutionx"
    mkdir -p "$_d" && cp "$_m" "$_d/spawn.mpq"
    rm -f "$DEST$PREFIX/share/applications/devilutionx-hellfire.desktop" \
          "$DEST$PREFIX/share/icons/hicolor/512x512/apps/devilutionx-hellfire.png"
    mv "$DEST$PREFIX/bin/devilutionx" "$DEST$PREFIX/share/diasurgical/devilutionx/devilutionx.bin"
    launcher devilutionx <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/share/diasurgical/devilutionx/devilutionx.bin" "\$@"
EOF
}
