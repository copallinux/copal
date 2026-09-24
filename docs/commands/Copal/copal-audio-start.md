# command:  copal-audio-start
# purpose:  Start the sound server -- PipeWire, WirePlumber and the PulseAudio shim -- for this login.
# why:      On Copal there is no systemd to start PipeWire per user, and it must
#           not run as a system service. This starts the three parts once per
#           session, skipping any already running, and does nothing at all on a
#           machine without PipeWire.
# see:      wpctl, pipewire, pactl

## Use
The i3 session runs it at startup. Run it by hand when a program says there
is no sound server; it is safe to run again.

## Examples
    copal-audio-start                    # start whatever is missing
    wpctl status                         # then see the devices
    tail $XDG_RUNTIME_DIR/copal-audio.log   # what the servers said

## Options
(none)

## Notes
- It starts `pipewire`, then `wireplumber` (the session manager, which
  connects devices) and `pipewire-pulse` (so PulseAudio programs play),
  each only if installed and not already running for your user.
- Their output goes to `copal-audio.log` in `$XDG_RUNTIME_DIR` (or
  `/tmp`), which is cleared at reboot.
- Stage 10 installs PipeWire and writes this; the i3 session's startup
  file is what calls it.
