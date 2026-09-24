# command:  copal-debug
# purpose:  Turn on Copal's debug collection: one folder, /var/log/copal, holding everything worth reading about a fault.
# why:      Off by default, because on a working machine the extra writes buy
#           nothing. When something is wrong, one command gathers a snapshot of
#           the machine and links to every relevant log in one place -- readable
#           over SSH, or bundled into one file to send to someone.
# see:      copal-logs, copal-startx, copal-gpu

## Use
`doas copal-debug on 1d` starts collecting and switches itself off after a
day. `copal-debug` alone says whether it is on and what it has gathered.
`bundle` makes a .tar.gz to copy off the machine.

## Examples
    copal-debug                          # on or off, and what is collected
    doas copal-debug on 1d               # collect for a day, then stop
    doas copal-debug collect             # refresh the snapshot now
    doas copal-debug bundle              # one archive in /tmp, ready for scp
    doas copal-debug off                 # stop; keep what is there
    doas copal-debug purge               # delete the collection
    COPAL_DEBUG=1 copal-startx           # debug for one command only

## Options
status           whether it is on, and what is in the folder (the default)
on [TIME]        start collecting; TIME (1d, 12h, 30m, or seconds) ends it
off              stop collecting, leave the folder
collect          refresh the snapshot
bundle           tar the folder, links resolved, into /tmp
purge            delete /var/log/copal
expire           switch off if the deadline has passed (cron runs this)

## Notes
- The folder holds `sysinfo.txt` (kernel, consoles, graphics, input,
  gettys, services, which Copal), `dmesg.log`, and links to the install
  transcript, the system log, Xorg's log and the last desktop session. A
  broken link is a finding: `xorg.log` pointing nowhere means X never
  started.
- `COPAL_DEBUG=1` or `=0` in the environment overrides the switch for one
  command. The switch itself is the file `/etc/copal/debug`.
- With debug on, copal-startx keeps ten session logs instead of two.
