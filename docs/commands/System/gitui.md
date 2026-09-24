# command:  gitui
# purpose:  A fast terminal interface for git, in tabs: status, log, files, stashes.
# why:      The catalogue's other git interface: quick to start on large
#           repositories, with every key it takes shown at the bottom.
# see:      git, lazygit, tig

## Use
Start it in a repository. Tabs along the top -- Status, Log, Files,
Stashing, Stashes -- switch with the number keys; the bar at the bottom
lists the keys for the current view.

## Examples
    gitui                                # the repository here
    gitui -d ~/code/copal/.git           # another repository

    1-5            (in gitui) switch tabs
    Enter          stage or unstage a file (Status)
    c              commit
    Esc / q        back / quit

## Options
-d, --directory DIR   the git directory to open
-t, --theme FILE      a theme file from its config directory
-l, --logging         write a log (to find a problem)

## Notes
- Its key bindings and theme are files in `~/.config/gitui`.
- It does what git does: a push that needs a password or a key follows
  git's own settings.
