# command:  copal-notify
# purpose:  Put one sentence on this machine's screen: as a notification, a Hyprland banner, or on the console.
# why:      The fleet's "message" verb lands here -- the museum's "please stand
#           back". It uses whatever the machine has, in order of how much screen
#           it takes: a Hyprland overlay, a notification, or the whole console
#           on a machine with no desktop.
# see:      copal-fleet-exec, notify-send, hyprctl

## Use
Give it the text as one argument. Mostly it is called by the fleet, but it
works as a quick message to the screen from a script or over SSH.

## Examples
    copal-notify "Back in five minutes"
    copal-notify "Build finished"        # from the end of a long script

## Options
TEXT    the sentence to show (required; quote it)

## Notes
- Inside Hyprland it uses `hyprctl notify` for 8 seconds; otherwise
  `notify-send` as a critical notification; with neither it writes the
  text to `/run/copal/banner` and to tty1.
- It takes the text as a single argument and never re-splits or
  interprets it. The fleet limits a message to 200 characters of letters,
  digits and `. , ! ? : -` before it gets here.
