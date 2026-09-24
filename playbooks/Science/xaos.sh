# playbook: xaos
# source:   github xaos-project/XaoS
# build:    build-base cmake samurai qt6-qtbase-dev qt6-qttools-dev
# runs:
#
# program:  XaoS
# label:    XaoS (fractal zoomer)
# shelf:    Science
# install:  xaos@source
# mode:     x
# gate:     !v6
# home:     https://xaos-project.github.io/
# about:    A real-time fractal zoomer: fly smoothly into the Mandelbrot set and dozens of other
#           fractals. Built-in tutorials explain the mathematics as you go.

# XaoS, the real-time fractal zoomer, from its own release. CMake over Qt 6
# Widgets; its OpenGL renderer is an option and stays off, so it draws in
# software and runs the same on every board. Its tutorials and the catalogue
# of formulae are data it installs beside it; its command is 'XaoS'.
XAOS_VER=4.3.8
xaos_install() {
    _s=$(gh_source xaos-project/XaoS "release-$XAOS_VER" \
         509f0b9d8f7f36a8f93613415efac3d55f23c9d108a7a0ca900f2ef7550564cc) || return 1
    cmake_stage "$_s" -DOPENGL=OFF -DMOBILE_UI=OFF || return 1
    # Its menu entry and icon are in xdg/, which the CMake install leaves out,
    # and the entry runs 'xaos' where the binary is 'XaoS'.
    mkdir -p "$DEST$PREFIX/share/applications" "$DEST$PREFIX/share/pixmaps"
    sed 's/^Exec=xaos/Exec=XaoS/' "$_s/xdg/io.github.xaos_project.XaoS.desktop" \
        > "$DEST$PREFIX/share/applications/io.github.xaos_project.XaoS.desktop"
    cp "$_s/xdg/xaos.png" "$DEST$PREFIX/share/pixmaps/xaos.png"
}
