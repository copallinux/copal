# command:  copal-code
# purpose:  Keep the source checkouts in ~/code: clone what is listed, pull what is there, then build it all.
# why:      A Copal machine arrives ready to work on its own projects. The list
#           of repositories lives on the boot partition, where you can edit it
#           from any computer before the card is even booted; this makes ~/code
#           match it, and hands over to copal-build.
# see:      copal-build, git, copal-guide

## Use
Run it as yourself, with no argument: it clones anything listed that is
missing, pulls (fast-forward only) anything that is there, and builds.
`add` and `rm` edit the list and need doas.

## Examples
    copal-code                           # clone, pull, build
    copal-code list                      # the list, and what is on disk
    doas copal-code add https://github.com/you/project
    copal-code                           # then clone it, as yourself
    doas copal-code rm project           # off the list; the checkout stays
    COPAL_NO_BUILD=1 copal-code          # clone and pull, build later

## Options
(none), sync    clone what is missing, pull what is there, then copal-build
list            each listed repository, and whether it is cloned
add URL...      add to the list (needs doas)
rm NAME...      remove from the list (needs doas); keeps the checkout
path            where the list is

## Notes
- The list is `copal-repos` on the boot partition (`/boot`), one URL per
  line, `#` for comments.
- `~/code/copal`, the repository the machine was built from, is always
  included and cannot be removed; repoint it with `git remote set-url`.
- Cloning tries SSH first, without prompting, and falls back to HTTPS; a
  machine with no SSH key yet still gets its checkouts. `copal-guide code`
  explains adding a key.
- A pull never forces: a checkout with local changes is warned about and
  left alone. A directory in the way that is not a checkout is skipped.
- Machines installed before 24 September 2026 have the Yodacon builder
  under this name; running stage 7 again installs this one, and the
  builder as copal-yodacon.
