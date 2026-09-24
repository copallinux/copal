# command:  vis
# purpose:  A small vi-like editor with multiple selections and sam's structural regular expressions.
# why:      The catalogue's lean modal editor: vi's keys in a fraction of vim's
#           size, plus multiple cursors and sam-style editing for changing
#           many places at once.
# see:      vim, nvim, hx

## Use
Edit as in vi. What it adds: several selections at once, all edited
together, and `:x/pattern/ command` to select every match in the
selection and act on each.

## Examples
    vis notes.txt                        # edit

    i  Esc          (in vis) insert / normal
    Ctrl-N          select the word, then the next match, and the next...
    I  A            insert at the start / end of every selection
    :x/foo/ c/bar/  change every foo in the selection to bar
    :w  :q          write / quit

## Options
-v    the version
--    everything after is a file name

## Notes
- Configuration is Lua: `~/.config/vis/visrc.lua`.
- It is vi, not vim: no `:s///`. `:x/old/ c/new/` over the selection
  (`:,` for the whole file) does the same job.
