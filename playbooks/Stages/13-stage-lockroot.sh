# playbook: stage-lockroot
# source:   copal
# origin:   stage
# stage:    13
# category: Handover
# step:     Hand root over to the admin user
# weight:   4
# levels:   server medium full
# summary:  Locks the root account and hands administration to your own account through doas. It
#           checks that the account works first, so it cannot lock you out.

# ----------------------------------------------- stage 13: hand over root ---
#
# The last stage of an install, and deliberately last: it takes away the
# account every earlier stage logs in as. Everything it does is reversible from
# a doas shell, and it refuses outright if the admin account is not in a state
# to open one.
stage_lockroot() {
    say "Stage 13: lock the root account, hand privilege to '$PI_USER'"
    root_handover_notes

    if root_locked && sed -n "/$SSH_BEGIN/,/$SSH_END/p" "$SSHCFG" 2>/dev/null \
         | grep -qi '^PermitRootLogin[[:space:]]*no'; then
        note "Already done -- root is locked and SSH refuses it."
        note "Undo with: doas passwd root"
        return 0
    fi

    # The pre-flight. Getting this wrong is a machine you cannot log into and
    # cannot repair without pulling the card, so each half is reported by name
    # rather than as one pass/fail.
    say "Checking '$PI_USER' can take over before anything is locked"
    _bad=0
    if can_login "$PI_USER"; then note "password    : set"
    else warn "password    : NOT set -- '$PI_USER' cannot log in at all"; _bad=1; fi
    if in_wheel "$PI_USER"; then note "wheel group : yes"
    else warn "wheel group : no -- doas will refuse"; _bad=1; fi
    if command -v doas >/dev/null 2>&1; then note "doas        : $(command -v doas)"
    else warn "doas        : not installed"; _bad=1; fi
    # NOT `doas -C /etc/doas.conf true`. Handing -C a command changes the
    # question from "is this file valid" to "may the user running me run that
    # command" -- and this runs as root, which no `permit :wheel` rule
    # matches, so the answer was no however healthy the configuration was.
    # That is what refused to hand over on a machine where doas worked
    # perfectly well: it reported a deny as a parse error.
    #
    # The real requirements are that every file doas reads parses and that
    # some rule reaches $PI_USER, both of which admin_ensure_doas checks --
    # and fixes, because this stage is the last chance to fix them while root
    # can still log in.
    if command -v doas >/dev/null 2>&1; then
        if admin_ensure_doas; then note "doas config : parses, and a rule reaches wheel"
        else warn "doas config : not usable -- see above"; _bad=1; fi
    fi

    if [ "$_bad" != 0 ]; then
        warn "not locking root -- fix the above first."
        note "Usually: run stage 1, or by hand:"
        note "  passwd $PI_USER && adduser $PI_USER wheel && apk add doas"
        note "  echo 'permit persist :wheel' > /etc/doas.d/wheel.conf"
        note "(/etc/doas.conf must exist too, even if every line in it is a comment.)"
        return 1
    fi

    # The hash check above says the password would be accepted; this says the
    # rest of the account works -- shell, home directory, groups. Run from
    # root, su asks for nothing, so a failure here is a real defect and not a
    # mistyped password.
    #
    # The home directory is checked separately rather than through su: su
    # falls back to / when it cannot chdir to $HOME and carries on, so it
    # would pass this test and still leave the person a shell that starts in
    # a directory they do not own and cannot write.
    say "Testing the account"
    ensure_user_home || true
    if su - "$PI_USER" -c 'id' >/dev/null 2>&1; then
        note "ok -- '$PI_USER' has a working shell"
    else
        warn "could not switch to '$PI_USER'. Not locking root."
        note "Check: getent passwd $PI_USER"
        return 1
    fi
    _uh=$(user_home)
    if [ -n "$_uh" ] && [ -d "$_uh" ]; then
        note "home        : $_uh"
    else
        warn "home        : $_uh is missing and could not be created"
        warn "not locking root -- fix that first."
        return 1
    fi

    warn "About to lock root. After this the ONLY way in is '$PI_USER' + doas."
    confirm "Lock the root account?" || { note "Left alone."; return 0; }

    say "Locking the root password"
    passwd -l root && note "root: $(shadow_hash root | cut -c1-2)... (locked)"

    if [ -f "$SSHCFG" ]; then
        say "Refusing root over SSH"
        # Through the same managed block stage 6 uses, so the two cannot
        # disagree about what the policy is. Passwords keep whatever setting
        # they already had -- locking root is not a reason to silently change
        # how the admin user authenticates.
        if _sshpw=$(answers_ssh_password); then
            note "answers.txt decides password login over SSH: $_sshpw"
            ssh_write_policy "$_sshpw"
        elif ssh_policy_present && ssh_password_on; then
            ssh_write_policy yes
        elif ssh_policy_present; then
            ssh_write_policy no
        elif ssh_has_key; then
            note "no policy block yet -- writing one, keys only"
            ssh_write_policy no
        else
            note "no policy block yet, and no key installed -- writing one that"
            note "keeps password login, so this does not lock you off the network"
            ssh_write_policy yes
        fi
    fi

    say "Stage 13 complete."
    note "Log in as: $PI_USER        Become root: doas -s"
    note "Undo, from a doas shell:   doas passwd root"
    commit_reminder
}
