# command:  zangband
# purpose:  ZAngband: Angband with a wilderness, towns, and Zelazny's Amber above the dungeon.
# why:      The catalogue's sprawling Angband variant: a whole overworld of towns
#           and dungeons rather than one town and one descent.
# see:      angband, nethack, brogue

## Use
Make a character, walk the wilderness between towns, and pick which
dungeons to take on. `?` is the help and `=` the options, as the title
screen says.

## Examples
    zangband                             # play

    arrows / hjkl  (in zangband) move
    ?  =           help / options
    g  i  w        pick up / inventory / wield
    <  >           stairs up / down
    Ctrl-X         save and quit

## Options
-n          a new character
-u<name>    play the character NAME: zangband -uRodney

## Notes
- It starts only for a member of the group `users`, which owns its score
  and save directories: otherwise "Cannot create the
  '/usr/lib/zangband/apex/scores.raw' file!" and a fatal error. Copal adds
  you from 24 Sep 2026; before that, `doas adduser $USER users`, then log
  out and in.
- Saves are shared in `/usr/lib/zangband/save`, by character name.
