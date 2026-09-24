# playbook: kspaceduel
# source:   github KDE/kspaceduel
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev
#           kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev
#           kxmlgui-dev libkdegames-dev kconfigwidgets-dev
# runs:     libkdegames
#
# program:  kspaceduel
# label:    KSpaceDuel (space combat)
# shelf:    Games
# install:  kspaceduel@source
# mode:     x
# gate:     !v6
# home:     https://apps.kde.org/kspaceduel/
# about:    Two spaceships orbit a sun and fight it out while gravity pulls at everything. Thrust,
#           turn and fire, for two players or one against the computer.

# KSpaceDuel, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
KSPACEDUEL_VER=26.04.3
kspaceduel_install() {
    _s=$(gh_source KDE/kspaceduel "v$KSPACEDUEL_VER" \
         d62c62684f12b6c4d78fbba84c8572e9379a3aa04fb032297dabd01afc63d659) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kspaceduel"
    mv "$DEST$PREFIX/bin/kspaceduel" "$DEST$PREFIX/lib/copal-store/kspaceduel/kspaceduel"
    launcher kspaceduel <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kspaceduel/kspaceduel" "\$@"
EOF
}
