# command:  nethack
# purpose:  NetHack: the deepest of the roguelikes -- a dungeon of letters, and everything interacts.
# why:      The catalogue's first roguelike and its deepest: a game people have
#           played for thirty-five years, in any terminal, over SSH included.
# see:      brogue, angband, zangband

## Use
Pick a role, a race and a name, and descend to retrieve the Amulet of
Yendor. You are the `@`. Every key is a command; `?` lists them. Death
is permanent, and there is a lot of it.

## Examples
    nethack                              # play
    nethack -u Rodney                    # play as Rodney (and resume his save)
    nethack -s                           # the high scores

    h j k l y u b n   (in nethack) move, including diagonally
    i  ,  d        inventory / pick up / drop
    s  #pray       search / pray (once in a while)
    S              save and quit;  ?  help

## Options
-u NAME      the character's name; a saved game of that name resumes
-s           show the scores
-p ROLE      choose the role: Valkyrie, Wizard, Samurai...
-X           explore mode: no death, no score

## Notes
- Options go in `~/.nethackrc`: `OPTIONS=number_pad:1` for the numeric
  keypad, `OPTIONS=color`, `OPTIONS=autopickup,pickup_types:$`.
- `S` saves; next time, the same name picks up where you left.
- A Valkyrie is the gentlest start.
