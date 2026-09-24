# command:  copal-widgets
# purpose:  The clock, date and weather on the wallpaper: show them, hide them, and see where they come from.
# why:      The desktop layer's widgets. The theme's own widget shell,
#           quickshell, is not packaged for Alpine, so waybar draws them; this
#           command turns them on and off without touching the bar, and seeds
#           the theme's own widget file for the day quickshell arrives.
# see:      copal-bar, copal-theme

## Use
`--off` hides them, `--on` brings them back, both at once; `--status`
says which are running and from where.

## Examples
    copal-widgets --status               # what is running
    copal-widgets --off                  # hide the clock and weather now
    copal-widgets --on                   # show them again
    copal-guide widgets                  # the longer version

## Options
--on        show the widgets
--off       hide them
--status    which are running, and from where
--seed      place the theme's widgets in its quickshell file (run at login)

## Notes
- What is drawn and where is `~/.config/waybar/desktop.json`; the type
  and colours, `desktop.css` beside it. Nothing regenerates those files
  once they exist, so edits stay.
