# playbook: bleachbit
# source:   github bleachbit/bleachbit
# build:    make
# runs:     python3 py3-gobject3 gtk+3.0
#
# program:  bleachbit
# label:    BleachBit (clean up disk space)
# shelf:    System
# install:  bleachbit@source
# mode:     x
# gate:     *
# home:     https://github.com/bleachbit/bleachbit
# about:    Frees disk space and privacy by deleting caches, logs, thumbnails and browser history.
#           It works program by program, with a preview first.

# BleachBit's own Makefile installs it, prefix and DESTDIR both honoured.
BLEACHBIT_VER=6.0.4
bleachbit_install() {
    _s=$(gh_source bleachbit/bleachbit "v$BLEACHBIT_VER" \
         5af7cec3ed77b38e2e9ef91201e69d75100664116669b04a053dfd788d996f12) || return 1
    make -C "$_s" install prefix="$PREFIX" DESTDIR="$DEST"
    # po/Makefile writes the translations to /usr/share/locale whatever the
    # prefix; they belong beside everything else.
    mkdir -p "$DEST$PREFIX/share"
    mv "$DEST/usr/share/locale" "$DEST$PREFIX/share/locale"
    rmdir -p "$DEST/usr/share" 2>/dev/null || true
    # The script looks for its package only in /usr/share; it is kept
    # beside the rest and started with the prefix on the path.
    mkdir -p "$DEST$PREFIX/lib/copal-store/bleachbit"
    mv "$DEST$PREFIX/bin/bleachbit" "$DEST$PREFIX/lib/copal-store/bleachbit/bleachbit"
    launcher bleachbit <<EOF
export PYTHONPATH="$PREFIX/share\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 "$PREFIX/lib/copal-store/bleachbit/bleachbit" "\$@"
EOF
}
# The first start writes its settings file and reports a write error while
# doing it (seen on the bench, with a fresh home); a settings file already
# there, marked as past the first start, and the window opens clean.
bleachbit_post() {
    seed_homes .config/bleachbit/bleachbit.ini <<'EOF'
[bleachbit]
first_start = False
EOF
}
