# command:  copal-fleet
# purpose:  A fleet machine's own half of the fleet: what it announces, what it reports, and whether it has been enrolled.
# why:      A Copal fleet is a set of machines on one LAN that trust one
#           certificate authority, run from a console. Each machine needs a
#           small, readable program for its side -- announcing itself, reporting
#           its health, taking part in choosing the warden -- and this is it.
# see:      copal-fleet-exec, copal-fleet-agent, copal-remote, avahi-browse

## Use
`copal-fleet` alone says what this machine thinks it is: its fleet, role,
tags, scene, and whether it is enrolled. The other verbs are mostly for the
console and the services; `facts` and `state` are good for a quick look.

## Examples
    copal-fleet                          # this machine's view of itself
    copal-fleet facts                    # health, one fact per line
    copal-fleet state                    # the same, on one line
    copal-fleet browse                   # which fleet machines this one can see
    copal-fleet logs all 2               # the warden's collected logs, two days
    rc-service copal-fleet status        # the service that keeps the beacon fresh

## Options
status           fleet, node, role, score, tags, scene, authority, enrolment (the default)
state            one line of facts, for the console
facts            id, versions, uptime, memory, temperature, card use, certificate days...
id               the node's name
role             node or warden (or the pinned role)
score            this node's score in the warden election
elect            recompute the role
beacon           rewrite the mDNS announcement
watch            elect and rewrite the beacon every 4 minutes (the service)
browse           the fleet machines visible from here
install-cert     install a host certificate read from stdin (root)
bus-key          this node's bus identity, made if needed
bus-users        write the bus membership from stdin (warden, root)
bus-config       rewrite /etc/nats/nats.conf (warden, root)
bus-address      where the bus is
bus-state        what this node's part of the bus is doing
logs ID|all [DAYS]  the logs the warden has collected, even for a dead node
-h, --help       the usage

## Notes
- The fleet console is a different program on the operator's machine:
  `tools/copal-fleet.sh` in the copal checkout, which the fleet guides
  call `copal fleet`. It reaches this one through copal-fleet-exec.
- The warden is chosen by a score every node computes and publishes; the
  highest announcing node takes the role. `role-pin` in
  `/etc/copal/fleet` fixes a role by hand.
- The settings are one file per field in `/etc/copal/fleet`. Stage 16
  installs the program and the `copal-fleet` service.
- The announcement says a machine is there, never that it is trusted:
  only its certificate decides that.
