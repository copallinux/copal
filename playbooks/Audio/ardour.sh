# playbook: ardour
# source:   url community.ardour.org
# build:    build-base python3 pkgconf gettext-dev itstool boost-dev glibmm2.66-dev libsndfile-dev
#           libsamplerate-dev liblo-dev taglib-dev vamp-sdk-dev rubberband-dev aubio-dev lv2-dev
#           lilv-dev serd-dev sord-dev sratom-dev suil-dev fftw-dev libarchive-dev curl-dev
#           libusb-dev cairomm1.14-dev pangomm2.46-dev pango-dev alsa-lib-dev pulseaudio-dev
#           libxml2-dev libwebsockets-dev readline-dev libxrandr-dev libxinerama-dev
# runs:
#
# program:  ardour9
# label:    Ardour (recording studio)
# shelf:    Audio
# install:  ardour@source
# mode:     x
# gate:     64
# home:     https://ardour.org
# about:    A full digital audio workstation: record many tracks at once, edit and mix them with
#           plugins and automation, and master the result. MIDI and virtual instruments too.

# Ardour: the digital audio workstation, built with waf. Its GitHub archives
# hold only a README: the build takes its version from 'git describe' or from
# libs/ardour/revision.cc, which only ardour.org's own source tarball has --
# so that tarball is the source here, pinned by SHA-256 like the rest.
#
# Backends: ALSA, PulseAudio (which PipeWire answers) and the dummy one. JACK
# is left out, so installing Ardour does not bring a JACK server with it;
# PipeWire's JACK layer is there for anyone who wants it. No phone-home
# check for updates, and no LRDF (LADSPA metadata nobody ships any more).
# Ardour is written against the glibmm-2.4 API series, which Alpine packages
# as glibmm2.66, cairomm1.14 and pangomm2.46; glibmm-dev is the newer 2.68.
#
# Its bundled GTK 2 (libs/tk/ytk and ydk) ships a fixed config.h that
# declares HAVE_GNU_FTW, glibc's nftw() extension -- FTW_ACTIONRETVAL and
# the FTW_STOP / FTW_SKIP_SUBTREE / FTW_CONTINUE returns, which musl does not
# have. With the two lines gone GTK takes its own portable path, a plain
# nftw walk, which is what it does on every non-glibc system.
ARDOUR_VER=9.8.0
ardour_install() {
    _t=$(url_asset "https://community.ardour.org/src/Ardour-$ARDOUR_VER.tar.bz2" \
         1f1a0ae658fb3b10e3fa6f9cab952ab6500955594c3773c5e9421f5e42b23d59) || return 1
    tar -xjf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/Ardour-$ARDOUR_VER"
    sed -i '/#define HAVE_GNU_FTW 1/d' "$_s/libs/tk/ytk/config.h" "$_s/libs/tk/ydk/config.h"
    _a=""; [ "$(uname -m)" = aarch64 ] && _a="--arm64"
    (cd "$_s" && LINKFLAGS="-Wl,-z,stack-size=8388608" python3 ./waf configure --prefix="$PREFIX" \
            --optimize --with-backends=alsa,pulseaudio,dummy --no-phone-home --no-lrdf \
            --freedesktop $_a \
        && nice -n 10 python3 ./waf build -j "$JOBS" \
        && python3 ./waf install --destdir="$DEST") || return 1
}
