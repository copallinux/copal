# playbook: kubrick
# source:   github KDE/kubrick
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev
#           kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev
#           kxmlgui-dev libkdegames-dev kconfigwidgets-dev kwidgetsaddons-dev glu-dev mesa-dev
# runs:     libkdegames glu
#
# program:  kubrick
# label:    Kubrick (3D Rubik's Cube)
# shelf:    Games
# install:  kubrick@source
# mode:     x
# gate:     !v6
# home:     https://apps.kde.org/kubrick/
# about:    A Rubik's Cube in 3D: turn the faces with the mouse until every side is one colour.
#           Cubes of other sizes and shapes, and demonstrations of the classic solutions.

# Kubrick, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
# Kubrick draws with fixed-function OpenGL (GL/gl.h, GLU) inside a Qt
# OpenGL widget. Alpine's aarch64 Qt is built for OpenGL ES, which stopped
# OpenToonz and blanks Fraqtive's 3D view -- but Kubrick's cube draws, shaded,
# front and back (seen on the bench, 23 Sep 2026).
KUBRICK_VER=26.04.3
kubrick_install() {
    _s=$(gh_source KDE/kubrick "v$KUBRICK_VER" \
         105f00cf36916abba2666db37a65302e835996eaf6788059917796726d20b68b) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kubrick"
    mv "$DEST$PREFIX/bin/kubrick" "$DEST$PREFIX/lib/copal-store/kubrick/kubrick"
    launcher kubrick <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kubrick/kubrick" "\$@"
EOF
}
