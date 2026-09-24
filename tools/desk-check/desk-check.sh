#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# desk-check -- drive the site's desktop (docs/index.html) in a real browser
# and report what passed.
#
#   make desk-check                       every check
#   sh tools/desk-check/desk-check.sh t-desk3      one page of them
#   sh tools/desk-check/desk-check.sh --shots OUTDIR   the report's figures
#
# Each t-desk*.js is a page of checks (phase 1 the shell, 2 program windows,
# 3 the site in the menus, 4 keys, fields and what a screen reader is told).
# It is loaded after desk.js, clicks and types and steps through history the
# way a person would, and reports each verdict by requesting /verdict/N/TEXT
# from the server that serves it -- so the verdicts are read from the server's
# log, and no window has to be looked at. Firefox runs headless: nothing
# appears on any screen.
#
# Needs firefox (firefox-esr on Alpine) and python3. docs/ is served, not
# opened as files, because a page opened from file:// may not reach into the
# frames it opens, and the desktop does.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
DOCS="$(cd "$HERE/../../docs" && pwd)"
FF=$(command -v firefox-esr || command -v firefox || true)
[ -n "$FF" ] || { echo "desk-check: needs firefox" >&2; exit 2; }

WORK=$(mktemp -d)
SRV=""
cleanup() {
    [ -n "$SRV" ] && kill "$SRV" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

# docs/ and the checks, side by side, so the pages load the checks as their own.
mkdir -p "$WORK/site"
for f in "$DOCS"/*; do
    case "$f" in */._*) continue ;; esac     # the Mac's AppleDouble files
    ln -s "$f" "$WORK/site/$(basename "$f")"
done
for f in "$HERE"/*.js; do ln -s "$f" "$WORK/site/$(basename "$f")"; done

# One page per page of checks: index.html with that page's script after desk.js.
# The screenshot page makes fetch synchronous and fades instant, because a
# headless screenshot is taken at the load event.
for t in "$HERE"/t-desk*.js; do
    n=$(basename "$t" .js)
    # desk.js is asked for with a version stamp (tools/copal-stamp.py).
    sed -E "s#(<script src=\"desk\.js[^\"]*\"></script>)#\1\n<script src=\"$n.js\"></script>#" \
        "$DOCS/index.html" > "$WORK/site/$n.html"
done
sed -E -e 's#(<script src="menu-data\.js[^"]*"></script>)#<script src="t-syncfetch.js"></script>\n\1#' \
    -e 's#(<script src="desk\.js[^"]*"></script>)#\1\n<script src="t-menu.js"></script>#' \
    "$DOCS/index.html" > "$WORK/site/t-shot.html"

PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$WORK/site" > "$WORK/log" 2>&1 &
SRV=$!
sleep 1
URL="http://127.0.0.1:$PORT"

shot() {  # <width,height> <out.png> <address suffix>
    p=$(mktemp -d -p "$WORK")
    timeout 90 "$FF" --headless --no-remote --profile "$p" --window-size "$1" \
        --screenshot "$2" "$URL/t-shot.html$3" >/dev/null 2>&1 || true
    rm -rf "$p"
}

if [ "${1:-}" = --shots ]; then
    out=${2:?--shots needs a directory}
    mkdir -p "$out"
    shot 1400,860 "$out/welcome.png" ""
    shot 1400,860 "$out/tiled.png" "?menu=split"
    shot 1400,860 "$out/gui.png" "?menu=gui"
    shot 1400,860 "$out/keys.png" "?menu=keys"
    shot 390,844 "$out/phone-welcome.png" ""
    shot 390,844 "$out/phone-gui.png" "?menu=gui"
    shot 390,844 "$out/phone-app.png" "#app/brogue"
    echo "screenshots in $out"
    exit 0
fi

pages=${1:-$(cd "$HERE" && ls t-desk*.js | sed 's/\.js$//')}
fail=0
for n in $pages; do
    # Only what this page writes to the server's log: the log is not emptied
    # between pages, because the server goes on writing at its own offset.
    from=$(($(wc -l < "$WORK/log") + 1))
    p=$(mktemp -d -p "$WORK")
    "$FF" --headless --no-remote --profile "$p" "$URL/$n.html" >/dev/null 2>&1 &
    ff=$!
    i=0
    while [ $i -lt 90 ] && ! tail -n +"$from" "$WORK/log" | grep -q 'GET /verdict/'; do sleep 1; i=$((i + 1)); done
    sleep 3          # the rest of the verdicts, which arrive together
    kill "$ff" 2>/dev/null || true
    wait "$ff" 2>/dev/null || true
    rm -rf "$p"      # a profile is tens of megabytes, and /tmp is a small tmpfs
    tail -n +"$from" "$WORK/log" | grep -o 'GET /verdict/[0-9]*/[^ ]*' | sort -t/ -k3 -n | python3 -c '
import sys, urllib.parse
for l in sys.stdin: print("  " + urllib.parse.unquote(l.split("/", 3)[3].strip()))' > "$WORK/$n.out"
    np=$(grep -c '^  PASS' "$WORK/$n.out" || true)
    nf=$(grep -cE '^  (FAIL|ERROR)' "$WORK/$n.out" || true)
    if [ "$np" = 0 ] && [ "$nf" = 0 ]; then
        echo "  FAIL    $n: no verdicts at all -- the page did not run"; fail=1
    elif [ "$nf" != 0 ]; then
        echo "  FAIL    $n: $np passed, $nf failed"; grep -E '^  (FAIL|ERROR)' "$WORK/$n.out"; fail=1
    else
        echo "  ok      $n: $np checks passed"
    fi
done
exit "$fail"
