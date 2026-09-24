# playbook: stage-sshkey
# source:   copal
# origin:   stage
# stage:    6
# category: Access
# step:     Install the SSH key from the card
# weight:   3
# levels:   server medium full
# summary:  Authorises the Mac's public key for the admin account, so the machine can be reached
#           without a password. Only the .pub half of the key ever travelled.

stage_sshkey() {
    say "Stage 6: authorise the Mac's SSH key for '$PI_USER'"
    KEYSRC="$BOOT/authorized_keys"
    [ -f "$KEYSRC" ] || {
        warn "no $KEYSRC on the boot partition."
        note "copal-prep.sh copies it there from ~/.ssh/*.pub on the Mac."
        return 0
    }
    id "$PI_USER" >/dev/null 2>&1 || {
        warn "user '$PI_USER' does not exist yet -- run stage 1 first"
        return 0
    }

    HOMEDIR=$(user_home)
    [ -n "$HOMEDIR" ] || die "cannot determine the home directory for $PI_USER"
    # In the automatic order this is the first stage to touch the home
    # directory, and `mkdir -p $HOMEDIR/.ssh` would happily create a
    # root-owned $HOMEDIR on the way past -- a home directory its owner
    # cannot write, which is worse than not having one.
    ensure_user_home || true

    say "Installing into $HOMEDIR/.ssh/authorized_keys"
    mkdir -p "$HOMEDIR/.ssh"
    # sshd refuses to use these if they are group- or world-writable.
    if [ -f "$HOMEDIR/.ssh/authorized_keys" ] \
       && grep -qxF "$(cat "$KEYSRC")" "$HOMEDIR/.ssh/authorized_keys"; then
        note "that key is already authorised"
    else
        cat "$KEYSRC" >> "$HOMEDIR/.ssh/authorized_keys"
        note "added $(awk '{print $1, $NF}' "$KEYSRC")"
    fi
    chown -R "$PI_USER" "$HOMEDIR/.ssh"
    chmod 700 "$HOMEDIR/.ssh"
    chmod 600 "$HOMEDIR/.ssh/authorized_keys"

    rc-update add sshd default >/dev/null 2>&1 || true
    rc-service sshd start >/dev/null 2>&1 || rc-service sshd restart >/dev/null 2>&1 || true

    # --- the policy ---------------------------------------------------------
    say "Applying the SSH policy"
    cat <<MSG
    The default from here is the one worth having: the key you just installed
    is the only way in, root cannot log in over the network at all, and
    '$PI_USER' is the only account sshd will consider.

    A password is a thing that can be guessed by anyone who can reach port 22.
    A key cannot, and you already have one on this card -- so leaving password
    login on buys nothing and costs you every brute-force attempt on the
    internet. It stays available as a toggle rather than a rebuild:

        doas copal-ssh password on     # allow passwords again
        doas copal-ssh password off    # keys only
        doas copal-ssh status          # what is in force now

MSG
    # ssh_key_usable, NOT ssh_has_key. The difference is the whole guard: one
    # asks whether the file exists, the other whether sshd will accept it. The
    # first is what this used to check, and it disabled password login on a key
    # the daemon then refused -- see ssh_key_usable for the lockout that made.
    # answers.txt first, when it has an opinion: this was decided on the Mac,
    # by the person who chose the password, and asking again here would let an
    # unattended install answer it differently from how they meant.
    if _sshpw=$(answers_ssh_password); then
        if [ "$_sshpw" = no ]; then
            note "answers.txt: password login over SSH is to be OFF."
            ssh_key_usable || {
                warn "there is no key sshd will accept, so SSH will refuse EVERY"
                warn "login after this. That is what answers.txt asked for --"
                warn "it is what stops a known password being a network login."
                note "The console still works. To undo it from there:"
                note "    doas copal-ssh password on"
            }
            ssh_write_policy no || warn "policy not applied"
        else
            note "answers.txt: password login over SSH stays on."
            ssh_write_policy yes || warn "policy not applied"
        fi
    elif ssh_key_usable; then
        AUTO_DEFAULT=y
        if confirm_yes "Require the key and disable password login over SSH?"; then
            ssh_write_policy no || warn "policy not applied"
        else
            note "Leaving password login enabled."
            ssh_write_policy yes || warn "policy not applied"
        fi
    else
        # The guard that matters. Without a key sshd will actually honour,
        # key-only locks the machine off the network entirely, so it is not
        # offered -- not even in automatic mode, where nobody is watching.
        if ssh_has_key; then
            warn "there IS a key in $HOMEDIR/.ssh/authorized_keys, but sshd will not use it."
            warn "The warnings above say which check failed."
        else
            warn "no key in $HOMEDIR/.ssh/authorized_keys."
        fi
        warn "NOT disabling password login -- that would lock you out entirely."
        ssh_write_policy yes || warn "policy not applied"
        note "Fix the ownership, then: doas copal-ssh password off"
    fi

    say "Installing /usr/local/bin/copal-ssh"
    cat > /usr/local/bin/copal-ssh <<COPALSSH
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-ssh -- read and change the SSH policy Copal wrote into sshd_config.
#
#   copal-ssh status            show what is in force
#   copal-ssh password on|off   allow / refuse password authentication
#   copal-ssh root on|off       allow / refuse root login over SSH
#   copal-ssh users U [U...]    replace the AllowUsers list
#
# Everything lives in one managed block at the top of the file; delete the
# block by hand and stock OpenSSH behaviour returns.
set -eu
CFG=$SSHCFG
USER_DEFAULT=$PI_USER
COPALSSH
cat >> /usr/local/bin/copal-ssh <<'COPALSSH'
B='# >>> copal ssh policy >>>'
E='# <<< copal ssh policy <<<'

[ "$(id -u)" = 0 ] || { echo "needs root: doas copal-ssh $*" >&2; exit 1; }
[ -f "$CFG" ] || { echo "no $CFG" >&2; exit 1; }

get() { sed -n "/$B/,/$E/p" "$CFG" | awk -v k="$1" 'tolower($1)==tolower(k){print $2; exit}'; }

status() {
    if ! grep -qF "$B" "$CFG"; then
        echo "No Copal policy block -- sshd is using its stock configuration."
        grep -iE '^[[:space:]]*(PermitRootLogin|PasswordAuthentication|AllowUsers)' "$CFG" || true
        return 0
    fi
    printf 'password login : %s\n' "$(get PasswordAuthentication)"
    printf 'root login     : %s\n' "$(get PermitRootLogin)"
    printf 'allowed users  : %s\n' "$(sed -n "/$B/,/$E/p" "$CFG" | sed -n 's/^AllowUsers[[:space:]]*//p')"
    printf 'public keys    : %s\n' "$(get PubkeyAuthentication)"
}

# Rewrite one keyword inside the block, leaving everything else alone.
set_key() {  # <keyword> <value>
    grep -qF "$B" "$CFG" || { echo "no Copal policy block to edit" >&2; exit 1; }
    cp "$CFG" "$CFG.copal.bak"
    awk -v b="$B" -v e="$E" -v k="$1" -v v="$2" '
        $0 == b { inb = 1 }
        $0 == e { inb = 0 }
        inb && tolower($1) == tolower(k) { print k, v; next }
        { print }
    ' "$CFG" > "$CFG.copal.new" && mv "$CFG.copal.new" "$CFG"
    if sshd -t 2>/dev/null; then
        rc-service sshd reload >/dev/null 2>&1 || rc-service sshd restart >/dev/null 2>&1 || true
    else
        echo "sshd rejected the change -- reverting." >&2
        sshd -t 2>&1 | sed 's/^/  /' >&2
        cp "$CFG.copal.bak" "$CFG"
        exit 1
    fi
}

has_key() {
    h=$(getent passwd "$USER_DEFAULT" | cut -d: -f6)
    [ -n "$h" ] && [ -s "$h/.ssh/authorized_keys" ]
}

case "${1:-status}" in
    status) status ;;
    password)
        case "${2:-}" in
            on|yes)  set_key PasswordAuthentication yes
                     set_key KbdInteractiveAuthentication yes
                     set_key ChallengeResponseAuthentication yes
                     echo "Password login is ON." ;;
            off|no)
                if ! has_key; then
                    echo "Refusing: $USER_DEFAULT has no authorized_keys, so turning" >&2
                    echo "passwords off would lock this machine off the network." >&2
                    exit 1
                fi
                set_key PasswordAuthentication no
                set_key KbdInteractiveAuthentication no
                set_key ChallengeResponseAuthentication no
                echo "Password login is OFF -- keys only." ;;
            *) echo "usage: copal-ssh password on|off" >&2; exit 2 ;;
        esac ;;
    root)
        case "${2:-}" in
            on|yes) set_key PermitRootLogin prohibit-password
                    echo "Root may log in over SSH BY KEY ONLY (prohibit-password)." ;;
            off|no) set_key PermitRootLogin no; echo "Root login over SSH refused." ;;
            *) echo "usage: copal-ssh root on|off" >&2; exit 2 ;;
        esac ;;
    users)
        shift
        [ "$#" -gt 0 ] || { echo "usage: copal-ssh users NAME [NAME...]" >&2; exit 2; }
        set_key AllowUsers "$*"
        echo "AllowUsers: $*" ;;
    *) sed -n '2,${/^#/!q; /^# SPDX/d; /^# Copyright/d; p;}' "$0"; exit 2 ;;
esac
COPALSSH
    chmod 0755 /usr/local/bin/copal-ssh

    say "Stage 6 complete."
    note "From the Mac:  ssh $PI_USER@$(hostname)"
    note "or by address: ssh $PI_USER@$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{sub(/\/.*/,"",$2); print $2; exit}')"
    note "Change the policy later with: doas copal-ssh status"
}
