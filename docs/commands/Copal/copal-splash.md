# command:  copal-splash
# purpose:  Draw the i3 desktop's key bindings onto the wallpaper, so the first screen teaches the keys.
# why:      On the X11 desktop there is no welcome screen, and a tiling window
#           manager with no visible menu is a blank wall to a newcomer. The
#           keys, printed where the wallpaper would be, are the way in.
# see:      i3, copal-guide, feh

## Use
i3 runs it at startup. Run it yourself after editing `~/.config/i3/keys.txt`
to see the change without logging out.

## Examples
    copal-splash                         # redraw the desktop now
    rm ~/.cache/copal-splash.png; copal-splash   # force a fresh image

## Options
(none)

## Notes
- It draws the bindings and group headings from `keys.txt` (the section
  from START SOMETHING to IF SOMETHING), at the screen's size from xrandr,
  with a line of the essential keys along the bottom.
- The image is `~/.cache/copal-splash.png` and is remade only when
  `keys.txt` is newer, so logging in costs nothing.
- It needs ImageMagick to draw and feh to show; without them the desktop
  is a plain colour, set with xsetroot. It is for the i3 desktop only;
  Hyprland has its own wallpaper and Super+/ for the keys.
