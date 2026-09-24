# command:  copal-wallpaper
# purpose:  Choose and paint the desktop's wallpaper, from the theme's collection or your own pictures.
# why:      Hyprland's own wallpaper tool, hyprpaper, is not packaged for
#           Alpine; copal-wallpaper paints with swaybg, remembers the choice,
#           and is what the session starts.
# see:      copal-theme

## Use
`--pick` shows thumbnails to choose from; `set FILE` uses any picture.
Without arguments it paints the chosen one and keeps running -- the
session starts it that way.

## Examples
    copal-wallpaper --pick               # choose, with thumbnails
    copal-wallpaper set ~/Pictures/lake.jpg   # any picture of yours
    copal-wallpaper --list               # what is available, and from where
    copal-wallpaper --fetch              # download diinki's published collection

## Options
--pick        choose one, with thumbnails
set FILE      use FILE from now on
--list        the wallpapers, and where each came from
--fetch       download the theme author's full collection

## Notes
- The bundled wallpapers are in `~/.config/hypr/wallpapers_bundled`;
  `--fetch` adds the rest of the collection.
- The choice is remembered across logins; `set` is all it takes.
