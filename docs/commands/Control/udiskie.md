# command:  udiskie
# purpose:  Mount USB sticks and cards automatically when they are plugged in, with a tray icon.
# why:      The catalogue's automounter: plug in a stick and it appears under
#           /run/media, with a notification -- no mount commands. It talks to
#           udisks2, which starts on demand.
# see:      lsblk, sshfs

## Use
Run it in the background of the desktop session; it mounts removable
media as it arrives and offers to unmount from its tray icon. For a
one-off, `udisksctl` mounts and unmounts by hand.

## Examples
    udiskie -a -n -t &                   # automount, notify, tray icon
    udiskie -a -n -s &                   # the icon only while something is mounted
    udisksctl mount -b /dev/sda1         # mount one partition by hand
    udisksctl unmount -b /dev/sda1       # and unmount it
    udisksctl status                     # the drives udisks2 sees

## Options
-a, --automount    mount new devices as they appear
-n, --notify       show a notification for each
-t, --tray         show a tray icon
-s, --smart-tray   the tray icon only while there is something to show
-N, --no-notify    no notifications
-T, --no-tray      no tray icon

## Notes
- To start it with the desktop, add
  `exec-once = udiskie -a -n -s` to `~/.config/hypr/local.conf`.
- Media are mounted under `/run/media/$USER/LABEL`; unmount before pulling a
  stick out, or the last writes may not reach it.
