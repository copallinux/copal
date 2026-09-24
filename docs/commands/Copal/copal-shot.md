# command:  copal-shot
# purpose:  Super+Shift+S: drag a rectangle, and that part of the screen is saved as a picture.
# why:      The Hyprland desktop's screenshot key. The theme binds hyprshot,
#           which Alpine does not package; copal-shot does the same with grim
#           (grab) and slurp (select), which it does.
# see:      grim, scrot, tesseract

## Use
Press Super+Shift+S, then drag over the area you want; release and it is
saved to `~/Pictures` as `screenshot-DATE-TIME.png` (to `/tmp` if there is
no Pictures folder). Escape cancels.

## Examples
    copal-shot                           # select a region, save it
    grim ~/Pictures/whole.png            # the whole screen, with grim directly
    grim -g "$(slurp)" - | wl-copy       # a region straight to the clipboard

## Options
(none: it always asks for a region)

## Notes
- It saves without saying so: look in `~/Pictures`.
- For the whole screen, a window, or a copy on the clipboard, use grim
  directly, as in the examples.
- On the i3 desktop (X11) screenshots are `scrot`; copal-shot is for
  Wayland.
