# command:  tig
# purpose:  A text-mode browser for git history: the log, each commit's diff, blame.
# why:      The catalogue's git history reader: faster than scrolling
#           `git log -p`, and its blame view walks back through a line's past.
# see:      git, lazygit, gitui, delta

## Use
With no arguments it lists the commits; Enter opens one's diff in a
split below. It takes the same arguments as `git log`, and has views for
blame, status and refs.

## Examples
    tig                                  # the log
    tig README.md                        # commits that touched one file
    tig blame src/main.c                 # who changed each line
    tig status                           # stage and unstage, like git add -p
    tig --all                            # every branch

    Enter          (in tig) open the selection
    j k            move;  q  back, or quit
    /              search

## Options
blame FILE     the blame view
status         the status view
refs           branches and tags
--all          every ref, not just the current branch
PATH           only commits touching PATH

## Notes
- In the blame view, a comma on a line moves blame to the commit before
  it: the way to follow a line back.
- Settings go in `~/.tigrc` (or `~/.config/tig/config`).
