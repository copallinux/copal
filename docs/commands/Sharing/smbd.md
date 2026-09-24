# command:  smbd
# purpose:  Samba's file server: share folders with Windows and macOS machines over SMB.
# why:      The catalogue's way to make the Pi's files appear in Finder or
#           Explorer like any network drive. Alpine's default configuration
#           already shares each user's home folder, once the user has a Samba
#           password.
# see:      sshfs, syncthing, rc-service

## Use
Give your account a Samba password, start the service, and connect from
the other machine: `smb://PI/yourname` in macOS Finder (Cmd-K), or
`\\PI\yourname` in Windows Explorer. More shares are sections in
`/etc/samba/smb.conf`.

## Examples
    doas smbpasswd -a $USER              # a Samba password for your account (once)
    doas rc-service samba start          # start it now
    doas rc-update add samba             # and at every boot
    testparm -s                          # check smb.conf, and print what is in force
    smbd -b | head                       # how this Samba was built

## Options
-F, --foreground      run in the foreground (for debugging)
-i, --interactive     run interactively, logging to the terminal
-s, --configfile=F    another configuration file
-b, --build-options   print the build options
-V, --version         the version

## Notes
- The Samba password is separate from your login password: `smbpasswd`
  sets it, and a share refuses you until it is set.
- The service is `samba`, which starts smbd and nmbd together; the
  command itself is rarely run by hand.
- A share for a folder of its own:
  `[music]` then `path = /home/you/Music` and `read only = no` in
  `smb.conf`, then `doas rc-service samba restart`.
