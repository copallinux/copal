# command:  syncthing
# purpose:  Keep folders in sync between your machines, directly, with no server in between.
# why:      The catalogue's continuous sync: a folder on the Pi and the same
#           folder on the Mac or a phone stay identical, over the LAN or the
#           internet, encrypted.
# see:      rsync, unison, croc

## Use
Run it as yourself; it serves a web page at 127.0.0.1:8384 where you add
the other machines (by their device ID) and choose which folders to
share. After that it works in the background.

## Examples
    syncthing                            # start it (and open the web page)
    syncthing serve --no-browser         # start without opening a browser
    syncthing device-id                  # this machine's ID, to give the others
    syncthing paths                      # where its config and database are
    syncthing browser                    # open its web page in the browser

## Options
serve                  run it (the default command)
  --no-browser         with serve: do not open the web page
  --gui-address=URL    with serve: the page elsewhere, e.g. 0.0.0.0:8384
device-id              print this device's ID
paths                  where its files are
-H, --home=PATH        another config and database directory

## Notes
- Run it as yourself, not the system service: the service runs as the
  user `syncthing`, which cannot read or write your home folder.
  `exec-once = syncthing serve --no-browser` in `~/.config/hypr/local.conf`
  starts it with the desktop.
- To see the web page from another machine, an SSH tunnel keeps it
  private: `ssh -L 8384:127.0.0.1:8384 pi`, then browse to
  localhost:8384 there.
- A deleted file is deleted everywhere. Turn on file versioning for a
  folder if that worries you.
