# command:  htop
# purpose:  An interactive process viewer: CPU, memory, and every process, live.
# why:      The task manager on Copal's i3 desktop, where Super+T opens it, and
#           the first thing to run when a machine feels slow.
# see:      copal-tm, btop, rc-status

## Use
The meters at the top show each core, memory and swap; the list below
shows the processes, the busiest first. Keys along the bottom sort,
search and filter the list.

## Examples
    htop                                 # everything
    htop -u $USER                        # only your processes
    htop -t                              # as a tree: which started which
    htop -p 1234,5678                    # only these process IDs

    F3  F4         (in htop) search / filter
    F5             tree view
    F6             sort by a column
    F10            quit

## Options
-u USER        only USER's processes
-t, --tree     start in tree view
-p PIDS        only these processes
-d N           the update delay, in tenths of a second
-s COLUMN      sort by COLUMN

## Notes
- F2 is the setup screen: meters, columns and colours, saved to
  `~/.config/htop/htoprc`.
- Memory shown as "used" leaves out the page cache; a nearly full bar of
  cache is normal.
