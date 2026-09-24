# playbook: pixelorama
# source:   github Orama-Interactive/Pixelorama
# build:
# runs:     godot@testing
#
# program:  pixelorama
# label:    Pixelorama (pixel art)
# shelf:    Creative
# install:  pixelorama@source
# mode:     x
# gate:     !v6
# home:     https://github.com/Orama-Interactive/Pixelorama
# about:    A pixel-art editor and sprite animator. Layers, onion skins, tile mode and palettes,
#           exporting to PNG, GIF and sprite sheets.

# Pixelorama: a pixel-art editor written in Godot, run as a Godot project by
# Alpine's Godot. Held at 1.2, the last release made for Godot 4.6, which is
# what edge/testing carries; 1.2.1 on want 4.7. A Godot project imports its
# assets into a cache inside itself on first run, and /usr/local is not
# writable by the person running it, so the import is done here, at build
# time, and the project is installed already imported.
PIXELORAMA_VER=1.2
pixelorama_install() {
    _s=$(gh_source Orama-Interactive/Pixelorama "v$PIXELORAMA_VER" \
         45accd447b0561003bf484725326df48223bdab9e695a1a510f9ac5ff82afd06) || return 1
    HOME="$W/home" XDG_DATA_HOME="$W/home/data" XDG_CONFIG_HOME="$W/home/config" \
        godot --headless --path "$_s" --import
    [ -d "$_s/.godot/imported" ] || { echo "the Godot import made no cache"; return 1; }
    _d="$PREFIX/lib/copal-store/pixelorama"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/256x256/apps"
    cp -r "$_s/." "$DEST$_d/"
    rm -rf "$DEST$_d/.github" "$DEST$_d/Misc"
    cp "$_s/assets/graphics/icons/icon.png" "$DEST$PREFIX/share/icons/hicolor/256x256/apps/pixelorama.png"
    launcher pixelorama <<EOF
exec godot --path "$_d" "\$@"
EOF
    desktop_entry pixelorama Pixelorama pixelorama pixelorama "Graphics;2DGraphics;RasterGraphics;" \
        "Draw pixel art and animate sprites"
}
