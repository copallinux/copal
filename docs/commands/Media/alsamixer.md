# command:  alsamixer
# purpose:  The sound card's own mixer, in the terminal: every hardware level and switch.
# why:      Stage 10 installs alsa-utils with it. Most volume is PipeWire's
#           (wpctl), but a card's hardware controls -- a headphone switch,
#           a muted input, HDMI -- are set here.
# see:      wpctl, pactl

## Use
It opens on the default device, which on Copal is PipeWire: one volume.
F6 chooses the sound card itself, and shows every control the hardware
has. Arrows move and change; M mutes.

## Examples
    alsamixer                            # the default device (PipeWire)
    alsamixer -c 0                       # the first sound card's own controls
    alsamixer -V all                     # playback and capture together
    aplay -l                             # the cards, and their numbers

    F6             (in alsamixer) choose a card
    Left Right     choose a control;  Up Down  change it
    M              mute / unmute (MM at the foot means muted)
    F4             the capture (recording) controls;  Esc  quit

## Options
-c N        open card N
-D DEVICE   open a named ALSA device
-V VIEW     playback, capture or all
-g          no colours

## Notes
- "MM" under a control is muted, "00" is playing. A muted Master or
  Headphone control is the usual reason for silence with the volume
  up.
- `doas alsactl store` keeps hardware levels across reboots; the
  `alsa` service restores them at boot.
