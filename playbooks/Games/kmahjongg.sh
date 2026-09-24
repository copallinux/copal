# playbook: kmahjongg
# source:   github KDE/kmahjongg
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev
#           kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev
#           kxmlgui-dev libkdegames-dev knewstuff-dev libkmahjongg-dev
# runs:     libkdegames libkmahjongg
#
# program:  kmahjongg
# label:    KMahjongg (mahjong solitaire)
# shelf:    Games
# install:  kmahjongg@source
# mode:     x
# gate:     !v6
# home:     https://apps.kde.org/kmahjongg/
# about:    Mahjong solitaire: clear the board by matching pairs of free tiles. Dozens of layouts
#           and tile sets, with a hint when you are stuck.

# KMahjongg, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
# Its tiles and layouts come from libkmahjongg, which Alpine packages.
KMAHJONGG_VER=26.04.3
kmahjongg_install() {
    _s=$(gh_source KDE/kmahjongg "v$KMAHJONGG_VER" \
         891b17cae420fd5d7b07efac7a4bbf5883c17a5a35d027d0fab8eb3897ebcf22) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kmahjongg"
    mv "$DEST$PREFIX/bin/kmahjongg" "$DEST$PREFIX/lib/copal-store/kmahjongg/kmahjongg"
    launcher kmahjongg <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kmahjongg/kmahjongg" "\$@"
EOF
}
