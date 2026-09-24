# command:  copal-camera
# purpose:  Open the camera application, whichever one this machine has.
# why:      One answer to "the camera", asked from three places -- the Camera
#           entry in copal-menu, Super+Shift+B on both desktops, and the camera
#           role in a copal-desk layout. Birdshot first, from ~/code; then
#           other camera programs.
# see:      birdshot, copal-desk

## Use
Run it, or press Super+Shift+B; it opens the first camera program it
finds: birdshot's window, else birdshot's browser viewfinder, else another
installed camera application. `--which` says which, and opens nothing.

## Examples
    copal-camera                         # open the camera
    copal-camera --which                 # print the command it would run
    CAMERA=cheese copal-camera           # use another program, once

## Options
--which     print the command it would run; exit 1 if there is none

## Notes
- `$CAMERA` overrides the choice, as `$BROWSER` does for the browser:
  set it in `~/.profile.local` and every place that opens "the camera"
  follows.
- Birdshot is one of the checkouts stage 7 builds into `~/.local/bin`;
  copal-camera looks there even when the session did not read
  `~/.profile`.
