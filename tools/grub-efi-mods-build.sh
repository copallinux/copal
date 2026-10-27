#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
#
# grub-efi-mods-build.sh -- the GRUB modules the network boot entry loads on a
# UEFI machine, kept in vendor/grub-x86_64-efi/ and copied by copal-prep.sh
# to boot/grub/x86_64-efi/ on every PC card.
#
# WHY MODULES AND NOT A NEW GRUB. The UEFI GRUB a card boots is Alpine's own
# \EFI\BOOT\BOOTX64.EFI, taken from its ISO, and that path works and is left
# alone. It has every module the boot needs built in, but not `chainloader`,
# which starting netboot.xyz.efi needs. It does load more from
# $prefix/x86_64-efi/ (its strings say so), and its prefix is
# ($root)/boot/grub. So the netboot entry says `insmod chain`, GRUB loads
# chain.mod and what it depends on from the card, and nothing else changes.
#
# A module must come from the same GRUB as the image that loads it. Both are
# Alpine's grub 2.14 (the image's strings name grub-2.14's source paths); this
# checks the package version it took and writes it to SOURCE.
#
# RUN IT ON ALPINE as an ordinary user, like grub-bios-build.sh:
#   sh tools/grub-efi-mods-build.sh [OUTDIR]   default: vendor/grub-x86_64-efi
set -eu

OUT="${1:-vendor/grub-x86_64-efi}"
WANT='chain'

command -v apk >/dev/null 2>&1 || { echo "grub-efi-mods-build: needs Alpine (apk)" >&2; exit 2; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" "$OUT"
(cd "$WORK" && apk fetch -q grub-efi)
tar -xzf "$WORK"/grub-efi-*.apk -C "$WORK/root" 2>/dev/null || true
VERSION=$(cd "$WORK" && ls grub-efi-*.apk | sed 's/^grub-efi-//; s/\.apk$//')
M="$WORK/root/usr/lib/grub/x86_64-efi"
[ -f "$M/moddep.lst" ] || { echo "grub-efi-mods-build: no moddep.lst in grub-efi-$VERSION" >&2; exit 1; }

# The modules wanted and everything they depend on, from moddep.lst.
closure() {
    awk -v want="$WANT" '
        { sub(/:/, ""); m = $1; $1 = ""; deps[m] = $0 }
        END {
            n = split(want, todo, " ")
            while (n > 0) {
                m = todo[n--]
                if (m == "" || (m in seen)) continue
                seen[m] = 1; print m
                k = split(deps[m], d, " ")
                for (i = 1; i <= k; i++) todo[++n] = d[i]
            }
        }' "$M/moddep.lst"
}
rm -f "$OUT"/*.mod
for _m in $(closure); do cp "$M/$_m.mod" "$OUT/"; done
(cd "$OUT" && sha256sum *.mod > SHA256SUMS)
cat > "$OUT/SOURCE" <<SRC
GRUB $VERSION (Alpine package grub-efi, $(cat /etc/alpine-release 2>/dev/null || echo unknown)),
x86_64-efi modules: $(cd "$OUT" && ls *.mod | tr '\n' ' ')
taken by tools/grub-efi-mods-build.sh on $(date -u +%Y-%m-%d) for: $WANT

GRUB is free software under the GNU General Public License, version 3 or
later. Its corresponding source is Alpine's: the aports recipe main/grub at
the release above, and the GNU tarball it names, https://ftp.gnu.org/gnu/grub/ .
These files are GRUB's, not Copal's, and are not covered by Copal's MIT licence.
SRC
echo "grub-efi-mods-build: GRUB $VERSION -> $OUT ($(ls "$OUT"/*.mod | wc -l) modules)"
