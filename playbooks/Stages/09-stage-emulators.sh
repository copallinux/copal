# playbook: stage-emulators
# source:   copal
# origin:   stage
# stage:    9
# category: Emulators
# step:     Mini vMac and VICE (compiles from source)
# weight:   6
# levels:   medium full
# summary:  Compiles Mini vMac and sets up VICE, with disk images and launchers. The classic
#           Macintosh and the Commodore machines, one command each.

stage_emulators() {
    say "Stage 9: retro emulators"
    require_disk_root "A source build (there is nowhere to build)" || return 0
    require_network || return 1
    apk info -e build-base >/dev/null 2>&1 || { warn "run stage 7 first (needs a C toolchain)"; return 0; }

    SRCDIR=/usr/local/src
    mkdir -p "$SRCDIR"

    cat <<'MSG'

    Two very different propositions:

      Mini vMac   Macintosh Plus: a 8 MHz 68000 with 4 MB. Emulating it on a
                  1 GHz ARM is not hard, so it runs at full speed. The source
                  is small and builds in minutes. Recommended.

      VICE        The Commodore 64. Packaged in edge/testing for every
                  architecture here, so this is now a download of a few
                  minutes rather than the multi-hour source build it used to
                  be. It brings c1541 with it, so this stage can hand you a
                  properly formatted blank floppy to save to, and vsid, which
                  plays SID music without emulating a whole C64.

    Both are set up as a directory under your home with disks and launchers in
    it, not just a binary on PATH:

      ~/minivmac   disk1.dsk and shared.dsk, blank, plus run-plus.sh
      ~/vice       disks/blank.d64 and disks/work.d64, formatted and empty,
                   plus run-c64.sh and run-sid.sh

    ROMs differ between the two. Mini vMac needs a Macintosh Plus ROM dumped
    from hardware you own -- it will not start without it, and it is not ours
    to ship. VICE bundles its own C64 ROMs, which are freely redistributable,
    so it works the moment it is installed.

MSG
    cat <<'MSG'
      Basilisk II  A later Mac -- 68040, System 7 through 8.1 -- and the only
                  one of the three with NETWORKING. Mini vMac has none at all:
                  "Mini vMac does not currently support networking", no
                  Ethernet and no modem emulation, and its FAQ points here.
                  Needs a Mac II/Quadra ROM, not the Plus ROM, and emulating a
                  68040 costs far more than a 68000.

MSG
    ask "Set up which? [b=both (recommended) / m=Mini vMac / v=VICE / k=Basilisk / all / skip]"
    case "$REPLY" in
        b|B|both) _do_minivmac=1; _do_vice=1; _do_basilisk=0 ;;
        m*)       _do_minivmac=1; _do_vice=0; _do_basilisk=0 ;;
        v*)       _do_minivmac=0; _do_vice=1; _do_basilisk=0 ;;
        k*)       _do_minivmac=0; _do_vice=0; _do_basilisk=1 ;;
        a*)       _do_minivmac=1; _do_vice=1; _do_basilisk=1 ;;
        *)        note "Skipping."; return 0 ;;
    esac

    if [ "${_do_basilisk:-0}" = 1 ]; then
        say "Basilisk II"
        if try_add basilisk2; then
            # Installed is not the same as working. Prove it runs on this
            # hardware before leaving it on the system -- an emulator that
            # segfaults on ARMv6 is worse than not having it, because you will
            # waste an evening assuming the problem is your ROM.
            say "Checking it actually runs here"
            if BasiliskII --help >/dev/null 2>&1 || [ $? -le 1 ]; then
                note "the binary executes on this CPU"
                note "Networking: set Ethernet to 'slirp' in the preferences and"
                note "the emulated Mac gets a NAT'd connection through eth0 --"
                note "no root and no bridge needed."
                warn "it needs a Macintosh II or Quadra ROM. The Mac Plus ROM"
                warn "that Mini vMac uses will NOT work."
                note "Expect it to be slow: a 68040 is a great deal more to"
                note "emulate than the 68000 in a Mac Plus."
            else
                warn "the basilisk2 binary does not run on this CPU."
                note "Removing it again -- you asked not to keep it if it does not work."
                apk del basilisk2 >/dev/null 2>&1 || true
            fi
        else
            warn "no basilisk2 package for armhf in the configured repositories."
            cat <<'BAS'
    It can be built from source -- github.com/kanjitalk755/macemu -- but read
    this before saying yes.

    Basilisk II's JIT compiler is x86_64 only. On ARM it falls back to
    interpreting every 68040 instruction in software. That interpreter is
    running here on a single in-order ARMv6 core at 1 GHz with no NEON, which
    is the weakest target the project supports, emulating a CPU far larger
    than the 68000 Mini vMac handles at full speed.

    So: it will probably build, and it will probably be too slow to use. The
    build itself is a substantial C++ tree -- expect a couple of hours.

    Your own rule was that if it does not work on this Pi you do not want it.
    This is the honest reading of "does not work": not a failure to compile,
    but a System 7 that takes minutes to reach the desktop.
BAS
            if confirm "Build Basilisk II from source anyway?"; then
                say "Building Basilisk II"
                # gmp and mpfr are required on non-x86: the CPU core generator
                # uses them. The upstream README calls this out for arm64; the
                # same applies to armhf.
                add_optional git autoconf automake m4 gcc g++ make \
                             sdl2-dev libx11-dev gmp-dev mpfr-dev
                cd "$SRCDIR"
                if [ ! -d macemu ]; then
                    git clone --depth 1 https://github.com/kanjitalk755/macemu \
                      || { warn "clone failed"; return 0; }
                fi
                BASLOG=/var/log/basilisk-build.log
                note "build output -> $BASLOG   (tail -f it from another terminal)"
                if cd "$SRCDIR/macemu/BasiliskII/src/Unix" \
                   && ./autogen.sh >"$BASLOG" 2>&1 \
                   && nice -n 10 make >>"$BASLOG" 2>&1; then
                    if [ -x ./BasiliskII ]; then
                        install -m 0755 ./BasiliskII /usr/local/bin/BasiliskII
                        note "installed /usr/local/bin/BasiliskII"
                        warn "needs a Macintosh II or Quadra ROM -- NOT the Plus ROM."
                        note "Networking: set Ethernet to 'slirp' in its preferences."
                        note "Judge it on speed before keeping it."
                    else
                        warn "make finished but no BasiliskII binary appeared"
                        tail -20 "$BASLOG" 2>/dev/null | sed 's/^/      /'
                    fi
                else
                    warn "Basilisk II build failed. Last 20 lines of $BASLOG:"
                    tail -20 "$BASLOG" 2>/dev/null | sed 's/^/      /'
                    note "Source left in $SRCDIR/macemu."
                fi
            else
                note "Skipping Basilisk II. Mini vMac remains the one that works."
            fi
        fi
    fi

    # ---------------------------------------------------------- Mini vMac --
    if [ "${_do_minivmac:-0}" = 1 ]; then
        add_optional libx11-dev libxext-dev
        cd "$SRCDIR"
        _tgz="minivmac-$MINIVMAC_VER.src.tgz"
        _url="https://www.gryphel.com/d/minivmac/minivmac-$MINIVMAC_VER/$_tgz"

        # Three sources, in order of how much can go wrong with them: one
        # already unpacked here from a previous run, one copal-prep.sh staged
        # on the boot partition, and the network. The staged copy is the point
        # -- an hours-long unattended install should not turn on a web server
        # being up at the moment it happens to reach stage 9, which is exactly
        # how the first hardware run lost this stage.
        #
        # The staged name decides the version rather than MINIVMAC_VER: the
        # tarball on the card is the one that is actually going to be built,
        # and a mismatch between the two would name the wrong version in every
        # message from here down.
        if [ ! -f "$_tgz" ]; then
            _staged=$(ls "$BOOT"/minivmac/minivmac-*.src.tgz 2>/dev/null | head -n1 || true)
            if [ -n "$_staged" ]; then
                if cp "$_staged" "$SRCDIR/"; then
                    _tgz=$(basename "$_staged")
                    _v=${_tgz#minivmac-}; MINIVMAC_VER=${_v%.src.tgz}
                    note "using $_tgz from the card -- no download needed"
                else
                    warn "could not copy $_staged -- falling back to the download"
                fi
            fi
        fi

        say "Building Mini vMac $MINIVMAC_VER"
        if [ ! -f "$_tgz" ] && ! wget -q "$_url"; then
            warn "could not download $_url"
            note "Version numbers move. Check https://www.gryphel.com/c/minivmac/"
            note "and re-run with:  MINIVMAC_VER=<version> sh /boot/copal-init.sh"
            note "Or stage it on the card and skip the network entirely:"
            note "  on the Mac -- ./fetch-minivmac.sh && ./copal-prep.sh --refresh"
        else
            rm -rf "$SRCDIR/minivmac-build"; mkdir -p "$SRCDIR/minivmac-build"
            tar xzf "$_tgz" -C "$SRCDIR/minivmac-build"
            # The archive unpacks into its own top-level directory (minivmac/),
            # so setup/tool.c is one level down from where it was extracted.
            # Find it rather than assuming the directory's name, which has
            # changed between releases.
            _src=$(dirname "$(find "$SRCDIR/minivmac-build" -name tool.c -path '*/setup/*' | head -1)" 2>/dev/null)
            _src=${_src%/setup}
            if [ -z "$_src" ] || [ ! -f "$_src/setup/tool.c" ]; then
                warn "setup/tool.c is not in the extracted archive; layout has changed"
                note "look in $SRCDIR/minivmac-build and build by hand"
                _src=""
            fi
            [ -n "$_src" ] && cd "$_src" && note "building in $_src"
            # Mini vMac generates its own build script: compile the config
            # tool, run it for the target, run the result, then make.
            # -t larm is the Linux ARM target; the default model is a Mac Plus.
            # setup.sh is generated with a '#! /bin/bash' shebang, but it is
            # POSIX-clean (verified with 'dash -n') -- it only uses printf and
            # test to write cfg/ and a Makefile, so Alpine's ash runs it and
            # bash does not need installing. It must be RUN, not sourced: its
            # line 7 is  my_obj_d="${my_project_d}bld/"  and my_project_d is
            # deliberately unset (it means "build here"), which is instant
            # death under this script's 'set -u'. All its output is files, so
            # a separate process loses nothing. That Makefile then calls gcc
            # on src/OSGLUXWN.c, the X11 glue, which is why libx11-dev is
            # installed above.
            if [ -n "$_src" ] \
               && gcc setup/tool.c -o setup_t \
               && ./setup_t -t larm > setup.sh \
               && sh ./setup.sh \
               && make; then
                if [ -x ./minivmac ]; then
                    install -m 0755 ./minivmac /usr/local/bin/minivmac
                    note "installed /usr/local/bin/minivmac"
                    # A binary on its own is not a usable emulator: it needs a
                    # directory with disks in it, which is what this builds.
                    # The menu has always looked for ~/minivmac/run-*.sh; until
                    # now nothing created them.
                    minivmac_profile
                else
                    warn "build reported success but no ./minivmac binary appeared"
                fi
            else
                warn "Mini vMac build failed. See the output above."
                note "Source left in $SRCDIR/minivmac-build for inspection."
            fi
        fi
    fi

    # -------------------------------------------------------------- VICE --
    #
    # This used to compile VICE from source: a multi-hour build on one ARMv6
    # core, warned about as unverified, and needing xa -- a 6502 cross-assembler
    # not in the repositories -- to get past the halfway point.
    #
    # None of that is necessary. VICE 3.10 is packaged in edge/testing for all
    # three architectures this script supports, and a tagged @testing install
    # takes that one package without moving the rest of the system off stable.
    # Minutes instead of hours, and it brings c1541 with it, which is what
    # makes a genuinely formatted blank floppy possible.
    #
    # The source build is kept as a fallback for the day the package is not
    # there, but it is no longer the first thing tried.
    if [ "${_do_vice:-0}" = 1 ]; then
        say "Installing VICE (Commodore 64)"
        _vice_ok=0
        if try_add vice@testing; then
            _vice_ok=1
            note "installed from edge/testing: $(command -v x64sc || echo x64sc)"
            note "binaries: x64sc x64 x128 xvic xplus4 xpet vsid c1541 petcat"
        else
            warn "no vice package available -- falling back to a source build."
            cat <<'MSG'
    That is the multi-hour path: a large C codebase on one core. It also
    needs xa, a 6502 cross-assembler, which is not in the repositories --
    without it the compile normally dies partway through, hours in.

    Unless you specifically want to build it, the better answer is to skip
    VICE and come back when the package returns.
MSG
            if confirm "Attempt the source build anyway?"; then
                say "Building VICE $VICE_VER -- this is the long one"
                note "free space on /: $(free_mb) MB (the build wants ~2 GB)"
                have_space_mb 2048 "the VICE source build" || true
                zram_active || warn "zram is not active -- stage 5 first makes an OOM far less likely"
                note "Run this under tmux so a dropped console does not kill it."
                add_optional autoconf automake libtool bison flex pkgconf \
                             sdl2-dev sdl2_image-dev libpng-dev giflib-dev zlib-dev \
                             alsa-lib-dev texinfo dos2unix xa
                cd "$SRCDIR"
                _vtgz="vice-$VICE_VER.tar.gz"
                _vurl="https://sourceforge.net/projects/vice-emu/files/releases/$_vtgz/download"
                if [ ! -f "$_vtgz" ] && ! wget -q -O "$_vtgz" "$_vurl"; then
                    rm -f "$_vtgz"
                    warn "could not download VICE $VICE_VER"
                    note "Check https://vice-emu.sourceforge.io/ for the current version and"
                    note "re-run with:  VICE_VER=<version> sh /boot/copal-init.sh"
                else
                    rm -rf "vice-$VICE_VER"
                    tar xzf "$_vtgz"
                    if cd "vice-$VICE_VER"; then
                        BUILDLOG=/var/log/vice-build.log
                        note "full build output -> $BUILDLOG  (tail -f it elsewhere)"
                        if ./configure --enable-sdl2ui --disable-html-docs \
                                       --disable-pdf-docs --without-pulse >"$BUILDLOG" 2>&1 \
                           && nice -n 10 make >>"$BUILDLOG" 2>&1 \
                           && make install >>"$BUILDLOG" 2>&1; then
                            _vice_ok=1
                            say "VICE built and installed."
                        else
                            warn "VICE build failed. Last 20 lines of $BUILDLOG:"
                            tail -20 "$BUILDLOG" 2>/dev/null | sed 's/^/      /'
                            note "Source left in $SRCDIR/vice-$VICE_VER."
                        fi
                    else
                        warn "unexpected archive layout"
                    fi
                fi
            else
                note "Skipped VICE."
            fi
        fi

        # The disks are the point of the exercise, so make them whenever there
        # is a c1541 to make them with -- however VICE got here.
        [ "$_vice_ok" = 1 ] && vice_profile
    fi

    say "Stage 9 complete."
}
