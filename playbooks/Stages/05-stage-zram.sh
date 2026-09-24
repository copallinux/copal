# playbook: stage-zram
# source:   copal
# origin:   stage
# stage:    5
# category: Memory
# step:     Compressed swap in RAM (zram)
# weight:   4
# levels:   server medium full
# summary:  Sets up compressed swap in RAM. On a 512 MB board it is the single largest win, and it
#           spares the card from wear.

# ------------------------------------------------------- stage 5: zram -----
stage_zram() {
    say "Stage 5: compressed swap in RAM (zram)"
    cat <<'MSG'
    A block device that compresses whatever is written to it and keeps it in
    RAM. Used as swap it buys back roughly its own size again in usable
    memory, at the cost of CPU to compress -- and unlike swapping to the SD
    card, it costs no writes to flash and no seek latency.

    On 512 MB this is the single biggest win available.
MSG

    if ! modprobe zram 2>/dev/null; then
        warn "the zram module is not available in this kernel."
        note "Nothing was changed."
        return 0
    fi
    note "zram module loaded"
    add_optional util-linux   # zramctl, for inspecting it later

    # Half of RAM as the uncompressed size. Real occupancy is lower -- text
    # and heap typically compress 2-3x -- and pages only occupy RAM once
    # written, so this is a ceiling and not a reservation.
    ZRAM_KB=$(awk '/MemTotal/ {printf "%d", $2 / 2}' /proc/meminfo)
    note "sizing zram0 at ${ZRAM_KB} kB (half of RAM)"

    # /etc/local.d/*.start is run at boot by the 'local' service. Doing it
    # this way avoids depending on a packaged init script whose conf format
    # differs between releases.
    say "Installing /etc/local.d/zram.start"
    mkdir -p /etc/local.d
    cat > /etc/local.d/zram.start <<ZRAM
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# Compressed swap in RAM. Written by copal-init.sh.
modprobe zram || exit 0
[ -e /dev/zram0 ] || exit 0
# Already set up (re-run of local.d)? Leave it alone.
grep -q '^/dev/zram0' /proc/swaps && exit 0
# lz4 is much cheaper than zstd on an ARMv6 core; fall back to the default.
echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo $((ZRAM_KB * 1024)) > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null
# Higher priority than any disk swap, so this fills first.
swapon -p 100 /dev/zram0
ZRAM
    chmod +x /etc/local.d/zram.start

    # Swapping to RAM is cheap, so lean on it rather than reclaiming caches.
    say "Setting vm.swappiness=100"
    mkdir -p /etc/sysctl.d
    printf '# zram swap is cheap; prefer it over dropping page cache.\nvm.swappiness=100\n' \
        > /etc/sysctl.d/60-zram.conf
    sysctl -w vm.swappiness=100 >/dev/null 2>&1 || true

    rc-update add local default >/dev/null 2>&1 || true

    say "Enabling it now"
    if /etc/local.d/zram.start; then
        note "$(free -m | awk '/Swap:/ {print "swap: " $2 " MB total"}')"
        grep '^/dev/zram0' /proc/swaps | sed 's/^/    /' || warn "zram0 is not in /proc/swaps"
    else
        warn "could not enable zram now; it will be retried at boot"
    fi

    say "Stage 5 complete."
    note "Check later with: zramctl   and   free -m"
}
