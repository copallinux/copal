# playbook: stage-apps
# source:   copal
# origin:   stage
# stage:    12
# category: Software
# step:     The application catalogue
# weight:   4
# levels:   medium full
# summary:  Installs the catalogue: over three hundred programs, each with a line saying what it is
#           for, and their first-run settings. The longest stage, most of it downloading.

stage_apps() {
    say "Stage 12: applications"

    # Written first and unconditionally, the way stage 7 writes copal-code: a
    # machine that declines the catalogue should still have the command that
    # installs fonts later.
    install_copal_fonts

    # The catalogue is 3-5 GB installed -- the largest single thing this
    # script does, and the one with the least chance of fitting in RAM.
    require_disk_root "The application catalogue (3-5 GB)" || return 0

    if ! x_installed; then
        warn "X is not installed. Most of this catalogue is graphical."
        confirm "Install the terminal programs anyway?" || return 0
    fi

    write_catalogue

    cat <<'MSG'

    A curated set, in the spirit of the old minimal distributions -- Damn
    Small Linux fitted a browser, a mail client, a spreadsheet, a media
    player and an image editor into 50 MB, and it did that by picking one
    good small program per job rather than by shipping less.

    The constraint here is sharper than disk: 512 MB of RAM shared with the
    framebuffer. So the picks are the small ones, and the heavyweights are
    marked as such rather than hidden.

    THIS LIST IS ALREADY FILTERED FOR YOUR BOARD. Every entry below exists
    for the architecture you are running -- nothing here will fail with "no
    such package". What that costs is that the list is shorter on an ARMv6
    Zero than on a Pi 4, and the missing rows are named in the guide rather
    than shown greyed out.

    Browsers. On armhf there is no Chromium and no Firefox; nobody builds
    either for ARMv6. BadWolf is the modern engine that IS available on every
    port -- WebKitGTK, current TLS -- with Dillo, NetSurf and Links as the
    small-and-fast options. On armv7 and aarch64 Firefox ESR, Chromium and
    Thunderbird appear in the list as well.

    Mail. Thunderbird is an Alpine package -- 151.0.1, 93 MB down and 259 MB
    installed -- so there is nothing to compile and nothing to fetch by hand.
    'Everything' installs it, and stage 1's mail address seeds the account so
    it opens on an inbox rather than a wizard.

    There is no Thunderbird for ARMv6 or 32-bit x86, and this is one to take
    at face value rather than route around: it is a Firefox-sized Rust and
    C++ tree that wants several gigabytes of RAM to link, so a Zero cannot
    build what nobody ships for it. Claws Mail is the answer on those boards
    -- a full IMAP client, GPG and all, in a few MB -- and it is in the
    minimal set, seeded from the same address.

    Games, and the honest version: there is no usable OpenGL here. X renders
    on the CPU through fbdev, so anything expecting a GPU falls back to a
    software rasteriser. SuperTux, Xonotic, OpenMW and GZDoom are listed
    where they are packaged, and on a Zero they are slideshows -- they are in
    the table because a Pi 4 runs them and the same catalogue serves both.
    What a machine of this class was always good at is turn-based, 2D and
    text: NetHack, Brogue, Angband, OpenTTD, Freeciv, ScummVM, chess.

    A few entries are marked '@testing'. Those come from edge/testing, which
    is Alpine's unstable branch, and they are tagged so that apk takes ONLY
    that package from there and leaves the rest of the system on stable.
    VICE, MilkyTracker, Schism Tracker, Maxima, Cura, CherryTree, Lynis and
    Ticker are all in that group -- genuinely wanted, genuinely not in
    stable.

    Not packaged for ANY of these architectures, so no amount of searching
    will help: Endless Sky, 0 A.D., Teeworlds, Hedgewars, Frozen Bubble,
    OpenRA, ADOM, ToME4, Fuse (Spectrum), PrusaSlicer, OpenSCAD, LibreCAD,
    Fritzing, gerbv, Joblin/Obsidian, and the whole of kdegames. Some of what
    Alpine lacks, the Copal Store (stage 18) compiles from its GitHub source:
    LibreCAD, OpenShot, DDNet, Descent, Marathon and more.

    On burning discs: the software is here (xorriso authors and burns ISOs,
    xfburn is the GTK front end), but a Pi Zero has one USB OTG port and no
    optical drive, so you would need a powered hub and a USB enclosure.

MSG

    _secs=$(catalogue_available | cut -d'|' -f1 | awk '!s[$0]++')
    note "Sections: $(echo "$_secs" | tr '\n' ' ')"
    cat <<'MSG'

    Choose:
      m   Minimal set   -- one good program per job, about 60 MB:
                           Dillo, Links, Lynx, Bombadillo, Claws Mail,
                           Audacious, Mousepad, PCManFM, GPicView, Zathura,
                           Galculator, Xarchiver
      a   Everything    -- the whole catalogue for this board, minus the
                           handful too big to install unattended: GIMP,
                           Krita, Blender, FreeCAD, KiCad, LibreOffice,
                           Calibre, TeX Live, Chromium, Brave, FileZilla
                           and Remmina. Install those by section.
                           Thunderbird IS included -- see below
      s   By section    -- pick one section at a time
      l   List          -- show the catalogue and what is already installed
      q   Back to the main menu

MSG
    ask "Choose [m/a/s/l/q]:"
    case "$REPLY" in
        l|L)
            catalogue_available | while IFS='|' read -r sec label pkgs bin mode; do
                if command -v "$bin" >/dev/null 2>&1; then _m="installed"
                else _m="-"; fi
                printf '    %-11s %-34s %-10s %s\n' "$sec" "$label" "$_m" "$pkgs"
            done
            return 0 ;;
        m|M) _want="dillo links lynx bombadillo claws-mail audacious
                    audacious-plugins mousepad pcmanfm gpicview zathura
                    zathura-pdf-mupdf galculator xarchiver 7zip unzip" ;;
        a|A) # The standing exclusions: too big to install unattended, and
             # listed in the 'a' description above so this is not a surprise.
             #
             # Brave is on this list for the Flatpak runtime rather than for
             # Brave: ~600 MB all told, and the only entry in the table that
             # would pull a second userland onto the card. The full monty
             # already has it from stage 4, so the only machine this withholds
             # it from is one that never asked for it -- and stage 12 -> s ->
             # Internet installs it in one step for one that did.
             _excl='gimp|blender|freecad|kicad|libreoffice-writer|calibre@testing|texlive-full|krita|chromium|com\.brave\.Browser@flathub|remmina|filezilla'
             # AND, at the FULL level only, the other graphical browsers.
             #
             # That level installs Brave in stage 4, and Firefox ESR is left
             # in the catalogue as the second engine -- Gecko beside Blink,
             # which is the pair worth having. Dillo, NetSurf and BadWolf are
             # then three more rendering engines nobody asked for on a machine
             # that already has two good ones, and a browser you never open is
             # just card and menu clutter.
             #
             # Only at 'full'. On medium and server BadWolf may be the ONLY
             # browser the machine gets (stage 4 picks it there), and Dillo
             # and NetSurf are the small-and-fast pair that make a Zero
             # usable -- removing them there would be taking the browser off
             # the boards that need one most.
             #
             # The TEXT browsers stay at every level: links, elinks, w3m, lynx
             # and retawq are a few hundred kB each, they work over SSH with
             # no display at all, and they are tools rather than browsers.
             if [ "$(copal_profile)" = full ]; then
                 _excl="$_excl|dillo|netsurf|badwolf"
                 note "full install: Brave and Firefox ESR only -- skipping Dillo, NetSurf, BadWolf"
             fi
             _want=$(catalogue_available \
                     | grep -vE "\|($_excl)\|" \
                     | cut -d'|' -f3 | tr '\n' ' ')
             # THUNDERBIRD IS IN THIS SET, and it is the one heavyweight that
             # is. It was withheld with the others, which put a full install
             # on a machine with no mail client but Claws Mail -- and the
             # exclusion was never about Thunderbird's size: Firefox ESR sits
             # in this same set at 227 MB installed against Thunderbird's 259,
             # and FileZilla and Remmina are withheld at a few MB each.
             #
             # What the size does earn is a check rather than an exclusion.
             # 93 MB comes down and 259 MB lands; asking for 700 MB free
             # leaves room for the rest of the catalogue behind it. A card
             # too full is told so and gets everything else, and the Mail
             # section installs it alone later.
             if ! have_space_mb 700 "Thunderbird (93 MB download, 259 MB installed)"; then
                 _want=$(echo "$_want" | tr ' ' '\n' | grep -vx thunderbird | tr '\n' ' ')
                 note "Skipping Thunderbird. Stage 12 -> s -> Mail installs it on its own."
             fi ;;
        s|S)
            note "Sections: $(echo "$_secs" | tr '\n' ' ')"
            ask "Which section?"
            _pick="$REPLY"
            _want=$(catalogue_available | awk -F'|' -v s="$_pick" 'tolower($1)==tolower(s){print $3}' | tr '\n' ' ')
            [ -n "$_want" ] || { warn "no such section: $_pick"; return 0; } ;;
        *) return 0 ;;
    esac

    # Deduplicate -- several entries share a package (7zip, unzip, the
    # audacious plugins) and apk is happier asked once.
    _want=$(echo $_want | tr ' ' '\n' | awk 'NF && !s[$0]++' | tr '\n' ' ')
    note "About to install:"
    note "$_want"
    confirm "Go ahead?" || return 0


    # add_optional one at a time rather than in one apk call: on a board this
    # slow a single failed name should not throw away twenty good ones.
    #
    # '@flathub' rows are not apk names and apk must never see one -- it would
    # report "package not found" for a package that exists perfectly well
    # somewhere apk cannot reach, which is the most misleading error this
    # stage could print. Routed by the same suffix the catalogue writes.
    for _p in $_want; do
        case "$_p" in
            *@flathub) add_flathub "${_p%@flathub}" || true ;;
            *)         add_optional "$_p" ;;
        esac
    done

    # Kate and Emacs are catalogue entries, so they arrive HERE -- at stage 12
    # -- and stage 7 has long since run and found no binary to configure. In a
    # full-automatic install that gap is the whole distance between "installed"
    # and "set up as an IDE": stage 7 is hours earlier and cannot know what
    # this stage is about to add. So ask again now. Both writers return
    # immediately if the editor is absent, and leave an existing config alone
    # if it is already there, which makes calling them twice free and safe.
    dev_write_kate_config
    dev_write_emacs_config
    seed_app_configs
    offer_source_builds

    # ------------------------------------------------------------------
    # The fonts, after the catalogue rather than inside it. They are not
    # applications and they do not belong in a menu: nothing here opens, and
    # what they change is how everything else looks.
    #
    # THREE GROUPS BY DEFAULT and one left out. coding, console and ibmpc go on
    # unattended; 'web' -- the metric-compatible document set -- does not,
    # because it is the group whose absence you notice only when opening
    # somebody's .docx, and that is a thing to install when it happens rather
    # than 120 MB carried by every machine. One command away either way:
    #
    #   doas copal-fonts install web
    #
    # Unattended the answer is yes: a coding machine that arrives with DejaVu
    # Sans Mono and nothing else has failed at the one thing it was for.
    say "Fonts"
    note "coding faces (ligature and plain), console/TTY, and the IBM PC set."
    note "About 215 MB. Iosevka and the large Nerd cuts are NOT in this --"
    note "they are 1.9 GB between them; 'copal-fonts install coding-extra' asks."
    note "'copal-fonts' afterwards for those and for the document fonts."
    if [ "${AUTO:-0}" = 1 ]; then AUTO_DEFAULT=y; fi
    if confirm_yes "Install them?"; then
        require_network && /usr/local/bin/copal-fonts install coding console ibmpc \
            || warn "fonts skipped -- 'doas copal-fonts install coding console ibmpc' later"
    else
        note "Skipped. 'doas copal-fonts install coding' when you want them."
    fi

    say "Done"
    note "Open the menu (Super+z) -- everything installed now appears in it,"
    note "and what you skipped is under Install."
    commit_reminder
}
