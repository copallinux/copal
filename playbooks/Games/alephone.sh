# playbook: alephone
# source:   github Aleph-One-Marathon/alephone
# build:    build-base boost-dev asio-dev sdl2-dev sdl2_ttf-dev sdl2_image-dev openal-soft-dev
#           libsndfile-dev glu-dev mesa-dev zlib-dev libpng-dev curl-dev zziplib-dev libvorbis-dev
#           libvpx-dev libyuv-dev libebml-dev libmatroska-dev miniupnpc-dev
# runs:
#
# program:  marathon
# label:    Marathon (the free trilogy, Aleph One)
# shelf:    Games
# install:  alephone@source
# mode:     x
# gate:     64
# home:     https://github.com/Aleph-One-Marathon/alephone
# about:    Bungie's 1990s first-person shooters Marathon, Marathon 2 and Marathon Infinity,
#           released free and played on Aleph One, the engine built from Bungie's source. Three
#           launchers: marathon, marathon2, marathon-infinity.

# Marathon: Bungie's trilogy, released free, on Aleph One, the engine built
# from Bungie's own source. The release tarball has its configure script
# already generated; the three games' data come from the same GitHub release
# (about 90 MB between them) and each gets its own launcher.
ALEPHONE_VER=20250829
# libvpx, libyuv, libebml and libmatroska: film export (recording a game
# or a replay to video) and video playback; miniupnpc: hosting a network
# game through a home router. All five were absent from the first build.
# Film export blits with glBlitFramebufferEXT, a name Alpine's libGL
# (glvnd) does not export; the core glBlitFramebuffer it does export has
# the same signature, so the one is defined as the other.
alephone_install() {
    _t=$(gh_asset Aleph-One-Marathon/alephone "release-$ALEPHONE_VER" "AlephOne-$ALEPHONE_VER.tar.bz2" \
         e7c447034aa35dd85ca6836dd8367034c4f4512aa0d14e9781d7033946098806) || return 1
    mkdir -p "$W/src" && tar -xjf "$_t" -C "$W/src"
    _s=$(printf '%s\n' "$W"/src/*)
    (cd "$_s" && ./configure --prefix="$PREFIX" CXXFLAGS="-g -O2 -DglBlitFramebufferEXT=glBlitFramebuffer" \
        && nice -n 10 make -j "$JOBS" && make DESTDIR="$DEST" install)
    _data="$PREFIX/share/alephone"
    mkdir -p "$DEST$_data"
    for _g in "Marathon:644fa202a8df19fd5c36b8c4bc3777c33afd291e2874669defc1819d8e132620:marathon:Marathon" \
              "Marathon2:cac0ce7bd37b91f5da15ad63be1b6131e1f75496906e8fd6af20f0bb1ab86cf9:marathon2:Marathon 2" \
              "MarathonInfinity:8b6ba6b2ca9714a2235b3063281f176ccd27a2e23b96c014f5c700d9a222a018:marathon-infinity:Marathon Infinity"; do
        _z=${_g%%:*}; _x=${_g#*:}; _sum=${_x%%:*}; _x=${_x#*:}; _cmd=${_x%%:*}; _dir=${_x#*:}
        _f=$(gh_asset Aleph-One-Marathon/alephone "release-$ALEPHONE_VER" "$_z-$ALEPHONE_VER-Data.zip" "$_sum")
        unzip -q "$_f" -d "$DEST$_data"
        launcher "$_cmd" <<EOF
exec "$PREFIX/bin/alephone" "$_data/$_dir" "\$@"
EOF
        desktop_entry "$_cmd" "$_dir" "$_cmd" alephone "Game;ActionGame;" "Bungie's $_dir, on the Aleph One engine"
    done
}
