# playbook: taisei
# source:   github taisei-project/taisei
# build:    build-base meson samurai pkgconf sdl3-dev freetype-dev libwebp-dev zlib-dev zstd-dev
#           cglm-dev libunibreak-dev opusfile-dev libpng-dev openssl-dev
# runs:
#
# program:  taisei
# label:    Taisei (bullet hell)
# shelf:    Games
# install:  taisei@source
# mode:     x
# gate:     64
# home:     https://github.com/taisei-project/taisei
# about:    A Touhou Project fan game: a vertical shoot-'em-up of dense, patterned bullet storms,
#           six stages with a story, and practice modes. Arrow keys, Z to shoot, X for a bomb, Shift
#           to focus.

# Taisei: a Touhou fan game, a bullet-hell shooter in C over SDL3, meson. The
# release archive is the one to build from: it carries the submodules that
# GitHub's tag archive leaves out. Its fallbacks are .wrap files that meson
# would download, so downloads are off and every library is Alpine's. Only
# the OpenGL 3.3 renderer is built: the SDL_GPU and GLES ones need shaders
# cross-compiled by glslang and SPIRV-Cross at build time, and GL 3.3 is what
# the Pi's V3D and the VM's virgl both offer. The allocator is musl's own;
# mimalloc would be a subproject. The game's assets are installed as files,
# not packed into zips: the packer compresses with Python's zstd module,
# which Alpine's Python 3.14 is built without. Its threads get glibc-sized
# stacks, as Naev's do (see there).
TAISEI_VER=1.4.6
taisei_install() {
    _t=$(gh_asset taisei-project/taisei "v$TAISEI_VER" "taisei-$TAISEI_VER.tar.xz" \
         18d03c67dcc8c7faff22e8defdafc3a734b46c591618d1a678e6e914846889d9) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/taisei-$TAISEI_VER"
    LDFLAGS="${LDFLAGS:-} -Wl,-z,stack-size=8388608" \
    meson setup "$W/build" "$_s" --prefix="$PREFIX" --buildtype=release --wrap-mode=nodownload \
        -Dallocator=libc -Dpackage_data=disabled -Dr_default=gl33 -Dr_gles30=disabled -Dr_sdlgpu=disabled \
        -Dshader_transpiler=disabled -Ddocs=disabled -Dtests=disabled -Dgamemode=disabled
    meson compile -C "$W/build" -j "$JOBS"
    DESTDIR="$DEST" meson install -C "$W/build"
}
