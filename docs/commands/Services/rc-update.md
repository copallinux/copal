# command:  rc-update
# purpose:  Choose which services start at boot, and in which runlevel.
# why:      How every stage enables what it installs -- sshd and chronyd in
#           stage 1, acpid, bluetooth, seatd and the rest later. Undoing one
#           of those choices is rc-update del.
# see:      rc-service, rc-status, openrc

## Use
Add a service to a runlevel, or take it out. Most services belong in
`default`; a few that must run before the network or the desktop go in
`boot`. `rc-update` with no arguments shows what starts where.

## Examples
    rc-update                            # every enabled service and its runlevel
    doas rc-update add syncthing default # start it at every boot from now on
    doas rc-update del bluetooth default # stop starting it at boot
    doas rc-update del -a oldthing       # out of every runlevel, e.g. after removing it
    rc-update show -v                    # every service, enabled or not

## Options
add NAME [LEVEL]    enable in LEVEL; with no level, the current one (default)
del NAME [LEVEL]    disable in LEVEL; delete is the same word
show [LEVEL]        what is enabled, and where
-a, --all           with del: from every runlevel
-v, --verbose       with show: list the services in no runlevel too
-u, --update        rebuild the dependency cache (after clock skew)

## Notes
- Enabling does not start it now: `rc-update add X` and then
  `rc-service X start`, or wait for the next boot.
- Removing a package can leave its service in a runlevel; OpenRC then
  complains at boot about a script that is not there.
  `rc-update del -a NAME` clears it.
- "clock skew detected": a file in `/etc` is newer than the clock, which
  happens on a Pi with no real-time clock before chronyd has set the time.
  It passes once the time is right; `rc-update -u` forces the rebuild.
