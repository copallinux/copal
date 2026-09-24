# command:  snake
# purpose:  Collect the money and reach the exit, with a snake after you.
# why:      Part of the catalogue's BSD games: not the phone game, the older one,
#           where you are the one being chased.
# see:      robots, atc

## Use
You are the `@`. Pick up the money (`$`) -- a new one appears each time
-- and leave through the exit (`#`) before the snake (`S` and its `s`
body) catches you. As you get richer, the snake gets hungrier.

## Examples
    snake                                # play, on the whole screen
    snake 60 20                          # a smaller field: width, height
    snake -s                             # the scores, and exit

    h j k l  or arrows   (in the game) move
    Space                warp out of a tight spot, at a price

## Options
WIDTH HEIGHT   the size of the field (default: the screen)
-s             print the scores and exit

## Notes
- Only leaving by the exit scores. Being eaten is worth nothing.
- Scores go in the shared table (`/usr/share/bsdgames`), kept from
  24 Sep 2026 for members of `users`, which Copal adds you to.
