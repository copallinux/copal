# playbook: persepolis
# source:   github persepolisdm/persepolis
# build:    meson samurai
# runs:     python3 py3-pyside6 py3-psutil py3-requests py3-setproctitle aria2 yt-dlp ffmpeg
#           libnotify
#
# program:  persepolis
# label:    Persepolis (download manager)
# shelf:    Transfer
# install:  persepolis@source
# mode:     x
# gate:     !v6
# home:     https://github.com/persepolisdm/persepolis
# about:    A download manager built on aria2, using many connections per file. Queues, schedules,
#           and video pages through yt-dlp.

# Persepolis: meson, with its Python package steered into a private directory
# by meson's own python.purelibdir option. It drives aria2 for the transfers
# and yt-dlp for video pages.
PERSEPOLIS_VER=5.2.0
persepolis_install() {
    _s=$(gh_source persepolisdm/persepolis "$PERSEPOLIS_VER" \
         8d002e369955fd77e5353714185ce3edb98463b7117a26583b72f4db4e51b2c8) || return 1
    _py="lib/copal-store/persepolis/python"
    # Its install script checks for the dependencies by importing them, and
    # fails the install when one is missing -- which on a staging build is
    # the wrong moment to ask. apk has already been told what to install.
    sed -i "/add_install_script('check_dependencies.py')/d" "$_s/meson.build"
    meson setup "$W/build" "$_s" --prefix="$PREFIX" -Dpython.purelibdir="$_py" -Dpython.platlibdir="$_py"
    meson compile -C "$W/build"
    DESTDIR="$DEST" meson install -C "$W/build"
    mv "$DEST$PREFIX/bin/persepolis" "$DEST$PREFIX/lib/copal-store/persepolis/persepolis"
    launcher persepolis <<EOF
export PYTHONPATH="$PREFIX/$_py\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 "$PREFIX/lib/copal-store/persepolis/persepolis" "\$@"
EOF
}
