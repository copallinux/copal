# playbook: stage-sdcard
# source:   copal
# origin:   stage
# stage:    15
# category: Care
# step:     What wears a card, logs, a read-only root
# weight:   0
# summary:  Explains what wears out an SD card, and offers a gentler log policy and a read-only
#           root. It changes nothing unless you choose something.

stage_sdcard() {
    say "Stage 15: SD card care -- writes, logs, and the read-only option"

    _rofs=$(awk '$2 == "/" {print $4}' /proc/mounts | head -n1)
    cat <<MSG

    CURRENT STATE

      root filesystem : $(root_fstype)
      root mounted    : ${_rofs:-unknown}
      /tmp            : $(is_mounted /tmp && awk '$2=="/tmp"{print $3}' /proc/mounts || echo 'on the root filesystem')
      /var/log        : $(is_mounted /var/log && awk '$2=="/var/log"{print $3}' /proc/mounts || echo 'on the root filesystem')
      swap            : $(zram_active && echo 'zram (RAM, no card writes)' || grep -q '^/dev/mmc' /proc/swaps 2>/dev/null && echo 'ON THE CARD -- run stage 5' || echo 'none')
      read-only root  : $(readonly_root_on && echo 'YES (overlaytmpfs)' || echo 'no -- the card is written normally')

    Most of the work is already done. Stage 3 puts /tmp and /var/log on
    tmpfs, mounts the root noatime with commit=600 so journal flushes are
    batched, and stage 5's zram means swap never reaches the card.

    That has a consequence worth knowing: /var/log is RAM, so your logs are
    gone at every reboot. It also means a runaway process writing a log
    cannot fill the card -- it fills a 32 MB tmpfs, hits ENOSPC, and stops.
    The card is not involved.

MSG
    _c=$(printf '')
    ask "Choose [r=read-only root / l=log policy / s=syslog size / w=what should I worry about / q=back]:"
    case "$REPLY" in
        r|R) sdcard_readonly ;;
        l|L) sdcard_logs ;;
        s|S) sdcard_syslog ;;
        w|W) sdcard_advice ;;
        *)   note "Nothing changed."; return 0 ;;
    esac
    say "Stage 15 complete."
}
