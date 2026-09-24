# playbook: stage-fleet
# source:   copal
# origin:   stage
# stage:    16
# category: Fleet
# step:     Join the named fleet, and announce it
# weight:   4
# levels:   server medium full
# summary:  Joins a named fleet of Copal machines: a certificate, a beacon on the network, and one
#           console for the room. On a card with no fleet named it does nothing.

stage_fleet() {
    say "Stage 16: the fleet -- this machine as one of several"

    _g=$(answers_fleet COPAL_FLEET || true)
    if [ -z "$_g" ]; then
        cat <<'MSG'

    THIS CARD IS NOT PART OF A FLEET, and that is the ordinary case.

    A fleet is a named set of Copal machines on one LAN that trust one
    certificate authority: they find each other, prove themselves, and answer
    one console. Eight Raspberry Pis in a museum, switched on together each
    morning, is what it was built for.

    Nothing about it can be turned on from here, because the parts that matter
    are decided on the machine that WRITES the card:

        make answers            name a fleet; it offers to make the authority
        make answers-node N=2   card 2, card 3, ... without another interview

    Both write into answers.txt, copal-prep.sh puts them on the card, and this
    stage picks them up at the next install. See docs/fleet-plan.md.

MSG
        return 0
    fi

    cat <<MSG

    FLEET: $_g

    This machine is card $(answers_fleet COPAL_FLEET_INDEX || echo '?') of $(answers_fleet COPAL_FLEET_SIZE || echo '?').

    What this stage does:

      - records the fleet's name, this card's index, role and tags
      - installs the fleet's certificate authority, PUBLIC half, so that
        nothing on this network is ever trusted on first sight
      - creates the '$FLEET_ACCT' service account, which the console's
        automation lands in and which cannot get a shell
      - points sshd at the authority, and binds that account to one forced
        command that accepts a list of verbs and refuses everything else
      - installs avahi and announces this machine, if discovery is mdns
      - installs the bus key format, and generates NO key yet: this machine's
        bus identity is made the first time the console asks for it
      - if this card's role is warden, installs nats-server and starts it with
        a membership of nobody. If it is not, makes sure no bus is running here

    What it does NOT do:

      - open anything to the internet
      - put a private key anywhere
      - change how you log in. Your own account is untouched

    Afterwards, from the console:   copal fleet ls   then   copal fleet enrol

MSG
    confirm_yes "Join fleet '$_g'?" || { note "Nothing changed."; return 0; }

    fleet_write_identity
    fleet_install_ca      || warn "continuing without an authority -- enrolment will not work"
    fleet_install_tools
    fleet_service_account || warn "the service account is incomplete"
    fleet_remote_tools    || warn "the screen and banner tools are not installed"
    fleet_sshd_policy     || warn "sshd was left as it was"
    fleet_discovery       || true
    # Every node gets the key format, because every node needs a bus identity.
    # Only the warden gets a server, and fleet_warden_bus is what decides that
    # -- including taking one away from a node that has just been demoted.
    fleet_bus_tools       || warn "the bus key format is not installed here"
    fleet_warden_bus      || true
    # Last, because it reads the session word that stage 17 may have written.
    fleet_remote_rdp      || true

    say "Stage 16 complete."
    note ""
    note "This machine is $(hostname), card $(cat "$FLEET_DIR/index" 2>/dev/null) of fleet $_g."
    note "It is announcing itself. It has NOT been enrolled: no certificate has"
    note "been signed for it yet, and until one is, the console will show it as a"
    note "candidate rather than a node. From the machine that holds the authority:"
    note ""
    note "    copal fleet ls        -- it should appear with a '?'"
    note "    copal fleet enrol     -- checks its token, signs, installs"
    note "    copal fleet ls        -- a '✓'"
    note ""
    note "On this machine: copal-fleet status, and copal-fleet bus-state"
}
