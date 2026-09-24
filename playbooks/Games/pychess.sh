# playbook: pychess
# source:   github pychess/pychess
# build:
# runs:     python3 py3-gobject3 py3-cairo py3-psutil py3-pexpect py3-sqlalchemy py3-websockets
#           gtk+3.0 gtksourceview4 gstreamer gst-plugins-base gst-plugins-good librsvg
#           stockfish@testing
#
# program:  pychess
# label:    PyChess
# shelf:    Games
# install:  pychess@source
# mode:     x
# gate:     *
# home:     https://github.com/pychess/pychess
# about:    Chess against the computer, with Stockfish installed alongside. Play online at FICS and
#           Lichess too, with opening books, puzzles and lessons.

# THE PYTHON PROGRAMS keep their modules in a directory of their own,
# $PREFIX/lib/copal-store/NAME, and their launcher puts it on PYTHONPATH.
# Not site-packages: Alpine's Python does not read /usr/local's, and a path
# with python3.14 in it breaks the day Alpine moves to 3.15. Every library
# they import comes from Alpine's py3-* packages -- nothing from PyPI.

# PyChess runs from its source tree, the way its README runs it.
PYCHESS_VER=1.2.0
pychess_install() {
    _s=$(gh_source pychess/pychess "$PYCHESS_VER" \
         da989acb45ebe77fa013ab68a5e6d4202c8d831af68e3533c8b96a9b5e387548) || return 1
    _d="$PREFIX/lib/copal-store/pychess"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/scalable/apps"
    # The whole tree: it opens ARTISTS, AUTHORS and the rest by path at start.
    cp -r "$_s/." "$DEST$_d/"
    rm -rf "$DEST$_d/testing" "$DEST$_d/debian" "$DEST$_d/macos" "$DEST$_d/devsvg"
    cp "$_s/pychess.svg" "$DEST$PREFIX/share/icons/hicolor/scalable/apps/"
    launcher pychess <<EOF
exec python3 "$_d/pychess" "\$@"
EOF
    desktop_entry pychess PyChess pychess pychess "Game;BoardGame;" "Play chess against the computer or online"
}
# Two dialogs on the first start, both spared: the tip of the day, and one
# asking leave to download scoutfish and chess_db -- prebuilt glibc programs,
# which would not run here if they were fetched.
pychess_post() {
    seed_homes .config/pychess/config <<'EOF'
[General]
show_tip_at_startup = False
download_scoutfish = False
download_chess_db = False
dont_show_externals_at_startup = True
EOF
}
