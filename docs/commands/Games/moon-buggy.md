# command:  moon-buggy
# purpose:  Drive a buggy across the moon, jumping craters and blasting rocks -- in a terminal.
# why:      The store's terminal arcade game: one key to jump, one to fire,
#           and it gets faster. Playable anywhere, over SSH included.
# see:      robots, snake, nethack

## Use
The buggy drives itself; jump over the craters with Space and clear
rocks with the laser. The timing of a jump is fixed, so the skill is
choosing when.

## Examples
    moon-buggy                           # play
    moon-buggy -n                        # skip the title screen
    moon-buggy -s                        # the high scores, and exit

    Space  j       (in the game) jump
    a  l           fire the laser
    q              quit (the score is kept)

## Options
-n, --no-title       no title screen
-s, --show-scores    print the high scores and exit
-m, --mesg           keep other users' messages off the screen

## Notes
- A jump can only start with the wheels on the ground: jumping early is
  the usual way to land in the next crater.
- It comes from Alpine's testing repository (`moon-buggy@testing`).
