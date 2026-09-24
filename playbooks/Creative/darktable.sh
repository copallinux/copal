# playbook: darktable
# source:   github darktable-org/darktable
# build:    build-base cmake samurai pkgconf gettext-dev intltool libxslt perl gtk+3.0-dev glib-dev
#           libxml2-dev potrace-dev libgphoto2-dev imath-dev openexr-dev libjxl-dev libwebp-dev
#           libavif-dev libheif-dev lensfun-dev sqlite-dev curl-dev libarchive-dev exiv2-dev
#           portmidi-dev openjpeg-dev libsecret-dev graphicsmagick-dev icu-dev lua5.4-dev
#           pugixml-dev osm-gps-map-dev cups-dev json-glib-dev lcms2-dev libjpeg-turbo-dev tiff-dev
#           librsvg-dev libpng-dev zlib-dev sdl2-dev iso-codes-dev
# runs:     iso-codes exiftool
#
# program:  darktable
# label:    darktable (raw photo developer)
# shelf:    Creative
# install:  darktable@source
# mode:     x
# gate:     64
# home:     https://github.com/darktable-org/darktable
# about:    A darkroom for camera raw files: exposure, colour, lens correction and masks, applied
#           without touching the original. Its lighttable sorts, rates and tags a whole shoot.

# darktable: a raw photo developer, CMake over GTK 3. Compiled here rather
# than taken from Alpine (5.4.1) at the owner's wish, and newer for it. The
# release archive carries its submodules -- rawspeed, LibRaw, libxcf,
# whereami -- which GitHub's tag archive does not; every other library is
# Alpine's, Lua 5.4 included (its in-tree Lua stays off).
#
# Everything useful is on: OpenMP, Lua 5.4 with the bundled lua-scripts and
# script manager, the map view, printing, tethering (gphoto2), MIDI
# controllers (PortMidi), GraphicsMagick import, and the JPEG XL, HEIF, AVIF, WebP, OpenEXR and JPEG
# 2000 formats. Exiv2 is Alpine's, built with ISOBMFF, so Canon CR3 metadata
# reads. exiftool comes along for the Lua scripts that call it, and
# iso-codes names the interface languages in preferences (its pkg-config
# file is in -dev). Lensfun's lens database arrives with the library.
#
# Left out: OpenCL (no GPU compute on a Pi or under UTM, and its build-time
# test compiles need clang), G'MIC (Alpine has it only in edge/testing, and
# a stable-branch program linked to an edge library breaks when edge moves
# on; it adds only the LUT 3D module's compressed .gmz packs -- .cube and
# PNG LUTs work without it), colord (a system daemon with polkit, only for
# reading the monitor profile automatically -- an ICC file can be chosen in
# preferences instead), KWallet (no KDE desktop), and the tests.
#
# rawspeed learns the CPU's page size by compiling a probe that tests
# _POSIX_C_SOURCE, which glibc defines by default and musl does not, so on
# Alpine the probe is an #error and configuring stops. The size is given
# instead, from getconf -- this machine's, since a Pi 5 kernel may use 16 KB
# pages -- and rawspeed then skips its probe. Its L1d cache-line probe fails
# the same way (it asks sysconf for a name only glibc has), so the line size
# is read from sysfs, or is rawspeed's own fallback of 64 where the kernel
# does not say, as under UTM. Every 64-bit core a Pi has uses 64.
DARKTABLE_VER=5.6.1
darktable_install() {
    _t=$(gh_asset darktable-org/darktable "release-$DARKTABLE_VER" "darktable-$DARKTABLE_VER.tar.xz" \
         e8b84ac98b0b689a244e4036c4b56394c1d58ce2d9abc05e0a060ef9f756dc36) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _cl=$(cat /sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size 2>/dev/null) || _cl=""
    cmake_stage "$W/darktable-$DARKTABLE_VER" -DBUILD_TESTING=OFF -DUSE_OPENCL=OFF \
        -DTESTBUILD_OPENCL_PROGRAMS=OFF -DUSE_COLORD=OFF -DUSE_KWALLET=OFF -DUSE_GMIC=OFF \
        -DUSE_XMLLINT=OFF -DBUILD_CMSTEST=OFF -DRAWSPEED_PAGESIZE="$(getconf PAGESIZE)" \
        -DRAWSPEED_CACHELINESIZE="${_cl:-64}" || return 1
}
# darktable opens a "Welcome to darktable!" dialog over its first window, once
# per home. A darktablerc holding only that flag spares it; darktable fills in
# every other setting from its defaults on the first run.
darktable_post() {
    printf 'ui/show_welcome_screen=FALSE\n' | seed_homes .config/darktable/darktablerc
}
