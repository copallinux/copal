# command:  pactl
# purpose:  PulseAudio's control command, answered here by PipeWire.
# why:      Copal runs pipewire-pulse, so programs written for PulseAudio
#           work unchanged -- and pactl, which most answers online use, works
#           too. For everyday volume and output, wpctl is the native tool.
# see:      wpctl

## Use
List the outputs (sinks) and inputs (sources) by name, change their
volume, and move a playing stream from one device to another. The
special names `@DEFAULT_SINK@` and `@DEFAULT_SOURCE@` save looking them up.

## Examples
    pactl info                                   # the server: PipeWire, via pulse
    pactl list short sinks                       # outputs, one line each
    pactl set-sink-volume @DEFAULT_SINK@ +5%     # louder
    pactl set-sink-mute @DEFAULT_SINK@ toggle    # mute
    pactl set-default-sink alsa_output.platform-hdmi   # a named output as default
    pactl list short sink-inputs                 # what is playing right now
    pactl move-sink-input 42 @DEFAULT_SINK@      # move stream 42 to the default output
    pactl subscribe                              # watch events as they happen

## Options
info                            the server and its defaults
list [short] TYPE               sinks, sources, sink-inputs, cards, modules
set-sink-volume NAME VOL        50%, +5%, -5%
set-sink-mute NAME 1|0|toggle   mute
set-default-sink NAME           the default output
move-sink-input N SINK          move a playing stream
-f, --format=json               JSON output

## Notes
- `pactl info` saying "Server Name: PulseAudio (on PipeWire ...)" is
  right: it is PipeWire's pulse layer. There is no PulseAudio daemon,
  and `pulseaudio -k` answers are not for this system.
- "Connection refused": no PipeWire in this session -- over SSH, say.
  See `wpctl`.
