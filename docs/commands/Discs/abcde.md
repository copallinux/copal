# command:  abcde
# purpose:  A Better CD Encoder: rip a CD, look up its track names, encode and tag, in one command.
# why:      The catalogue's CD-to-music-library tool: cdparanoia to rip, a
#           database lookup for the names, an encoder for FLAC, Ogg or MP3.
# see:      cdparanoia, cmus

## Use
Insert the CD and run it. It looks up the disc, asks you to confirm the
names, rips every track and encodes them into folders by artist and
album.

## Examples
    abcde                                # rip and encode, with the defaults
    abcde -o flac                        # to FLAC
    abcde -o flac,ogg                    # two formats at once
    abcde -N -o flac                     # no questions (unattended)
    abcde -c ~/.abcde.conf               # with your own settings

## Options
-o FORMATS   output formats: flac, ogg, mp3, opus...
-N           non-interactive: accept the lookup's answer
-d DEV       the CD drive
-c FILE      another configuration file
-x           eject the CD when done

## Notes
- Settings go in `~/.abcde.conf`: `OUTPUTTYPE`, `OUTPUTDIR`, the naming
  pattern.
- Each format needs its encoder. Its default, Ogg, needs `oggenc`
  (vorbis-tools), which abcde does not pull in: the catalogue row brings
  it and `flac` from 24 Sep 2026. MP3 needs `lame`.
- Not on 32-bit ARMv7: its row is gated off there.
