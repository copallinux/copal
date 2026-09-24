# command:  adventure
# purpose:  Colossal Cave Adventure: the first text adventure, from 1977.
# why:      Part of the catalogue's BSD games (bsd-games): the ancestor of Zork
#           and of every text adventure since, typed a command at a time.
# see:      frotz, nethack

## Use
Read the description, type a command of one or two words -- `go north`,
`get lamp`, `open grate` -- and read what happens. Map the cave on
paper as you go; that is how it was meant to be played.

## Examples
    adventure                            # start (answer "no" to the instructions, or read them)

    enter building     (in the cave) move, by direction or by place
    get lamp           take things;  inventory  what you carry
    look               describe the place again
    save               stop here, to continue later
    quit               end the game, with a score

## Options
(none)

## Notes
- The first thing to do is take the lamp. The cave is dark.
- It understands the first five letters of a word: `inven` is
  inventory.
- `help` and `info` are commands too: the game explains itself.
