# playbook: kreversi
# source:   github KDE/kreversi
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev
#           kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev
#           kxmlgui-dev libkdegames-dev qt6-qtdeclarative-dev kcolorscheme-dev kconfigwidgets-dev
#           kiconthemes-dev kjobwidgets-dev kio-dev kwidgetsaddons-dev
# runs:     libkdegames
#
# program:  kreversi
# label:    KReversi (Othello)
# shelf:    Games
# install:  kreversi@source
# mode:     x
# gate:     !v6
# home:     https://apps.kde.org/kreversi/
# about:    Reversi, also called Othello, against the computer at several levels. Outflank the other
#           colour's stones to turn them to yours.

# KReversi, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
# Its board is drawn in Qt Quick, so it needs Qt's QML modules to build.
KREVERSI_VER=26.04.3
kreversi_install() {
    _s=$(gh_source KDE/kreversi "v$KREVERSI_VER" \
         67f41e49cf6f6b30b989d7d1b4a7feea5241c70584085902fb78976ffb6c6702) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kreversi"
    mv "$DEST$PREFIX/bin/kreversi" "$DEST$PREFIX/lib/copal-store/kreversi/kreversi"
    launcher kreversi <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kreversi/kreversi" "\$@"
EOF
}
