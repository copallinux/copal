# command:  robots
# purpose:  Escape the robots: every move, they step toward you, and collide into junk.
# why:      Part of the catalogue's BSD games: a five-minute puzzle, in any
#           terminal, with a score table.
# see:      snake, atc, nethack

## Use
Robots (`+`) move one step toward you (`@`) each turn. When two collide,
or one walks into a junk heap (`*`), they die: a point each. Clear the
field and the next one starts. You have no weapon, only a teleporter.

## Examples
    robots                               # play

    h j k l y u b n   (in the game) move, diagonals included
    .  or Space       stay where you are for a turn
    t                 teleport, somewhere random
    q                 quit

## Options
(none)

## Notes
- Standing still is a move: the robots close in and, lined up right,
  pile into each other.
- Scores are shared in `/usr/share/bsdgames` by the group `users`; Copal
  links the path the game expects and adds you to the group from
  24 Sep 2026. Before that, a score was shown and then lost.
