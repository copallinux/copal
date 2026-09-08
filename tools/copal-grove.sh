#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
#
#  COPAL GROVE -- the console for a fleet of Copal machines on one LAN.
#
# A GROVE is a named set of Copal machines that trust one certificate
# authority. They announce themselves by mDNS, prove themselves by SSH
# certificate, and answer this program. See docs/grove-plan.md for the design
# and docs/grove-lab-report.md for the interface it is growing into.
#
# THE ONE RULE THIS FILE EXISTS TO ENFORCE: discovery announces, it never
# authorizes. A beacon fills a list. A certificate decides. Every function
# below that reads a beacon produces a CANDIDATE; only cert_state() returns a
# verdict, and only a node that passes it is ever handed a credential.
#
# Usage:
#   copal grove ls                 what is out there, and what it has proved
#   copal grove ca [--create]      the grove certificate authority
#   copal grove trust              teach this machine to trust the grove
#   copal grove login              an 8-hour operator certificate
#   copal grove sign NODE...       sign one node's host key
#   copal grove enrol              sign every candidate with a matching token
#   copal grove run VERB [ARG...]  one verb, fanned out, a result per node
#   copal grove status NODE        one node's facts
#   copal grove inventory          an Ansible inventory, out of discovery
#   copal grove bus                put every enrolled node on the message bus
#   copal grove bus --check        what the warden says the bus is doing
#
# The day, once a grove directory exists (milestone 3):
#   copal grove init               make groves/<name>/ from the template
#   copal grove scene              which scenes this grove has
#   copal grove scene NAME         apply one: wake, show, reset, rest, sleep
#   copal grove power on|off       the machines a console can switch (see 9.1)
#   copal grove wait               block until the grove has announced itself
#
# Options most verbs take:
#   --grove NAME   which grove (default: the one named in answers.txt)
#   --via HOST     browse from HOST over ssh instead of browsing here. macOS
#                  has no avahi-browse, so this is how a Mac sees the grove:
#                  it asks a node that can already see it. The Mac is the
#                  certificate authority, not the eyes.
#   --tag TAG      only nodes carrying that tag
#   --node ID      only that node
#   --user NAME    the login account on the nodes (default: from answers.txt)
#   --all          with ls, also list strangers -- machines on this network
#                  that are not in the grove
#   --json         with inventory, JSON for Ansible instead of an INI file
#   --check        with scene, ansible's dry run: report, change nothing
#   --pass         with scene, ask for the doas password once and reuse it
#   --timeout N    with wait, how long to wait for beacons (default 120s)
set -eu

B='\033[1m'; D='\033[2m'; C='\033[36m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; Z='\033[0m'
die()  { printf "${R}error:${Z} %s\n" "$*" >&2; exit 1; }
info() { printf "${C}==>${Z} %s\n" "$*" >&2; }
note() { printf '    %s\n' "$*" >&2; }
warn() { printf "${Y}warning:${Z} %s\n" "$*" >&2; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANSWERS="${COPAL_ANSWERS:-$ROOT/answers.txt}"
HOME_COPAL="${COPAL_HOME:-$HOME/.copal}"
NKEYS="$ROOT/tools/copal_nkeys.py"
SERVICE="_copal-grove._tcp"
TAB=$(printf '\t')

TMP="${TMPDIR:-/tmp}/copal-grove.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT INT TERM

# Parsed, never sourced. answers.txt holds a crypt hash beginning with a dollar
# sign and a digit; sourcing it under `set -u` ends the program on that line.
# Same reader as tools/copal-answers.sh, for the same reason.
answer() {  # <key>
    [ -f "$ANSWERS" ] || return 0
    sed -n "s/^$1=[\"']\{0,1\}\(.*\)/\1/p" "$ANSWERS" \
        | sed "s/[\"']\{0,1\}[[:space:]]*$//" | head -1
}

GROVE=""; VIA=""; TAG=""; ONLY=""; LOGIN_USER=""; HOURS=8; SHOW_ALL=0; CREATE=0
JSON=0; CHECK=0; ASKPASS=0; TIMEOUT=120
SHIFTN=0

# Sets SHIFTN and returns 0 when it consumed the argument, 1 when it did not.
# A status code carrying a count was tried and is the wrong shape: `cmd && a ||
# case $?` loses the code the moment anything runs between them.
take_common() {
    SHIFTN=1
    case "$1" in
        --grove)   GROVE="${2:?--grove needs a name}"; SHIFTN=2 ;;
        --grove=*) GROVE="${1#*=}" ;;
        --via)     VIA="${2:?--via needs a host}"; SHIFTN=2 ;;
        --via=*)   VIA="${1#*=}" ;;
        --tag)     TAG="${2:?--tag needs a tag}"; SHIFTN=2 ;;
        --tag=*)   TAG="${1#*=}" ;;
        --node)    ONLY="${2:?--node needs an id}"; SHIFTN=2 ;;
        --node=*)  ONLY="${1#*=}" ;;
        --user)    LOGIN_USER="${2:?--user needs a name}"; SHIFTN=2 ;;
        --user=*)  LOGIN_USER="${1#*=}" ;;
        --hours)   HOURS="${2:?--hours needs a number}"; SHIFTN=2 ;;
        --hours=*) HOURS="${1#*=}" ;;
        --all)     SHOW_ALL=1 ;;
        --create)  CREATE=1 ;;
        --json)    JSON=1 ;;
        --check)   CHECK=1 ;;
        --pass|--ask-become-pass) ASKPASS=1 ;;
        --timeout)   TIMEOUT="${2:?--timeout needs seconds}"; SHIFTN=2 ;;
        --timeout=*) TIMEOUT="${1#*=}" ;;
        *) return 1 ;;
    esac
    return 0
}

settle() {
    [ -n "$GROVE" ] || GROVE=$(answer COPAL_GROVE)
    [ -n "$GROVE" ] || die "no grove named. Run 'make answers', or pass --grove NAME."
    GDIR="$HOME_COPAL/groves/$GROVE"
    CADIR="$HOME_COPAL/ca"
    CA="$CADIR/${GROVE}_ca"
    CAPUB="$CA.pub"
    TOKENS="$GDIR/tokens"
    NODES_FILE="$GDIR/nodes"
    OPKEY="$GDIR/operator"
    mkdir -p "$GDIR/hosts"
    chmod 700 "$HOME_COPAL" "$HOME_COPAL/groves" "$GDIR" 2>/dev/null || true
    [ -n "$VIA" ] || VIA=$(conf_get via)
    [ -n "$LOGIN_USER" ] || LOGIN_USER=$(conf_get user)
    [ -n "$LOGIN_USER" ] || LOGIN_USER=$(answer COPAL_USER)
    [ -n "$LOGIN_USER" ] || LOGIN_USER=user
    PSK=$(answer COPAL_GROVE_PSK)
    # TWO DIRECTORIES, and the split is invariant 7 rather than tidiness.
    # GDIR is ~/.copal/groves/<name>: private state -- the operator key, the
    # token ledger, host keys. SDIR is groves/<name> in a git checkout: the
    # scenes and the roles, which are what actually gets executed on eight
    # machines and therefore have to be reviewable, committed and signed. The
    # grove executes what the repository says, not what the network says, and
    # a scene living in a dotfile directory nobody diffs is how that stops
    # being true.
    SDIR="${COPAL_GROVE_DIR:-$ROOT/groves/$GROVE}"
}
conf_get() {  # <key> -- from ~/.copal/groves/<grove>/grove.conf
    [ -f "$GDIR/grove.conf" ] || return 0
    sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$GDIR/grove.conf" | head -1
}

# --------------------------------------------------------------- beacons ---
#
# One beacon per line:   id <TAB> address <TAB> k=v;k=v;...
#
# Browsed ONCE per invocation and cached, because cert checking already costs a
# round trip per node and a verb that browses three times is a verb that takes
# three times as long to say nothing new.
#
# Four sources, in this order, and the order is the whole portability story:
#
#   COPAL_GROVE_BEACONS   a file of beacon lines. Testing, and a browse
#                         captured somewhere else.
#   avahi-browse          this machine can see the segment. Linux, Alpine, and
#                         a console running ON a node.
#   --via HOST            ask a node to browse for us. The macOS path.
#   nodes file            a written-down list, for discovery=static.
beacons() {
    [ -f "$TMP/beacons" ] || browse > "$TMP/beacons"
    cat "$TMP/beacons"
}
browse() {
    if [ -n "${COPAL_GROVE_BEACONS:-}" ]; then
        [ -f "$COPAL_GROVE_BEACONS" ] || die "no such beacon file: $COPAL_GROVE_BEACONS"
        cat "$COPAL_GROVE_BEACONS"; return 0
    fi
    if [ -n "$VIA" ]; then
        ssh -n -o BatchMode=yes -o ConnectTimeout=8 "$VIA" 'copal-grove browse' 2>/dev/null \
            || die "could not browse via $VIA -- is it up, and does it have copal-grove?"
        return 0
    fi
    if command -v avahi-browse >/dev/null 2>&1; then
        # -rpt: resolve, parse-friendly, terminate. An '=' record is a resolved
        # service; field 8 is the address and field 10 the TXT records, quoted
        # and space separated.
        avahi-browse -rpt "$SERVICE" 2>/dev/null | awk -F';' '
            $1 == "=" {
                addr = $8; txt = $10
                gsub(/"/, "", txt); gsub(/ +/, ";", txt)
                id = $4
                n = split(txt, kv, ";")
                for (i = 1; i <= n; i++) if (kv[i] ~ /^n=/) id = substr(kv[i], 3)
                print id "\t" addr "\t" txt
            }' | sort -u
        return 0
    fi
    if [ -f "$NODES_FILE" ]; then
        # A static list carries no TXT record, so it claims nothing -- which is
        # correct. Everything about these nodes has to be proved rather than
        # read, and cert_state below is what proves it.
        sed 's/#.*//' "$NODES_FILE" \
            | awk -v g="$GROVE" 'NF >= 2 { print $1 "\t" $2 "\t" "g=" g }'
        return 0
    fi
    die "nothing to browse with. Install avahi-utils, pass --via HOST, or write $NODES_FILE"
}

txt_get() {  # <txt blob> <key>
    printf '%s' "$1" | tr ';' '\n' | sed -n "s/^$2=//p" | head -1
}

# The rolling HMAC in the beacon. A SPAM FILTER, and the comment sits here
# because this is where somebody is most likely to be tempted: the key is on
# every card in the grove, so it identifies a grove and authenticates nobody.
# Its whole job is to keep the list from filling with anything on the segment
# that fancies calling itself museum-03.
beacon_hmac_ok() {  # <id> <claimed> -- 0 ok, 1 bad, 2 cannot say
    [ -n "$PSK" ] || return 2
    [ -n "$2" ] || return 2
    command -v openssl >/dev/null 2>&1 || return 2
    _now=$(date +%s)
    # Two windows, because a beacon written at 09:04:59 is read at 09:05:01 and
    # a clock that is a second out must not make a node look like a forgery.
    for _slip in 0 1; do
        _w=$(( (_now / 300) - _slip ))
        _want=$(printf '%s' "$1$GROVE$_w" \
            | openssl dgst -sha256 -hmac "$PSK" -r 2>/dev/null | cut -c1-16)
        [ "$_want" = "$2" ] && return 0
    done
    return 1
}

# --------------------------------------------------------- the verdict -----
#
# The only function here that decides anything. It asks the node for its host
# certificate WITHOUT LOGGING IN -- ssh-keyscan -c fetches whatever certificate
# sshd offers -- and checks the signing CA against ours by fingerprint. There
# is no trust-on-first-use anywhere in it.
ca_fingerprint() {
    [ -f "$CAPUB" ] || return 1
    ssh-keygen -l -f "$CAPUB" 2>/dev/null | awk '{ print $2 }'
}
cert_state() {  # <address> -> enrolled | candidate | foreign | unreachable | no-ca
    _addr="$1"
    _c="$TMP/scan.$(printf '%s' "$_addr" | tr -c 'A-Za-z0-9' '_')"
    # </dev/null on every one of these, and it is load-bearing rather than
    # tidy: ssh-keyscan reads hosts from stdin when it runs out of arguments,
    # each of these runs INSIDE a `while read` loop over the beacon list, and
    # without the redirect the first node swallows the rest of the list. The
    # symptom is a wall that shows one machine out of eight, which is how this
    # was found.
    [ -f "$_c" ] || ssh-keyscan -c -T 5 -t ed25519 "$_addr" > "$_c" 2>/dev/null </dev/null || true
    _p="$_c.plain"
    [ -f "$_p" ] || ssh-keyscan -T 5 "$_addr" > "$_p" 2>/dev/null </dev/null || true

    _fp=$(ca_fingerprint) || { printf 'no-ca\n'; return 0; }
    if ! grep -q 'cert-v01' "$_c" 2>/dev/null; then
        if grep -q 'ssh-' "$_p" 2>/dev/null; then printf 'candidate\n'; else printf 'unreachable\n'; fi
        return 0
    fi
    # ssh-keygen -L wants a file, and the keyscan line has the host in front of
    # the key, so the key half is cut out into one.
    awk '/cert-v01/ { $1 = ""; sub(/^ /, ""); print; exit }' "$_c" > "$_c.key"
    _signer=$(ssh-keygen -L -f "$_c.key" 2>/dev/null \
        | sed -n 's/.*Signing CA: [^ ]* \(SHA256:[A-Za-z0-9+/=]*\).*/\1/p' | head -1)
    if [ -n "$_signer" ] && [ "$_signer" = "$_fp" ]; then printf 'enrolled\n'; else printf 'foreign\n'; fi
}

# Beacons for this grove only, after --tag and --node, as id<TAB>addr<TAB>txt.
selected() {
    beacons | while IFS="$TAB" read -r _id _addr _txt; do
        [ -n "$_id" ] || continue
        _g=$(txt_get "$_txt" g)
        [ -z "$_g" ] || [ "$_g" = "$GROVE" ] || continue
        [ -z "$ONLY" ] || [ "$ONLY" = "$_id" ] || continue
        if [ -n "$TAG" ]; then
            case ",$(txt_get "$_txt" t)," in *",$TAG,"*) : ;; *) continue ;; esac
        fi
        printf '%s\t%s\t%s\n' "$_id" "$_addr" "$_txt"
    done
}

# --------------------------------------------------------------- ls --------
cmd_ls() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for ls"
        shift "$SHIFTN"
    done
    settle
    if [ -f "$CAPUB" ]; then _cah="CA $(ca_fingerprint)"
    else _cah="${R}no certificate authority${Z} -- copal grove ca --create"; fi
    printf "\n${B}Grove ${C}%s${Z}${B}${Z}  ${D}%b${Z}\n\n" "$GROVE" "$_cah"
    printf "        %-14s %-16s %-8s %-18s %s\n" "NODE" "ADDRESS" "ROLE" "PROVED" "SEEN"
    selected | while IFS="$TAB" read -r _id _addr _txt; do
        _role=$(txt_get "$_txt" r); [ -n "$_role" ] || _role="?"
        _h=0; beacon_hmac_ok "$_id" "$(txt_get "$_txt" k)" || _h=$?
        case "$(cert_state "$_addr")" in
            enrolled)  _m="${G}✓${Z}"; _w="cert ok" ;;
            candidate) _m="${Y}?${Z}"; _w="not enrolled" ;;
            foreign)   _m="${R}✗${Z}"; _w="ANOTHER CA" ;;
            no-ca)     _m="${Y}?${Z}"; _w="no CA on this machine" ;;
            *)         _m="${D}·${Z}"; _w="unreachable" ;;
        esac
        [ "$_h" = 1 ] && _w="$_w, BAD BEACON"
        _up=$(txt_get "$_txt" u); [ -n "$_up" ] || _up="-"
        printf "    %b   %-14s %-16s %-8s %-18s %s\n" "$_m" "$_id" "$_addr" "$_role" "$_w" "$_up"
    done
    printf '\n'
    [ "$SHOW_ALL" = 1 ] && strangers
    printf "    ${D}✓ proved by certificate    ? found, not yet enrolled    ✗ another CA${Z}\n"
    printf "    ${D}A beacon fills this list. A certificate is what decides.${Z}\n\n"
}

# Machines on this network that are NOT in the grove. Shown, never contacted.
# The security value and the interface value are the same thing: an operator
# who can see what appeared on the gallery network today is better off than one
# who cannot, and it costs one extra browse.
strangers() {
    if ! command -v avahi-browse >/dev/null 2>&1; then
        note "strangers need avahi-browse on this machine"; return 0
    fi
    beacons | cut -f2 | sort -u > "$TMP/mine"
    printf "    ${Y}Strangers${Z} ${D}-- on this network, not in the grove${Z}\n"
    avahi-browse -apt 2>/dev/null | awk -F';' '$1 == "=" { print $8 "\t" $4 }' \
        | sort -u | while IFS="$TAB" read -r _a _nm; do
            [ -n "$_a" ] || continue
            grep -qxF "$_a" "$TMP/mine" && continue
            printf "    ${D}!${Z}   %-14s %-16s %s\n" "-" "$_a" "$_nm"
        done
    printf '\n'
}

# --------------------------------------------------------------- ca --------
cmd_ca() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for ca"
        shift "$SHIFTN"
    done
    settle
    if [ -f "$CAPUB" ] && [ "$CREATE" = 0 ]; then
        info "Grove '$GROVE' certificate authority"
        note "public   $CAPUB"
        if [ -f "$CA" ]; then note "private  $CA"
        else note "private  NOT ON THIS MACHINE -- it can verify, it cannot sign"; fi
        note "$(ssh-keygen -l -f "$CAPUB" 2>/dev/null)"
        return 0
    fi
    [ -f "$CAPUB" ] && die "a CA already exists at $CAPUB -- delete it deliberately or keep it"
    mkdir -p "$CADIR"; chmod 700 "$CADIR"
    info "Creating the certificate authority for grove '$GROVE'."
    note "The private half never leaves this machine and never goes on a card."
    note "Back it up: losing it means re-enrolling every machine by hand."
    ssh-keygen -t ed25519 -a 100 -C "copal grove CA $GROVE" -f "$CA"
    info "Created $CAPUB"
}

# ------------------------------------------------------------ trust --------
#
# One line in known_hosts for the whole grove, however large it grows. This is
# the payoff of having a CA at all, and it is worth being loud about: after it
# there is no first-connection prompt for any node ever again -- and a host key
# that CHANGES becomes an error this console can explain, rather than a warning
# an operator learns to press through.
cmd_trust() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for trust"
        shift "$SHIFTN"
    done
    settle
    [ -f "$CAPUB" ] || die "no CA. Run: copal grove ca --create"
    _kh="$HOME/.ssh/known_hosts"
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; : >> "$_kh"
    # awk and not `grep -v`, because grep exits 1 when it prints nothing --
    # which is exactly the case where the file held only this line, and the
    # `&&` then skipped the rewrite and left the old line to be duplicated by
    # the append below. Running trust twice produced two lines; awk always
    # exits 0 and always rewrites.
    awk -v g="$GROVE" '!index($0, "copal grove CA " g)' "$_kh" > "$TMP/kh"
    cat "$TMP/kh" > "$_kh"
    # Scoped to the grove's own names and to private address space rather than
    # to '*'. A bare '*' would let this CA vouch for any host this account ever
    # connects to, which is more authority than a museum's eight Raspberry Pis
    # have any business holding.
    printf '@cert-authority %s %s\n' \
        "${GROVE}-*,${GROVE}-*.local,10.*,192.168.*,172.16.*" "$(cat "$CAPUB")" >> "$_kh"
    info "Trusted the grove CA in $_kh"
    note "One line, for every node this grove will ever have."
}

# ------------------------------------------------------------ login --------
#
# An 8-hour operator certificate, on a key that belongs to the grove and to
# nothing else. The operator's own ~/.ssh/id_ed25519 is deliberately NOT
# signed: writing a certificate beside somebody's everyday key changes how that
# key behaves everywhere it is used, and a console should not do that to a
# person in order to reach eight Raspberry Pis.
cmd_login() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for login"
        shift "$SHIFTN"
    done
    settle
    [ -f "$CA" ] || die "no CA private key at $CA -- this machine cannot sign"
    if [ ! -f "$OPKEY" ]; then
        info "Making an operator key for grove '$GROVE'. It is used for nothing else."
        ssh-keygen -q -t ed25519 -N '' -C "copal grove operator $GROVE" -f "$OPKEY"
    fi
    ssh-keygen -q -s "$CA" -I "$(id -un)@$(hostname 2>/dev/null || echo console)" \
        -n grove-operator,grove-human -V "+${HOURS}h" "$OPKEY.pub"
    chmod 600 "$OPKEY"
    info "Operator certificate, valid ${HOURS}h, principals grove-operator and grove-human"
    ssh-keygen -L -f "$OPKEY-cert.pub" 2>/dev/null \
        | sed -n 's/^ *Valid:/    valid:/p' >&2
    if command -v ssh-add >/dev/null 2>&1 && [ -n "${SSH_AUTH_SOCK:-}" ]; then
        ssh-add -t "${HOURS}h" "$OPKEY" >/dev/null 2>&1 \
            && note "added to the agent; it expires by itself"
    fi
}

ssh_as_operator() {  # <host> <command>
    _h="$1"; shift
    ssh -n -o BatchMode=yes -o ConnectTimeout=8 -i "$OPKEY" "copal-grove@$_h" "$@"
}
# The same, but WITHOUT -n, for the two verbs that read stdin. Kept separate
# rather than made an option: -n is what stops ssh-keyscan and `while read`
# loops from eating each other (see cert_state), and the default must stay the
# safe one. Only call this where stdin is a file you opened on purpose.
ssh_as_operator_stdin() {  # <host> <command> -- stdin goes to the far end
    _h="$1"; shift
    ssh -o BatchMode=yes -o ConnectTimeout=8 -i "$OPKEY" "copal-grove@$_h" "$@"
}
ssh_as_login() {  # <host> <command> -- the bootstrap account, before certificates
    _h="$1"; shift
    ssh -n -o BatchMode=yes -o ConnectTimeout=8 "$LOGIN_USER@$_h" "$@"
}

# ------------------------------------------------------------- sign --------
#
# Enrolment. The node's host key is FETCHED, never generated here: it was born
# on the node and stays there, and only the certificate travels.
ledger_token() {  # <id>
    [ -f "$TOKENS" ] || return 0
    awk -F'\t' -v id="$1" '$1 == id && $3 == "unused" { t = $2 } END { print t }' "$TOKENS"
}
ledger_spend() {  # <id>
    [ -f "$TOKENS" ] || return 0
    awk -F'\t' -v OFS='\t' -v id="$1" '$1 == id { $3 = "spent" } { print }' "$TOKENS" \
        > "$TMP/tok" && cat "$TMP/tok" > "$TOKENS" && chmod 600 "$TOKENS"
}

sign_one() {  # <id> <address>
    _id="$1"; _addr="$2"
    [ -f "$CA" ] || die "no CA private key at $CA"
    _hk="$GDIR/hosts/$_id.pub"
    ssh-keyscan -T 8 -t ed25519 "$_addr" 2>/dev/null </dev/null \
        | awk '/ssh-ed25519/ { print $2, $3; exit }' \
        | sed 's/^/ssh-ed25519 /' > "$_hk" || true
    if [ ! -s "$_hk" ]; then warn "$_id: no host key answered at $_addr"; return 1; fi

    # THE TOKEN. Written to card N by `make answers-node N`, recorded in the
    # ledger here, and burned by the node the first time it is signed. A card
    # that goes missing enrols zero further times than the once it was for.
    _want=$(ledger_token "$_id")
    if [ -n "$_want" ]; then
        _have=$(ssh_as_login "$_addr" 'cat /etc/copal/grove/token 2>/dev/null' 2>/dev/null || true)
        if [ -z "$_have" ]; then
            warn "$_id: could not read its enrolment token"
            note "The bootstrap login has to work first: ssh $LOGIN_USER@$_addr"
            return 1
        fi
        if [ "$_have" != "$_want" ]; then
            warn "$_id: its token is not the one written to that card."
            note "This is the check refusing to sign a machine that is not the one"
            note "you made a card for. Nothing was signed."
            return 1
        fi
    else
        warn "$_id: no token on file here -- signing on reachability alone"
    fi

    ssh-keygen -q -s "$CA" -I "$_id" -h -n "$_id,$_id.local,$_addr" -V '+90d' "$_hk" \
        || { warn "$_id: signing failed"; return 1; }
    _cert="$GDIR/hosts/$_id-cert.pub"
    [ -s "$_cert" ] || { warn "$_id: no certificate produced"; return 1; }

    # Installed through the login account with doas, which is the only way in
    # that exists before there is a certificate. This one step needs the
    # operator's own key already on the node -- stage 6 put it there.
    if ! ssh_as_login "$_addr" 'doas /usr/bin/copal-grove install-cert' < "$_cert" >/dev/null 2>&1; then
        warn "$_id: could not install the certificate"
        note "By hand: ssh $LOGIN_USER@$_addr 'doas copal-grove install-cert' < $_cert"
        return 1
    fi
    ledger_spend "$_id"
    printf "    ${G}✓${Z} %-14s signed, valid 90 days\n" "$_id" >&2
    return 0
}

cmd_sign() {
    _want=""
    while [ $# -gt 0 ]; do
        if take_common "$@"; then shift "$SHIFTN"; continue; fi
        case "$1" in
            -*) die "unknown option '$1' for sign" ;;
            *)  _want="$_want $1"; shift ;;
        esac
    done
    settle
    [ -n "$_want" ] || die "which node? copal grove sign museum-03"
    for _id in $_want; do
        _addr=$(beacons | awk -F'\t' -v id="$_id" '$1 == id { print $2; exit }')
        [ -n "$_addr" ] || _addr="$_id"
        sign_one "$_id" "$_addr" || true
    done
}

cmd_enrol() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for enrol"
        shift "$SHIFTN"
    done
    settle
    [ -f "$CA" ] || die "no CA private key at $CA. Run: copal grove ca --create"
    info "Enrolling every candidate in grove '$GROVE'."
    selected > "$TMP/cand"
    _n=0
    while IFS="$TAB" read -r _id _addr _txt; do
        [ "$(cert_state "$_addr")" = candidate ] || continue
        _n=$((_n + 1))
        sign_one "$_id" "$_addr" || true
    done < "$TMP/cand"
    [ "$_n" -gt 0 ] || note "nothing was waiting to be enrolled"

    # A NODE THAT IS ENROLLED BUT NOT ON THE BUS IS A NODE THE WALL CANNOT SEE.
    # Best effort and quiet about it: a grove with no warden announcing is the
    # ordinary state through milestone 3, and enrolment must not start failing
    # because milestone 4 exists.
    if [ "$_n" -gt 0 ] && [ -n "$(warden_of)" ]; then
        note ""
        cmd_bus || warn "enrolled, but not put on the bus -- run: copal grove bus"
    fi
    note "Check with: copal grove ls"
}

# --------------------------------------------------------------- bus -------
#
# Milestone 4, the console's half. The SSH CA stays the grove's identity root
# and this verb does nothing to change that: it talks only to nodes that
# cert_state() already calls `enrolled`, and it asks each of them for a PUBLIC
# key the node generated on itself. Nothing here makes a node's key and nothing
# here ever sees a node's seed -- invariant 2, applied to a second key type.
# See docs/grove-plan.md §6, "How the bus is authenticated".
#
#   1. make this console's own bus identity, once
#   2. ask every enrolled node for its public nkey
#   3. find the warden
#   4. hand the warden the LIST -- and the warden renders the permissions
#
# Step 4 is the one worth defending. The console does not send nats.conf. It
# sends ids and public keys, and the allow-lists of invariant 5 are built on
# the warden from the warden's own idea of the grove's name. A console someone
# has tampered with cannot widen a permission by sending a cleverer file,
# because no file it sends is ever read as configuration.

console_nkey() {  # this console's public nkey, made once and kept
    _s="$CADIR/console.nk"
    if [ ! -s "$_s" ]; then
        mkdir -p "$CADIR"; chmod 700 "$CADIR"
        ( umask 077; python3 "$NKEYS" new-seed user > "$_s" ) \
            || { warn "could not make the console's bus identity"; return 1; }
        chmod 600 "$_s"
        note "made this console's bus identity: $_s"
        note "It sits beside the CA and is backed up with it."
    fi
    python3 "$NKEYS" public "$(cat "$_s")"
}

# The warden, as the beacons report it: role first, then score, because the
# plan's election is a sort and this is the console's half of that sort.
warden_of() {  # id<TAB>addr, or nothing
    selected | while IFS="$TAB" read -r _id _addr _txt; do
        [ "$(txt_get "$_txt" r)" = warden ] || continue
        printf '%s\t%s\t%s\n' "$(txt_get "$_txt" s)" "$_id" "$_addr"
    done | sort -rn | head -1 | cut -f2,3
}

cmd_bus() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for bus"
        shift "$SHIFTN"
    done
    settle
    command -v python3 >/dev/null 2>&1 || die "the bus needs python3 on this machine"
    [ -f "$NKEYS" ] || die "no $NKEYS -- this is not a full checkout"
    [ -f "$OPKEY" ] || die "no operator certificate here. Run: copal grove login"

    _w=$(warden_of)
    if [ -z "$_w" ]; then
        die "no node in grove '$GROVE' is announcing itself as the warden.

    The bus lives on the warden, so there is nowhere to put it. Either no card
    in this grove was given the warden role, or that machine is off. Check with
    'copal grove ls' -- the role column is what this reads."
    fi
    _wid=${_w%%"$TAB"*}; _waddr=${_w#*"$TAB"}

    if [ "$CHECK" = 1 ]; then
        info "The bus, as the warden ($_wid) reports it"
        ssh_as_operator "$_waddr" 'bus state' \
            || die "$_wid did not answer. Is it enrolled, and is the bus installed?"
        return 0
    fi

    info "Collecting bus identities in grove '$GROVE'."
    note "A node makes its key the first time it is asked, and keeps it after."
    : > "$TMP/members"
    _n=0; _skip=0
    selected > "$TMP/buscand"
    while IFS="$TAB" read -r _id _addr _txt; do
        [ -n "$_id" ] || continue
        if [ "$(cert_state "$_addr")" != enrolled ]; then
            _skip=$((_skip + 1))
            continue
        fi
        _k=$(ssh_as_operator "$_addr" 'bus key' 2>/dev/null | tr -d '\r' | head -1)
        case "$_k" in
            U?*) printf '%s %s node\n' "$_id" "$_k" >> "$TMP/members"
                 _n=$((_n + 1))
                 printf "    ${G}✓${Z} %-14s %s\n" "$_id" "$_k" >&2 ;;
            *)   warn "$_id: no bus key -- it answered '${_k:-nothing}'"
                 note "That node may predate milestone 4. Re-run stage 16 on it." ;;
        esac
    done < "$TMP/buscand"

    [ "$_n" -gt 0 ] || die "not one enrolled node gave up a bus key -- nothing to install"
    [ "$_skip" = 0 ] || note "$_skip machine(s) skipped: not enrolled. 'copal grove enrol' first."

    # THE CONSOLE IS A MEMBER TOO, and it goes in last so that the operator can
    # see it arrive. It publishes commands and subscribes to everything; it is
    # the only member that is allowed to do either.
    _ck=$(console_nkey) || die "no console identity, and the bus needs one"
    printf 'console %s console\n' "$_ck" >> "$TMP/members"
    printf "    ${G}✓${Z} %-14s %s\n" "console" "$_ck" >&2

    info "Installing the membership on the warden, $_wid."
    if ssh_as_operator_stdin "$_waddr" 'bus users' < "$TMP/members"; then
        note "The warden rendered it, nats-server accepted it, and reloaded."
        note "Read it there: /etc/nats/grove-users.conf -- it is invariant 5 in"
        note "the form the server enforces, and it is meant to be read."
    else
        die "$_wid refused the membership. Nothing on the bus changed.

    The warden checks every key's checksum and asks nats-server to parse the
    result before it installs anything, so a refusal here means the bus is
    still running on whatever it had before."
    fi
}

# --------------------------------------------------------------- run -------
#
# Fan-out. Every node gets the same verb, every node gets its own result line,
# and a node that did not answer says so rather than being counted as done.
# "I told eight machines to shut down" and "eight machines shut down" are
# different claims, and only the second one may be printed.
cmd_run() {
    _verb=""
    while [ $# -gt 0 ]; do
        if take_common "$@"; then shift "$SHIFTN"; continue; fi
        _verb="$*"; break
    done
    settle
    [ -n "$_verb" ] || die "which verb? copal grove run state"
    [ -s "$OPKEY-cert.pub" ] || die "no operator certificate. Run: copal grove login"

    selected > "$TMP/sel"
    : > "$TMP/list"
    while IFS="$TAB" read -r _id _addr _txt; do
        if [ "$(cert_state "$_addr")" = enrolled ]; then
            printf '%s\t%s\n' "$_id" "$_addr" >> "$TMP/list"
        else
            printf "    ${Y}skip${Z}  %-14s not enrolled -- copal grove enrol\n" "$_id" >&2
        fi
    done < "$TMP/sel"
    [ -s "$TMP/list" ] || die "no enrolled node matched"
    info "$_verb → $(wc -l < "$TMP/list" | tr -d ' ') nodes"

    mkdir -p "$TMP/out"
    while IFS="$TAB" read -r _id _addr; do
        (
            if _r=$(ssh_as_operator "$_addr" "$_verb" 2>&1); then
                printf 'ok\t%s\n' "$(printf '%s' "$_r" | head -1)" > "$TMP/out/$_id"
            else
                printf 'FAIL\t%s\n' "$(printf '%s' "$_r" | head -1)" > "$TMP/out/$_id"
            fi
        ) &
    done < "$TMP/list"
    wait

    _good=0; _bad=0
    while IFS="$TAB" read -r _id _addr; do
        if [ -s "$TMP/out/$_id" ]; then
            IFS="$TAB" read -r _st _msg < "$TMP/out/$_id"
        else
            _st=FAIL; _msg="no answer"
        fi
        if [ "$_st" = ok ]; then
            _good=$((_good + 1)); printf "    ${G}ok${Z}    %-14s %s\n" "$_id" "$_msg" >&2
        else
            _bad=$((_bad + 1));  printf "    ${R}FAIL${Z}  %-14s %s\n" "$_id" "$_msg" >&2
        fi
    done < "$TMP/list"
    printf "\n    %s ok, %s failed\n\n" "$_good" "$_bad" >&2
    [ "$_bad" -eq 0 ]
}

cmd_status() {
    _id=""
    while [ $# -gt 0 ]; do
        if take_common "$@"; then shift "$SHIFTN"; continue; fi
        _id="$1"; shift
    done
    settle
    [ -n "$_id" ] || die "which node? copal grove status museum-03"
    _row=$(beacons | awk -F'\t' -v id="$_id" '$1 == id { print; exit }')
    [ -n "$_row" ] || die "$_id is not announcing. Try: copal grove ls"
    _addr=$(printf '%s' "$_row" | cut -f2)
    _txt=$(printf '%s' "$_row" | cut -f3)
    printf "\n${B}%s${Z}  ${D}%s${Z}\n\n" "$_id" "$_addr"
    for _pair in "g grove" "r role" "a arch" "m ram-MB" "b build" "t tags" "u uptime" "s score" "c scene"; do
        _k=${_pair%% *}; _l=${_pair#* }
        _v=$(txt_get "$_txt" "$_k"); [ -n "$_v" ] || continue
        printf '    %-9s %s\n' "$_l" "$_v"
    done
    printf '    %-9s %s\n' "proved" "$(cert_state "$_addr")"
    _h=0; beacon_hmac_ok "$_id" "$(txt_get "$_txt" k)" || _h=$?
    case $_h in
        0) printf '    %-9s %s\n' "beacon" "matches the grove key" ;;
        1) printf '    %-9s %s\n' "beacon" "DOES NOT MATCH the grove key" ;;
        *) printf '    %-9s %s\n' "beacon" "not checked (no key here, or no openssl)" ;;
    esac
    printf '\n'
}

# Discovery paying for itself: nobody edits a host list.
# The rows every inventory format is built from: one line per ENROLLED node,
# id, address, and the facts its beacon carried. Enrolled only, and that is the
# invariant rather than a filter -- an inventory is a list of machines this
# console is about to run commands on, and a candidate has proved nothing.
inventory_rows() {
    selected | while IFS="$TAB" read -r _id _addr _txt; do
        [ "$(cert_state "$_addr")" = enrolled ] || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$_id" "$_addr" \
            "$(txt_get "$_txt" r)" "$(txt_get "$_txt" t)" \
            "$(txt_get "$_txt" a)" "$(txt_get "$_txt" m)" "$(txt_get "$_txt" s)"
    done
}

# Ansible's dynamic-inventory JSON, which is what groves/<name>/inventory/
# copal_grove.py shells out to. Written here rather than in that script so
# there is ONE implementation of "which machines are in this grove", and it is
# the one that checks certificates.
inventory_json() {
    inventory_rows | awk -F'\t' -v grove="$GROVE" -v user="$LOGIN_USER" '
        function j(v) { gsub(/\\/, "\\\\", v); gsub(/"/, "\\\"", v); return "\"" v "\"" }
        function hostlist(s,   a, n, i, out) {
            n = split(s, a, " "); out = ""
            for (i = 1; i <= n; i++) if (a[i] != "")
                out = out (out == "" ? "" : ", ") j(a[i])
            return out
        }
        {
            id = $1; ids[++n] = id
            addr[id] = $2; role[id] = ($3 == "" ? "node" : $3); tags[id] = $4
            arch[id] = $5; ram[id] = $6; score[id] = $7
            members = members " " id
            byrole[role[id]] = byrole[role[id]] " " id
            m = split($4, t, ",")
            for (i = 1; i <= m; i++) if (t[i] != "") bytag[t[i]] = bytag[t[i]] " " id
        }
        END {
            printf "{\n  \"_meta\": {\n    \"hostvars\": {\n"
            for (i = 1; i <= n; i++) {
                id = ids[i]
                printf "      %s: {", j(id)
                printf "\"ansible_host\": %s, ", j(addr[id])
                printf "\"ansible_user\": %s, ", j(user)
                printf "\"copal_grove\": %s, ", j(grove)
                printf "\"copal_role\": %s, ", j(role[id])
                printf "\"copal_arch\": %s, ", j(arch[id])
                printf "\"copal_ram_mb\": %s, ", (ram[id] == "" ? "null" : ram[id] + 0)
                printf "\"copal_score\": %s, ", (score[id] == "" ? "null" : score[id] + 0)
                printf "\"copal_tags\": [%s]", hostlist(gensub_commas(tags[id]))
                printf "}%s\n", (i < n ? "," : "")
            }
            printf "    }\n  },\n"
            printf "  \"all\": { \"children\": [%s] },\n", j(grove)
            printf "  %s: { \"hosts\": [%s] }", j(grove), hostlist(members)
            for (r in byrole) printf ",\n  %s: { \"hosts\": [%s] }", j(r), hostlist(byrole[r])
            for (t in bytag)  printf ",\n  %s: { \"hosts\": [%s] }", j("tag_" t), hostlist(bytag[t])
            printf "\n}\n"
        }
        function gensub_commas(s) { gsub(/,/, " ", s); return s }
    '
}

cmd_inventory() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for inventory"
        shift "$SHIFTN"
    done
    settle
    if [ "$JSON" = 1 ]; then
        inventory_json
        return 0
    fi
    printf '# generated by copal grove inventory -- do not edit\n'
    printf '[%s]\n' "$GROVE"
    # The count goes through a file rather than a variable: the loop is the
    # right-hand side of a pipe and runs in a subshell, so anything it
    # increments is gone by the time the test below reads it.
    : > "$TMP/inv.n"
    selected | while IFS="$TAB" read -r _id _addr _txt; do
        [ "$(cert_state "$_addr")" = enrolled ] || continue
        printf 'x' >> "$TMP/inv.n"
        printf '%s ansible_host=%s ansible_user=%s\n' "$_id" "$_addr" "$LOGIN_USER"
    done
    printf '\n[%s:vars]\nansible_python_interpreter=/usr/bin/python3\n' "$GROVE"
    # An inventory holds ENROLLED nodes only, so a grove that is announcing
    # loudly and has never been enrolled produces an empty one. That is
    # correct, and it looks exactly like a broken inventory, so it says which
    # it is -- on stderr, where it cannot end up inside the file Ansible reads.
    if [ ! -s "$TMP/inv.n" ]; then
        if [ -f "$CAPUB" ]; then
            warn "no enrolled node in grove '$GROVE' -- the inventory is empty"
            note "candidates are not in it by design. Run: copal grove enrol"
        else
            warn "no certificate authority here, so nothing can be enrolled"
            note "run: copal grove ca --create, then copal grove enrol"
        fi
    fi
}

# ---------------------------------------------------------- the grove file --
#
# A DELIBERATELY SMALL READER, and it is not a TOML parser. It handles what a
# grove file actually holds -- [section] headers, key = "value", and flat
# arrays of strings -- and ignores anything else rather than guessing at it.
# The alternative was a real TOML library, which means a Python dependency on
# the console for a file with nine values in it, or two hundred lines of awk
# that would be wrong in ways nobody notices until a museum opens.
#
# Anything this cannot express belongs in a scene, where Ansible parses it.
toml_get() {  # <section> <key> -- the value, or an array one item per line
    [ -f "$SDIR/grove.toml" ] || return 0
    awk -v want="$1" -v key="$2" '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*\[/ { sec = $0
            gsub(/^[[:space:]]*\[+|\]+[[:space:]]*$/, "", sec); next }
        {
            eq = index($0, "=")
            if (!eq || sec != want) next
            k = substr($0, 1, eq - 1); v = substr($0, eq + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (k != key) next
            if (v ~ /^"/)      { v = substr(v, 2); sub(/".*$/, "", v); print v }
            else if (v ~ /^\[/) {
                gsub(/^\[|\].*$/, "", v)
                n = split(v, a, ",")
                for (i = 1; i <= n; i++) {
                    gsub(/^[[:space:]]*"?|"?[[:space:]]*$/, "", a[i])
                    if (a[i] != "") print a[i]
                }
            }
            else { sub(/[[:space:]]*#.*$/, "", v); print v }
            exit
        }' "$SDIR/grove.toml"
}

need_scenes() {
    [ -d "$SDIR" ] || die "no grove directory at $SDIR -- run: copal grove init"
    [ -d "$SDIR/scenes" ] || die "$SDIR has no scenes/ directory in it"
}

# --------------------------------------------------------------- init ------
#
# groves/<name>/ from groves/example/. The template is real, committed files
# rather than heredocs in this script for one reason: they are Ansible, and
# Ansible that lives inside a shell script cannot be linted, diffed or run by
# anybody who has not first extracted it.
cmd_init() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for init"
        shift "$SHIFTN"
    done
    settle
    _tpl="$ROOT/groves/example"
    [ -d "$_tpl" ] || die "no template at $_tpl"
    [ ! -e "$SDIR" ] || die "$SDIR already exists -- edit it, or remove it deliberately"
    mkdir -p "$SDIR" || die "could not make $SDIR"
    cp -R "$_tpl/." "$SDIR/" || die "could not copy the template into $SDIR"

    # No `sed -i`: it takes an argument on macOS and does not on Linux, and
    # this repository runs on both. Write beside the file and move it over.
    _fp=$(ca_fingerprint 2>/dev/null || true)
    find "$SDIR" -type f -print | while IFS= read -r _f; do
        sed -e "s|@GROVE@|$GROVE|g" -e "s|@USER@|$LOGIN_USER|g" \
            -e "s|@CA@|${_fp:-unknown -- run copal grove ca --create}|g" \
            "$_f" > "$_f.copal-new" && mv "$_f.copal-new" "$_f"
    done
    chmod 0755 "$SDIR/inventory/copal_grove.py" 2>/dev/null || true

    info "Wrote $SDIR"
    note "grove.toml         the grove file -- power, attachments, what a scene needs"
    note "scenes/            wake, show, reset, rest, sleep"
    note "roles/             what a scene actually does on a node"
    note "inventory/         the host list, out of discovery. Never edited by hand"
    note ""
    note "It is meant to be committed. The grove executes what the repository"
    note "says, not what the network says, so a scene nobody can diff is a scene"
    note "nobody can trust. Then:   copal grove scene"
}

# ------------------------------------------------------------- power -------
#
# SECTION 9.1 OF THE PLAN, IN CODE: A RASPBERRY PI CANNOT BE WOKEN BY
# WAKE-ON-LAN. There is no standby rail feeding the NIC, so any plan that says
# "WoL at 08:30" cannot be built, and a console that implies otherwise costs a
# museum its morning. What CAN be switched is the power itself, and that is a
# property of the room and not of the machine -- a switchable USB hub, a relay,
# a smart plug with a local API. So the grove file names one command per
# direction and a node-to-port list, and this runs them.
#
# THE PORT LIST IS THE SOURCE OF TRUTH HERE, not discovery, and that is the
# whole point: a machine that is switched off is not announcing, so anything
# that iterated over beacons would find nothing to switch on and report a
# cheerful nothing-to-do.
power_port() {  # <id>
    toml_get power ports | awk -F: -v id="$1" '$1 == id { print $2; exit }'
}
power_apply() {  # <on|off>
    _dir="$1"
    _m=$(toml_get power method); [ -n "$_m" ] || _m=always-on
    case "$_m" in
        always-on)
            note "power: always-on. Nothing to switch -- the nodes stay up, which"
            note "is the recommendation in the plan and needs no hardware."
            return 0 ;;
        command) : ;;
        *) warn "power method '$_m' is not one this console knows"; return 1 ;;
    esac
    _tpl=$(toml_get power "$_dir")
    [ -n "$_tpl" ] || { warn "the grove file has no [power] $_dir command"; return 1; }
    _hub=$(toml_get power hub)
    _any=0
    for _pair in $(toml_get power ports); do
        _id=${_pair%%:*}; _port=${_pair#*:}
        [ -z "$ONLY" ] || [ "$ONLY" = "$_id" ] || continue
        _any=1
        # The command comes from a file in a git checkout, which is invariant 7
        # and the reason running it is acceptable: the console executes what the
        # repository says. A grove file is as trusted as the console itself.
        _cmd=$(printf '%s' "$_tpl" \
            | sed -e "s|{hub}|$_hub|g" -e "s|{port}|$_port|g" -e "s|{node}|$_id|g")
        if sh -c "$_cmd" >/dev/null 2>&1; then
            printf "    ${G}ok${Z}    %-14s power %s\n" "$_id" "$_dir" >&2
        else
            printf "    ${R}FAIL${Z}  %-14s %s\n" "$_id" "$_cmd" >&2
        fi
    done
    if [ "$_any" = 0 ]; then
        warn "no node in [power] ports -- every machine here needs a human at a plug"
        return 1
    fi
}
cmd_power() {
    _dir=""
    while [ $# -gt 0 ]; do
        if take_common "$@"; then shift "$SHIFTN"; continue; fi
        case "$1" in on|off) _dir="$1" ;; *) die "power takes on or off" ;; esac
        shift
    done
    settle
    [ -n "$_dir" ] || die "copal grove power on|off"
    [ -f "$SDIR/grove.toml" ] || die "no grove file at $SDIR/grove.toml -- run: copal grove init"
    info "power $_dir"
    power_apply "$_dir"
}

# -------------------------------------------------------------- wait -------
#
# The morning's honest question: are they all here yet? Declared nodes, not
# discovered ones -- a node that never announces is the answer, and it can only
# be missed by a list that was built from what announced.
expected_nodes() {
    _e=$(toml_get grove nodes)
    if [ -n "$_e" ]; then printf '%s\n' "$_e"; return 0; fi
    # No list in the grove file: fall back to the naming stage 16 gives a card,
    # <grove>-NN, for as many cards as the interview said there were.
    _n=$(answer COPAL_GROVE_SIZE); [ -n "$_n" ] || return 0
    _i=1
    while [ "$_i" -le "$_n" ]; do
        printf '%s-%02d\n' "$GROVE" "$_i"
        _i=$((_i + 1))
    done
}
wait_for_nodes() {  # <seconds>
    _deadline=$(( $(date +%s) + $1 ))
    expected_nodes > "$TMP/expect"
    if [ ! -s "$TMP/expect" ]; then
        warn "no expected node list -- nothing to wait for"
        return 0
    fi
    info "waiting for $(wc -l < "$TMP/expect" | tr -d ' ') nodes, up to ${1}s"
    : > "$TMP/seen"
    while :; do
        rm -f "$TMP/beacons"          # the cache is per invocation; this polls
        beacons > "$TMP/now" 2>/dev/null || : > "$TMP/now"
        while IFS= read -r _id; do
            grep -qx "$_id" "$TMP/seen" 2>/dev/null && continue
            if awk -F'\t' -v id="$_id" '$1 == id { found = 1 } END { exit !found }' "$TMP/now"; then
                printf '%s\n' "$_id" >> "$TMP/seen"
                printf "    ${G}up${Z}    %-14s\n" "$_id" >&2
            fi
        done < "$TMP/expect"
        [ "$(wc -l < "$TMP/seen")" -ge "$(wc -l < "$TMP/expect")" ] && { info "all here"; return 0; }
        [ "$(date +%s)" -ge "$_deadline" ] && break
        sleep 5
    done
    while IFS= read -r _id; do
        grep -qx "$_id" "$TMP/seen" 2>/dev/null \
            || printf "    ${R}--${Z}    %-14s never announced\n" "$_id" >&2
    done < "$TMP/expect"
    warn "gave up after ${1}s. The scene will run on the nodes that are here."
    return 1
}
cmd_wait() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for wait"
        shift "$SHIFTN"
    done
    settle
    wait_for_nodes "$TIMEOUT"
}

# ------------------------------------------------------------- scene -------
#
# A scene is a named, declarative, idempotent state of the whole grove, and
# applying one twice does nothing the second time. "Today's task is different"
# is one file changed rather than eight machines touched.
#
# THE CONSOLE DOES THREE THINGS HERE AND ANSIBLE DOES THE FOURTH. Power cannot
# be done over SSH to a machine that is off, and waiting for beacons cannot be
# done by a playbook whose inventory is the thing being waited for, so those
# two are the console's. Recording what the grove is now doing is the
# console's. Everything that happens ON a node is Ansible's, because a
# playbook is reviewable and a shell loop over ssh is not.
#
# Ansible logs in as the HUMAN account with the operator certificate, not as
# the copal-grove service account: that account has a forced command by
# design, and a forced command cannot run a module. Host keys are checked
# normally and that is not a compromise -- `copal grove trust` put the CA in
# known_hosts, so every node in the grove validates without a prompt and a host
# key that CHANGES is an error rather than a warning to press through.
scene_list() {
    printf "\n${B}Scenes in ${C}%s${Z}\n\n" "$SDIR/scenes"
    for _f in "$SDIR"/scenes/*.yml; do
        [ -f "$_f" ] || { note "none yet"; break; }
        _n=$(basename "$_f" .yml)
        # The one-line description is the file's own '# scene:' comment, so it
        # cannot drift from the playbook the way a table in a README does.
        _d=$(sed -n 's/^# scene: *//p' "$_f" | head -1)
        printf "    ${C}%-8s${Z} %s\n" "$_n" "$_d"
    done
    printf "\n    ${D}copal grove scene NAME    --check to report without changing${Z}\n\n"
}
cmd_scene() {
    _name=""
    while [ $# -gt 0 ]; do
        if take_common "$@"; then shift "$SHIFTN"; continue; fi
        case "$1" in -*) die "unknown option '$1' for scene" ;; esac
        _name="$1"; shift
    done
    settle; need_scenes
    [ -n "$_name" ] || { scene_list; return 0; }
    _play="$SDIR/scenes/$_name.yml"
    [ -f "$_play" ] || die "no scene called '$_name' in $SDIR/scenes"
    command -v ansible-playbook >/dev/null 2>&1 \
        || die "no ansible-playbook on this console. Install ansible-core, or use 'copal grove run' for one verb"
    [ -s "$OPKEY-cert.pub" ] || die "no operator certificate. Run: copal grove login"

    _power=$(toml_get "scenes.$_name" power)
    if [ "$_power" = on ]; then
        info "$_name: power first -- a machine that is off cannot be configured"
        power_apply on || warn "power step incomplete -- carrying on with what is up"
        _w=$(toml_get "scenes.$_name" wait); [ -n "$_w" ] || _w="$TIMEOUT"
        wait_for_nodes "$_w" || true
    fi

    if [ "$(toml_get "scenes.$_name" become)" = true ] && [ "$ASKPASS" = 0 ]; then
        note "this scene becomes root on the nodes. If doas asks for a password,"
        note "re-run it as: copal grove scene $_name --pass"
    fi

    _limit=""
    [ -z "$ONLY" ] || _limit="$ONLY"
    [ -z "$TAG" ]  || _limit="tag_$TAG"

    set -- ansible-playbook -i "$SDIR/inventory/copal_grove.py" "$_play"
    [ "$CHECK" = 0 ]   || set -- "$@" --check --diff
    [ "$ASKPASS" = 0 ] || set -- "$@" --ask-become-pass
    [ -z "$_limit" ]   || set -- "$@" --limit "$_limit"
    if [ "$CHECK" = 1 ]; then info "scene $_name (check: nothing will change)"
    else                       info "scene $_name"; fi

    _rc=0
    COPAL_GROVE="$GROVE" \
    COPAL_GROVE_USER="$LOGIN_USER" \
    ANSIBLE_CONFIG="$SDIR/ansible.cfg" \
    ANSIBLE_PRIVATE_KEY_FILE="$OPKEY" \
    "$@" || _rc=$?

    if [ "$_rc" = 0 ] && [ "$CHECK" = 0 ]; then
        printf '%s\t%s\n' "$_name" "$(date '+%Y-%m-%dT%H:%M:%S')" > "$GDIR/scene"
        # The grove is now in a named state, and the console can say since when.
        info "grove '$GROVE' is $_name since $(cut -f2 "$GDIR/scene")"
        if [ "$(toml_get "scenes.$_name" power)" = "off-after" ]; then
            info "$_name: cutting power, now that every node has halted itself"
            power_apply off || warn "some ports were not switched"
        fi
    elif [ "$_rc" != 0 ]; then
        warn "ansible-playbook exited $_rc -- the grove is in no named state"
    fi
    return "$_rc"
}

# The header, up to the first line that is not a comment. It used to be a
# hardcoded line range, which silently truncated the moment the header grew.
usage() { awk 'NR >= 5 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0" >&2; }

case "${1:-}" in
    ls)                shift; cmd_ls "$@" ;;
    init)              shift; cmd_init "$@" ;;
    scene|scenes)      shift; cmd_scene "$@" ;;
    power)             shift; cmd_power "$@" ;;
    wait)              shift; cmd_wait "$@" ;;
    ca)                shift; cmd_ca "$@" ;;
    trust)             shift; cmd_trust "$@" ;;
    login)             shift; cmd_login "$@" ;;
    sign)              shift; cmd_sign "$@" ;;
    enrol|enroll)      shift; cmd_enrol "$@" ;;
    run)               shift; cmd_run "$@" ;;
    status)            shift; cmd_status "$@" ;;
    inventory)         shift; cmd_inventory "$@" ;;
    bus)               shift; cmd_bus "$@" ;;
    help|-h|--help|'') usage ;;
    *) die "no grove verb called '$1'. Try: copal grove help" ;;
esac
