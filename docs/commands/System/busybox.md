# command:  busybox
# purpose:  One small program that is three hundred commands: sh, sed, awk, vi, wget...
# why:      Alpine's base system is BusyBox, and so is Copal's. The fuller
#           levels pull in GNU coreutils, grep and tar beside it, but sed, awk,
#           find, xargs, vi, wget, ping, nc, ip, blkid and the shell /bin/sh
#           stay BusyBox's.
# see:      ip, logread, apk

## Use
Mostly invisible: each applet is a link to `/bin/busybox`, and runs as
whatever name it was called by. Call `busybox` by name to see what it
provides, to read an applet's help, or to run the BusyBox version of a
command a fuller package has replaced.

## Examples
    busybox --list                       # every applet it provides
    ls -l $(command -v sed)              # -> /bin/busybox: sed is BusyBox here
    busybox sed --help                   # an applet's options, and only those
    busybox wget -O- https://example.com # the applet, even if GNU wget is in
    apk info -W $(command -v find)       # BusyBox, or a real package?

## Options
--list          the applets, one per line
APPLET --help   that applet's usage: the options it really has

## Notes
- The answers online are mostly for GNU. BusyBox applets take fewer
  options, and some take an option and ignore it: `blkid -s UUID -o value`
  prints the whole line and exits 0 -- it once put a device path where a
  UUID belonged in Copal's grub.cfg. Check with `busybox APPLET --help`.
- `/bin/sh` is BusyBox `ash`, not bash: no arrays, no `[[ ]]` in scripts
  that start `#!/bin/sh`. Your login shell may be bash; scripts are not.
- There is one manual page for all of it -- `man busybox` -- and each
  applet's section in it is short. `--help` is usually quicker.
- Installing the GNU package (`findutils`, `sed`, `gawk`...) replaces the
  link; `apk del` puts BusyBox's back.
