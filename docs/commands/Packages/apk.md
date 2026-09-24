# command:  apk
# purpose:  Alpine's package manager: install, remove, upgrade and ask about packages.
# why:      Every program on a Copal machine arrives through it -- the stages
#           call it hundreds of times, and Copal Apps runs it for you. This is
#           apk-tools 3: some answers online are for version 2.
# see:      doas, flatpak, lbu

## Use
Keep `/etc/apk/world` -- the list of packages you asked for -- and make the
system match it. `apk add` and `apk del` edit that list and then install or
remove whatever it now implies; everything else asks questions.

## Examples
    doas apk update                      # fetch the current package lists
    doas apk upgrade --available         # upgrade everything, the usual way
    doas apk add ripgrep                 # install, and record it in world
    doas apk del ripgrep                 # remove it and what only it needed
    apk search -e ripgrep                # is there a package by that exact name
    apk info -W /usr/bin/rg              # which package owns this file
    apk info -R rsync                    # what a package depends on
    doas apk add -t .build gcc make      # a named group, removed in one step later

## Options
add NAME...            install and add to world; NAME@testing for edge/testing
del NAME...            remove from world, and what nothing else needs
update                 refresh the package lists (-U does it before any command)
upgrade                install available upgrades
fix NAME               reinstall a package without touching world
info -W FILE           which package owns a file (--who-owns)
info -R / -r NAME      its dependencies / what depends on it
list --installed       what is installed; --upgradable, --orphaned
policy NAME            which repositories carry it, at which versions
-t NAME                with add: a virtual package, so the group is one name
-s                     simulate: show what would change, change nothing
--no-cache             use no local cache (apk 3 spells every --no-X this way)

## Notes
- `world` is the truth. A package installed as a dependency is removed when
  nothing in world needs it any more; to keep it, `apk add` it by name.
- `@testing` names a repository tag: `apk add foo@testing` works only when
  `/etc/apk/repositories` has a line beginning `@testing`. Copal adds it the
  first time a catalogue row asks. One untagged testing name in a list makes
  apk refuse the whole list.
- `-t` groups build dependencies: `apk add -t .build gcc make`, then
  `apk del .build` takes them all away. Copal Apps does exactly this with
  `.copal-store-build-*`.
- On a diskless system (before stage 3) a change survives a reboot only
  after `lbu commit`; Copal's installed system is not diskless.
