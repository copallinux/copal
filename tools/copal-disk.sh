#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
#
# copal-disk.sh -- the one place that knows what a disk looks like.
#
# COPAL BUILDS COPAL MACHINES AND, UNTIL THIS FILE, COULD NOT BE BUILT ON ONE.
# copal-prep.sh is 31,000 lines of portable shell with a macOS-shaped hole in
# exactly one place: the twenty minutes where it finds, partitions and mounts a
# block device. The payload either side of that hole is COPIED, never executed,
# so nothing else in the build cares what the host is.
#
# The obvious fix is `if macos; then diskutil; else lsblk; fi` at each of the
# twenty-five call sites. That is twenty-five chances to port one branch and
# forget the other, in a file where forgetting costs somebody their external
# drive. So: one verb per operation, two backends, chosen once here.
#
# THE TRAP THIS EXISTS NOT TO REPEAT. A shim whose second backend can quietly
# no-op a verb it never implemented is worse than no shim -- the build walks
# past `bootflag` doing nothing and the failure arrives three steps later
# looking like a firmware bug. So every verb is dispatched through a table, a
# verb with no implementation is a hard die naming itself, and `verbs` prints
# the table so `self-test` can compare the two backends name for name.
#
#   copal-disk.sh list                     removable whole disks, for a human
#   copal-disk.sh show DISK                one disk's partitions, for a human
#   copal-disk.sh probe DISK               eleven facts, as key=value lines
#   copal-disk.sh part DISK N              name partition N (disk4s1 / sda1)
#   copal-disk.sh unmount-all DISK         unmount every volume on it
#   copal-disk.sh unmount DISK N           unmount one partition
#   copal-disk.sh mount DISK N             mount it, PRINT where
#   copal-disk.sh partition DISK BL BS RL RS    MBR: FAT32 boot + root
#   copal-disk.sh type DISK N HEX          set the MBR type byte
#   copal-disk.sh bootflag DISK N          mark partition N active
#   copal-disk.sh eject DISK               flush and let go of it
#   copal-disk.sh image-attach PATH        attach a raw image, PRINT the device
#   copal-disk.sh image-detach DEV         let go of it
#   copal-disk.sh image-attached PATH      PRINT the device, if it is attached
#   copal-disk.sh sha256-check SUMFILE     verify a downloaded file
#   copal-disk.sh verbs | backend | self-test
set -eu

die() { printf 'copal-disk: %s\n' "$*" >&2; exit 2; }

# The whole surface. Adding a line here without adding both functions is what
# self-test exists to catch.
VERBS='list show probe part unmount-all unmount mount partition type bootflag
eject image-attach image-detach image-attached sha256-check'

case "$(uname -s)" in
    Darwin) BACKEND=macos ;;
    Linux)  BACKEND=linux ;;
    *)      BACKEND='' ;;
esac

# Root, however this machine spells it. macOS says sudo; Alpine ships doas and
# no sudo at all on a minimal install. Neither is assumed, and being root
# already is the third case -- `make redeploy` runs as root and a doas inside
# a doas is a password prompt for no reason.
PRIV=''
priv() {
    if [ -z "$PRIV" ]; then
        if [ "$(id -u)" = 0 ]; then PRIV='-'
        elif command -v doas >/dev/null 2>&1; then PRIV='doas'
        elif command -v sudo >/dev/null 2>&1; then PRIV='sudo'
        else die "this needs root, and neither doas nor sudo is installed"
        fi
    fi
    if [ "$PRIV" = '-' ]; then "$@"; else "$PRIV" "$@"; fi
}

# ------------------------------------------------------------------ shared ---

# Bytes to something a human reads, without bc and without locale. Deliberately
# the same rounding on both backends so the two reports can be compared.
human_size() {
    _hs=$1
    if   [ "$_hs" -ge 1099511627776 ]; then printf '%s.%s TB\n' $((_hs/1099511627776)) $(((_hs%1099511627776)*10/1099511627776))
    elif [ "$_hs" -ge 1073741824 ];    then printf '%s.%s GB\n' $((_hs/1073741824))    $(((_hs%1073741824)*10/1073741824))
    elif [ "$_hs" -ge 1048576 ];       then printf '%s.%s MB\n' $((_hs/1048576))       $(((_hs%1048576)*10/1048576))
    else printf '%s bytes\n' "$_hs"
    fi
}

# ------------------------------------------------------------------- macOS ---

macos_list()        { diskutil list external physical; }
macos_show()        { diskutil list "/dev/$1"; }
macos_part()        { printf '%ss%s\n' "$1" "$2"; }
macos_unmount_all() { diskutil unmountDisk "/dev/$1" >/dev/null 2>&1 || true; }
macos_unmount()     { diskutil unmount "$(macos_part "$1" "$2")" >/dev/null 2>&1 || true; }

# diskutil mounts where it likes -- /Volumes/<label>, or "<label> 1" when a
# second build already took the name. So the mount point is READ BACK from the
# device rather than assumed, which is the bug the /Volumes/$BOOT_LABEL
# constant used to hide.
macos_mount() {
    _p=$(macos_part "$1" "$2")
    diskutil mount "$_p" >/dev/null 2>&1 || true
    _m=$(df "/dev/$_p" 2>/dev/null | awk 'NR==2 {sub(/^[^ ]+ +([0-9]+ +){4}[0-9]+% +/, ""); print}')
    [ -n "$_m" ] || die "mounted /dev/$_p but could not find where"
    printf '%s\n' "$_m"
}

macos_probe() {
    _i=$(diskutil info "/dev/$1" 2>/dev/null) || die "no such disk: /dev/$1"
    # grep exits 1 on no match, and a whole disk legitimately has no
    # "Ejectable" line at all; || true is what makes a missing field empty
    # instead of killing the caller under set -e.
    _g() { printf '%s\n' "$_i" | grep -E "^ *$1:" | head -n1 | sed 's/.*: *//' | xargs || true; }
    _bytes=$(printf '%s\n' "$_i" | grep -E '^ *Disk Size:' \
             | grep -oE '\([0-9]+ Bytes\)' | grep -oE '[0-9]+' | head -n1 || true)
    printf 'media_name=%s\n'     "$(_g 'Device / Media Name')"
    printf 'size_bytes=%s\n'     "${_bytes:-0}"
    printf 'size_human=%s\n'     "$(_g 'Disk Size' | sed 's/ (.*//')"
    printf 'removable=%s\n'      "$(_g 'Removable Media')"
    printf 'ejectable=%s\n'      "$(_g 'Ejectable')"
    printf 'internal=%s\n'       "$(_g 'Device Location')"
    printf 'virtual=%s\n'        "$(_g 'Virtual')"
    printf 'whole=%s\n'          "$(_g 'Whole')"
    printf 'protocol=%s\n'       "$(_g 'Protocol')"
    printf 'os_installable=%s\n' "$(_g 'OS Can Be Installed')"
    printf 'uuid=%s\n'           "$(_g 'Disk / Partition UUID')"
}

macos_partition() {
    # DISK BOOT_LABEL BOOT_SIZE ROOT_LABEL ROOT_SIZE. "R" is diskutil's word
    # for the remainder; with an explicit root size the rest is left
    # unallocated, which is what %noformat% R says.
    if [ "$5" = R ]; then
        diskutil partitionDisk "/dev/$1" MBRFormat MS-DOS "$2" "$3" MS-DOS "$4" R
    else
        diskutil partitionDisk "/dev/$1" MBRFormat MS-DOS "$2" "$3" \
            MS-DOS "$4" "$5" "Free Space" %noformat% R
    fi
}

# fdisk -e is interactive and has no batch mode; the keystrokes are the API.
macos_type()     { printf 't %s\n%s\nw\ny\nq\n' "$2" "$3" | priv fdisk -e "/dev/$1" >/dev/null 2>&1; }
macos_bootflag() { printf 'f %s\nw\ny\nq\n' "$2" | priv fdisk -e "/dev/$1" >/dev/null 2>&1; }
macos_eject()    { diskutil eject "/dev/$1"; }

# CRawDiskImage: a bare sector image with no header, which is what a card is
# and what QEMU expects back. Without it hdiutil looks for a UDIF structure and
# declines a file that has none.
macos_image_attach() {
    _d=$(hdiutil attach -imagekey diskimage-class=CRawDiskImage -nomount "$1" \
         | awk 'NR==1 { print $1 }') || die "hdiutil could not attach $1"
    [ -n "$_d" ] || die "hdiutil attached $1 but reported no device"
    printf '%s\n' "$_d"
}
macos_image_detach() {
    hdiutil detach "$1" >/dev/null 2>&1 || hdiutil detach -force "$1" >/dev/null 2>&1 || true
}
# hdiutil pads the key to a fixed width -- "image-path      : /path" -- so the
# separator matches as whitespace-colon-whitespace. Comparing against a literal
# "image-path : " never matched, which made this check silently useless once.
macos_image_attached() {
    hdiutil info 2>/dev/null | awk -v f="$1" '
        /^image-path[[:space:]]*:/ {
            line = $0
            sub(/^image-path[[:space:]]*:[[:space:]]*/, "", line)
            cur = (line == f)
        }
        cur && /^\/dev\/disk[0-9]+/ { print $1; exit }' || true
}
macos_sha256_check() { shasum -a 256 -c "$1"; }

# ------------------------------------------------------------------- Linux ---

linux_list() {
    lsblk -o NAME,SIZE,TYPE,TRAN,HOTPLUG,MODEL,MOUNTPOINTS \
        | awk 'NR==1 || $3=="disk"'
}
linux_show() { lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "/dev/$1"; }

# THE RULE MOST LIKELY TO BE GOT WRONG, AND THE ONE WHOSE FAILURE WRITES TO THE
# WRONG NODE. sda -> sda1, but mmcblk0 -> mmcblk0p1 and nvme0n1 -> nvme0n1p1
# and loop0 -> loop0p1: a name already ending in a digit takes a 'p' first, or
# "mmcblk01" is a device that does not exist and, worse, might.
linux_part() {
    case "$1" in
        *[0-9]) printf '%sp%s\n' "$1" "$2" ;;
        *)      printf '%s%s\n'  "$1" "$2" ;;
    esac
}

linux_unmount_all() {
    for _m in $(lsblk -n -o MOUNTPOINT "/dev/$1" 2>/dev/null | grep -v '^$' || true); do
        priv umount "$_m" >/dev/null 2>&1 || true
    done
}
linux_unmount() {
    priv umount "/dev/$(linux_part "$1" "$2")" >/dev/null 2>&1 || true
}

# Linux mounts where it is told, so this makes somewhere and says where. Named
# after the filesystem label when there is one, so a build in flight is legible
# in `mount` output; after the node when there is not.
linux_mount() {
    _p=$(linux_part "$1" "$2")
    _l=$(lsblk -n -o LABEL "/dev/$_p" 2>/dev/null | head -n1 | xargs || true)
    _root="${COPAL_MOUNT_ROOT:-$HOME/.copal/mnt}"
    _m="$_root/${_l:-$_p}"
    mkdir -p "$_m" || die "cannot create the mount point $_m"
    if ! mountpoint -q "$_m" 2>/dev/null; then
        priv mount "/dev/$_p" "$_m" || die "could not mount /dev/$_p at $_m"
    fi
    printf '%s\n' "$_m"
}

# Pure: one `lsblk -P` line in, the eleven keys out. Kept apart from the lsblk
# call so self-test can drive it from a recording instead of a device.
linux_probe_map() {
    _line=$(cat)
    _f() { printf '%s\n' "$_line" | sed -n "s/.*[[:space:]]\{0,1\}$1=\"\([^\"]*\)\".*/\1/p" | head -n1; }
    _model=$(_f MODEL); _size=$(_f SIZE); _rm=$(_f RM)
    _type=$(_f TYPE);   _tran=$(_f TRAN); _hot=$(_f HOTPLUG); _ptuuid=$(_f PTUUID)
    [ -n "$_size" ] || _size=0

    case "$_tran" in
        usb)  _proto='USB' ;;
        mmc)  _proto='Secure Digital' ;;
        '')   _proto='' ;;
        *)    _proto="$_tran" ;;
    esac
    [ "$_type" = loop ] && _proto='Disk Image'

    printf 'media_name=%s\n'     "${_model:-unknown}"
    printf 'size_bytes=%s\n'     "$_size"
    printf 'size_human=%s\n'     "$(human_size "$_size")"
    printf 'removable=%s\n'      "$([ "$_rm" = 1 ] && echo Removable || echo Fixed)"
    printf 'ejectable=%s\n'      "$([ "$_hot" = 1 ] && echo Yes || echo No)"
    printf 'internal=%s\n'       "$([ "$_hot" = 1 ] && echo External || echo Internal)"
    printf 'virtual=%s\n'        "$([ "$_type" = loop ] && echo Yes || echo No)"
    printf 'whole=%s\n'          "$(case "$_type" in disk|loop) echo Yes ;; *) echo No ;; esac)"
    printf 'protocol=%s\n'       "${_proto:-unknown}"
    # NO LINUX EQUIVALENT, AND NOT GUESSED. Mapping this to "No" would retire
    # one of the four soft signals without saying so; "unknown" is read as no
    # signal at all, and the caller counts how many each platform supplies.
    printf 'os_installable=%s\n' 'unknown'
    printf 'uuid=%s\n'           "${_ptuuid:-unknown}"
}

linux_probe() {
    [ -b "/dev/$1" ] || die "no such disk: /dev/$1"
    lsblk -b -d -P -o NAME,SIZE,MODEL,RM,TYPE,TRAN,HOTPLUG,PTUUID "/dev/$1" \
        2>/dev/null | linux_probe_map
}

linux_partition() {
    # The same MBR layout diskutil is asked for, written as an sfdisk script.
    # Types are the FAT32 default on both partitions here; `type` changes p2 to
    # 0x83 afterwards exactly as it does on macOS, so the sequence the card
    # goes through is the same sequence on both hosts.
    linux_unmount_all "$1"
    if [ "$5" = R ]; then
        _script="label: dos
,$3,c
,,c
"
    else
        _script="label: dos
,$3,c
,$5,c
"
    fi
    printf '%s' "$_script" | priv sfdisk --quiet --wipe always "/dev/$1" \
        || die "sfdisk could not partition /dev/$1"
    priv partprobe "/dev/$1" >/dev/null 2>&1 || true
    # Settle: the partition nodes are created by udev, not by sfdisk, and
    # mkfs on a node that does not exist yet is the classic flake here.
    _n=0
    while [ ! -b "/dev/$(linux_part "$1" 2)" ] && [ "$_n" -lt 50 ]; do
        _n=$((_n+1)); sleep 0.1
    done
    priv mkfs.vfat -F 32 -n "$2" "/dev/$(linux_part "$1" 1)" >/dev/null \
        || die "could not make the FAT filesystem on partition 1"
    priv mkfs.vfat -F 32 -n "$4" "/dev/$(linux_part "$1" 2)" >/dev/null \
        || die "could not make the FAT filesystem on partition 2"
}

linux_type()     { priv sfdisk --quiet --part-type "/dev/$1" "$2" "$3" >/dev/null 2>&1; }
linux_bootflag() { priv sfdisk --quiet --activate "/dev/$1" "$2" >/dev/null 2>&1; }

linux_eject() {
    sync 2>/dev/null || true
    linux_unmount_all "$1"
    case "$1" in
        loop*) priv losetup -d "/dev/$1" >/dev/null 2>&1 || true; return 0 ;;
    esac
    if command -v udisksctl >/dev/null 2>&1; then
        udisksctl power-off -b "/dev/$1" >/dev/null 2>&1 || true
    fi
    printf 'It is safe to remove /dev/%s\n' "$1"
}

# --partscan, or the partitions this build is about to create never appear as
# nodes and every mkfs after it writes to a device that does not exist.
linux_image_attach() {
    _d=$(priv losetup --partscan --find --show "$1") || die "losetup could not attach $1"
    [ -n "$_d" ] || die "losetup attached $1 but reported no device"
    printf '%s\n' "$_d"
}
linux_image_detach()   { priv losetup -d "$1" >/dev/null 2>&1 || true; }
linux_image_attached() { losetup -j "$1" 2>/dev/null | head -n1 | cut -d: -f1; }
linux_sha256_check()   { sha256sum -c "$1"; }

# -------------------------------------------------------------- self-test ---
# What can be proved with no card in a slot and no root: that both backends
# answer every verb, that the Linux parsing is right against RECORDED output,
# and that partition naming is right for the four kinds of device name there
# are. A recording and an expected answer -- not a second implementation.

FIX_CARD='NAME="sda" SIZE="15931539456" MODEL="SD Card Reader" RM="1" TYPE="disk" TRAN="usb" HOTPLUG="1" PTUUID="6f20736b"'
FIX_INTERNAL='NAME="nvme0n1" SIZE="1024209543168" MODEL="Samsung SSD 990" RM="0" TYPE="disk" TRAN="nvme" HOTPLUG="0" PTUUID="a1b2c3d4"'
FIX_BIGDRIVE='NAME="sdb" SIZE="2000398934016" MODEL="Expansion Desk" RM="0" TYPE="disk" TRAN="usb" HOTPLUG="1" PTUUID="deadbeef"'
FIX_LOOP='NAME="loop0" SIZE="17179869184" MODEL="" RM="0" TYPE="loop" TRAN="" HOTPLUG="0" PTUUID=""'
FIX_PART='NAME="sda1" SIZE="4294967296" MODEL="" RM="1" TYPE="part" TRAN="usb" HOTPLUG="1" PTUUID="6f20736b"'

TESTS=0
fail() { printf 'copal-disk: SELF-TEST FAILED: %s\n' "$*" >&2; exit 1; }
want() { # <got> <wanted> <what>
    TESTS=$((TESTS+1))
    [ "$1" = "$2" ] || fail "$3: got '$1', wanted '$2'"
}
probe_key() { printf '%s' "$1" | linux_probe_map | sed -n "s/^$2=//p"; }

self_test() {
    # 1. Totality. THE WHOLE REASON THIS FILE IS A TABLE. Both backends are
    #    defined on every host, so this proves the pair on either one.
    for _v in $VERBS; do
        _fn=$(printf '%s' "$_v" | tr '-' '_')
        for _b in macos linux; do
            TESTS=$((TESTS+1))
            command -v "${_b}_${_fn}" >/dev/null 2>&1 \
                || fail "verb '$_v' has no ${_b} implementation"
        done
    done

    # 2. Partition naming, per kind of device name.
    want "$(linux_part sda 1)"      sda1       'sda partition 1'
    want "$(linux_part sda 2)"      sda2       'sda partition 2'
    want "$(linux_part mmcblk0 1)"  mmcblk0p1  'mmcblk0 takes a p'
    want "$(linux_part nvme0n1 2)"  nvme0n1p2  'nvme0n1 takes a p'
    want "$(linux_part loop0 1)"    loop0p1    'loop0 takes a p'
    want "$(macos_part disk4 1)"    disk4s1    'macOS partition 1'
    want "$(macos_part disk4 2)"    disk4s2    'macOS partition 2'

    # 3. The card: every fact the safety checks read.
    want "$(probe_key "$FIX_CARD" media_name)" 'SD Card Reader' 'card media name'
    want "$(probe_key "$FIX_CARD" size_bytes)" 15931539456      'card size'
    want "$(probe_key "$FIX_CARD" removable)"  Removable        'card removable'
    want "$(probe_key "$FIX_CARD" ejectable)"  Yes              'card ejectable'
    want "$(probe_key "$FIX_CARD" internal)"   External         'card location'
    want "$(probe_key "$FIX_CARD" virtual)"    No               'card not virtual'
    want "$(probe_key "$FIX_CARD" whole)"      Yes              'card is whole'
    want "$(probe_key "$FIX_CARD" protocol)"   USB              'card protocol'
    want "$(probe_key "$FIX_CARD" uuid)"       6f20736b         'card uuid'

    # 4. The refusals. Each of these is a device the build must not write to,
    #    and the key the refusal reads.
    want "$(probe_key "$FIX_INTERNAL" internal)"  Internal 'an internal disk says so'
    want "$(probe_key "$FIX_INTERNAL" ejectable)" No       'an internal disk is not ejectable'
    want "$(probe_key "$FIX_PART" whole)"         No       'a partition is not a whole disk'
    want "$(probe_key "$FIX_LOOP" virtual)"       Yes      'a loop device is virtual'
    want "$(probe_key "$FIX_LOOP" whole)"         Yes      'a loop device is still whole'
    want "$(probe_key "$FIX_LOOP" protocol)"      'Disk Image' 'a loop device names itself'

    # 5. The soft signals, including the one Linux cannot answer.
    want "$(probe_key "$FIX_BIGDRIVE" size_bytes)" 2000398934016 'a 2 TB drive'
    want "$(probe_key "$FIX_BIGDRIVE" removable)"  Fixed         'an external SSD says Fixed'
    want "$(probe_key "$FIX_CARD" os_installable)" unknown       'Linux does not guess this'

    # 6. A model with spaces survives the parse, and an empty one becomes a
    #    word rather than an empty field the caller would print as a gap.
    want "$(probe_key "$FIX_LOOP" media_name)" unknown 'no model reads as unknown'

    # 7. Sizes, the same arithmetic on both hosts.
    want "$(human_size 15931539456)"  '14.8 GB' '16 GB card'
    want "$(human_size 2000398934016)" '1.8 TB' '2 TB drive'
    want "$(human_size 4194304)"       '4.0 MB' 'four megabytes'

    printf 'copal-disk: %s checks passed (%s backend, %s verbs)\n' \
        "$TESTS" "${BACKEND:-none}" "$(printf '%s\n' $VERBS | wc -l | xargs)"
}

# ------------------------------------------------------------------ verbs ---

_verb=${1:-}
[ $# -gt 0 ] && shift || true
case "$_verb" in
    verbs)     printf '%s\n' $VERBS; exit 0 ;;
    backend)   printf '%s\n' "${BACKEND:-none}"; exit 0 ;;
    self-test) self_test; exit 0 ;;
    '')        die "which verb? try: copal-disk.sh verbs" ;;
esac

printf '%s\n' $VERBS | grep -qx -- "$_verb" || die "no such verb: $_verb"
[ -n "$BACKEND" ] || die "$(uname -s) is not a host copal can build from (macOS or Linux)"

_impl="${BACKEND}_$(printf '%s' "$_verb" | tr '-' '_')"
command -v "$_impl" >/dev/null 2>&1 \
    || die "verb '$_verb' is not implemented on $BACKEND -- this is a bug in copal-disk.sh, not a missing tool"
"$_impl" "$@"
