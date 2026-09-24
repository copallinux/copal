# command:  redshift
# purpose:  Warm the screen's colour after sunset, following the time of day at your location.
# why:      The catalogue's night colour for the X11 desktop (i3). It has no
#           Wayland method, so on Hyprland it cannot reach the screen; there,
#           hyprsunset and gammastep -- installed with it as optionals -- do
#           the same job.
# see:      hyprctl

## Use
Give it your latitude and longitude; it shifts the colour temperature
through the day. `-O` sets one temperature and leaves it; `-x` resets.

## Examples
    redshift -l 51.5:-0.1                # follow the sun at London (runs until stopped)
    redshift -l 51.5:-0.1 -t 6500:3500   # daytime and night temperatures
    redshift -O 4000                     # one warm setting, now
    redshift -x                          # back to normal
    redshift -m list                     # the methods this build has

## Options
-l LAT:LON      your location
-t DAY:NIGHT    colour temperatures (default 6500:4500)
-O TEMP         one-shot: set TEMP and exit
-o              one-shot: set the current temperature and exit
-x              reset the screen
-P              reset the gamma first (for -O)
-m METHOD       randr, vidmode or drm

## Notes
- On Hyprland it has nothing to talk to: this build's methods are X11's
  (randr, vidmode) and bare DRM. Use `hyprsunset -t 4000`, Hyprland's own,
  or `gammastep`, redshift's Wayland-capable fork with the same options.
- Settings can live in `~/.config/redshift/redshift.conf` instead of on
  the command line.
