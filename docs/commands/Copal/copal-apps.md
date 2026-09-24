# command:  copal-apps
# purpose:  Copal Apps: the window for browsing Copal's programs by shelf, installing them, and watching installs happen.
# why:      The graphical face of copal-store. It never installs anything
#           itself and never needs root: Install opens a terminal running
#           `doas copal-store install`, and the window follows the progress.
#           At the full monty's first login it opens on the slideshow of the
#           queued programs arriving.
# see:      copal-store, copal-install, copal-menu

## Use
Open it from the menu or the command line. Shelves on the left, programs
with their status in the middle, one program in full on the right: its
picture, two sentences, where it comes from and how it installs. While
an install runs, it shows each program arriving with three progress bars.

## Examples
    copal-apps                           # the shelves and programs
    copal-apps gimp                      # opened on one program
    copal-apps --progress                # the install running now, as a slideshow
    copal-apps --follow                  # the slideshow, only if something is installing

## Options
ID            open on that program
--progress    the running install's slideshow: the run, the program, the step
--follow      the same, but only when an install is queued or running

## Notes
- Everything it shows comes from copal-store (`copal-store rows`,
  `copal-store playbook ID`) and the event stream it writes to
  `/var/log/copal/events`: the terminal and the window always agree.
- Pictures are the gallery's, fetched once into `~/.cache/copal-apps`;
  a program without one shows its icon.
- It needs a desktop (GTK); on a console, `copal-store` alone gives the
  same shelves as terminal menus.
