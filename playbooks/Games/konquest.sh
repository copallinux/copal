# playbook: konquest
# source:   github KDE/konquest
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev
#           qt6-qtscxml-dev kcolorscheme-dev kconfig-dev kcoreaddons-dev kcrash-dev
#           kdbusaddons-dev kdoctools-dev kguiaddons-dev ki18n-dev kwidgetsaddons-dev kxmlgui-dev
#           libkdegames-dev
# runs:     libkdegames
#
# program:  konquest
# label:    Konquest (galactic strategy)
# shelf:    Games
# install:  konquest@source
# mode:     x
# gate:     !v6
# home:     https://apps.kde.org/konquest/
# about:    KDE's galactic strategy game: send fleets from planet to planet and take the galaxy,
#           against the computer or friends sharing one screen. Every planet you hold builds more
#           ships each turn, so a game is a few minutes of planning and one good gamble.

# Konquest, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# the KDE Gear release that matches Alpine's libkdegames -- 26.04 -- so the
# game and the games library it links are one release series. Alpine packages
# libkdegames and every KDE Framework it needs, but not the game: the whole
# of kdegames is absent from v3.24 but for its library.
#
# StateMachine is Qt's SCXML module (qt6-qtscxml); ColorScheme is
# kcolorscheme. The handbook is built by kdoctools and installed with it, and
# the game's data goes under share/, where KDE programs look for it through
# XDG_DATA_DIRS -- which the launcher puts the store's prefix at the head of,
# so it is found under any prefix, not only /usr/local.
KONQUEST_VER=26.04.3
konquest_install() {
    _s=$(gh_source KDE/konquest "v$KONQUEST_VER" \
         b7451664cc8fe01f6596d150f24ac01e290fb7ea38020180cb5f451fdd060db2) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/konquest"
    mv "$DEST$PREFIX/bin/konquest" "$DEST$PREFIX/lib/copal-store/konquest/konquest"
    launcher konquest <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/konquest/konquest" "\$@"
EOF
}
