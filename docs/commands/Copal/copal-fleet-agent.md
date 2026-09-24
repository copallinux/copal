# command:  copal-fleet-agent
# purpose:  A fleet machine's standing connection to the fleet's message bus: presence, health and commands, all the time.
# why:      SSH answers when asked; the bus keeps the console's wall live
#           without asking. The agent announces the machine, publishes its state
#           as it changes, and runs commands that arrive on the bus -- through
#           copal-fleet-exec, the same checked list SSH uses, so the bus can
#           never do more than SSH can.
# see:      copal-fleet, copal-fleet-exec, rc-service

## Use
You do not run it; OpenRC does, as the unprivileged `copal-fleet`
account. Check on it with rc-service. `--self-test` runs its built-in
checks without touching the network.

## Examples
    rc-service copal-fleet-agent status  # is it running?
    doas rc-service copal-fleet-agent restart
    copal-fleet-agent --self-test        # its own checks

## Options
--self-test    run the built-in checks and exit

## Notes
- It publishes `hello` every 10 seconds, the node's state on change (at
  most every 5 seconds), new lines of `/var/log/copal-fleet.log`, and an
  acknowledgement for every command it ran.
- With no warden (and so no bus), it waits and tries again; that is
  normal during a handover, and SSH keeps working meanwhile.
- On the warden it also collects every node's log lines, so the logs of
  a machine that has died can still be read (`copal-fleet logs`).
- It publishes its own uptime, so the console can tell "the machine is
  up" from "the agent is alive".
