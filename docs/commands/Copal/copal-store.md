# command:  copal-store
# purpose:  Copal Apps from the command line: find programs by what they do, install and remove them, with everything they need.
# why:      The engine behind Copal Apps and the menu's Install: every program
#           Copal offers is a playbook, and copal-store runs it -- from an
#           Alpine package, a Flatpak, a build from GitHub source, or a clone
#           into ~/code -- then adds its man page, its optionals (plugins,
#           codecs, format loaders) and the groups it needs.
# see:      copal-apps, copal-install, apk

## Use
`list` and `info` to look; `install` and `remove` to change things (they
ask for doas). With no arguments it opens the store window, or terminal
menus where there is no desktop.

## Examples
    copal-store list Games               # a shelf: status, id, name
    copal-store info gimp                # what it is, where from, how it installs
    doas copal-store install gimp ffmpeg # install, with man pages, optionals, access
    doas copal-store remove gimp         # and remove
    copal-store optionals                # the optionals table
    doas copal-store optionals --installed   # catch up everything already installed
    doas copal-store access              # the groups installed programs need
    copal-store summary                  # what each build did: result, size, "with", "absent"

## Options
list [SECTION]         every program, or one shelf
info ID                one program: description, source, install method
install ID...          install (with man pages, optionals and access)
remove ID...           remove
recipes                the programs built from source
optionals [PKG...|--installed]   the plugins and helpers; install them
access [USER]          the groups programs need: plugdev, wireshark, dialout...
manpages PKG...        the man pages of these packages
summary                the build record
log ID                 one build's full log

## Notes
- A build from source records what it compiled in ("with") and what it
  could not find ("absent") in the summary: the answer to which formats
  and codecs a build has.
- Its logs are in `/var/log/copal-store`; the event stream Copal Apps
  reads is `/var/log/copal/events`.
- Installed on medium and full installs (stage 18).
