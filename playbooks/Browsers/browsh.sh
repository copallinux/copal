# playbook: browsh
# source:   github browsh-org/browsh
# build:    go
# runs:     firefox-esr
#
# program:  browsh
# label:    Browsh (the web in a terminal)
# shelf:    Browsers
# install:  browsh@source
# mode:     t
# gate:     !v6
# home:     https://github.com/browsh-org/browsh
# about:    A modern web browser inside a terminal, or over SSH. A headless Firefox renders each
#           page and Browsh draws it in text and colour blocks, video included.

# Browsh: the web in a terminal, rendered by a real Firefox running headless
# and drawn as text and half-block colour. The Go program embeds its Firefox
# extension (go:embed browsh.xpi); the release publishes that extension and,
# since 1.8.3, no Linux binary -- so the extension is fetched from the same
# release and built in. It drives whichever Firefox is here; Copal's is ESR.
BROWSH_VER=1.8.3
browsh_install() {
    _s=$(gh_source browsh-org/browsh "v$BROWSH_VER" \
         88462530dbfac4e17c8f8ba560802d21042d90236043e11461a1cfbf458380ca) || return 1
    _x=$(gh_asset browsh-org/browsh "v$BROWSH_VER" "browsh-$BROWSH_VER.xpi" \
         c0b72d7c61c30a0cb79cc1bf9dcf3cdaa3631ce029f1578e65c116243ed04e16) || return 1
    cp "$_x" "$_s/interfacer/src/browsh/browsh.xpi"
    mkdir -p "$DEST$PREFIX/lib/copal-store/browsh"
    (cd "$_s/interfacer" && GOPATH="$W/go" GOCACHE="$W/gocache" GOFLAGS=-modcacherw CGO_ENABLED=0 \
        go build -trimpath -ldflags "-s -w" -o "$DEST$PREFIX/lib/copal-store/browsh/browsh" ./cmd/browsh)
    launcher browsh <<EOF
_ff=\$(command -v firefox || command -v firefox-esr)
exec "$PREFIX/lib/copal-store/browsh/browsh" --firefox.path "\$_ff" "\$@"
EOF
}
