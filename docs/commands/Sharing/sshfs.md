# command:  sshfs
# purpose:  Mount a folder from another machine over SSH, and use it like a local one.
# why:      The catalogue's network folder with nothing to set up on the other
#           side: anywhere you can ssh to, you can mount. No root needed on
#           Copal.
# see:      ssh, smbd, rsync

## Use
Mount a remote folder onto an empty local one; programs then read and
write it as if it were here. Unmount with `fusermount3 -u` when done.

## Examples
    mkdir -p ~/mnt/pi
    sshfs pi:/home/you/Music ~/mnt/pi                # mount
    sshfs -o reconnect pi:Music ~/mnt/pi             # survive a dropped connection
    sshfs -p 2222 you@example.org:/srv ~/mnt/srv     # sshd on another port
    fusermount3 -u ~/mnt/pi                          # unmount

## Options
-p PORT             the SSH port
-o reconnect        reconnect after the connection drops
-o idmap=user       show the remote files as yours
-o follow_symlinks  follow links on the remote side
-f                  stay in the foreground (to see errors)

## Notes
- Unmounting is `fusermount3 -u`, not `umount`: a plain user may not
  umount.
- Everything goes through ssh, so `~/.ssh/config` hosts and keys work:
  `sshfs pi:` is enough when `pi` is a host there.
- A folder full of large files is slow to list over a slow link; for
  copying many files, `rsync` is faster.
