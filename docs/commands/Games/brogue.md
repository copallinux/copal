# command:  brogue
# purpose:  Brogue: a roguelike made to be learned -- twenty-six levels, no classes, beautiful in a terminal.
# why:      The catalogue's most approachable roguelike: fewer keys than NetHack,
#           a mouse that works, and a dungeon that shows you what it is doing.
# see:      nethack, angband

## Use
Descend twenty-six levels to the Amulet of Yendor and back out. You build
your character from what you find, not from a class. The mouse moves you
and describes what you point at; `?` lists the keys.

## Examples
    brogue                               # the menu
    brogue -n                            # a new game at once
    brogue -s 12345                      # a game from a seed (share it)
    brogue --scores                      # the high scores
    brogue -v game.broguerec             # watch a recording

    arrows / hjkl  (in brogue) move;  x  explore automatically
    i  s           inventory / search;  >  descend
    ?              every key;  Q  quit

## Options
-n               a new game, skip the menu
-s SEED          a new game from SEED
-o FILE          open a saved game
-v FILE          view a recording
--scores         print the scores
--size N         font size, 1 to 20 (in a window build)

## Notes
- `x` explores the level for you until something interesting happens;
  most of the game is choosing when to stop.
- Every game is recorded; recordings, saves and scores are kept in
  `~/.local/share/brogue`.
