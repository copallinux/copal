# command:  birdshot
# purpose:  Bird and sky capture for the Raspberry Pi HQ Camera, from the command line.
# why:      Copal's camera. copal-build builds the C++ pipeline from the
#           birdshot checkout; birdshot-gui is its window (Super+Shift+B), and
#           this is the same pipeline for a script or an SSH session.
# see:      copal-camera, copal-build

## Use
Capture with metered auto-exposure and quality gates that drop blurred
or badly exposed frames, fast bursts, timelapses, or a watch on the sky
that fires when a bird crosses it. Then stamp the EXIF and assemble a
session's frames into a video.

## Examples
    birdshot info                        # the camera, its modes, storage, calibration
    birdshot doctor                      # what is missing or wrong, and the fix
    birdshot capture -n 200              # 200 frames through the full pipeline
    birdshot rapid -n 500                # the fastest path: flat, timed names
    birdshot timelapse -i 5 -n 720       # one frame every 5 s, for an hour
    birdshot birdflight -n 20            # watch the sky; fire on a bird, 20 takes
    birdshot sessions                    # what has been captured, by session
    birdshot assemble SESSION --fps 60   # a session's frames into an MP4 (ffmpeg)
    birdshot sun                         # the sun now, and today's events

## Options
capture [-n N] [-v]        the full pipeline, with quality gates
rapid [-n N]               fastest single photos
timelapse [-i SEC] [-n N]  one frame every SEC seconds
birdflight [-n TAKES]      trigger on a bird
gui [--port N]             the live pipeline in a browser
exif DIR                   stamp EXIF into a session, losslessly
assemble DIR [--fps N]     frames to a movie; --out FILE
sun / plan / site          where the sun is, a plan for the days ahead, your site
info / sessions / doctor / selftest   the housekeeping
--config PATH              another settings file

## Notes
- It is for an IMX477 -- the Pi HQ Camera. Other cameras are not what
  its exposure ladder and gates are tuned for; `birdshot doctor` says
  what it found.
- Settings live in `~/.config/birdshot/settings.json`; every command
  reads it, and `--config` points at another.
- The first run of the window offers a calibration wizard, about a
  minute. Its numbers are what the quality gates judge by: run it.
