# command:  fluidsynth
# purpose:  A software synthesiser: play MIDI files, or MIDI keyboards, through a SoundFont.
# why:      The catalogue's MIDI synthesiser, installed with a General MIDI
#           SoundFont (TimGM6mb) so a .mid file makes sound straight away, and
#           a USB keyboard becomes an instrument.
# see:      openmpt123, xmp, alsamixer

## Use
Give it a SoundFont -- the instrument samples -- and MIDI files to play,
or leave it running for a keyboard or a sequencer to play through. It
starts an interactive prompt unless told not to.

## Examples
    fluidsynth -i -a alsa /usr/share/soundfonts/default.sf2 song.mid   # play a file
    fluidsynth -F song.wav /usr/share/soundfonts/default.sf2 song.mid  # render to WAV
    fluidsynth -a alsa /usr/share/soundfonts/default.sf2   # a synth for a keyboard
    aconnect -l                          # MIDI ports; connect keyboard to synth with aconnect A B

## Options
-a DRIVER        the audio driver: alsa or pulseaudio (both reach PipeWire)
-i, --no-shell   no prompt: play and exit
-F FILE          render to FILE instead of playing
-g GAIN          the volume, 0 to 10 (default 0.2)
-r RATE          the sample rate
-q, --quiet      no banner
-n, --no-midi-in no MIDI input

## Notes
- Without `-i` it waits at its own `>` prompt after the file ends;
  `quit` leaves.
- The default gain is quiet on purpose; `-g 1` for a louder start.
- A pages-long run of "ALSA lib ... Unknown PCM" at start is ALSA probing
  devices that do not exist; it is noise, not failure.
- Better SoundFonts are a download away: any `.sf2` file works the same.
