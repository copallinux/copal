# command:  openmpt123
# purpose:  Play tracker music -- MOD, XM, S3M, IT and dozens more -- in the terminal, accurately.
# why:      The catalogue's module player, built on OpenMPT's library: the most
#           faithful playback of the music of the Amiga and PC demoscene.
# see:      xmp, fluidsynth

## Use
Give it module files; it plays them in order and shows the pattern
position. It can also render a module to a WAV or FLAC file.

## Examples
    openmpt123 song.xm                   # play
    openmpt123 *.mod                     # a folder, in order
    openmpt123 --shuffle ~/Music/mods/*  # in any order
    openmpt123 --render song.it          # write song.it.wav, and play nothing
    openmpt123 --info song.s3m           # title, format, length, channels

    Space          (while playing) pause
    h  l           seek 10 s back / forward (j k: 1 s)
    n  m           previous / next file
    3  4           quieter / louder;  q  quit

## Options
--render          render each file to a WAV beside it
--info            print the module's details only
--shuffle         shuffle the files
--repeat N        repeat each song N times (-1 forever)
--gain DB         the volume, in dB
-q, --quiet       no display
--driver NAME     the audio output
--help-keyboard   every key it answers while playing

## Notes
- Modules are tiny: a three-minute XM is often under 100 kB. The
  Mod Archive (modarchive.org) holds over a hundred thousand.
- If there is no sound, `--driver help` lists the outputs this build
  has.
