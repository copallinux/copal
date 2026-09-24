# playbook: kretro
# source:   github KDE/kretro
# build:    build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev
#           qt6-qtdeclarative-dev qt6-qtsvg-dev qt6-qtmultimedia-dev kirigami-dev
#           kirigami-addons-dev kcoreaddons-dev kconfig-dev ki18n-dev sdl3-dev
# runs:     kirigami kirigami-addons
#
# program:  kretro
# label:    KRetro (Libretro front end, early)
# shelf:    Emulation
# install:  kretro@source
# mode:     x
# gate:     64
# home:     https://invent.kde.org/games/kretro
# about:    KDE's front end for Libretro emulator cores, with a game library for the desktop, a TV
#           or a phone. It is its first release and a work in progress, so expect gaps.

# KRetro, KDE's front end for Libretro emulator cores, at its first release,
# v0.0.1: a work in progress, as its own README says. Kirigami and Qt Quick,
# with SDL3 for controllers. It plays games through Libretro cores, which it
# does not bring; RetroArch, in the catalogue, is the finished way to play.
KRETRO_VER=0.0.1
kretro_install() {
    _s=$(gh_source KDE/kretro "v$KRETRO_VER" \
         7adc6b56c512acf911040f8501b98c0f052425413266e33222ea8e756e2ffae0) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
}
