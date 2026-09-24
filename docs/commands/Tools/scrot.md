# command:  scrot
# purpose:  Take a screenshot on an X11 desktop: the screen, a window, or a region.
# why:      The screenshot tool for Copal's i3 desktop, which runs on X11. On
#           the Hyprland desktop (Wayland) it cannot see the screen: there,
#           Super+Shift+S (copal-shot) and grim do the job.
# see:      copal-shot, tesseract

## Use
With no arguments it saves the whole screen as a PNG in the current
folder, named by the date and time. `-s` lets you drag out a region,
`-u` takes the focused window, `-d` waits first.

## Examples
    scrot                                # the whole screen, into this folder
    scrot ~/Pictures/%Y-%m-%d-%H%M%S.png # to a named file
    scrot -s                             # drag out a region
    scrot -u -d 3                        # the focused window, after 3 seconds
    scrot -e 'mv $f ~/Pictures/'         # run a command on the saved file

## Options
-s, --select      choose a region, or click a window
-u, --focused     the focused window
-d, --delay SEC   wait SEC seconds first
-c, --count       show a countdown with -d
-p, --pointer     include the mouse pointer
-e, --exec CMD    run CMD on the saved image ($f is its name)
-q, --quality N   image quality, 1-100

## Notes
- On Wayland it saves a black or empty picture, or fails: it asks the X
  server for the screen, which only holds X programs. Use `grim` (the
  whole screen), `grim -g "$(slurp)"` (a region) or Super+Shift+S.
- `%Y`, `%m` and the other date codes in the file name come from
  strftime.
