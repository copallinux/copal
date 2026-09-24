# playbook: stage-snapshots
# source:   copal
# origin:   stage
# stage:    11
# category: Snapshots
# step:     rsync snapshots on a third partition
# weight:   0
# summary:  Takes rsync snapshots onto a third partition, so a bad change can be rolled back. It
#           repartitions the disk, so it is asked for and never run unattended.

stage_snapshots() {
    say "Stage 11: snapshots"
    require_disk_root "This stage" || return 0

    cat <<'MSG'
    Three things worth knowing before choosing how to do this.

    ZFS is not an option. Timeshift does not support it at all, and ZFS wants
    far more RAM than this board has -- its ARC alone would exceed 512 MB.

    BTRFS is the filesystem Timeshift snapshots natively, but only in the
    Ubuntu-style layout: / on btrfs with @ and @home subvolumes. Your root is
    ext4, made by setup-disk, so using that mode means rebuilding the root
    filesystem from scratch -- redoing stage 3 and everything after it.

    RSYNC mode works on ext4 exactly as it is. Snapshots are hardlinked
    copies, so unchanged files cost nothing beyond a directory entry. This is
    the mode that fits what you already have, and it is what this stage sets
    up.

    A snapshot on the same partition protects against mistakes, not against
    the card failing. A separate partition is better; a different device is
    better still.
MSG

    # --- the partition ----------------------------------------------------
    say "Snapshot partition"
    _free=$(p2_free_sectors)
    if [ -b "$P3" ]; then
        note "$P3 already exists ($(fstype_of "$P3" || echo unformatted))"
    elif [ "$_free" -gt 2097152 ]; then
        note "$(( _free / 2048 )) MB unallocated after p2 -- enough for p3"
        if confirm "Create $P3 there?"; then
            add_optional parted e2fsprogs-extra
            parted -s "/dev/$DISKDEV" mkpart primary ext4 "$(( $(cat "$SYSP2/start") + $(cat "$SYSP2/size") ))s" 100%
            partx -a "/dev/$DISKDEV" 2>/dev/null || partprobe "/dev/$DISKDEV" 2>/dev/null || true
            [ -b "$P3" ] && mkfs.ext4 -F -L SNAPSHOTS "$P3" && note "created and formatted $P3"
        fi
    else
        warn "p2 fills the card -- there is no room for a third partition."
        cat <<'SHRINK'
    Making room means shrinking p2, and ext4 CANNOT be shrunk while it is
    mounted -- which it is, as /. Doing it needs the root filesystem offline,
    which on this machine means booting the diskless system that is still
    sitting on p1:

      1. Put the card in another machine and edit cmdline.txt: remove the
         'root=UUID=... rootfstype=ext4' part, keeping the rest. Save the
         original as cmdline.txt.sys first.
      2. Boot. You are back on the RAM-resident system, p2 unmounted.
      3. Run this stage again. With p2 not mounted it will offer to shrink
         it and create p3.
      4. Restore cmdline.txt from cmdline.txt.sys and reboot.

    Whether that is worth it is a fair question: snapshots on p3 of the same
    card still die with the card. An external USB disk, or rsync to another
    machine over the network, protects against more.
SHRINK
        if ! grep -q ' / ' /proc/mounts || ! mount | grep -q "^$P2 on / "; then
            :
        fi
        # Only offer the shrink when p2 really is not the running root.
        if ! awk -v d="$P2" '$1 == d && $2 == "/" {found=1} END {exit !found}' /proc/mounts; then
            say "p2 is not mounted as / -- the shrink can be done now"
            _p2mb=$(( $(cat "$SYSP2/size") / 2048 ))
            _halfmb=$(( _p2mb / 2 ))
            note "p2 is ${_p2mb} MB; splitting in half gives ${_halfmb} MB each"
            if confirm "Shrink p2 to ${_halfmb} MB and create p3 with the rest?"; then
                add_optional parted e2fsprogs-extra
                warn "this rewrites the partition table and resizes a filesystem."
                ask "Type yes to proceed:"
                if [ "$REPLY" = yes ]; then
                    umount "$P2" 2>/dev/null || true
                    e2fsck -f -y "$P2" || { warn "e2fsck failed -- stopping"; return 1; }
                    resize2fs "$P2" "${_halfmb}M" || { warn "resize2fs failed -- stopping"; return 1; }
                    parted -s "/dev/$DISKDEV" resizepart 2 "$(( _halfmb + 1 ))MiB"
                    parted -s "/dev/$DISKDEV" mkpart primary ext4 "$(( _halfmb + 2 ))MiB" 100%
                    partx -u "/dev/$DISKDEV" 2>/dev/null || partprobe "/dev/$DISKDEV" 2>/dev/null || true
                    mkfs.ext4 -F -L SNAPSHOTS "$P3" && note "created $P3"
                fi
            fi
        fi
    fi

    # --- mount it ----------------------------------------------------------
    if [ -b "$P3" ]; then
        mkdir -p "$P3MNT"
        if ! is_mounted "$P3MNT"; then
            _u=$(uuid_of "$P3")
            sed -i "\|[[:space:]]$P3MNT[[:space:]]|d" /etc/fstab
            printf 'UUID=%s\t%s\text4\tdefaults,noatime\t0 2\n' "$_u" "$P3MNT" >> /etc/fstab
            mount "$P3MNT" && note "mounted $P3 at $P3MNT"
        fi
    fi

    # --- timeshift ---------------------------------------------------------
    say "Timeshift"
    if apk info -e timeshift >/dev/null 2>&1; then
        note "already installed"
    else
        cat <<'MSG'
    Timeshift is packaged for armhf, but only in edge/testing -- it is not in
    the v3.24 stable branch this system runs. Installing it means pulling one
    package from edge into a stable system, which can drag in newer libraries
    than the rest of the system expects.

    Pinning the repository to that single install limits the blast radius,
    but it is still mixing branches, and it can break unrelated things later.
MSG
        if confirm "Install timeshift from edge/testing anyway?"; then
            apk add --no-cache \
                --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing \
                timeshift \
              || warn "timeshift install failed -- the rsync fallback below still works"
        else
            note "Skipping Timeshift itself."
        fi
    fi

    # --- rsync snapshots, with or without timeshift ------------------------
    # Works regardless of whether timeshift installed, and is the thing that
    # actually makes snapshots on ext4. Hardlinks mean an unchanged file costs
    # a directory entry rather than a copy.
    say "Installing /usr/local/bin/snapshot"
    add_optional rsync
    cat > /usr/local/bin/snapshot <<'SNAP'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# snapshot -- hardlinked full-system snapshots, in retention tiers.
#
#   snapshot take TIER        make one (tier is any name: daily, monthly, ...)
#   snapshot prune TIER N     keep the newest N in that tier
#   snapshot list             show every tier with sizes
#   snapshot diff TIER NAME   what has changed since that snapshot
#   snapshot restore TIER NAME  print the command to restore (does not run it)
#
# Every snapshot is a complete tree: the whole system including user files,
# not an incremental that needs its predecessors to be readable. Unchanged
# files are hardlinked to the most recent previous snapshot, so only what
# actually changed costs space. Deleting any snapshot is always safe -- the
# others keep their own links to the data.
set -eu

DEST="${SNAPSHOT_DIR:-/media/snapshots}"
[ -d "$DEST" ] || { echo "snapshot: no $DEST -- is the snapshot partition mounted?" >&2; exit 1; }

# What NOT to copy. /proc, /sys, /dev and /run are kernel interfaces, not
# files. /media and /mnt matter most: without excluding them a snapshot would
# recurse into the snapshot directory itself. /boot IS included -- a restore
# without the kernel, cmdline.txt and config.txt is not a restore.
EXCL="--exclude=/proc/* --exclude=/sys/* --exclude=/dev/* --exclude=/run/*
      --exclude=/tmp/* --exclude=/var/tmp/* --exclude=/var/log/*
      --exclude=/media/* --exclude=/mnt/* --exclude=/var/cache/apk/*
      --exclude=/lost+found --exclude=/swapfile"

# -A (ACLs) and -X (xattrs) are not in every rsync build, and passing an
# unsupported flag makes it exit with a usage message rather than degrade.
# Ask this rsync what it has instead of assuming.
RSOPTS="-aH --numeric-ids"
rsync --help 2>&1 | grep -q -- '--acls'   && RSOPTS="$RSOPTS -A"
rsync --help 2>&1 | grep -q -- '--xattrs' && RSOPTS="$RSOPTS -X"

newest_anywhere() {
    # Link against the most recent snapshot in ANY tier, not just this one --
    # a monthly taken the day after a daily should cost almost nothing.
    find "$DEST" -mindepth 2 -maxdepth 2 -type d -name '2*' 2>/dev/null | sort | tail -1
}

case "${1:-}" in
take)
    TIER="${2:-manual}"
    NAME="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$DEST/$TIER"
    LAST="$(newest_anywhere)"
    echo "snapshot: / -> $DEST/$TIER/$NAME"
    [ -n "$LAST" ] && echo "snapshot: hardlinking unchanged files against $LAST"
    # Written to .part first and renamed on success, so an interrupted run
    # (power loss, full disk) never leaves a partial tree that later looks
    # like a good snapshot.
    rm -rf "$DEST/$TIER/$NAME.part"
    # shellcheck disable=SC2086
    if rsync $RSOPTS --delete $EXCL \
             ${LAST:+--link-dest="$LAST"} / "$DEST/$TIER/$NAME.part/"; then
        mv "$DEST/$TIER/$NAME.part" "$DEST/$TIER/$NAME"
        echo "snapshot: done, $(du -sh "$DEST/$TIER/$NAME" | cut -f1) of new data"
    else
        rc=$?
        rm -rf "$DEST/$TIER/$NAME.part"
        echo "snapshot: FAILED (rsync exit $rc); nothing kept" >&2
        exit $rc
    fi
    ;;
prune)
    TIER="${2:-}"; N="${3:-7}"
    [ -n "$TIER" ] || { echo "usage: snapshot prune TIER N" >&2; exit 1; }
    [ -d "$DEST/$TIER" ] || exit 0
    # Names sort chronologically, so "all but the last N" is a plain tail.
    # 'head -n -N' is a GNU extension; busybox head rejects it outright.
    # Count first, then drop the oldest (total - N).
    TOTAL=$(ls -1d "$DEST/$TIER"/2* 2>/dev/null | wc -l | tr -d ' ')
    [ "$TOTAL" -gt "$N" ] || { echo "snapshot: $TOTAL in $TIER, keeping $N -- nothing to prune"; exit 0; }
    ls -1d "$DEST/$TIER"/2* 2>/dev/null | sort | head -n "$((TOTAL - N))" | while read -r s; do
        echo "snapshot: removing $s"
        rm -rf "$s"
    done
    ;;
list)
    for t in "$DEST"/*/; do
        [ -d "$t" ] || continue
        echo "== $(basename "$t")  ($(ls -1d "$t"2* 2>/dev/null | wc -l) snapshots)"
        du -sh "$t"2* 2>/dev/null | sed 's/^/   /' || true
    done
    echo
    echo "total on $DEST: $(du -sh "$DEST" 2>/dev/null | cut -f1)"
    df -h "$DEST" | tail -1
    ;;
diff)
    [ -n "${3:-}" ] || { echo "usage: snapshot diff TIER NAME" >&2; exit 1; }
    # shellcheck disable=SC2086
    rsync $RSOPTS -n --delete --itemize-changes $EXCL / "$DEST/$2/$3/" | head -200
    ;;
restore)
    [ -n "${3:-}" ] || { echo "usage: snapshot restore TIER NAME" >&2; exit 1; }
    SRC="$DEST/$2/$3"
    [ -d "$SRC" ] || { echo "no such snapshot: $SRC" >&2; exit 1; }
    cat <<RESTORE
Restoring over a running system is not something to do casually, so this
prints the command rather than running it.

To restore individual files, just copy them out:
    cp -a $SRC/home/user/somefile /home/user/

To restore everything, boot the diskless system on p1 first (remove root=
from cmdline.txt), mount p2, then:

    rsync -aHAX --delete --numeric-ids \\
        --exclude=/proc/* --exclude=/sys/* --exclude=/dev/* --exclude=/run/* \\
        $SRC/ /mnt/

Doing that against a mounted, running root will replace libraries underneath
processes that are using them.
RESTORE
    ;;
*) sed -n '2,${/^#/!q; /^# SPDX/d; /^# Copyright/d; p;}' "$0"; exit 1 ;;
esac
SNAP
    chmod 0755 /usr/local/bin/snapshot

    # --- scheduling --------------------------------------------------------
    # Alpine's busybox crond runs /etc/periodic/{daily,monthly} from the stock
    # root crontab, so dropping scripts there needs no crontab editing.
    say "Scheduling: 7 daily, 24 monthly"
    add_optional busybox-openrc

    cat > /etc/periodic/daily/snapshot-daily <<'CRON'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# Daily full-system snapshot, keeping the last 7. Run by crond at 02:00 from
# the stock Alpine root crontab (run-parts /etc/periodic/daily).
[ -d /media/snapshots ] || exit 0   # partition not mounted; nothing to do
/usr/local/bin/snapshot take daily && /usr/local/bin/snapshot prune daily 7
CRON

    cat > /etc/periodic/monthly/snapshot-monthly <<'CRON'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# Monthly full-system snapshot, keeping the last 24 -- two years of history.
# Run by crond at 05:00 on the 1st (run-parts /etc/periodic/monthly).
[ -d /media/snapshots ] || exit 0
/usr/local/bin/snapshot take monthly && /usr/local/bin/snapshot prune monthly 24
CRON

    chmod 0755 /etc/periodic/daily/snapshot-daily /etc/periodic/monthly/snapshot-monthly
    mkdir -p "$P3MNT/daily" "$P3MNT/monthly" 2>/dev/null || true

    rc-update add crond default >/dev/null 2>&1 || true
    rc-service crond start >/dev/null 2>&1 || rc-service crond restart >/dev/null 2>&1 || true
    if rc-service crond status >/dev/null 2>&1; then
        note "crond is running"
    else
        warn "crond is not running -- snapshots will not happen on their own"
        note "start it with: rc-service crond start"
    fi
    note "daily   02:00, keeping 7"
    note "monthly 05:00 on the 1st, keeping 24"
    note "stock Alpine crontab: $(grep -c periodic /etc/crontabs/root 2>/dev/null || echo 0) periodic entries found"

    say "Stage 11 complete."
    cat <<'MSG'
    snapshot take daily        make one now, rather than waiting for cron
    snapshot list              every tier, with sizes and free space
    snapshot diff daily NAME   what has changed since that snapshot
    snapshot restore ...       prints how to restore; does not do it

    The first snapshot copies everything and will take a while on this card.
    Every one after that hardlinks whatever has not changed, so it is fast and
    costs only the difference. Each snapshot is still a complete tree -- you
    can delete any of them without harming the others.
MSG
    if [ -b "$P3" ]; then
        note "snapshots live on $P3, separate from the root filesystem"
    else
        warn "no $P3 -- snapshots are going onto the SAME partition as /."
        warn "That protects against mistakes, but not against the card failing."
    fi
    warn "This is one SD card. For real safety, copy snapshots off it:"
    note "  rsync -aHAX /media/snapshots/ user@othermachine:/backup/$(hostname)/"
}
