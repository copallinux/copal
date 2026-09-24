# command:  gtypist
# purpose:  GNU Typist: touch-typing lessons and drills in the terminal.
# why:      The catalogue's typing tutor: lessons from the home row up, with
#           speed and error rates, in any terminal -- the course
#           `copal-guide keyboard` points to.
# see:      copal-morse

## Use
Start it and pick a course from the menu: the Q series teaches QWERTY
from nothing, others Dvorak, Colemak and numbers. Each lesson explains,
then drills; mistakes show as you make them.

## Examples
    gtypist                              # the menu of courses
    gtypist -b                           # track your personal best speeds
    gtypist -e 3                         # allow up to 3% errors before a repeat
    gtypist -n                           # no timer: accuracy only

## Options
-b, --personal-best    keep your best speeds
-e, --max-error=PCT    the error rate a drill may have (default 3)
-n, --notimer          turn off the speed timer
-t, --term-cursor      use the terminal's own cursor

## Notes
- Escape leaves a lesson; the menu's last line exits.
- It comes from Alpine's testing repository (`gtypist@testing`).
