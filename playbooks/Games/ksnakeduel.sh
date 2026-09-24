# playbook: ksnakeduel
# source:   github KDE/ksnakeduel
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev
#           kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev
#           kxmlgui-dev libkdegames-dev kcompletion-dev kconfigwidgets-dev kguiaddons-dev
#           kiconthemes-dev kwidgetsaddons-dev
# runs:     libkdegames
#
# program:  ksnakeduel
# label:    KSnakeDuel (light-cycle duel)
# shelf:    Games
# install:  ksnakeduel@source
# mode:     x
# gate:     !v6
# home:     https://apps.kde.org/ksnakeduel/
# about:    A snake duel in the spirit of Tron's light cycles: steer so the other runs into a wall
#           or a trail first. Two players at one keyboard, or one against the computer.

# KSnakeDuel, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
KSNAKEDUEL_VER=26.04.3
ksnakeduel_install() {
    _s=$(gh_source KDE/ksnakeduel "v$KSNAKEDUEL_VER" \
         552fc2b130327738d75003b6e6c46118fabf5c726b880e8c32290845a35b5e33) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/ksnakeduel"
    mv "$DEST$PREFIX/bin/ksnakeduel" "$DEST$PREFIX/lib/copal-store/ksnakeduel/ksnakeduel"
    launcher ksnakeduel <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/ksnakeduel/ksnakeduel" "\$@"
EOF
}
