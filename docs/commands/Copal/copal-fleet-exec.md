# command:  copal-fleet-exec
# purpose:  The only thing the fleet console's logins can run: a short, fixed list of verbs, each checked, each logged.
# why:      This is the fleet's security boundary. sshd sends every login by
#           the copal-fleet account here, with no shell, no terminal and no
#           forwarding, and what arrives is matched against a list of verbs
#           rather than run as a command. A verb not on the list is refused and
#           logged -- there is no pass-through.
# see:      copal-fleet, copal-fleet-agent, copal-remote, copal-notify, sshd

## Use
You do not run it; sshd does, as a forced command, with the console's
request in `SSH_ORIGINAL_COMMAND`. The fleet agent hands bus commands to it
the same way. Read it to know exactly what the console can do to a machine.

## Examples
    copal fleet run uptime               # from the console: one verb, every node
    copal fleet run message Please stand back
    doas tail /var/log/copal-fleet.log   # on a node: what was asked, and refused

## Options
state, status, facts, score, id, uptime   reports; nothing changes
beacon                 rewrite the mDNS announcement
power off|reboot       shut down or restart
snapshot restore       restore the node's snapshot (if it has copal-snapshot)
scene apply NAME       record the scene name; applying it is Ansible's job
bus key|users|state    the node's bus identity, membership (warden), state
logs ID|all [DAYS]     the warden's collected logs
log tail [N]           the last lines of this node's fleet log
remote start|stop|status   share the screen, bounded (see copal-remote)
message TEXT           put a sentence on the screen (see copal-notify)

## Notes
- A message is at most 200 characters of letters, digits, spaces and
  `. , ! ? :` and `-`: no quotes, brackets or slashes, so nothing in it
  can be read as markup or shell syntax.
- A scene name is lowercase letters, digits and dashes.
- Every request is logged with the caller's address to
  `/var/log/copal-fleet.log`; refusals are marked REFUSED.
- Adding a verb means editing this file, and nothing else can add one:
  the bus agent parses no verbs of its own.
