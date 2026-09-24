# playbook: amiberry
# source:   github BlitterStudio/amiberry
# build:    build-base cmake samurai pkgconf sdl3-dev sdl3_image-dev@testing flac-dev mpg123-dev
#           libpng-dev zlib-dev curl-dev nlohmann-json libpcap-dev zstd-dev libmpeg2-dev
#           portmidi-dev enet-dev libserialport-dev@testing mesa-dev dbus-dev wayland-dev
#           wayland-protocols
# runs:     sdl3 sdl3_image@testing flac-libs mpg123-libs libpng libcurl libpcap zstd-libs libmpeg2
#           portmidi enet libserialport@testing
#
# program:  amiberry
# label:    Amiberry (Amiga emulator)
# shelf:    Games
# install:  amiberry@source
# mode:     x
# gate:     64
# home:     https://github.com/BlitterStudio/amiberry
# about:    An Amiga 500 to 4000 emulator tuned for ARM boards, with WHDLoad for games from
#           hard-disk images. Needs Kickstart ROMs for most software; AROS boots without them.

# Amiberry: an Amiga emulator tuned for ARM, on SDL3. Alpine has every library
# it asks for, two of them in edge/testing, so none of its FetchContent
# fallbacks (which would clone at build time) is used. It needs Kickstart ROMs
# to run most software; its built-in AROS ROM boots without them.
AMIBERRY_VER=8.3.0
amiberry_install() {
    _s=$(gh_source BlitterStudio/amiberry "v$AMIBERRY_VER" \
         881628c2465fe28063b8444350e78167e7a9ed047def66b9ef3cfdabd4bdc1d6) || return 1
    # musl declares aarch64's mcontext_t.regs as unsigned long, glibc as
    # unsigned long long: both 64 bits there, so the cast is exact.
    sed -i 's|unsigned long long\* regs = context->regs;|unsigned long long* regs = reinterpret_cast<unsigned long long*>(context->regs);  // copal: musl|' \
        "$_s/src/osdep/sigsegv_handler.cpp"
    # musl's C++ NULL is nullptr, which no static_cast turns into an address;
    # glibc's is an integer. The intent is zero.
    sed -i 's|static_cast<uaecptr>(NULL)|static_cast<uaecptr>(0)|g' "$_s/src/custom.cpp"
    # Native file dialogs: nativefiledialog-extended is a git submodule, which
    # GitHub's archive leaves as an empty directory, so the build turned them
    # off. Release 1.4.0 fills it -- the first with the Wayland window API
    # (NFD_SetWaylandDisplay) Amiberry calls; 1.2.1, which Naev pins, lacks
    # it. Amiberry builds it for xdg-desktop-portal, which needs only D-Bus.
    _n=$(gh_source btzy/nativefiledialog-extended v1.4.0 \
         38116050495cd7de77a91d6d8d59c1aa0a0848c56daa60029bd5b59f3c897229) || return 1
    rmdir "$_s/external/nativefiledialog-extended" && cp -r "$_n" "$_s/external/nativefiledialog-extended"
    # ...which has a submodule of its own, the Wayland protocol files, left
    # empty the same way. Alpine's wayland-protocols is that repository.
    _wp=$(pkg-config --variable=pkgdatadir wayland-protocols)
    rm -rf "$_s/external/nativefiledialog-extended/3ps/wayland-protocols"
    ln -s "$_wp" "$_s/external/nativefiledialog-extended/3ps/wayland-protocols"
    cmake_stage "$_s" -DFETCHCONTENT_FULLY_DISCONNECTED=ON -DUSE_DBUS=OFF -DUSE_GPIOD=OFF
}
