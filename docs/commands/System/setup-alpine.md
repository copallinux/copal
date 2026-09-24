# command:  setup-alpine
# purpose:  Alpine's installer: keyboard, hostname, network, time, users, sshd, disk.
# why:      Stage 1 runs it with an answer file that copal-prep.sh wrote on the
#           Mac, so the first boot asks almost nothing. Copal gives it no disk
#           (DISKOPTS=none): stage 3 installs to disk itself.
# see:      lbu, doas, wpa_passphrase

## Use
Run once on a new Alpine system. It calls a family of smaller scripts in
turn -- `setup-keymap`, `setup-interfaces`, `setup-timezone`,
`setup-user`, `setup-sshd` and the rest -- and those are the useful part
afterwards: each one redoes a single step on a machine already running.

## Examples
    doas setup-interfaces                # redo the network, wifi included
    doas setup-timezone                  # change the time zone
    doas setup-keymap                    # change the keyboard layout
    doas setup-apkrepos                  # choose another package mirror
    setup-alpine -c answers.txt          # write a blank answer file, change nothing
    cat /media/*/answers.txt             # the answers Copal's stage 1 used

## Options
-f FILE    install from an answer file (a path or a URL)
-c FILE    write an answer file template and stop
-q         quick: hostname, networking and a mirror, nothing else
-e         set an empty root password (implied by -q)
-a         write an apkovl only; install nothing to disk

## Notes
- An answer file is a shell script it sources: `KEYMAPOPTS`,
  `HOSTNAMEOPTS`, `INTERFACESOPTS`, `USEROPTS`, `DISKOPTS` and so on. There
  is no variable for the root password; Copal answers that prompt itself.
- Run over SSH, it leaves the network running while it rewrites the
  settings, so the connection you are using is not cut from under you.
- The other setup scripts are in `/usr/sbin`: `ls /usr/sbin/setup-*`.
  Each has its own man page: `man setup-interfaces`.
