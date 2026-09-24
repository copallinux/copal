# command:  wpctl
# purpose:  Control PipeWire's audio: volume, mute, and which device plays.
# why:      Copal's sound is PipeWire with WirePlumber, started with each
#           session by copal-audio-start. The desktop's volume keys are wpctl
#           commands; so is changing the output from HDMI to headphones.
# see:      pactl, bluetoothctl

## Use
`wpctl status` lists the devices -- sinks are outputs, sources are
inputs -- each with an ID number, and marks the default with `*`. Every
other command takes an ID, or `@DEFAULT_AUDIO_SINK@` for the current
output.

## Examples
    wpctl status                                     # devices, IDs, the default
    wpctl get-volume @DEFAULT_AUDIO_SINK@            # the output's volume
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+        # up 5% (5%- for down)
    wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ # up, but never past 100%
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle       # mute, and back
    wpctl set-default 48                             # make device 48 the output
    wpctl inspect 48                                 # everything about it

## Options
status                    the whole graph: devices, sinks, sources, streams
get-volume ID             the volume, 1.00 being 100%
set-volume ID VOL[%][+-]  set, or step up or down
set-mute ID 1|0|toggle    mute, unmute, toggle
set-default ID            the default output or input
inspect ID                all of a node's properties
set-volume -l N ID VOL    go no higher than N (1.0 = 100%)

## Notes
- "Could not connect to PipeWire": no PipeWire is running for this user
  in this session -- typical over SSH or on a console. Run it from the
  desktop's terminal, or start it with `copal-audio-start`.
- IDs change between sessions. In a script, use `@DEFAULT_AUDIO_SINK@`
  and `@DEFAULT_AUDIO_SOURCE@`, not numbers.
- The RTKit warnings it prints first ("RTKit error ... ServiceUnknown")
  are harmless: there is no RTKit on Copal, and audio runs without it.
