#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
#
# grub-bios-build.sh -- GRUB's legacy-BIOS boot code, built once, kept in
# vendor/grub-i386-pc/, and written onto every PC card by `copal-disk.sh
# biosboot` with nothing but dd.
#
# WHY THIS IS A FILE AND NOT A STEP OF THE BUILD. A BIOS boots by running the
# first 440 bytes of the disk, which load the rest of the boot loader from the
# sectors before partition 1. grub-install writes both, and it is a Linux tool;
# cards are written on a Mac. But what grub-install writes is only bytes, and
# for an MBR disk whose partition 1 starts at sector 2048 (which is what
# diskutil and sfdisk both give) they are the same bytes on every card:
#
#   boot.img   440 bytes into sector 0. Its kernel sector (offset 0x5c) is
#              already 1, so it loads core.img from sector 1 as it stands.
#   core.img   into sectors 1 onward. grub-mkimage already ends its first
#              sector with a blocklist of "start at sector 2, the rest of me",
#              which is exactly the embedding grub-bios-setup would write.
#
# The one patch grub-bios-setup makes for a hard disk -- two NOPs over the
# drive-check jump at 0x66, so a BIOS that hands over a wrong drive number
# still boots -- is made by copal-disk.sh, because it is two bytes and stating
# it there is clearer than hiding it in a blob.
#
# The prefix is (,msdos1)/boot/grub: partition 1 of whatever disk the BIOS
# booted, with no UUID and no label, so one core.img serves every card. Every
# module grub.cfg needs is built in, because the card carries no i386-pc/
# module directory for GRUB to load more from.
#
# RUN IT ON ALPINE (any Copal machine will do), as an ordinary user: it uses
# `apk fetch`, which downloads the packages without installing them, and runs
# grub-mkimage out of the unpacked package. Then copy vendor/grub-i386-pc/
# back into the repository.
#
#   sh tools/grub-bios-build.sh [OUTDIR]     default: ./vendor/grub-i386-pc
set -eu

OUT="${1:-vendor/grub-i386-pc}"
# linux16: the network boot entry starts netboot.xyz's .lkrn with it.
MODULES='biosdisk part_msdos fat normal linux linux16 echo test search search_label
search_fs_uuid search_fs_file configfile ls minicmd cat halt reboot'

command -v apk >/dev/null 2>&1 || { echo "grub-bios-build: needs Alpine (apk)" >&2; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" "$OUT"

(cd "$WORK" && apk fetch -q grub grub-bios)
for _p in "$WORK"/*.apk; do
    # An .apk is gzipped tar segments; tar reads the payload and complains
    # about the signature segment, which is harmless here.
    tar -xzf "$_p" -C "$WORK/root" 2>/dev/null || true
done
VERSION=$(cd "$WORK" && ls grub-bios-*.apk | sed 's/^grub-bios-//; s/\.apk$//')

G="$WORK/root/usr/lib/grub/i386-pc"
[ -f "$G/boot.img" ] || { echo "grub-bios-build: no boot.img in grub-bios-$VERSION" >&2; exit 1; }

# shellcheck disable=SC2086  # the module list is words, on purpose
"$WORK/root/usr/bin/grub-mkimage" -d "$G" -O i386-pc \
    -o "$OUT/core.img" -p '(,msdos1)/boot/grub' $MODULES
cp "$G/boot.img" "$OUT/boot.img"

# The two facts copal-disk.sh relies on, checked here so a GRUB that ever
# changes them fails at build time rather than at a black screen.
_ks=$(od -An -tu1 -j 92 -N 1 "$OUT/boot.img" | tr -d ' ')
[ "$_ks" = 1 ] || { echo "grub-bios-build: boot.img kernel sector is $_ks, not 1" >&2; exit 1; }
_bl=$(od -An -tu1 -j 500 -N 1 "$OUT/core.img" | tr -d ' ')
[ "$_bl" = 2 ] || { echo "grub-bios-build: core.img blocklist starts at $_bl, not 2" >&2; exit 1; }

(cd "$OUT" && sha256sum boot.img core.img > SHA256SUMS)
cat > "$OUT/SOURCE" <<EOF
GRUB $VERSION (Alpine packages grub and grub-bios, $(cat /etc/alpine-release 2>/dev/null || echo unknown) $(uname -m)),
built by tools/grub-bios-build.sh on $(date -u +%Y-%m-%d).
grub-mkimage -O i386-pc -p '(,msdos1)/boot/grub'
  $(echo $MODULES)

GRUB is free software under the GNU General Public License, version 3 or
later. Its corresponding source is Alpine's: the aports recipe
main/grub at the release above, and the GNU tarball it names,
https://ftp.gnu.org/gnu/grub/ . These two files are GRUB's, not Copal's,
and are not covered by Copal's MIT licence.
EOF
echo "grub-bios-build: GRUB $VERSION -> $OUT ($(wc -c < "$OUT/core.img") byte core.img)"
