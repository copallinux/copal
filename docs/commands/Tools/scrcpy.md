# command:  scrcpy
# purpose:  Show and control an Android phone on the desktop, over USB or Wi-Fi, through adb.
# why:      The store's phone mirror: the phone's screen in a window, typed on
#           with the keyboard, its sound on the Pi's speakers -- nothing
#           installed on the phone.
# see:      waydroid, adb

## Use
Turn on USB debugging on the phone (Developer options), plug it in and
accept the prompt on the phone, then run scrcpy. The phone's screen opens
in a window; the mouse and keyboard control it.

## Examples
    adb devices                          # is the phone seen and authorised?
    scrcpy                               # mirror and control it
    scrcpy -m 1024                       # a smaller picture, for a slower board
    scrcpy --no-audio                    # picture only
    scrcpy -e                            # a phone connected over Wi-Fi (adb tcpip)
    scrcpy --record=phone.mp4            # record the screen while mirroring

## Options
-m, --max-size=N     limit the longer side to N pixels
-b, --video-bit-rate=R   the video bit rate
--no-audio           no sound forwarding
-s, --serial=ID      choose a phone when several are connected
-e, --select-tcpip   use the phone connected over TCP/IP
--record=FILE        record while mirroring

## Notes
- "adb: no permissions" means the phone's USB device is not yours: the
  Android udev rules (an optional of scrcpy) give it to `plugdev`, and
  `copal-store access` adds you to that group.
- The first connection must be accepted on the phone: "Allow USB
  debugging?".
