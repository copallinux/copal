# playbook: stage-ext4-cache
# source:   copal
# origin:   stage
# stage:    2
# category: System
# step:     Format p2 and move the apk cache
# weight:   6
# levels:   server medium full
# summary:  Formats the card's second partition as ext4 and moves the package cache onto it.
#           Packages downloaded now survive the reboot that is coming.

# ------------------------------------------- stage 2: ext4 p2 + apk cache ---
stage_ext4_cache() {
    say "Stage 2: ext4 on $P2, and the apk cache on it"
    cat <<'MSG'
    Packages installed with `apk add` live in the tmpfs root and vanish on
    reboot. The apk cache fixes that: with a cache on real storage, everything
    in the saved package list is reinstalled from the card at boot, offline.

    The cache needs a real filesystem -- it cannot go on the FAT boot
    partition. So this formats p2 as ext4 and points the cache there. p2 is
    also what stage 3 later installs a full root filesystem onto, so this is
    worth doing either way.
MSG
    [ -b "$P2" ] || die "$P2 not found -- was this card partitioned by copal-prep.sh?"

    if [ "$(fstype_of "$P2")" = ext4 ]; then
        warn "$P2 is already ext4."
        confirm "Reformat it (erases anything on it)?" || {
            note "Keeping the existing filesystem."
            _skip_mkfs=1
        }
    fi

    if [ "${_skip_mkfs:-0}" != 1 ]; then
        require_network || return 1
        apk add e2fsprogs
        warn "about to ERASE $P2. The boot partition p1 is not touched."
        ask "Type yes to proceed:"
        [ "$REPLY" = "yes" ] || { note "Aborted; nothing was erased."; return 0; }
        mkfs.ext4 -F -L COPALROOT "$P2"
    fi
    unset _skip_mkfs

    say "Adding $P2MNT to /etc/fstab"
    # setup-apkcache resolves the cache directory to a mount point and then
    # runs `mount <mountpoint>` -- which only works when fstab already has the
    # entry. Adding it first is what makes setup-apkcache succeed.
    mkdir -p "$P2MNT"
    UUID=$(uuid_of "$P2")
    [ -n "$UUID" ] || die "could not read the UUID of $P2"
    sed -i "\|[[:space:]]$P2MNT[[:space:]]|d" /etc/fstab
    printf 'UUID=%s\t%s\text4\tdefaults,noatime\t0 2\n' "$UUID" "$P2MNT" >> /etc/fstab
    is_mounted "$P2MNT" || mount "$P2MNT"
    note "mounted: $(df -h "$P2MNT" | awk 'NR==2 {print $1, $2, "on", $6}')"

    say "Pointing the apk cache at $P2MNT/cache"
    setup-apkcache "$P2MNT/cache"
    note "cache -> $(readlink /etc/apk/cache)"

    say "Teaching lbu to recreate the mount point"
    # The root filesystem is a tmpfs rebuilt from the apkovl on every boot, so
    # the empty directory $P2MNT has to be inside the apkovl or `mount -a` at
    # boot has nowhere to mount p2. Include the directory, exclude its
    # contents -- the cache is already persistent on p2 itself, and putting it
    # in the apkovl would bloat it enormously.
    lbu include "$P2MNT"
    lbu exclude "$P2MNT/cache"

    say "Committing"
    lbu commit -d || die "lbu commit failed"

    # Prove the mount point really is in the overlay rather than assuming it.
    say "Verifying the overlay contains the mount point"
    if tar tzf "$BOOT"/*.apkovl.tar.gz 2>/dev/null | grep -q "media/$(basename "$P2")"; then
        note "ok -- $P2MNT is in the apkovl and will exist after a reboot"
    else
        warn "$P2MNT is NOT in the apkovl. p2 will not mount at boot, and the"
        warn "apk cache will be a dangling symlink. Check 'lbu status'."
    fi

    say "Stage 2 complete."
    note "Test it: apk add tmux && lbu commit -d && reboot"
    note "tmux should still be there afterwards, reinstalled from the cache."
}
