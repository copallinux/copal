# playbook: stage-sys-install
# source:   copal
# origin:   stage
# stage:    3
# category: System
# step:     Move the root filesystem onto the card
# weight:   8
# levels:   server medium full
# summary:  Moves the running system from RAM onto the disk, in Alpine's sys mode, and reboots into
#           it. The one stage that restarts the machine; the install carries on by itself
#           afterwards.

# ------------------------------------------- stage 3: move root onto ext4 ---
stage_sys_install() {
    say "Stage 3: move the root filesystem onto $P2"
    cat <<'MSG'
    Only worth doing if you want a desktop. The tmpfs root is about half of
    RAM (~200 MB here), which is too small to install X into -- `apk add`
    fails with ENOSPC while the card sits 99% empty. The limit is RAM, not
    storage.

    The cost: the system writes to the SD card in normal use from then on,
    and boot depends on the ext4 partition being healthy. The RAM-resident
    setup on p1 stays intact as a fallback.
MSG
    [ -b "$P2" ] || die "$P2 not found"
    [ "$(fstype_of "$P2")" = ext4 ] || die "$P2 is not ext4 yet -- run stage 2 first"
    apkovl_exists || die "no saved configuration -- run stage 1 first (setup-disk copies the running config into the new root, so it must exist)"

    if sys_installed; then
        warn "cmdline.txt already has a root= -- this looks done already."
        confirm "Redo it? (reformats $P2, erasing the apk cache on it)" || { note "Skipped."; return 0; }
    fi

    # setup-disk runs `apk add --root /mnt linux-KFLAV alpine-base ...`, so it
    # installs the kernel over the network. No network, no kernel, no boot.
    require_network || return 1

    if ! is_pi_boot; then
        # A PC kernel flavour: lts on hardware, virt in a VM. Both are correct
        # here, and neither is an "rpi" flavour, so the Pi check below would
        # warn about a perfectly good system.
        case "$KFLAV" in
            lts|virt) note "kernel flavor: $KFLAV (PC) -- setup-disk will install linux-$KFLAV" ;;
            *) warn "unexpected kernel flavor '$KFLAV' for a PC." ;;
        esac
    else
    case "$KFLAV" in
        rpi*) : ;;
        *) warn "kernel flavor looks like '$KFLAV', not an rpi flavor."
           warn "setup-disk would install linux-$KFLAV, which may not boot here."
           confirm "Continue anyway?" || return 0 ;;
    esac
    fi

    warn "about to ERASE $P2 and install a system onto it."
    ask "Type yes to proceed:"
    [ "$REPLY" = "yes" ] || { note "Aborted; nothing was erased."; return 0; }

    say "Backing up the boot partition's configuration"
    # setup_raspberrypi_bootloader does
    #     echo "root=... modules=..." > "$mnt"/boot/cmdline.txt
    # -- a truncating overwrite. p1 is about to be mounted at /mnt/boot, so
    # that is the real cmdline.txt. Back it up first; it is the way back.
    mount -o remount,rw "$BOOT"
    if is_pi_boot; then
        cp "$BOOT/cmdline.txt" "$BOOT/cmdline.txt.bak"
        cp "$BOOT/config.txt" "$BOOT/config.txt.bak"
        CMDLINE_BEFORE=$(cat "$BOOT/cmdline.txt")
    else
        # The PC equivalent, and the file this stage will rewrite. Backed up for
        # the same reason: it is the way back to a machine that still boots.
        BOOTCFG="$BOOT/boot/grub/grub.cfg"
        [ -f "$BOOTCFG" ] || die "no $BOOTCFG -- was this card written by copal-prep.sh for a PC?"
        cp "$BOOTCFG" "$BOOTCFG.bak"
        CMDLINE_BEFORE="(grub.cfg, $(grep -c menuentry "$BOOTCFG") entries)"
    fi

    is_mounted "$P2MNT" && umount "$P2MNT"
    mkfs.ext4 -F -L COPALROOT "$P2"

    say "Mounting the target: $P2 at /mnt, and p1 at /mnt/boot"
    mkdir -p /mnt
    mount "$P2" /mnt
    # The VideoCore firmware reads the kernel only from FAT, so setup-disk
    # refuses a non-vfat /boot on a Pi:
    #     supported_boot_fs() { ... if is_rpi; then supported=vfat; fi ... }
    # It works out what /boot *is* by looking for a mount at $mnt/boot and
    # falling back to the root device -- so without this mount the check sees
    # ext4 and aborts with "ext4 is not supported. Only supported are: vfat".
    #
    # p1 is already mounted at $BOOT. A second mount of the same device with
    # the same options shares one superblock, so the two views stay coherent.
    mkdir -p /mnt/boot
    mount "$P1" /mnt/boot

    say "Running setup-disk (this installs a kernel; it takes a while)"
    note "A 'WARNING: no kernel found' from mkinitfs here is expected and"
    note "harmless -- setup-disk installs the bootloader package on the"
    note "running diskless system, which has no kernel package of its own."
    if is_pi_boot; then
        setup-disk -k "$KFLAV" -m sys /mnt
    else
        # BOOTLOADER=none is setup-disk's own supported value for "install the
        # system, touch no bootloader". Without it setup-disk would run
        # grub-install, which writes to the MBR and to EFI NVRAM -- neither of
        # which is wanted here: this card already has a working GRUB on its ESP,
        # placed by copal-prep.sh, and the only thing that needs to change is the
        # text file it reads. Keeping setup-disk out of that is what makes this
        # stage reversible by restoring one file.
        BOOTLOADER=none setup-disk -k "$KFLAV" -m sys /mnt
    fi

    # setup-disk populated /mnt with `apk add --root /mnt`, so anything wrong
    # with the umask at that moment is now baked into the filesystem this
    # machine is about to boot from. Check it here, while /mnt is still
    # mounted and a wrong mode is one chmod away rather than a reinstall.
    fix_system_dir_modes /mnt
    ensure_user_home /mnt || true

    # ---- verify setup-disk actually did the job, rather than hoping --------
    say "Verifying the installed system"
    FAIL=0
    for f in /mnt/sbin/init /mnt/etc/fstab; do
        [ -e "$f" ] || { warn "missing $f"; FAIL=1; }
    done
    if [ -f "/mnt/boot/vmlinuz-$KFLAV" ]; then
        KPATH="vmlinuz-$KFLAV"; IPATH="initramfs-$KFLAV"
        note "ok -- kernel at $BOOT/$KPATH"
    elif [ -f "/mnt/boot/boot/vmlinuz-$KFLAV" ]; then
        KPATH="boot/vmlinuz-$KFLAV"; IPATH="boot/initramfs-$KFLAV"
        note "ok -- kernel at $BOOT/$KPATH"
    else
        warn "no vmlinuz-$KFLAV anywhere on the boot partition."
        warn "setup-disk could not install the kernel -- almost always network."
        FAIL=1
    fi
    ls -d /mnt/lib/modules/* >/dev/null 2>&1 || { warn "no /lib/modules in the new root"; FAIL=1; }

    if [ "$FAIL" = 1 ]; then
        say "Rolling back"
        if is_pi_boot; then
            cp "$BOOT/cmdline.txt.bak" "$BOOT/cmdline.txt"
            note "cmdline.txt restored; this Pi still boots the way it does now."
        else
            cp "$BOOTCFG.bak" "$BOOTCFG"
            note "grub.cfg restored; this machine still boots the way it does now."
        fi
        die "stage 3 did not complete. Transcript: $LOG"
    fi

    # ---- point the firmware at the newly installed kernel -----------------
    # Stock config.txt has 'kernel=boot/vmlinuz-rpi', which is where the
    # diskless payload keeps it. setup-disk installed the kernel into
    # /mnt/boot, which IS the root of p1 -- a different path. Left alone, the
    # firmware would boot the old diskless kernel and initramfs against the
    # new root=, which does not work. config.txt includes usercfg.txt last,
    # and later directives win, so correct it there.
    if is_pi_boot; then
        say "Pointing config.txt at the installed kernel (via usercfg.txt)"
        touch "$BOOT/usercfg.txt"
        sed -i '/^# >>> copal-init.sh/,/^# <<< copal-init.sh/d' "$BOOT/usercfg.txt"
        cat >> "$BOOT/usercfg.txt" <<EOF
# >>> copal-init.sh managed block >>>
# setup-disk installed the kernel at the root of the boot partition, not in
# boot/ where the diskless payload kept it. These override config.txt.
kernel=$KPATH
initramfs $IPATH
# <<< copal-init.sh managed block <<<
EOF
        note "kernel=$KPATH"
        note "initramfs $IPATH"
    else
        # THE PC EQUIVALENT. On a Pi, setup-disk's raspberrypi-bootloader backend
        # rewrites cmdline.txt with the new root= itself. With BOOTLOADER=none
        # nothing does, so this writes the boot configuration by hand -- which is
        # also why it is a whole file rather than a patch: there is exactly one
        # correct menu now (boot the installed system from p2) where before there
        # were three diskless ones.
        say "Rewriting grub.cfg for the installed system"
        # root= by UUID, not /dev/sda2: the same card in a different port, or with
        # another disk present, is a different device name and the machine would
        # not boot. The UUID travels with the filesystem.
        # Test the shape, not just emptiness: a UUID with a space in it becomes
        # a truncated root= and a second word grub reads as another parameter,
        # and the failure surfaces at boot rather than here.
        _uuid=$(uuid_of "$P2")
        case "$_uuid" in
            *[!0-9a-fA-F-]* | "") _uuid= ;;
        esac
        if [ -n "$_uuid" ]; then _root="UUID=$_uuid"; else
            warn "could not read a UUID for $P2 -- falling back to the device name"
            warn "which will break if the disk is ever enumerated differently."
            _root="$P2"
        fi
        # modules= must still carry what the initramfs needs to reach the root
        # filesystem: ext4 now, plus the same controller drivers as before.
        cat > "$BOOTCFG" <<EOF
# Rewritten by copal-init.sh stage 3. The previous version is grub.cfg.bak --
# restore it to go back to the diskless system, which still works: modloop and
# the .apkovl are untouched on this partition.
set timeout=5
set default=0

menuentry "Copal Linux" {
    linux /$KPATH root=$_root ro modules=ext4,sd-mod,usb-storage,ahci,nvme,mmc_block,sdhci,sdhci_pci rootfstype=ext4 console=tty0
    initrd /$IPATH
}

menuentry "Copal Linux (single user)" {
    linux /$KPATH root=$_root ro modules=ext4,sd-mod,usb-storage,ahci,nvme,mmc_block,sdhci,sdhci_pci rootfstype=ext4 console=tty0 single
    initrd /$IPATH
}
EOF
        note "kernel  /$KPATH"
        note "initrd  /$IPATH"
        note "root    $_root"
    fi

    # ---- flash-friendly fstab ---------------------------------------------
    say "Tuning /etc/fstab for flash"
    # setup-disk regenerates fstab with `genfstab -U`, so the root line is a
    # UUID= (not /dev/mmcblk0p2) and /boot is already listed because p1 was
    # mounted. It also appends a bare `tmpfs /tmp tmpfs` -- replace that with
    # sized entries so /tmp and /var/log churn never reaches the card.
    #
    # A tmpfs size is a ceiling, not a reservation: it costs nothing until
    # something fills it. So it is a share of RAM, not a number: a fifth is
    # about 100 MB on a Zero and over a gigabyte in a 6 GB VM. The fixed
    # 64 MB it replaces was a Zero's number applied everywhere, and on the VM
    # it broke the Go linker and the Endless Sky link while protecting
    # nothing.
    sed -i '/^tmpfs[[:space:]][[:space:]]*\/tmp[[:space:]]/d' /mnt/etc/fstab
    cat >> /mnt/etc/fstab <<FSTAB
tmpfs  /tmp      tmpfs  defaults,noatime,size=$TMP_SIZE  0 0
tmpfs  /var/log  tmpfs  defaults,noatime,size=32M  0 0
FSTAB
    # noatime avoids a write on every read; commit=600 batches journal
    # flushes. Match the mountpoint field -- the device field is a UUID now.
    sed -i -E 's|^([^#[:space:]]+[[:space:]]+/[[:space:]]+ext4[[:space:]]+)[^[:space:]]+|\1defaults,noatime,commit=600|' /mnt/etc/fstab

    # setup-disk also swallowed the share. Stage 1 mounted it at /mnt/share,
    # and with /mnt as the new root setup-disk read that as a mount at /share
    # OF THE NEW SYSTEM: its line says /share, carries the live options and
    # so no nofail, and the new root has no /mnt/share for ~/Shared to point
    # at. Put the line back the way stage 1 wrote it, and the directory with
    # it. See the note above configure_9p_share().
    if grep -q '^share[[:space:]]' /mnt/etc/fstab 2>/dev/null; then
        share_fstab_write /mnt/etc/fstab
        mkdir -p /mnt/mnt/share
        note "share: setup-disk read it as /share; back to /mnt/share, with nofail"
    fi

    # The carried-over config points /etc/apk/cache at /media/mmcblk0p2/cache,
    # which was p2 -- and p2 is now the root filesystem itself. Left alone
    # that is a dangling symlink and apk breaks on first use.
    say "Repointing the apk cache for the new root"
    rm -f /mnt/etc/apk/cache
    mkdir -p /mnt/var/cache/apk /mnt/etc/apk
    ln -s /var/cache/apk /mnt/etc/apk/cache
    sed -i "\|[[:space:]]$P2MNT[[:space:]]|d" /mnt/etc/fstab
    note "cache -> /var/cache/apk (on the new root)"

    echo
    note "fstab:"
    grep -v '^[[:space:]]*#' /mnt/etc/fstab | grep -v '^[[:space:]]*$' | sed 's/^/      /'
    echo
    # The check belongs INSIDE the branch. It used to sit below the fi and read
    # cmdline.txt unconditionally, so a PC or VM -- which has no cmdline.txt at
    # all, only grub.cfg -- got
    #
    #     grep: /media/vda1/cmdline.txt: No such file or directory
    #     error: cmdline.txt has no root= -- setup-disk did not finish
    #
    # one line after announcing "boot config after : 2 entries, root= set". The
    # stage had in fact succeeded; the verification was reading the other
    # platform's file.
    if is_pi_boot; then
        note "cmdline.txt before: $CMDLINE_BEFORE"
        note "cmdline.txt after : $(cat "$BOOT/cmdline.txt")"
        grep -q 'root=' "$BOOT/cmdline.txt" \
            || die "cmdline.txt has no root= -- setup-disk did not finish"
    else
        note "boot config before: $CMDLINE_BEFORE"
        note "boot config after : $(grep -c menuentry "$BOOTCFG") entries, root= set"
        grep -q 'root=' "$BOOTCFG" \
            || die "$BOOTCFG has no root= -- setup-disk did not finish"
        # "has a root=" was too weak a test once: it passed on
        # root=UUID=/dev/vda2:, which is what busybox blkid's ignored -s/-o
        # flags produced, and the first sign of trouble was an initramfs that
        # could not find the disk. Print what a kernel would actually receive
        # -- everything up to the first space -- and insist it names a UUID or
        # a device, nothing else.
        _rootarg=$(sed -n 's/.*[[:space:]]\(root=[^[:space:]]*\).*/\1/p' "$BOOTCFG" | head -n1)
        note "root argument     : $_rootarg"
        case "$_rootarg" in
            root=UUID=*[!0-9a-fA-F-]* | root=UUID=)
                die "$BOOTCFG has a malformed root= ($_rootarg) -- not a UUID" ;;
            root=UUID=* | root=/dev/*) ;;
            *) die "$BOOTCFG has an unusable root= ($_rootarg)" ;;
        esac
    fi

    # After the reboot this card is mounted at /boot, not /media/mmcblk0p1.
    # Leave a copy on the new root that is runnable by name from anywhere, so
    # the moved mount point cannot strand the remaining stages.
    say "Installing /usr/local/bin/copal on the new root"
    mkdir -p /mnt/usr/local/bin
    if cp "$0" /mnt/usr/local/bin/copal 2>/dev/null; then
        chmod 0755 /mnt/usr/local/bin/copal
        note "after rebooting, just run: copal"
    else
        warn "could not install the convenience copy; use 'sh /boot/copal-init.sh'"
    fi

    # setup-disk populated the new root from packages plus the apkovl. The
    # apkovl does carry /home/$PI_USER -- setup-alpine puts it in lbu's
    # include list -- but only as it stood at the last `lbu commit -d`, which
    # was stage 1 or 2, when it was empty. Confirm it is there and owned by
    # the right account before the reboot takes /mnt away, because after that
    # every stage that writes a dotfile is writing into whatever this left.
    ensure_user_home /mnt || true
    _nh=$(user_home)
    [ -n "$_nh" ] && [ -d "/mnt$_nh" ] \
        || warn "'$PI_USER' has no home directory on the new root -- stage 1 remakes it"

    # The reboot below is the only point in the install where control leaves
    # this script entirely. In automatic mode the way back has to be in place
    # on the NEW root before that happens -- /mnt is still mounted here, and
    # will not be after.
    if [ "${AUTO:-0}" = 1 ]; then
        auto_install_resume_hook /mnt
    fi

    sync
    umount /mnt/boot
    umount /mnt

    say "Stage 3 complete."
    cat <<MSG
    A reboot is REQUIRED before anything else. Until then / is still the
    tmpfs, the new root on p2 is merely populated, and stage 4 will refuse
    to install X into a filesystem that is about to be replaced.

    ---------------------------------------------------------------------
    AFTER THE REBOOT, LOG BACK IN AS  root  -- NOT AS '$PI_USER'.

    Stages 4 to 13 install software, and installing is root's job. There
    are two accounts and they have two different jobs:

        root      installs the system   -- you are here, stages 1-13
        $PI_USER      runs the desktop      -- once stage 4 has finished

    Log in as '$PI_USER' too early and copal-init.sh will tell you it needs
    root; the desktop will not be there yet either, because stage 4 is
    what installs it. Finish the stages as root first.
    ---------------------------------------------------------------------

    So, as root:

        sh /boot/copal-init.sh

    If you did log in as '$PI_USER', you do not have to log out -- put doas
    in front and carry on:

        doas sh /boot/copal-init.sh

    Note the path change: the boot partition is mounted at /boot from now on,
    NOT at /media/mmcblk0p1, which stops existing the moment the new fstab
    takes effect. (`copal` on its own also works -- a copy was installed
    to /usr/local/bin -- but /boot/copal-init.sh is always there.)

    Then check:
        df -h            # / should be /dev/mmcblk0p2, not tmpfs
        free -m
        ls -l /dev/fb0   # the framebuffer

    If it does not come back, put the card in another machine and:
        cp cmdline.txt.bak cmdline.txt
        (and delete the copal-init.sh managed block from usercfg.txt)
    That restores the RAM-resident system: with no root= the initramfs falls
    back to modloop plus the .apkovl.tar.gz, both still on p1, untouched.
    Read copal.log on that same partition to find out what went wrong.
MSG

    if confirm_yes "Reboot now?"; then
        say "Rebooting. Log back in as ROOT (not $PI_USER), then run:  sh /boot/copal-init.sh"
        sync
        # The log is on a FAT partition; make sure it is on the card before
        # the kernel stops caring about our buffers.
        umount "$BOOT" 2>/dev/null || mount -o remount,ro "$BOOT" 2>/dev/null || true
        reboot
        exit 0
    fi
    warn "Not rebooting. Stages 4-8 will not behave correctly until you do."
}
