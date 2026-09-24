# command:  xmp
# purpose:  The Extended Module Player: tracker music in the terminal, with a channel-by-channel view.
# why:      The catalogue's other module player: small, and it can solo and mute
#           channels as it plays -- the way to hear how a tracker song is built.
# see:      openmpt123, fluidsynth

## Use
Play module files; the display shows the patterns and channels moving.
Number keys mute channels while it plays, so the parts can be heard one
at a time.

## Examples
    xmp song.mod                         # play
    xmp -l song.xm                       # loop it
    xmp -o song.wav song.xm              # render to a WAV instead of playing
    xmp -S 0,1 song.mod                  # only channels 0 and 1
    xmp -L                               # every format it reads

    1..0           (while playing) mute or unmute channels 1 to 10
    Space          pause;  f / b  next / previous pattern
    q              quit

## Options
-l, --loop             loop the song
-o, --output-file F    write to F instead of playing
-S, --solo LIST        play only these channels
-a, --amplify N        amplification, 0 to 3
-d, --driver NAME      the output driver
-L, --list-formats     the formats it reads

## Notes
- It comes from Alpine's testing repository (`xmp@testing`).
- For the most faithful playback of IT and newer formats, `openmpt123`
  is the reference; xmp is lighter and shows more.
