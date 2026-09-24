# playbook: funkin
# source:   github HTV04/funkin-rewritten
# build:    zip
# runs:     love
#
# program:  funkin-rewritten
# label:    Friday Night Funkin' Rewritten (LOVE)
# shelf:    Games
# install:  funkin@source
# mode:     x
# gate:     *
# home:     https://github.com/HTV04/funkin-rewritten
# about:    The rhythm game where you out-sing your girlfriend's father, arrow keys to the beat.
#           Rebuilt on the LOVE engine.

# Friday Night Funkin' Rewritten, a LOVE game: its source tree, zipped, is the
# game file LOVE runs. The release's images are already in the tree.
FUNKIN_VER=1.1.0-beta.2-1
funkin_install() {
    _s=$(gh_source HTV04/funkin-rewritten "v$FUNKIN_VER" \
         5563f4096234f3b2b108bbfcf69f5fdc4fa5b77b4dbc680eb86a6876d837d8fa) || return 1
    _d="$PREFIX/lib/copal-store/funkin"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/256x256/apps"
    (cd "$_s/src/love" && zip -q -r -9 "$DEST$_d/funkin-rewritten.love" .)
    cp "$_s/src/love/icons/default.png" "$DEST$PREFIX/share/icons/hicolor/256x256/apps/funkin-rewritten.png"
    launcher funkin-rewritten <<EOF
exec love "$_d/funkin-rewritten.love" "\$@"
EOF
    desktop_entry funkin-rewritten "Friday Night Funkin' Rewritten" funkin-rewritten funkin-rewritten \
        "Game;MusicGame;" "Rhythm battles, arrow keys to the beat"
}
