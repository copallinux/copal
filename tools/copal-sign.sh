#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-sign.sh -- sign the installer, and check that it is signed.
#
#   tools/copal-sign.sh signers PUBKEY    write copal.allowed_signers: who may
#                                         sign. It goes onto every card, and
#                                         a machine trusts what its card said.
#   tools/copal-sign.sh sign KEY          write copal-prep.sh.sig with the
#                                         private key KEY
#   tools/copal-sign.sh check             is copal-prep.sh.sig a signature of
#                                         copal-prep.sh, by a key in
#                                         copal.allowed_signers?
#
# The signature is SSH's own (ssh-keygen -Y), as a capture's is in Static
# Stream: no keyring, no second tool, and the key is one that exists already.
# It is made for the name 'installer@copal' and the purpose 'copal-installer',
# and 'copal -U' on a machine checks it against both.
#
# SIGN WHEN A RELEASE IS TAGGED, and commit the .sig with it. A commit after
# that changes copal-prep.sh and not the signature, and 'check' says so: main
# is unsigned between releases, on purpose, and a machine is updated to a tag.

set -eu
cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1

SIGN_AS=installer@copal
SIGN_FOR=copal-installer
FILE=copal-prep.sh
SIGNERS=copal.allowed_signers

die() { printf 'copal-sign: %s\n' "$*" >&2; exit 1; }
command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is not installed"

case "${1:-}" in
    signers)
        [ -n "${2:-}" ] || die "which public key?  tools/copal-sign.sh signers ~/.ssh/id_ed25519.pub"
        [ -f "$2" ] || die "no such file: $2"
        # Two fields of a .pub, the type and the key; its comment is left behind.
        read -r _type _key _ < "$2" || true
        case "$_type" in
            ssh-*|ecdsa-*|sk-*) ;;
            *) die "$2 is not a public key: it begins '$_type'" ;;
        esac
        printf '%s namespaces="%s" %s %s\n' "$SIGN_AS" "$SIGN_FOR" "$_type" "$_key" > "$SIGNERS"
        printf '  ok      %s: %s may sign the installer\n' "$SIGNERS" "$(ssh-keygen -l -f "$2" | cut -d' ' -f2)" ;;
    sign)
        [ -n "${2:-}" ] || die "which key?  tools/copal-sign.sh sign ~/.ssh/id_ed25519"
        [ -f "$2" ] || die "no such file: $2"
        rm -f "$FILE.sig"
        ssh-keygen -Y sign -f "$2" -n "$SIGN_FOR" "$FILE" >/dev/null 2>&1 \
            || die "ssh-keygen could not sign $FILE with $2"
        printf '  ok      %s: a signature of %s\n' "$FILE.sig" "$FILE"
        if [ -f "$SIGNERS" ]; then
            exec "$0" check
        fi ;;
    check)
        [ -f "$SIGNERS" ] || die "no $SIGNERS -- tools/copal-sign.sh signers PUBKEY"
        [ -f "$FILE.sig" ] || die "no $FILE.sig -- tools/copal-sign.sh sign KEY"
        if ssh-keygen -Y verify -f "$SIGNERS" -I "$SIGN_AS" -n "$SIGN_FOR" -s "$FILE.sig" < "$FILE" >/dev/null 2>&1; then
            printf '  ok      %s is signed by a key in %s\n' "$FILE" "$SIGNERS"
        else
            die "$FILE.sig is not a signature of $FILE as it is now, by a key in $SIGNERS"
        fi ;;
    *)  sed -n '5,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
