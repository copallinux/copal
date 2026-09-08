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
set -eu

B='\033[1m'; D='\033[2m'; C='\033[36m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; Z='\033[0m'
die()  { printf "${R}error:${Z} %s\n" "$*" >&2; exit 1; }
info() { printf "${C}==>${Z} %s\n" "$*" >&2; }
note() { printf '    %s\n' "$*" >&2; }
warn() { printf "${Y}warning:${Z} %s\n" "$*" >&2; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANSWERS="${COPAL_ANSWERS:-$ROOT/answers.txt}"
HOME_COPAL="${COPAL_HOME:-$HOME/.copal}"
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
    note "Check with: copal grove ls"
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
    for _pair in "g grove" "r role" "a arch" "m ram-MB" "b build" "t tags" "u uptime" "s score"; do
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
cmd_inventory() {
    while [ $# -gt 0 ]; do
        take_common "$@" || die "unknown option '$1' for inventory"
        shift "$SHIFTN"
    done
    settle
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

usage() { sed -n '5,38p' "$0" | sed 's/^# \{0,1\}//' >&2; }

case "${1:-}" in
    ls)                shift; cmd_ls "$@" ;;
    ca)                shift; cmd_ca "$@" ;;
    trust)             shift; cmd_trust "$@" ;;
    login)             shift; cmd_login "$@" ;;
    sign)              shift; cmd_sign "$@" ;;
    enrol|enroll)      shift; cmd_enrol "$@" ;;
    run)               shift; cmd_run "$@" ;;
    status)            shift; cmd_status "$@" ;;
    inventory)         shift; cmd_inventory "$@" ;;
    help|-h|--help|'') usage ;;
    *) die "no grove verb called '$1'. Try: copal grove help" ;;
esac
