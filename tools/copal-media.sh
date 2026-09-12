#!/bin/sh
# SPDX-License-Identifier: MIT
# copal-media.sh -- write down that a card, an image or a machine was made.
#
# THE INSECURITY IN A PILE OF EIGHT SD CARDS IS NOT CRYPTOGRAPHIC. It is that a
# card is an anonymous object with a one-time enrolment token baked onto it and
# nothing on the outside of it saying which one it is. This file is the piece
# of paper that would otherwise be a piece of paper: one append-only line per
# write, in ~/.copal/fleets/<fleet>/media, mode 600.
#
#   copal-media.sh record --fleet NAME --index N --host ID --board B \
#                         --target sd|img|vm [--sha256 HEX] [--token TOKEN] \
#                         [--outcome ok|N]
#
# THE TOKEN IS NEVER WRITTEN DOWN. What lands in the file is the first eight
# hex of its SHA-256 -- enough to match a card to a ledger row, useless to
# anyone who reads the file. A manifest that carried tokens would be a manifest
# that enrolled nodes, which is the thing the tokens exist to gate.
#
# Called by the Makefile after a successful write, so a card written from the
# command line is recorded the same way one written from the console is.
set -eu

die() { printf 'copal-media: %s\n' "$*" >&2; exit 2; }

fingerprint() {
    # Eight hex characters, from whichever of the three usual programs exists.
    # No openssl on a minimal Mac install is a real case; so is no sha256sum.
    _t=$1
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$_t" | sha256sum | cut -c1-8
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$_t" | shasum -a 256 | cut -c1-8
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s' "$_t" | openssl dgst -sha256 | sed 's/.*= *//' | cut -c1-8
    else
        printf '%s' '-'
    fi
}

cmd_record() {
    _fleet=''; _index=''; _host=''; _board=''; _target=''
    _sha='-'; _token=''; _outcome=ok
    while [ $# -gt 0 ]; do
        case "$1" in
            --fleet)   _fleet=${2:-}; shift 2 ;;
            --index)   _index=${2:-}; shift 2 ;;
            --host)    _host=${2:-}; shift 2 ;;
            --board)   _board=${2:-}; shift 2 ;;
            --target)  _target=${2:-}; shift 2 ;;
            --sha256)  _sha=${2:-}; shift 2 ;;
            --token)   _token=${2:-}; shift 2 ;;
            --outcome) _outcome=${2:-}; shift 2 ;;
            *) die "unknown option $1" ;;
        esac
    done
    [ -n "$_fleet" ]  || die "which fleet?"
    [ -n "$_host" ]   || die "which host?"
    [ -n "$_target" ] || die "sd, img or vm?"
    case "$_target" in
        sd|img|vm) ;;
        *) die "the target is sd, img or vm" ;;
    esac
    # A tab-separated file with a tab inside a field is a file that reads back
    # wrong, and every one of these is a name rather than prose.
    for _f in "$_fleet" "$_host" "$_board" "$_target" "$_sha" "$_outcome"; do
        case "$_f" in
            *"$(printf '\t')"*|*"$(printf '\n')"*) die "a field with a tab or a newline in it" ;;
        esac
    done

    _dir="$HOME/.copal/fleets/$_fleet"
    mkdir -p "$_dir"
    chmod 700 "$HOME/.copal" 2>/dev/null || true
    _file="$_dir/media"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')" \
        "${_index:--}" "$_host" "${_board:--}" "$_target" \
        "${_sha:--}" "$(fingerprint "$_token")" "$_outcome" \
        >> "$_file"
    chmod 600 "$_file" 2>/dev/null || true
    printf 'recorded: %s %s %s\n' "$_host" "$_target" "$_outcome"
}

cmd_show() {
    _fleet=${1:-}
    [ -n "$_fleet" ] || die "which fleet?"
    _file="$HOME/.copal/fleets/$_fleet/media"
    [ -f "$_file" ] || { printf 'nothing has been written for %s yet\n' "$_fleet"; return 0; }
    printf 'when\tidx\thost\tboard\ttarget\tsha256\ttoken\tout\n'
    cat "$_file"
}

case "${1:-}" in
    record) shift; cmd_record "$@" ;;
    show)   shift; cmd_show "$@" ;;
    self-test)
        # The one thing worth proving without a card in a slot: the token goes
        # in and does not come out.
        _t='TOK-abc123-secret'
        _fp=$(fingerprint "$_t")
        [ "${#_fp}" -eq 8 ] || die "a fingerprint is eight characters, got ${#_fp}"
        case "$_fp" in *"$_t"*) die "the token leaked into its own fingerprint" ;; esac
        printf 'copal-media: 2 checks passed\n' ;;
    *)
        printf 'usage: copal-media.sh record --fleet NAME --host ID --target sd|img|vm [...]\n' >&2
        printf '       copal-media.sh show NAME\n' >&2
        exit 2 ;;
esac
