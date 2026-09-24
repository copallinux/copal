# command:  atc
# purpose:  Air Traffic Control: route planes through your airspace without a collision.
# why:      Part of the catalogue's BSD games, and the best of them -- unplayable
#           until you have read `man atc`, and excellent afterwards.
# see:      robots, snake

## Use
Planes enter at the edges; guide each to its exit or airport at the right
altitude, and keep them apart. Every command starts with the plane's
letter, then the action and its value, and Enter sends it; `?` lists
what may come next at any point.

## Examples
    atc                                  # the default airspace
    atc -l                               # the airspaces there are
    atc Killer                           # a harder one
    atc -s                               # the scores
    man atc                              # read this first

## Options
-l          list the scenarios
-s          print the score table
SCENARIO    play that airspace: Default, Atlantis, Killer, OHare

## Notes
- `ba5` sends plane b to 5000 feet; `btd` turns it to heading east.
  Directions are the eight keys around `s`: `w` north, `e` north-east,
  `d` east, round to `q` north-west.
- Planes enter at 7000 feet and must leave through their exit at 9000,
  or land at their airport by going to 0 directly over it.
