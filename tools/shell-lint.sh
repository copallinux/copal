#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# shell-lint.sh -- make shell-lint, and part of make lint: shellcheck over
# every shell script here, held to docs/text-safety-lab-report.md, section VI.
#
#   an error or a warning    fails
#   /tmp/name.$$             fails: a name that can be guessed
#   a script with no set -u  fails, if it is one that is run
#   a note (info, style)     is counted, and the count may only go down:
#                            NOTES below is the most there may be
#
# A warning that is wrong is answered where it is raised, with
#   # shellcheck disable=SC2034  # and the reason, in a few words
# so that the next reader is told why, and the one after that can disagree.
#
# Without shellcheck this is skipped, and says so: the Mac that builds the
# cards need not have it, and the bench does.

set -eu
NOTES=0

cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1

if ! command -v shellcheck >/dev/null 2>&1; then
    printf '  --      shell-lint skipped: no shellcheck here  (apk add shellcheck)\n'
    exit 0
fi

list=$(mktemp)
said=$(mktemp)
trap 'rm -f "$list" "$said"' EXIT

find . -name '*.sh' ! -name '._*' \
    ! -path './.git/*' ! -path './vendor/*' ! -path './build/*' | sort > "$list"
files=$(wc -l < "$list" | tr -d ' ')

# It exits 1 when it has anything to say, which is not a failure here.
xargs shellcheck -f gcc < "$list" > "$said" 2>&1 || true

# One thing shellcheck does not look for: a file in /tmp whose name can be
# guessed, /tmp/name.$$. A script that runs as root writes where a link was
# put for it. mktemp names a file; mktemp -d makes a folder that is ours.
if xargs grep -nE '^[[:space:]]*[^#[:space:]].*/tmp/[A-Za-z0-9._-]+\.\$\$' < "$list" > "$said.tmp" 2>/dev/null; then
    printf '\033[31merror:\033[0m shell-lint: a file in /tmp with a name that can be guessed; use mktemp\n'
    sed 's/^\.\//          /' "$said.tmp" | cut -c1-150
    rm -f "$said.tmp"
    exit 1
fi
rm -f "$said.tmp"

# And another: a script that is run says what happens when a name was never
# set. One that is read into another -- a playbook, a library -- has no '#!'
# and takes the setting of whatever read it.
unset_ok=$(while read -r f; do
    head -n 1 "$f" | grep -q '^#!' || continue
    grep -qE '^[[:space:]]*set -[a-z]*u' "$f" || printf '%s\n' "$f"
done < "$list")
if [ -n "$unset_ok" ]; then
    printf '\033[31merror:\033[0m shell-lint: a script that is run, with no set -eu (or set -u, and the reason):\n'
    printf '%s\n' "$unset_ok" | sed 's/^\.\//          /'
    exit 1
fi

bad=$(grep -cE ': (error|warning): ' "$said" || true)
notes=$(grep -cE ': (note|style): ' "$said" || true)

if [ "$bad" -gt 0 ]; then
    printf '\033[31merror:\033[0m shell-lint: %s errors and warnings in %s scripts\n' "$bad" "$files"
    grep -E ': (error|warning): ' "$said" | sed 's/^\.\//          /'
    exit 1
fi
if [ "$notes" -gt "$NOTES" ]; then
    printf '\033[31merror:\033[0m shell-lint: %s notes, and %s is the most there may be\n' "$notes" "$NOTES"
    printf '          all of them follow; the new one is in what was changed last\n'
    grep -E ': (note|style): ' "$said" | sed 's/^\.\//          /'
    exit 1
fi
printf '  ok      shell-lint: %s scripts, no error or warning, %s notes\n' "$files" "$notes"
if [ "$notes" -lt "$NOTES" ]; then
    printf '  note    shell-lint: NOTES in tools/shell-lint.sh can come down to %s\n' "$notes"
fi
