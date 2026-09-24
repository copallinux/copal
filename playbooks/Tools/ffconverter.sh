# playbook: ffconverter
# source:   github l-koehler/FF-converter
# build:    py3-pip py3-setuptools py3-wheel
# runs:     python3 py3-qt5 ffmpeg imagemagick
#
# program:  ffconverter
# label:    FF Multi Converter
# shelf:    Tools
# install:  ffconverter@source
# mode:     x
# gate:     *
# home:     https://github.com/l-koehler/FF-converter
# about:    Converts audio, video, images and documents between formats, in batches. It is a front
#           end to ffmpeg and ImageMagick.

# FF Multi Converter: a PyQt5 front end to ffmpeg, ImageMagick, unoconv and
# pandoc, whichever are present. pip installs it from the source tree into a
# private target directory -- --no-deps, so pip fetches nothing.
FFCONVERTER_VER=2.4.6
ffconverter_install() {
    _s=$(gh_source l-koehler/FF-converter "v$FFCONVERTER_VER" \
         41c8b93151464ef12aa35ec5f77fed52c2998ed05f0cd564aab6ca344ea73388) || return 1
    _t="$PREFIX/lib/copal-store/ffconverter"
    # It looks for presets.xml under /usr/local/share and /usr/share; the
    # prefix it was installed to goes first.
    sed -i "s|presets_lookup_dirs = \\[|presets_lookup_dirs = [\"$PREFIX/share/\", |" "$_s/ffconverter/config.py"
    pip3 install --no-deps --no-build-isolation --no-compile --break-system-packages \
         --target "$DEST$_t" "$_s"
    rm -rf "$DEST$_t/bin" "$DEST$_t/share"
    mkdir -p "$DEST$PREFIX/share/ffconverter" "$DEST$PREFIX/share/icons/hicolor/128x128/apps"
    cp "$_s/share/presets.xml" "$DEST$PREFIX/share/ffconverter/"
    cp "$_s/share/ffconverter.png" "$DEST$PREFIX/share/icons/hicolor/128x128/apps/"
    launcher ffconverter <<EOF
export PYTHONPATH="$_t\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -c 'import sys; from ffconverter.ffconverter import main; sys.exit(main())' "\$@"
EOF
    desktop_entry ffconverter "FF Multi Converter" ffconverter ffconverter "Utility;AudioVideo;" \
        "Convert audio, video, image and document files"
}
