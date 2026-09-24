#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-fleet-cmd -- make 'copal fleet' a real command on the operator's machine.
#
#   make install-fleet        (or: sh tools/copal-fleet-cmd.sh [BINDIR])
#
# The Mac or Linux host that holds the fleet's certificate authority has no
# 'copal' command: that is the front door on a Copal machine, and it already
# answers 'copal fleet'. Here, this writes a small one into ~/.local/bin (or
# BINDIR) that does only that -- runs THIS checkout's tools/copal-fleet.sh --
# so the fleet guides' 'copal fleet ls' works as typed, and orrery's default
# --fleet-cmd finds it. The console runs from the checkout rather than a copy
# because it needs the checkout around it: answers.txt, tools/, fleets/.
#
# It will not overwrite a 'copal' it did not write, and it says so. Run it
# again if the checkout moves.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$HOME/.local/bin}"
DEST="$BIN/copal"
MARK="written by 'make install-fleet'"

[ -f "$ROOT/tools/copal-fleet.sh" ] || { echo "no tools/copal-fleet.sh in $ROOT" >&2; exit 1; }

# A Copal machine's front door already has the verb, and shadowing it from
# ~/.local/bin (which comes first on PATH) would hide every other thing it does.
if [ -f /usr/local/bin/copal ] && grep -q 'the front door on the machine itself' /usr/local/bin/copal 2>/dev/null; then
    echo "This is a Copal machine: its own 'copal' already runs 'copal fleet'. Nothing written."
    exit 0
fi
if [ -e "$DEST" ] && ! grep -qF "$MARK" "$DEST" 2>/dev/null; then
    echo "refusing: $DEST exists and is not one this wrote. Move it, or name another directory:" >&2
    echo "  sh tools/copal-fleet-cmd.sh DIR" >&2
    exit 1
fi

# The checkout's path goes in single-quoted; one with a quote in it is refused
# rather than escaped, because nobody's checkout is called that on purpose.
case "$ROOT" in *\'*) echo "refusing: the checkout's path has a quote in it: $ROOT" >&2; exit 1 ;; esac

mkdir -p "$BIN"
cat > "$DEST.new" <<EOF
#!/bin/sh
# copal -- 'copal fleet' on the operator's machine, $MARK
# in $ROOT. Run that again if the checkout moves.
case "\${1:-}" in
    fleet) shift; exec sh '$ROOT/tools/copal-fleet.sh' "\$@" ;;
    *) echo "copal: on this machine it is only 'copal fleet ...' -- the rest is 'make' in $ROOT" >&2; exit 2 ;;
esac
EOF
chmod 0755 "$DEST.new"
mv "$DEST.new" "$DEST"
echo "wrote $DEST -- 'copal fleet' runs $ROOT/tools/copal-fleet.sh"
case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "note: $BIN is not on PATH in this shell; add it, or run $DEST directly." ;;
esac
