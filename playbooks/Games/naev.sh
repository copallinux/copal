# playbook: naev
# source:   github naev/naev
# build:    build-base meson samurai pkgconf sdl2-dev sdl2_image-dev enet-dev pcre2-dev
#           libunibreak-dev cmark-dev yaml-dev libxml2-dev physfs-dev freetype-dev libpng-dev
#           libwebp-dev luajit-dev glpk-dev suitesparse-dev openblas-dev openal-soft-dev
#           libvorbis-dev libogg-dev gettext-dev dbus-dev py3-yaml
# runs:
#
# program:  naev
# label:    Naev (space sandbox)
# shelf:    Games
# install:  naev@source
# mode:     x
# gate:     64
# home:     https://github.com/naev/naev
# about:    A 2D space trading and combat game with a large written story: fly, trade, take missions
#           and join factions across hundreds of systems. Inspired by Escape Velocity.

# Naev: 2D space trading and combat with a long written story, meson. The
# release's source archive carries the game's data (most of its 444 MB).
# Every library comes from Alpine -- LuaJIT, SuiteSparse, GLPK and OpenBLAS
# for its fleet physics and economy among them -- except the file dialog,
# nativefiledialog-extended, which Alpine does not package and meson would
# fetch from its wrap while configuring. Instead both of that wrap's files
# come from wrapdb's own GitHub release through gh_asset, pinned by the
# hashes Naev's .wrap names, and are put in subprojects/packagecache, where
# meson finds them with downloads switched off. Its portal backend is used
# (D-Bus to xdg-desktop-portal) rather than GTK 3, which it would otherwise
# pull in whole for one dialog. Naev finds SuiteSparse's libraries but not its
# headers, which Alpine keeps in their own directory; pkg-config knows which.
# Linked for glibc-sized thread stacks, as cmake_stage does: Naev loads its
# textures on worker threads, and under Mesa's software renderer the first
# upload JIT-compiles a shader there, which overflowed musl's 128 KB.
NAEV_VER=0.12.6
NAEV_NFDE_WRAP=nativefiledialog-extended_1.2.1-1
naev_install() {
    _t=$(gh_asset naev/naev "v$NAEV_VER" "naev-$NAEV_VER-source.tar.xz" \
         e81c0e25630146f3a709a540679a75c0af4983f858184130ebac5c6ba7d4592a) || return 1
    _n=$(gh_asset mesonbuild/wrapdb "$NAEV_NFDE_WRAP" nativefiledialog-extended-1.2.1.tar.gz \
         443697a857c4efacbe08cdaf5182724fa9d9b9a79b8feff2a1601bde1df46b07) || return 1
    _p=$(gh_asset mesonbuild/wrapdb "$NAEV_NFDE_WRAP" "${NAEV_NFDE_WRAP}_patch.zip" \
         044a2e881d874d55a892b61cf553aa7678d1c0f06cfaeb39a1b43f34ca976b09) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/naev-$NAEV_VER"
    mkdir -p "$_s/subprojects/packagecache"
    cp "$_n" "$_s/subprojects/packagecache/nativefiledialog-extended-1.2.1.tar.gz"
    cp "$_p" "$_s/subprojects/packagecache/${NAEV_NFDE_WRAP}_patch.zip"
    LDFLAGS="${LDFLAGS:-} -Wl,-z,stack-size=8388608" \
    meson setup "$W/build" "$_s" --prefix="$PREFIX" --buildtype=release --wrap-mode=nodownload \
        -Dc_args="$(pkg-config --cflags-only-I CHOLMOD)" -Dluajit=enabled -Ddocs_c=disabled -Ddocs_lua=disabled \
        -Dnativefiledialog-extended:xdg-desktop-portal=enabled
    meson compile -C "$W/build" -j "$JOBS"
    DESTDIR="$DEST" meson install -C "$W/build"
}
