#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# redeploy-staged.sh -- the part of 'make redeploy' that 'copal -U' cannot do.
#
# 'copal -U --from CHECKOUT' installs one file, copal-init.sh. But a card
# carries more than that from the checkout: tools/copal-theme,
# tools/copal-terminal-theme and themes/, which the installer copies into
# place from the boot partition when a stage asks for them. So a machine that
# was only ever redeployed ran the theme tool its card was written with,
# whatever the checkout said, and a fix to it never arrived.
#
# This puts the checkout's copies on the boot partition, and over the
# installed ones where there are any. Run as root, from 'make redeploy'.
#
#   COPAL_BOOT, COPAL_BIN, COPAL_THEMES   other places, for a test

set -eu
cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1

die() { printf 'redeploy-staged: %s\n' "$*" >&2; exit 1; }

BOOT=${COPAL_BOOT:-}
if [ -z "$BOOT" ]; then
    for _d in /boot /media/*; do
        if [ -f "$_d/answers.txt" ]; then
            BOOT=$_d
            break
        fi
    done
fi
[ -n "$BOOT" ] && [ -d "$BOOT" ] || die "no boot partition with answers.txt on it: is this a Copal machine?"
BIN=${COPAL_BIN:-/usr/local/bin}
THEMES=${COPAL_THEMES:-/usr/local/share/copal/themes}

# The boot partition is FAT, and may be mounted read-only. Put it back as it was.
remounted=0
if ! touch "$BOOT/.copal-redeploy" 2>/dev/null; then
    mount -o remount,rw "$BOOT" 2>/dev/null || die "$BOOT is read-only and would not remount"
    remounted=1
fi
rm -f "$BOOT/.copal-redeploy"

mkdir -p "$BOOT/tools" "$BOOT/themes"
for _t in copal-theme copal-terminal-theme; do
    [ -f "tools/$_t" ] || die "no tools/$_t in this checkout"
    sh -n "tools/$_t" || die "tools/$_t does not parse -- not installing it"
    cp "tools/$_t" "$BOOT/tools/$_t"
    if [ -f "$BIN/$_t" ]; then
        # To a name beside it, then renamed: the tool may be running.
        cp "tools/$_t" "$BIN/.$_t.new"
        chmod 0755 "$BIN/.$_t.new"
        mv -f "$BIN/.$_t.new" "$BIN/$_t"
        printf '  ok      %s -> %s and %s\n' "tools/$_t" "$BOOT/tools" "$BIN"
    else
        printf '  ok      %s -> %s  (not installed here yet; the stage that wants it will)\n' "tools/$_t" "$BOOT/tools"
    fi
done

cp -R themes/. "$BOOT/themes/"
_n=0
for _d in themes/*/; do
    [ -d "$_d" ] || continue
    _name=$(basename "$_d")
    _n=$((_n + 1))
    if [ -d "$THEMES/$_name" ]; then
        cp "$_d"* "$THEMES/$_name/"
        chmod 0644 "$THEMES/$_name"/*
    fi
done
printf '  ok      themes/ -> %s/themes  (%s themes)\n' "$BOOT" "$_n"

if [ -f copal.allowed_signers ]; then
    cp copal.allowed_signers "$BOOT/copal.allowed_signers"
    printf '  ok      copal.allowed_signers -> %s\n' "$BOOT"
fi

sync
if [ "$remounted" = 1 ]; then
    mount -o remount,ro "$BOOT" 2>/dev/null || true
fi
