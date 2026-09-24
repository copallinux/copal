# playbook: veracrypt
# source:   github veracrypt/VeraCrypt
# build:    build-base pkgconf wxwidgets-dev fuse3-dev pcsc-lite-dev
# runs:     fuse3 doas-sudo-shim
#
# program:  veracrypt
# label:    VeraCrypt (encrypted volumes)
# shelf:    Tools
# install:  veracrypt@source
# mode:     x
# gate:     64
# home:     https://github.com/veracrypt/VeraCrypt
# about:    Makes an encrypted file or disk that opens as a drive with the right password. The
#           successor to TrueCrypt; mounting asks for your admin password.

# VeraCrypt: encrypted volumes and whole-disk encryption, TrueCrypt's heir.
# Its own Makefile, wxWidgets for the window, FUSE 3 to present a mounted
# volume. Its Linux 'install' stages into /usr, so the three files that
# matter are placed here instead. Mounting needs root, which it asks for
# through sudo -- on a Copal machine, doas-sudo-shim answers.
VERACRYPT_VER=1.26.29
veracrypt_install() {
    _s=$(gh_source veracrypt/VeraCrypt "VeraCrypt_$VERACRYPT_VER" \
         5141f046e90c8d7660d1eef7d492c4a0ee15283500f092ebb2b72d5260779229) || return 1
    # The Makefile derives SOURCE_DATE_EPOCH from git, or else from the
    # release date in Common/Tcdefs.h with an awk that busybox's awk cannot
    # run; given explicitly, that date is 8 June 2026.
    nice -n 10 make -C "$_s/src" -j "$JOBS" WITHFUSE3=1 SOURCE_DATE_EPOCH=1780876800
    mkdir -p "$DEST$PREFIX/bin" "$DEST$PREFIX/share/applications" "$DEST$PREFIX/share/pixmaps"
    cp "$_s/src/Main/veracrypt" "$DEST$PREFIX/bin/"
    cp "$_s/src/Setup/Linux/veracrypt.desktop" "$DEST$PREFIX/share/applications/"
    cp "$_s/src/Resources/Icons/VeraCrypt-256x256.xpm" "$DEST$PREFIX/share/pixmaps/veracrypt.xpm"
}
