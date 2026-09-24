# command:  ascitty
# purpose:  A raytraced city of typeable characters, in real time in a terminal -- with a taxi game inside.
# why:      One of the checkouts in ~/code, built by copal-build: a showpiece for
#           a colour terminal, and a test of one. The same city runs on a
#           Commodore Plus/4.
# see:      copal-build, copal-terminal-theme

## Use
Start it and a cab drives itself round the city, taking fares. Touch a key
and you are driving: `wasd` is the vehicle, the arrows are the view, and
`\` hands it back to the autopilot. The frame is the size of the window,
so a bigger terminal is a bigger city.

## Examples
    ascitty                              # the city, the cab driving itself
    ascitty --play                       # at the wheel from the start
    ascitty --walk                       # on foot instead
    ascitty --copter                     # above the city
    ascitty --mode ascii --color none    # 7-bit, no colour: the mode the name is about
    ascitty --shot 30 > city.txt         # render 30 frames, keep the last as text
    ascitty --bench                      # 200 frames as fast as it can, and a report

    w a s d          (in the city) throttle, steer left, brake/reverse, steer right
    q  e             hard left / hard right
    space  z         brake / handbrake
    t                get out and walk
    \                back to the autopilot;  Esc  quit

## Options
--play          drive from the start, no autopilot
--walk          on foot
--copter        in the air
--mode M        ascii or unicode (default unicode)
--color D       true, 16 or none (default: from $COLORTERM)
--size WxH      a fixed frame instead of the window's size
--fps N         frame rate cap (default 30)
--seed N        another city
--sky N         start at phase N of 12: 0 night, 3 sunrise, 5 noon, 8 sunset
--shot [N]      render N frames, print the last, exit
--bench         measure the renderer

## Notes
- The terminal is the bottleneck, not the renderer: a big frame takes the
  renderer a millisecond and the terminal twenty. Bands of the picture a
  frame behind mean the terminal is falling behind -- a smaller window or
  `--fps 15` fixes it.
- Hold the keys: the throttle winds on while it is down, as the steering
  does, so a tap does very little.
- `--color` follows `$COLORTERM`; set `--color 16` if the colours look
  wrong over SSH.
