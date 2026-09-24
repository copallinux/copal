# playbook: stage-grow
# source:   copal
# origin:   stage
# stage:    8
# category: System
# step:     Grow p2 into the free space
# weight:   4
# levels:   server medium full
# summary:  Grows the root partition into the rest of the disk while it is mounted. On a virtual
#           machine whose disk was made bigger, this is what claims the new space.

stage_grow() {
    say "Stage 8: grow $P2 into the free space after it"
    # Room of a different kind, and on every machine: a /tmp still capped at
    # the 64 MB that older installs were given.
    retune_tmp
    _free=$(p2_free_sectors)
    if [ "$_free" -le 131072 ]; then
        note "Nothing to do -- $P2 already reaches the end of the card."
        return 0
    fi
    note "unallocated after p2: $(( _free / 2048 )) MB"
    note "p2 now              : $(df -h "$P2" 2>/dev/null | awk 'NR==2{print $2}' || echo unknown)"
    cat <<'MSG'

    The free space is physically after p2, so p2's end can simply be moved
    outward and the filesystem grown into it. Nothing is copied and nothing is
    reformatted -- the data already on p2 stays exactly where it is.

    ext4 grows online, so this works even while p2 is mounted as /.

    The partition table is still rewritten, which is the one genuinely risky
    moment. If power is lost between rewriting the table and the filesystem
    resize, p2 may need an e2fsck before it mounts again.
MSG
    require_network || return 1
    add_optional sfdisk e2fsprogs-extra

    command -v sfdisk >/dev/null 2>&1 || { warn "sfdisk is unavailable -- cannot resize"; return 1; }
    command -v resize2fs >/dev/null 2>&1 || { warn "resize2fs is unavailable -- cannot resize"; return 1; }

    [ "$(fstype_of "$P2")" = ext4 ] || { warn "$P2 is not ext4 -- refusing to touch it"; return 1; }

    warn "about to rewrite the partition table of /dev/$DISKDEV."
    ask "Type yes to proceed:"
    [ "$REPLY" = "yes" ] || { note "Aborted; nothing was changed."; return 0; }

    say "Backing up the partition table"
    # Enough to put things back by hand if the resize goes wrong.
    dd if="/dev/$DISKDEV" of="$BOOT/mbr-backup.bin" bs=512 count=1 2>/dev/null \
        && note "first sector saved to $BOOT/mbr-backup.bin"

    say "Moving the end of partition 2 to the end of the card"
    # sfdisk, not parted: p2 is mounted as / whenever this runs, and parted -s
    # meets its own "partition is being used, are you sure?" with a silent no
    # -- which no reboot changes, since / is always in use. ', +' keeps p2's
    # start and takes every sector after it; --no-reread skips the in-use
    # check, which is the kernel's refusal to re-read the whole table, not a
    # danger to the data.
    if ! printf ', +\n' | sfdisk --quiet --no-reread -N 2 "/dev/$DISKDEV"; then
        warn "sfdisk could not rewrite the table."
        note "Nothing was changed. The first sector is saved in $BOOT/mbr-backup.bin."
        return 1
    fi

    # The kernel will not re-read the table of a disk it is running from, so
    # nudge it into picking up just the new partition size.
    partx -u "/dev/$DISKDEV" 2>/dev/null || partprobe "/dev/$DISKDEV" 2>/dev/null || true

    say "Growing the filesystem"
    if resize2fs "$P2"; then
        note "done"
    else
        warn "resize2fs did not complete."
        note "The partition is larger but the filesystem is not yet. This is"
        note "safe -- no data was lost. Reboot and run stage 8 again; the"
        note "kernel will have the new size by then."
        return 1
    fi

    say "Stage 8 complete."
    note "p2 now: $(df -h "$P2" 2>/dev/null | awk 'NR==2{print $2 " (" $5 " used)"}')"
    df -h / | sed 's/^/    /'
}
