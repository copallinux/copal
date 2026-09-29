#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-app-sweep.sh -- run the gallery sweep: every row of the list through
# copal-app-probe.sh --gallery, one probe at a time, never two (a second
# probe's window gets attributed to the first and closed).
#
#   tools/copal-app-sweeplist.py                 # writes the list
#   setsid nohup tools/copal-app-sweep.sh > ~/.cache/copal-gallery/sweep.log 2>&1 < /dev/null &
#
# Detached like that it outlives the terminal it was started from. Progress:
# tail -f ~/.cache/copal-gallery/sweep.log; verdicts also land in ~/copal-apps/log.txt.
# -u and not -e: a probe that fails is a verdict, written down, and the
# sweep goes on to the next row. A name that was never set is a mistake.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd) || exit 1
LIST="${1:-$HOME/.cache/copal-gallery/gallery-list.txt}"
export PATH="$HOME/.cache/copal-bin:$REPO/tools:$PATH"
# The programs run in a scratch directory: editors given a first action
# leave swap and autosave files behind, and they should not land in the repo.
mkdir -p "$HOME/.cache/copal-gallery/cwd" && cd "$HOME/.cache/copal-gallery/cwd" || exit 1
TAB="$(printf '\t')"
while IFS="$TAB" read -r name cmd act; do
    [ -n "$name" ] || continue
    # shellcheck disable=SC2034  # w is read inside the eval below
    case "$name" in winebox-*|winecfg) w=60 ;; *) w=30 ;; esac
    if [ -n "$act" ]; then set -- --act "copal-act $act"; else set --; fi
    echo "=== $(date +%H:%M:%S) $name"
    # ONE WORD OF THIS LINE IS CODE, AND ONLY ONE: $cmd, the row's command
    # line, which is written as a person would type it -- foot -e sh -c
    # 'links; sleep 25' -- and has to be read by a shell to be run at all.
    # The list is copal-app-sweeplist.py's, made from the catalogue, in the
    # person's own ~/.cache. Everything else is left for eval to expand, in
    # quotes, so that a checkout in a folder with a space or a $ in its name
    # is a folder and not a command.
    eval '"$REPO/tools/copal-app-probe.sh" --wait "$w" --gallery "$REPO/docs/img/gallery" "$@" "$name" '"$cmd"
done < "$LIST"
echo "=== $(date +%H:%M:%S) SWEEP DONE"
