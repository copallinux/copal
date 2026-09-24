# playbook: ddnet
# source:   github ddnet/ddnet
# build:    build-base cmake samurai python3 rust cargo sdl2-dev sqlite-dev curl-dev freetype-dev
#           libogg-dev opus-dev opusfile-dev libpng-dev wavpack-dev glslang glslang-dev
#           vulkan-headers vulkan-loader-dev openssl-dev zlib-dev
# runs:
#
# program:  DDNet
# label:    DDNet (DDraceNetwork)
# shelf:    Games
# install:  ddnet@source
# mode:     x
# gate:     64
# home:     https://github.com/ddnet/ddnet
# about:    Cooperative Teeworlds: a team of tiny gunners hooks and jumps through puzzle maps
#           together. Thousands of maps, online or on a LAN.

# DDNet: DDraceNetwork, the cooperative Teeworlds that outlived Teeworlds.
# CMake over C++ with one Rust library inside, which cargo builds -- its
# crates come from crates.io at build time, into a CARGO_HOME inside the
# build directory that goes when the build does. The video recorder (FFmpeg)
# and the self-updater are left out: the store is the updater.
DDNET_VER=20.0
ddnet_install() {
    _s=$(gh_source ddnet/ddnet "$DDNET_VER" \
         c4f6cca7b04e9d370fc2f187b873347b546d6e0c749c01fa7e5cd7d278c88851) || return 1
    # DATA_DIR is DDNet's own compile-time hook for where its data is; without
    # it the game looks in /usr/local/share and a few fixed places, and any
    # other prefix starts with no data at all (seen on the bench: exit 139).
    # The escaped quotes survive the sh -c that ninja runs each command in.
    CARGO_HOME="$W/cargo" CXXFLAGS="${CXXFLAGS:-} -DDATA_DIR=\\\"$PREFIX/share/ddnet/data\\\"" \
        cmake_stage "$_s" -DVIDEORECORDER=OFF -DAUTOUPDATE=OFF \
        -DINFORM_UPDATE=OFF -DPREFER_BUNDLED_LIBS=OFF -DTOOLS=OFF -DUPNP=OFF
}
