# command:  rc-service
# purpose:  Start, stop, restart or ask about one OpenRC service.
# why:      The command every stage uses to bring a service up once it is
#           installed, and the one to reach for when a service needs a kick:
#           sshd after an edit to its config, bluetooth after a pairing sulks.
# see:      rc-update, rc-status, openrc

## Use
Run a service's script with a verb: `start`, `stop`, `restart`, `status`,
and whatever else that script offers. It finds the script (in
`/etc/init.d` or `/usr/local/etc/init.d`) and resolves the services it
needs first. `service` is the same command under its old name.

## Examples
    rc-service sshd status               # running or not
    doas rc-service sshd restart         # after editing /etc/ssh/sshd_config
    doas rc-service bluetooth start      # start one now (not at boot)
    rc-service -l                        # every service there is
    doas rc-service -s chronyd restart   # restart only if it is running
    doas rc-service syncthing zap        # forget a state that is wrong

## Options
start, stop, restart   the usual verbs; status says started, stopped or crashed
zap                    reset the recorded state to stopped, running nothing
-l, --list             list every service
-e, --exists NAME      exit 0 if the service exists
-i, --ifexists         run the verb only if the service exists
-s, --ifstarted        run the verb only if it is started
-S, --ifstopped        run the verb only if it is stopped
-D, --nodeps           ignore its dependencies
-d, --debug            trace the script as it runs (set -x)

## Notes
- Starting a service does not make it start at boot. That is
  `rc-update add NAME`; the two are separate on purpose.
- "already starting" or a service shown as started that plainly is not:
  its recorded state is out of step with reality. `rc-service NAME zap`
  resets it, then `start` again.
- `status` needs no root; anything that changes a service does.
- Stopping a service also stops the services that need it -- stopping
  `dbus` takes bluetooth down with it. OpenRC says so as it does it.
