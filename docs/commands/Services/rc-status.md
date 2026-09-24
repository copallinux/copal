# command:  rc-status
# purpose:  Show which services are running, runlevel by runlevel.
# why:      The first question after a boot that went wrong, or a desktop
#           piece that is missing: is its service started, stopped or
#           crashed. No root needed.
# see:      rc-service, rc-update, openrc

## Use
List the current runlevel's services and their state. With `-a` it shows
every runlevel; with `-c` only what has crashed, which after a bad boot is
usually the short list you want.

## Examples
    rc-status                            # the current runlevel
    rc-status -a                         # every runlevel
    rc-status -c                         # only crashed services
    rc-status -m                         # started by hand, in no runlevel
    rc-status -u                         # installed but in no runlevel
    rc-status -r                         # the name of the current runlevel

## Options
-a, --all           services in every runlevel
-c, --crashed       only crashed services
-m, --manual        services started by hand, not by a runlevel
-u, --unused        services in no runlevel
-s, --servicelist   every service and its state, as one list
-r, --runlevel      print the current runlevel's name
-f ini              output a script can parse

## Notes
- "crashed" means OpenRC started it and its process has gone. The cause
  is in `/var/log/messages` or the service's own log, not here; restart it
  with `rc-service NAME restart`.
- A service missing from the list is in no runlevel -- `rc-status -u` to
  find it, `rc-update add` to put it in one.
