# playbook: stage-base-config
# source:   copal
# origin:   stage
# stage:    1
# category: System
# step:     Apply the setup-alpine answers
# weight:   4
# levels:   server medium full
# summary:  Applies the answers given on the Mac through Alpine's own setup: keyboard, time zone,
#           network, the admin account and doas. The machine is still running from RAM at this
#           point.

# ---------------------------------------------------- stage 1: base config ---
stage_base_config() {
    say "Stage 1: applying setup-alpine answers"
    [ -f "$ANSWERS" ] || die "missing $ANSWERS -- was this card written by copal-prep.sh?"

    if apkovl_exists; then
        warn "a saved configuration already exists on the boot partition."
        note "Re-running setup-alpine will ask everything again, including the"
        note "root password, and overwrite the answers it set last time."
        confirm "Run setup-alpine again anyway?" || { note "Skipped."; return 0; }
    fi

    note "First, a few questions of Copal's own: the name and email for git"
    note "commits, and the repositories to check out into ~/code. They are"
    note "saved on the card and acted on by stage 7, which is why that stage"
    note "does not stop to ask an hour and a half from now."
    note "Then keymap, hostname, network, timezone, mirror, sshd and user come"
    note "from answers.txt."
    if answers_pw_hash >/dev/null 2>&1; then
        note "The root password comes from answers.txt too, as a hash, so this"
        note "stage asks nothing at all. '$PI_USER' gets the same password."
    else
        note "The root password is the one thing it will ask for --"
        note "setup-alpine has no answer-file variable for it."
        note "It will also ask for a password for '$PI_USER'. Whatever you type"
        note "there is overwritten immediately afterwards with root's, so that"
        note "the two accounts share one password. It will not accept an empty"
        note "one, so type the root password again there and it changes nothing."
    fi

    # Every question a human has to answer, in one place. The git identity goes
    # first because it is Copal's own prompt and can have the plain terminal to
    # itself; the screen comes down for it and goes back up, exactly as it does
    # for setup-alpine below.
    tui_suspend
    git_identity_ask
    # Last of Copal's own questions, and the only one that is about what this
    # machine is FOR rather than about how it is built. It goes after the
    # identity because it is the same conversation continued: who you are, and
    # then what you came here to work on.
    repos_ask
    tui_resume

    # setup-alpine writes over the whole terminal and asks questions of its own,
    # so the progress screen comes down for the duration and goes back up after.
    # Suspending is not optional: leaving it up would interleave its output with
    # addressed repaints and leave both unreadable.
    # THE ONE PROMPT, and whether it happens at all.
    #
    # With a hash on the card, setup-alpine still insists on being given a
    # password -- there is no flag that skips it -- so it is handed a throwaway
    # one on stdin and the real hash replaces it a moment later. The throwaway
    # is random and never leaves this shell: it exists only to satisfy three
    # prompts, and root's hash is overwritten before the stage ends.
    #
    # Piping to setup-alpine works because busybox passwd reads from stdin when
    # stdin is not a terminal. That is also why the throwaway is repeated four
    # times: root twice, then '$PI_USER' twice, and a short read there would
    # leave setup-alpine consuming the next stage's input.
    if _pw_hash=$(answers_pw_hash); then
        note "Root password comes from answers.txt -- nothing to type."
        _throwaway=$(dd if=/dev/urandom bs=1 count=18 2>/dev/null | base64 | tr -d '=+/' )
        tui_suspend
        printf '%s\n%s\n%s\n%s\n' \
            "$_throwaway" "$_throwaway" "$_throwaway" "$_throwaway" \
            | setup-alpine -f "$ANSWERS"
        tui_resume
        _throwaway=""
        apply_answers_password "$_pw_hash" || true
        _pw_hash=""
    else
        tui_prompt "ROOT PASSWORD" \
            "setup-alpine is about to ask for it. There is no answer-file variable for a password, so this is the one thing a full-automatic install cannot fill in." \
            "You will be asked TWICE more -- once to confirm, then again for '$PI_USER'. Type the same thing all three times." \
            "Run 'make answers' on the Mac to stop being asked at all." \
            ''
        tui_suspend
        setup-alpine -f "$ANSWERS"
        tui_resume
    fi

    dedupe_repositories

    # Before the commit, so the synced password goes into the same apkovl.
    admin_sync_password || warn "'$PI_USER' may not be able to log in -- check 'passwd $PI_USER'"
    # Unconditional, and deliberately after the || above: a password sync that
    # failed is exactly when the privilege grant is most likely to have been
    # skipped, and least likely to be noticed.
    admin_ensure_privileges || warn "'$PI_USER' is not a working administrator -- stage 13 will decline to lock root"
    # Cheap, and it repairs a root laid down by a version of this script that
    # leaked a restrictive umask into stage 3.
    fix_system_dir_modes
    root_handover_notes

    # Before the commit, so the fstab line and the module list are inside the
    # apkovl. On a diskless system a change made after it is a change lost.
    configure_9p_share
    configure_vm_graphics_env
    configure_power_button
    configure_debug_flag

    # Before the commit, and before anything relies on persistence.
    lbu_fix_media

    # WHY THIS IS CONDITIONAL, and it did not used to be.
    #
    # lbu exists to rebuild a RAM-resident root from an apkovl at every boot.
    # Once stage 3 has moved / onto p2 there is no such thing to rebuild: the
    # root filesystem is the persistent copy, /etc is already saved because it
    # is already on disk, and the apkovl is a snapshot nothing will ever read.
    #
    # Running it anyway does not merely waste effort, it FAILS -- and fails in
    # a way that reads as a broken machine. lbu takes its medium from
    # LBU_MEDIA and looks for /media/$LBU_MEDIA, but a sys-installed Alpine
    # mounts that partition at /boot instead, so the directory lbu wants is
    # simply not there. lbu answers a missing medium by printing its top-level
    # usage and exiting 1, which is a confusing thing to hand someone: the
    # message is about subcommands, and the actual complaint is a path.
    #
    # This mattered because re-running stage 1 is the documented repair for an
    # admin account, and on a finished machine it died at the last line --
    # after having done all of its real work.
    if is_diskless; then
        say "Committing the configuration to the boot partition"
        # Without this, nothing at all survives a reboot on a diskless system.
        lbu commit -d || die "lbu commit failed -- see above. Nothing will persist until this works."
        ls -l "$BOOT"/*.apkovl.tar.gz
    else
        say "Root filesystem is persistent -- no lbu commit needed"
        note "/ is $(root_fstype) on $(awk '$2 == "/" { print $1 }' /proc/mounts), so everything"
        note "written above is already saved. lbu and the apkovl are for a"
        note "RAM-resident root, which this machine stopped having at stage 3."
    fi

    say "Stage 1 complete."
    note "The configuration is saved. From here the system survives a reboot,"
    note "but installed packages do not -- that is what stage 2 is for."
}
