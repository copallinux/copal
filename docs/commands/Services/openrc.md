# command:  openrc
# purpose:  Alpine's init system: starts and stops services by runlevel.
# why:      Every service on a Copal machine -- sshd, chronyd, bluetooth, seatd,
#           acpid -- is an OpenRC script in /etc/init.d, and every stage that
#           enables one does it with rc-update. There is no systemd here.
# see:      rc-service, rc-update, rc-status

## Use
Switch the machine to a runlevel: OpenRC starts what that runlevel lists
and stops what it does not. At boot it runs sysinit, then boot, then
default; you rarely call `openrc` by hand. The day-to-day commands are
`rc-service` (start and stop one), `rc-update` (what starts at boot) and
`rc-status` (what is running).

## Examples
    rc-status                            # the current runlevel and its services
    doas openrc default                  # bring the default runlevel back up
    doas openrc nonetwork                # drop to the runlevel without networking
    ls /etc/init.d                       # every service this machine could run
    ls /etc/local.d                      # Copal's boot-time scripts (*.start)

## Options
RUNLEVEL          switch to it: sysinit, boot, default, nonetwork, shutdown
-n, --no-stop     start the runlevel's services, stop none of the others
-S, --sys         the kind of system OpenRC thinks it is on (VM, container...)
-v, --verbose     say what it does

## Notes
- The systemd answers online do not apply: no `systemctl`, no
  `journalctl`, no unit files. `systemctl restart sshd` is
  `rc-service sshd restart`; `systemctl enable sshd` is
  `rc-update add sshd`; the journal is `/var/log/messages`.
- A runlevel is a directory, `/etc/runlevels/NAME`, of links to
  `/etc/init.d` scripts. `rc-update` edits those links; editing them by
  hand works too.
- `/etc/local.d/*.start` run at the end of boot, through the `local`
  service -- Copal's zram swap is started from there (stage 5). A script
  is run only if it is executable.
- `/etc/rc.conf` holds the global settings. Two worth knowing, both off:
  `rc_parallel`, and `rc_logger`, which when on writes the whole boot to
  `/var/log/rc.log` -- the thing to turn on when a boot goes wrong too
  fast to read.
