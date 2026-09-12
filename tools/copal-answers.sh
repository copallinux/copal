#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
#
#  COPAL ALPINE LINUX -- collect the answers an unattended install needs.
#
# `make answers` asks the handful of questions that would otherwise stop the
# install dead an hour in, and writes them to answers.txt in the project root.
# copal-prep.sh sources that file at build time and copies the COPAL_* values
# onto the card, where copal-init.sh reads them back.
#
# THE PASSWORD IS NOT STORED. What is stored is its SHA-512 crypt hash -- the
# same string /etc/shadow holds -- so the file, and every image built from it,
# can be read by anyone without giving up the password. Stage 1 applies it with
# `chpasswd -e`, which takes an already-hashed value.
#
# THE DEFAULT IS 'hunter2', AND IT IS A JOKE PASSWORD ON A REAL MACHINE. It is
# here because automated testing needs a password it already knows, and that is
# the only thing it is good for. What is actually being built is not a toy:
#
#   - openssh is installed and running from stage 1 (SSHDOPTS="-c openssh")
#   - the login user shares root's password, and sshd's AllowUsers permits
#     exactly that account
#   - root over SSH is always refused, but PASSWORD authentication is left ON
#     whenever no SSH key was installed -- see stage 13, which keeps it rather
#     than locking someone off a board they would have to fetch. So on a build
#     with no key, 'user' plus this password is a working network login
#   - the guest has its own address on the host network, a full compiler
#     toolchain, and everything needed to run a server
#
# A key from this Mac is installed by default, and stage 13 turns password
# authentication off when it finds one -- which is the single fact that makes
# the default defensible at all. Build with CFG_SSHKEY= to skip the key, or
# put the machine anywhere that matters, and 'hunter2' is exactly as bad as it
# looks. Set a real one here; that is the whole point of this being a file you
# can edit.
#
# THE FLEET. Answer the fleet questions and this file stops describing one
# machine and starts describing one machine OUT OF SEVERAL -- a named fleet
# that shares a certificate authority, finds itself on the LAN, and is driven
# from one console. See docs/fleet-plan.md. Leave the fleet name empty and
# nothing below it is asked, nothing is installed, and the machine built is
# exactly the standalone machine it has always been.
#
# --node N is what makes eight cards bearable: it re-writes answers.txt for
# card N of the fleet -- new hostname, new one-time enrolment token, every
# other answer left alone -- without asking a single question. Eight cards is
# one interview and seven of these.
#
# Usage:
#   tools/copal-answers.sh              ask, then write answers.txt
#   tools/copal-answers.sh --show       print the current answers, no password
#   tools/copal-answers.sh --force      overwrite without confirming
#   tools/copal-answers.sh --node N     card N of the fleet; asks nothing
#   tools/copal-answers.sh --node N --role warden --tags wall,sdr
set -euo pipefail

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*" >&2; }
note() { printf '    %s\n' "$*" >&2; }
# warn was used in four places before it existed. Under `set -euo pipefail` an
# undefined command is exit 127, so every one of those recoveries -- "no such
# key file, continuing without one" -- killed the script instead of recovering.
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANSWERS="$ROOT/answers.txt"
CRYPT="$ROOT/tools/sha512-crypt.py"
FORCE=0
SHOW=0
NODE=""
ROLE_ARG=""
TAGS_ARG=""
TAGS_SET=0
while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=1 ;;
        --show)  SHOW=1 ;;
        --node)  NODE="${2:-}"; shift ;;
        --node=*) NODE="${1#*=}" ;;
        --role)  ROLE_ARG="${2:-}"; shift ;;
        --role=*) ROLE_ARG="${1#*=}" ;;
        --tags)  TAGS_ARG="${2:-}"; TAGS_SET=1; shift ;;
        --tags=*) TAGS_ARG="${1#*=}"; TAGS_SET=1 ;;
        -h|--help) sed -n '5,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument '$1'. See --help." ;;
    esac
    shift
done
case "$NODE" in
    ''|*[!0-9]*) [ -z "$NODE" ] || die "--node takes a number, not '$NODE'" ;;
esac
[ "$NODE" = 0 ] && die "--node counts from 1"
if [ -n "$ROLE_ARG" ] || [ "$TAGS_SET" = 1 ]; then
    [ -n "$NODE" ] || die "--role and --tags only mean anything with --node"
fi
case "${ROLE_ARG:-node}" in
    node|warden|console) ;;
    *) die "--role must be node, warden or console" ;;
esac

if [ "$SHOW" -eq 1 ]; then
    [ -f "$ANSWERS" ] || die "no answers.txt yet. Run: make answers"
    # The hash is a hash, but printing it invites shoulder-surfing a offline
    # crack, so it is shown as its presence only.
    # The token is single use and unspent until a node enrols, so it is worth
    # the same masking as the hash -- a screenshot of --show should not be a
    # working enrolment for somebody else's machine.
    sed -e "s/^\\(COPAL_ROOT_PW_HASH=\\).*/\\1<set>/" \
        -e "s/^\\(COPAL_FLEET_TOKEN=\\).\\{1,\\}/\\1<set>/" "$ANSWERS"
    exit 0
fi

[ -x "$CRYPT" ] || die "missing $CRYPT"
python3 "$CRYPT" --selftest >/dev/null 2>&1 \
    || die "sha512-crypt self-test failed -- refusing to write a hash I cannot trust"

if [ -f "$ANSWERS" ] && [ "$FORCE" -eq 0 ] && [ -z "$NODE" ]; then
    info "answers.txt already exists."
    note "Its current values are the defaults below -- press Enter to keep each."
fi

# Existing answers become the defaults, so re-running this to change one thing
# does not mean retyping the rest.
#
# PARSED, not sourced, and that distinction is load-bearing. Sourcing a file
# whose hash line reads COPAL_ROOT_PW_HASH="$6$rounds=..." expands $6 as a
# positional parameter, and under `set -u` that is not a warning, it is the end
# of the script -- which is exactly how this was found. Parsing also means a
# file hand-edited into either quoting style still reads correctly.
get_answer() {  # <variable name>
    [ -f "$ANSWERS" ] || return 0
    sed -n "s/^$1=[\"']\{0,1\}\(.*\)/\1/p" "$ANSWERS" \
        | sed "s/[\"']\{0,1\}[[:space:]]*$//" | head -1
}
if [ -f "$ANSWERS" ]; then
    COPAL_GIT_NAME=$(get_answer COPAL_GIT_NAME)
    COPAL_GIT_EMAIL=$(get_answer COPAL_GIT_EMAIL)
    COPAL_GIT_REPOS=$(get_answer COPAL_GIT_REPOS)
    COPAL_USER=$(get_answer COPAL_USER)
    COPAL_HOSTNAME=$(get_answer COPAL_HOSTNAME)
    COPAL_TIMEZONE=$(get_answer COPAL_TIMEZONE)
    COPAL_KEYMAP=$(get_answer COPAL_KEYMAP)
    COPAL_ROOT_PW_HASH=$(get_answer COPAL_ROOT_PW_HASH)
    COPAL_SSH_KEY=$(get_answer COPAL_SSH_KEY)
    COPAL_MAIL_ADDRESS=$(get_answer COPAL_MAIL_ADDRESS)
    COPAL_MAIL_NAME=$(get_answer COPAL_MAIL_NAME)
    COPAL_MAIL_IMAP=$(get_answer COPAL_MAIL_IMAP)
    COPAL_MAIL_SMTP=$(get_answer COPAL_MAIL_SMTP)
    COPAL_AUTO=$(get_answer COPAL_AUTO)
    COPAL_SSH_PASSWORD_LOGIN=$(get_answer COPAL_SSH_PASSWORD_LOGIN)
    # The fleet. COPAL_FLEET_PSK and COPAL_FLEET_CA are properties of the
    # FLEET and must be identical on every card in it; index and token are
    # properties of THE CARD and differ on every one. --node changes the
    # second pair and nothing else, which is the whole reason it exists.
    COPAL_FLEET=$(get_answer COPAL_FLEET)
    COPAL_FLEET_SIZE=$(get_answer COPAL_FLEET_SIZE)
    COPAL_FLEET_INDEX=$(get_answer COPAL_FLEET_INDEX)
    COPAL_FLEET_ROLE=$(get_answer COPAL_FLEET_ROLE)
    COPAL_FLEET_DISCOVERY=$(get_answer COPAL_FLEET_DISCOVERY)
    COPAL_FLEET_REMOTE=$(get_answer COPAL_FLEET_REMOTE)
    COPAL_FLEET_REMOTE_MINUTES=$(get_answer COPAL_FLEET_REMOTE_MINUTES)
    COPAL_FLEET_CA=$(get_answer COPAL_FLEET_CA)
    COPAL_FLEET_PSK=$(get_answer COPAL_FLEET_PSK)
    COPAL_FLEET_TAGS=$(get_answer COPAL_FLEET_TAGS)
fi

# 16 bytes of urandom as hex, without depending on openssl or on a shell whose
# $RANDOM is worth anything. od is in coreutils on the Mac and in busybox on
# Alpine, so this is the one form that works in both places.
rand_hex() { od -An -tx1 -N"${1:-16}" /dev/urandom | tr -d ' \n'; }

# museum + 3 -> museum-03. Two digits because a fleet that reaches ten sorts
# wrongly with one, and every list in the console is sorted by name.
fleet_hostname() { printf '%s-%02d' "$1" "$2"; }

# SINGLE quotes, always, and this is not stylistic. A SHA-512 crypt hash
# begins "$6$rounds=..." -- inside double quotes the shell expands $6 as a
# positional parameter, which under `set -u` aborts copal-prep.sh outright and
# under setup-alpine on the card silently truncates the hash to "$rounds=...",
# locking the account. Names with an apostrophe are handled the POSIX way:
# close the quote, escape the apostrophe, reopen.
sq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

write_answers() {
# Written 0600 before anything goes in it, so there is no window where the
# file exists and is world-readable.
umask 077
: > "$ANSWERS"
cat > "$ANSWERS" <<EOF
# Copal -- answers for an unattended install.  Written by: make answers
#
# Edit this by hand or re-run 'make answers'; either way copal-prep.sh picks it
# up on the next build. Changing anything here means rebuilding the image for
# it to take effect -- these values are baked onto the card, not read at boot.
#
# COPAL_ROOT_PW_HASH is a SHA-512 crypt hash, the same string /etc/shadow
# holds. The password itself is not here and cannot be recovered from this.
# Replace it by running 'make answers' again, not by editing this line.
#
# This file is listed in .gitignore. Keep it that way.

COPAL_GIT_NAME=$(sq "${COPAL_GIT_NAME}")
COPAL_GIT_EMAIL=$(sq "${COPAL_GIT_EMAIL}")
# Space-separated, one word per URL. Cloned into ~/code by stage 7; stage 1
# offers this list and lets it be changed on the machine.
COPAL_GIT_REPOS=$(sq "${COPAL_GIT_REPOS:-}")
COPAL_USER=$(sq "${COPAL_USER}")
COPAL_HOSTNAME=$(sq "${COPAL_HOSTNAME}")
COPAL_TIMEZONE=$(sq "${COPAL_TIMEZONE}")
COPAL_KEYMAP=$(sq "${COPAL_KEYMAP}")
COPAL_ROOT_PW_HASH=$(sq "${COPAL_ROOT_PW_HASH}")

# Mail, if given: stage 12 seeds Thunderbird and Claws Mail from these so the
# first start opens on the Inbox, not the account wizard. IMAP over TLS on
# 993, SMTP over TLS on 465, password asked by the client on first use.
COPAL_MAIL_ADDRESS=$(sq "${COPAL_MAIL_ADDRESS}")
COPAL_MAIL_NAME=$(sq "${COPAL_MAIL_NAME}")
COPAL_MAIL_IMAP=$(sq "${COPAL_MAIL_IMAP}")
COPAL_MAIL_SMTP=$(sq "${COPAL_MAIL_SMTP}")

# The .pub half of a key on this Mac. copal-prep.sh copies it to the card as
# authorized_keys; the private key never leaves this machine.
COPAL_SSH_KEY=$(sq "${COPAL_SSH_KEY}")
# yes or no. 'no' means sshd accepts keys only.
COPAL_SSH_PASSWORD_LOGIN=$(sq "${COPAL_SSH_PASSWORD_LOGIN}")

# 1 = do not stop to ask anything the values above can answer.
COPAL_AUTO=$(sq "${COPAL_AUTO:-1}")

# --- the fleet -------------------------------------------------------------
# Empty COPAL_FLEET means a standalone machine and stage 16 does nothing at
# all. Everything below is read by copal-prep.sh, copied to the card, and used
# once by copal-init.sh; see docs/fleet-plan.md for what each one becomes.
#
# Identical on every card in the fleet:      FLEET, SIZE, CA, PSK, DISCOVERY
# Different on every card in the fleet:      INDEX, TOKEN, HOSTNAME, ROLE, TAGS
#
# Write the other cards with:  tools/copal-answers.sh --node 2
COPAL_FLEET=$(sq "${COPAL_FLEET:-}")
COPAL_FLEET_SIZE=$(sq "${COPAL_FLEET_SIZE:-}")
COPAL_FLEET_INDEX=$(sq "${COPAL_FLEET_INDEX:-}")
# node | warden | console -- a preference at first boot, not a fixed rank.
COPAL_FLEET_ROLE=$(sq "${COPAL_FLEET_ROLE:-}")
# Comma separated. Scenes assign work by tag, so a dongle can move boards.
COPAL_FLEET_TAGS=$(sq "${COPAL_FLEET_TAGS:-}")
# mdns | static | off
COPAL_FLEET_DISCOVERY=$(sq "${COPAL_FLEET_DISCOVERY:-}")
# off | auto -- whether this node may ever put its screen on the network, and
# for how long once it does.
COPAL_FLEET_REMOTE=$(sq "${COPAL_FLEET_REMOTE:-}")
COPAL_FLEET_REMOTE_MINUTES=$(sq "${COPAL_FLEET_REMOTE_MINUTES:-}")
# The PUBLIC half of the fleet certificate authority. Every card carries it so
# that no machine is ever trusted on first sight. The private half stays in
# ~/.copal/ca on the machine that ran this script and must never be on a card.
COPAL_FLEET_CA=$(sq "${COPAL_FLEET_CA:-}")
# A spam filter on the discovery beacon, not a credential: it is on every card,
# so it says which fleet a beacon claims to be from and proves nothing. The
# certificate above is what actually decides. Do not promote this to a secret.
COPAL_FLEET_PSK=$(sq "${COPAL_FLEET_PSK:-}")
# One-time enrolment token, THIS CARD ONLY, burned when the node is signed. A
# fresh one is generated every time this script runs, so a card that goes
# missing cannot enrol a second time.
COPAL_FLEET_TOKEN=$(sq "${COPAL_FLEET_TOKEN:-}")
EOF
chmod 600 "$ANSWERS"
record_token
}

# THE TOKEN LEDGER, and the reason it has to exist: answers.txt only ever holds
# the token for the card being written NEXT. The console has to check card 3's
# token months after card 8 was written, so each one is recorded here as it is
# generated, and `copal fleet enrol` marks it spent once the node is signed.
#
# One unused entry per hostname. Re-running for the same card supersedes the
# old token rather than adding to it -- two live tokens for one machine would
# mean the check has two right answers, which is not a check.
record_token() {
    [ -n "${COPAL_FLEET:-}" ] || return 0
    [ -n "${COPAL_FLEET_TOKEN:-}" ] || return 0
    _led="$HOME/.copal/fleets/$COPAL_FLEET"
    mkdir -p "$_led" || return 0
    chmod 700 "$HOME/.copal" "$HOME/.copal/fleets" "$_led" 2>/dev/null || true
    _f="$_led/tokens"
    : >> "$_f"
    # awk rather than `grep -v`: grep exits 1 when it prints nothing, which is
    # exactly the empty-ledger case, and the rewrite would then be skipped.
    awk -F'\t' -v h="$COPAL_HOSTNAME" '!($1 == h && $3 == "unused")' "$_f" > "$_f.new" \
        && mv "$_f.new" "$_f"
    printf '%s\t%s\tunused\n' "$COPAL_HOSTNAME" "$COPAL_FLEET_TOKEN" >> "$_f"
    chmod 600 "$_f"
}

summarise() {
info "Wrote $ANSWERS (mode 600)"
note ""
note "  git identity   ${COPAL_GIT_NAME} <${COPAL_GIT_EMAIL}>"
note "  ~/code         $(set -- ${COPAL_GIT_REPOS:-}; [ $# -gt 0 ] && echo "$# repositor$([ $# = 1 ] && echo y || echo ies)" || echo '(none)')"
[ -n "$COPAL_MAIL_ADDRESS" ] && note "  mail           ${COPAL_MAIL_ADDRESS} via ${COPAL_MAIL_IMAP} / ${COPAL_MAIL_SMTP}"
note "  user           ${COPAL_USER}"
note "  hostname       ${COPAL_HOSTNAME}"
note "  root password  stored as a SHA-512 hash, not recoverable"
note "  ssh key        ${COPAL_SSH_KEY:-(none)}"
note "  ssh passwords  $COPAL_SSH_PASSWORD_LOGIN"
if [ -n "${COPAL_FLEET:-}" ]; then
note "  fleet          ${COPAL_FLEET} -- card ${COPAL_FLEET_INDEX} of ${COPAL_FLEET_SIZE}, role ${COPAL_FLEET_ROLE}"
note "  fleet tags     ${COPAL_FLEET_TAGS:-(none)}"
note "  fleet discovery ${COPAL_FLEET_DISCOVERY}"
note "  fleet screen    ${COPAL_FLEET_REMOTE:-auto}, ${COPAL_FLEET_REMOTE_MINUTES:-30} minutes"
note "  fleet CA       ${COPAL_FLEET_CA:-(none -- weaker; see docs/fleet-plan.md)}"
note "  enrolment      a fresh single-use token for this card"
fi
note ""
note "The next 'make alldebug' builds images that install without stopping."
}

# --- --node N: card N of the fleet, without an interview --------------------
#
# The seven cards after the first. Everything stays as it is except the three
# things that MUST differ per card -- the index, the hostname derived from it,
# and a fresh single-use enrolment token -- and nothing is asked, so this can
# be run from a loop while cards are swapped.
if [ -n "$NODE" ]; then
    [ -f "$ANSWERS" ] || die "no answers.txt yet. Run 'make answers' first."
    [ -n "${COPAL_FLEET:-}" ] \
        || die "answers.txt has no fleet. Run 'make answers' and name one."
    [ -n "${COPAL_FLEET_SIZE:-}" ] && [ "$NODE" -le "$COPAL_FLEET_SIZE" ] \
        || die "card $NODE of a fleet of ${COPAL_FLEET_SIZE:-?}"
    COPAL_FLEET_INDEX="$NODE"
    COPAL_HOSTNAME=$(fleet_hostname "$COPAL_FLEET" "$NODE")
    COPAL_FLEET_TOKEN=$(rand_hex 16)
    # The role drops back to 'node' rather than being carried, because there is
    # one warden and it was almost certainly card 1. Carrying it would give a
    # fleet of eight machines that all prefer to be warden -- survivable, since
    # the election sorts it out in two announcement intervals, but it is a
    # confusing thing to read in a console and it is not what anybody meant.
    # --role says otherwise. Tags DO carry, because they usually describe the
    # fleet rather than the board; --tags is how the one with the dongle differs.
    COPAL_FLEET_ROLE="${ROLE_ARG:-node}"
    [ "$TAGS_SET" = 1 ] && COPAL_FLEET_TAGS="$TAGS_ARG"
    write_answers
    info "Card $NODE of $COPAL_FLEET_SIZE: $COPAL_HOSTNAME, role $COPAL_FLEET_ROLE, new enrolment token"
    note "tags: ${COPAL_FLEET_TAGS:-(none)}"
    note "Everything else is unchanged. Build the card, then --node $((NODE + 1))."
    exit 0
fi

# The hostname pool -- 300 oceans, seas, lakes and rivers -- lives in
# copal-prep.sh, and is LIFTED from there rather than copied. Two copies of a
# 300-word list is two lists that drift, and the reason the pool exists at all
# is that a fixed default stops being unique the moment there is a second
# machine on the network. Sourcing copal-prep.sh outright is not an option: it
# would run a disk-writing script to ask a question. So the two functions are
# cut out by name and evaluated on their own.
#
# If that extraction ever fails -- the functions renamed, copal-prep.sh moved
# -- the fallback is a fixed name and a note saying so, not a broken prompt.
PREP="$ROOT/copal-prep.sh"
if [ -r "$PREP" ] \
   && _pool=$(sed -n '/^hostname_pool() {/,/^}/p;/^random_hostname() {/,/^}/p' "$PREP") \
   && [ -n "$_pool" ]; then
    eval "$_pool"
else
    random_hostname() { printf 'copal\n'; }
    note "could not read the hostname pool from copal-prep.sh -- using 'copal'"
fi

ask() {  # <prompt> <default> <variable name>
    local _p="$1" _d="$2" _v="$3" _r=""
    if [ -n "$_d" ]; then
        printf '  %s [%s]: ' "$_p" "$_d" >&2
    else
        printf '  %s: ' "$_p" >&2
    fi
    IFS= read -r _r || true
    [ -n "$_r" ] || _r="$_d"
    printf -v "$_v" '%s' "$_r"
}

printf '\n\033[1mCopal -- answers for an unattended install\033[0m\n\n'
note "Anything answered here stops being a question during the install."
note "Enter alone keeps the value in brackets."
note "The hostname offered is picked at random from 300 oceans, seas, lakes"
note "and rivers -- a fixed name stops being unique at the second machine."
note "Once answers.txt exists its own hostname is the default, not a new one."
printf '\n'

# Identity. The git config on this Mac is the best guess available, offered
# HERE, at a prompt, where it is seen and confirmed. copal-prep.sh itself no
# longer reads it: with no answers file, stage 1 asks on the target instead.
_def_name="${COPAL_GIT_NAME:-$(git config --global --get user.name 2>/dev/null || true)}"
_def_email="${COPAL_GIT_EMAIL:-$(git config --global --get user.email 2>/dev/null || true)}"
ask "Name for git commits"   "$_def_name"                 COPAL_GIT_NAME
ask "Email for git commits"  "$_def_email"                COPAL_GIT_EMAIL
ask "Login name in the guest" "${COPAL_USER:-user}"       COPAL_USER
# Mail, optional. With these four, stage 12 writes the account into
# Thunderbird and Claws Mail before their first start, so neither opens its
# account wizard. Enter on the address skips the lot; the password is never
# asked here -- the client asks once, on first connection, and keeps it.
ask "Mail address for Thunderbird/Claws (Enter: none)" "${COPAL_MAIL_ADDRESS:-}" COPAL_MAIL_ADDRESS
if [ -n "$COPAL_MAIL_ADDRESS" ]; then
    _dom="${COPAL_MAIL_ADDRESS#*@}"
    ask "  Name shown on mail"  "${COPAL_MAIL_NAME:-$COPAL_GIT_NAME}"  COPAL_MAIL_NAME
    ask "  IMAP server"         "${COPAL_MAIL_IMAP:-imap.$_dom}"       COPAL_MAIL_IMAP
    ask "  SMTP server"         "${COPAL_MAIL_SMTP:-smtp.$_dom}"       COPAL_MAIL_SMTP
else
    COPAL_MAIL_NAME=""; COPAL_MAIL_IMAP=""; COPAL_MAIL_SMTP=""
fi
# --- the fleet -------------------------------------------------------------
#
# Asked before the hostname, because a fleet NAMES the hostname: card 3 of the
# fleet 'museum' is 'museum-03' and there is nothing to pick. Answer nothing
# here and the next question is the ordinary random-ocean one, which is what
# every build up to now has had.
printf '\n'
note "A FLEET is a named set of Copal machines on one LAN that trust"
note "one certificate authority, find each other, and answer one console."
note "Empty means a standalone machine -- everything below is then skipped."
ask "Fleet name (Enter: none)" "${COPAL_FLEET:-}" COPAL_FLEET

# A fleet name becomes a hostname, an mDNS label and an SSH principal, so it
# has to survive all three. Lowercase letters, digits and dashes; that is the
# intersection, and rejecting the rest here is cheaper than debugging a name
# that resolves on one machine and not on another.
if [ -n "$COPAL_FLEET" ]; then
    case "$COPAL_FLEET" in
        *[!a-z0-9-]*|-*|*-|'')
            die "fleet name must be lowercase letters, digits and inner dashes" ;;
    esac
    [ "${#COPAL_FLEET}" -le 24 ] \
        || die "fleet name is too long -- it has to leave room for '-08'"
fi

if [ -n "$COPAL_FLEET" ]; then
    ask "  How many machines in the fleet" "${COPAL_FLEET_SIZE:-8}" COPAL_FLEET_SIZE
    ask "  Which one is THIS card"         "${COPAL_FLEET_INDEX:-1}" COPAL_FLEET_INDEX
    case "$COPAL_FLEET_SIZE$COPAL_FLEET_INDEX" in
        *[!0-9]*) die "the size and the index are numbers" ;;
    esac
    [ "$COPAL_FLEET_INDEX" -ge 1 ] || die "cards count from 1"
    [ "$COPAL_FLEET_INDEX" -le "$COPAL_FLEET_SIZE" ] \
        || die "card $COPAL_FLEET_INDEX of a fleet of $COPAL_FLEET_SIZE"

    # The role is a STARTING role, not a fixed one. Any node can end up warden:
    # the election in docs/fleet-plan.md scores hardware and uptime and the
    # answer here only decides what the machine tries to be on its first boot.
    note ""
    note "  node    an ordinary member -- the right answer for all eight"
    note "  warden  prefers to be the rendezvous and log sink at first boot"
    note "  console runs the operator's console as well as being a node"
    ask "  Role (node | warden | console)" "${COPAL_FLEET_ROLE:-node}" COPAL_FLEET_ROLE
    case "$COPAL_FLEET_ROLE" in
        node|warden|console) ;;
        *) die "role must be node, warden or console" ;;
    esac

    ask "  Tags, comma separated (Enter: none)" "${COPAL_FLEET_TAGS:-}" COPAL_FLEET_TAGS

    note ""
    note "  mdns    announce on the LAN and be found -- avahi is installed"
    note "  static  no announcing; the console reads a list of addresses"
    note "  off     no discovery of any kind"
    ask "  Discovery (mdns | static | off)" "${COPAL_FLEET_DISCOVERY:-mdns}" COPAL_FLEET_DISCOVERY
    case "$COPAL_FLEET_DISCOVERY" in
        mdns|static|off) ;;
        *) die "discovery must be mdns, static or off" ;;
    esac

    # THE SCREEN. This is the one answer that decides whether a certificate
    # holder can ever put this machine's display on the network, so it is asked
    # rather than defaulted quietly, and 'off' is a real answer for a node in a
    # public space.
    note ""
    note "  auto  the console may ask this node for its screen, briefly"
    note "  off   this node is never viewable, and refuses on the node itself"
    ask "  Screen (auto | off)" "${COPAL_FLEET_REMOTE:-auto}" COPAL_FLEET_REMOTE
    case "$COPAL_FLEET_REMOTE" in
        auto|off) ;;
        *) die "the screen setting must be auto or off" ;;
    esac
    ask "  Minutes before the screen stops itself (0 = until stopped)" \
        "${COPAL_FLEET_REMOTE_MINUTES:-30}" COPAL_FLEET_REMOTE_MINUTES
    case "$COPAL_FLEET_REMOTE_MINUTES" in
        ''|*[!0-9]*) die "the screen deadline is a number of minutes" ;;
    esac

    # THE CERTIFICATE AUTHORITY, and the only part of this that is a secret
    # worth anything. The PUBLIC half travels on every card and is what lets a
    # node verify the console and the console verify the node. The PRIVATE half
    # stays on this Mac in ~/.copal/ca and must never be written to a card --
    # a CA private key on an SD card in a museum is the fleet's whole security
    # sitting in a slot anyone can pull.
    _cadir="$HOME/.copal/ca"
    _ca="${COPAL_FLEET_CA:-$_cadir/${COPAL_FLEET}_ca.pub}"
    if [ ! -f "$_ca" ]; then
        note ""
        note "No certificate authority for fleet '$COPAL_FLEET' yet."
        note "It signs host certificates (so no machine is ever trusted on"
        note "first sight) and 8-hour user certificates (so a stolen one"
        note "expires by itself). The private half never leaves this Mac."
        printf '  Create one now? [Y/n]: ' >&2
        IFS= read -r _mkca || true
        case "${_mkca:-y}" in
            [Nn]*) note "No CA. The fleet falls back to plain keys -- weaker."; _ca="" ;;
            *)
                mkdir -p "$_cadir" && chmod 700 "$_cadir"
                if ssh-keygen -t ed25519 -a 100 -C "copal fleet CA $COPAL_FLEET" \
                              -f "$_cadir/${COPAL_FLEET}_ca"; then
                    _ca="$_cadir/${COPAL_FLEET}_ca.pub"
                    info "Created $_ca"
                    note "Back up $_cadir/${COPAL_FLEET}_ca. Losing it means"
                    note "re-enrolling every machine in the fleet by hand."
                else
                    warn "ssh-keygen did not complete -- continuing without a CA"
                    _ca=""
                fi ;;
        esac
    fi
    # The same check the login key gets, for the same reason: what goes on a
    # card must be the .pub half and nothing else.
    if [ -n "$_ca" ]; then
        if ! grep -qE '^(ssh-(ed25519|rsa)|ecdsa-sha2-)' "$_ca" 2>/dev/null; then
            warn "$_ca is not an OpenSSH public key -- ignoring it"
            note "Never put a CA private key here. Only the .pub half travels."
            _ca=""
        fi
    fi
    COPAL_FLEET_CA="$_ca"

    # The pre-shared key is a SPAM FILTER on the beacon, and calling it
    # anything more is a mistake the plan spends a paragraph on: it is on every
    # card, so it identifies a fleet and authenticates nobody. It stops the
    # console's candidate list from filling with whatever else on the segment
    # fancies calling itself 'museum-03'. The CA does the actual deciding.
    [ -n "${COPAL_FLEET_PSK:-}" ] || COPAL_FLEET_PSK=$(rand_hex 16)

    # The enrolment token is per CARD and single use. Regenerated here every
    # time, which is why --node is safe to run seven times: card 4 cannot enrol
    # as card 3, and a card that goes missing enrols zero further times.
    COPAL_FLEET_TOKEN=$(rand_hex 16)

    COPAL_HOSTNAME=$(fleet_hostname "$COPAL_FLEET" "$COPAL_FLEET_INDEX")
    info "This card is $COPAL_HOSTNAME -- card $COPAL_FLEET_INDEX of $COPAL_FLEET_SIZE"
    note "Build this card, then: make answers-node N=2   -- and so on to $COPAL_FLEET_SIZE."
else
    COPAL_FLEET_SIZE=""; COPAL_FLEET_INDEX=""; COPAL_FLEET_ROLE=""
    COPAL_FLEET_TAGS=""; COPAL_FLEET_DISCOVERY=""; COPAL_FLEET_CA=""
    COPAL_FLEET_PSK="";  COPAL_FLEET_TOKEN=""
fi

printf '\n'
if [ -n "$COPAL_FLEET" ]; then
    ask "Hostname"           "$COPAL_HOSTNAME"                       COPAL_HOSTNAME
else
    ask "Hostname"           "${COPAL_HOSTNAME:-$(random_hostname)}" COPAL_HOSTNAME
fi
ask "Timezone"               "${COPAL_TIMEZONE:-US/Pacific}" COPAL_TIMEZONE
ask "Keymap"                 "${COPAL_KEYMAP:-us us}"     COPAL_KEYMAP

# The checkouts. Not one question but a list, so it is a loop rather than an
# `ask` -- and the whole thing is optional: stage 1 asks again on the machine
# and Enter here simply means "I will decide there".
#
# What this buys is the same thing the password hash buys. Answered here, an
# unattended install ends with the repositories already cloned into ~/code and
# nothing having stopped to ask; left empty, stage 1 stops for it.
printf '\n'
note "Repositories to check out into ~/code on the machine. Cloned by stage 7,"
note "while the install still has a network. Enter alone finishes the list;"
note "Enter at the first prompt leaves it to be asked during the install."
note "https URLs work as-is -- an ssh URL needs a key the GUEST holds."
if [ -n "${COPAL_GIT_REPOS:-}" ]; then
    note ""
    note "Already on file:"
    for _r in ${COPAL_GIT_REPOS}; do note "  $_r"; done
    printf '  Keep them? [Y/n]: ' >&2
    IFS= read -r _keep || true
    case "${_keep:-y}" in [Nn]*) COPAL_GIT_REPOS="" ;; esac
fi
while :; do
    printf '  Repository URL [Enter when done]: ' >&2
    IFS= read -r _r || true
    [ -n "$_r" ] || break
    # A URL with a space in it would become two list entries the moment
    # copal-prep.sh word-splits this, so it is refused here rather than
    # silently mangled on the card.
    case "$_r" in
        *[[:space:]]*) printf '\033[33m  A git URL cannot contain a space.\033[0m\n' >&2; continue ;;
    esac
    case " ${COPAL_GIT_REPOS:-} " in
        *" $_r "*) note "  already listed"; continue ;;
    esac
    COPAL_GIT_REPOS="${COPAL_GIT_REPOS:+$COPAL_GIT_REPOS }$_r"
done

# The password. Read twice with echo off, never written anywhere in the clear,
# and never passed as an argument -- an argument is visible in ps to every
# process on the machine, so it goes to the hasher on stdin.
printf '\n'
note "Root password. Also becomes '$COPAL_USER's, as it does today."
if [ -n "${COPAL_ROOT_PW_HASH:-}" ]; then
    note "A password is already on file. Enter alone keeps it; type a new one"
    note "to replace it. There is no way to display the old one."
else
    note "Enter alone sets it to 'hunter2', a joke password. It is here so that"
    note "automated testing has one it knows -- not because this is a toy."
    note ""
    note "This guest runs sshd, shares this password with '$COPAL_USER', has its"
    note "own address on your network, a full toolchain, and can serve. Root over"
    note "SSH is always refused and an installed key turns password login off --"
    note "but a build without a key leaves '$COPAL_USER' plus this password as a"
    note "working remote login. Type a real one unless you are throwing this"
    note "machine away today."
fi
# What Enter alone does depends on whether a password is already on file, so
# the prompt says which -- on the line being typed at, not three lines above
# it where it scrolls out of view behind the notes.
if [ -n "${COPAL_ROOT_PW_HASH:-}" ]; then
    _pw_hint="Enter = keep current"
else
    _pw_hint="Enter = hunter2"
fi
_pw="" _pw2=""
while :; do
    printf '  Password [%s] (not echoed): ' "$_pw_hint" >&2
    IFS= read -rs _pw || true; printf '\n' >&2
    if [ -z "$_pw" ]; then
        if [ -n "${COPAL_ROOT_PW_HASH:-}" ]; then
            info "Keeping the password already in answers.txt."
            _pw=""
            break
        fi
        _pw="hunter2"
        info "Using the default: hunter2"
        break
    fi
    printf '  Again: ' >&2
    IFS= read -rs _pw2 || true; printf '\n' >&2
    [ "$_pw" = "$_pw2" ] && break
    printf '\033[33m  They did not match. Again.\033[0m\n' >&2
done

# Whether the password just chosen is the default one. Known HERE and nowhere
# else: the hash is salted, so two builds with 'hunter2' produce different
# strings and nothing downstream can compare them. The answer is recorded
# rather than re-derived.
_is_default_pw=0
[ "$_pw" = hunter2 ] && _is_default_pw=1

if [ -n "$_pw" ]; then
    COPAL_ROOT_PW_HASH=$(printf '%s\n' "$_pw" | python3 "$CRYPT" --rounds 656000)
    _pw="" _pw2=""
fi
[ -n "${COPAL_ROOT_PW_HASH:-}" ] || die "no password hash produced"

# --- the key, and whether passwords are allowed over the network -----------
#
# A key is what makes any of this safe, so this does not merely ask whether one
# exists -- it offers to make one and then uses it. copal-prep.sh already
# copies the named key onto the card and stage 1 installs it for the login
# user, so naming it here is the whole of the wiring.
printf '\n'
_key=""
for _k in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_rsa.pub"; do
    [ -f "$_k" ] && { _key="$_k"; break; }
done
[ -n "${COPAL_SSH_KEY:-}" ] && [ -f "${COPAL_SSH_KEY}" ] && _key="$COPAL_SSH_KEY"

if [ -n "$_key" ]; then
    note "SSH key found: $(awk '{print $1, $NF}' "$_key" 2>/dev/null)"
    ask "Public key to authorise" "$_key" _key
else
    note "No SSH key on this Mac. Without one, reaching the guest over the"
    note "network means password login -- the thing worth avoiding."
    printf '  Create an ed25519 key now? [Y/n]: ' >&2
    IFS= read -r _mk || true
    case "${_mk:-y}" in
        [Nn]*) note "No key. Password login stays on; ssh-keygen later closes that." ;;
        *)
            # ssh-keygen's own prompts, not reimplemented ones: it asks for a
            # passphrase and confirms it, and an unencrypted private key must
            # be the user's explicit choice rather than this script's silent
            # default. -a 100 is the KDF work factor for the encrypted form.
            note "ssh-keygen will ask for a passphrase. An empty one means the"
            note "private key is usable by anything that can read the file."
            if ssh-keygen -t ed25519 -a 100 -C "copal $(id -un)@$(hostname -s)" \
                          -f "$HOME/.ssh/id_ed25519"; then
                _key="$HOME/.ssh/id_ed25519.pub"
                info "Created $_key"
            else
                warn "ssh-keygen did not complete -- continuing without a key"
                _key=""
            fi ;;
    esac
fi

# Validate what we ended up with rather than trusting the path.
if [ -n "$_key" ]; then
    if [ ! -f "$_key" ]; then
        warn "no such key file: $_key -- continuing without one"; _key=""
    elif ! grep -qE '^(ssh-(ed25519|rsa)|ecdsa-sha2-|sk-)' "$_key"; then
        warn "$_key does not look like an OpenSSH PUBLIC key -- ignoring it"
        note "It should be the .pub half. Never put a private key here."
        _key=""
    fi
fi
COPAL_SSH_KEY="$_key"

# THE RULE, and the point of this whole section:
#
#   default password        -> password login over SSH OFF, always. A password
#                              written down in the repository is not a
#                              credential, and leaving it reachable over the
#                              network is the failure being prevented.
#   custom password + key   -> OFF as well. The key works and is better.
#   custom password, no key -> ON, because otherwise there is no way in at all.
if [ "$_is_default_pw" = 1 ]; then
    COPAL_SSH_PASSWORD_LOGIN=no
    note ""
    note "Default password in use -- SSH password login will be DISABLED."
    if [ -n "$COPAL_SSH_KEY" ]; then
        note "Your key is what gets you in over the network."
    else
        note "With no key either, SSH will refuse every login. The console"
        note "still works, and 'doas copal-ssh password on' undoes it there."
    fi
elif [ -n "$COPAL_SSH_KEY" ]; then
    COPAL_SSH_PASSWORD_LOGIN=no
    note ""
    note "Key set and a real password chosen -- SSH will accept the key only."
else
    COPAL_SSH_PASSWORD_LOGIN=yes
    note ""
    note "No key, so SSH password login stays ON for '$COPAL_USER'."
    note "Run 'ssh-keygen -t ed25519' and re-run 'make answers' to close that."
fi
note "Change it by hand in answers.txt if that is not what you want."

write_answers
summarise
