# playbook: stage-hyprland
# source:   copal
# origin:   stage
# stage:    17
# category: Desktop
# step:     Hyprland and the Antiquity theme
# weight:   10
# levels:   full
# summary:  Installs Hyprland on Wayland with the Linux Antiquity theme and makes it the session:
#           the full monty. On aarch64 and x86_64 only; X stays installed as the fallback.

stage_hyprland() {
    say "Stage 17: Hyprland and the Linux Antiquity theme (the full monty)"

    require_disk_root "A Wayland compositor and the theme" || return 0

    # The boards this can never work on are refused with the reason, not a
    # failed package install an hour later. armhf and armv7 have no Hyprland
    # package -- and no GLES-capable Mesa worth the name on a Zero's
    # VideoCore -- so the answer is stage 4, which was designed for exactly
    # that hardware. Unattended, the answer is no: AUTO_DEFAULT=n makes the
    # full-automatic install skip this stage on a Zero instead of wedging.
    case "$(apk --print-arch 2>/dev/null || uname -m)" in
        aarch64|x86_64) : ;;
        *)  warn "this is a $(apk --print-arch 2>/dev/null || uname -m) board -- Alpine packages no Hyprland for it."
            note "Stage 4 (X.Org and i3) is the desktop for this hardware."
            if [ "${AUTO:-0}" = 1 ]; then AUTO_DEFAULT=n; fi
            confirm "Try anyway (it will almost certainly fail)?" || return 0 ;;
    esac

    require_network || return 1
    have_space_mb 900 "Hyprland, Qt-free Wayland stack and the theme" || return 1

    # ------------------------------------------------------------------
    # The compositor and the theme's programs. hyprland, kitty and mako are
    # the spine -- without any one of them this is not the Antiquity desktop,
    # so plain `apk add` and a hard stop, unlike everything after them.
    # foot AND NOT KITTY is the terminal on the spine, which is a change from
    # what the theme ships, and the reason is a machine this was tested on.
    #
    # kitty draws through OpenGL and nothing else. Where the compositor is
    # already on llvmpipe -- a VM with no VirGL, a Pi through fbdev, any host
    # that does not hand a GPU through -- kitty opens a window and exits
    # within a second, taking the only terminal on a fresh desktop with it.
    # 'copal-gpu' names that case; the desktop it leaves has no way to type.
    #
    # There is a second reason, visible in the theme's own kitty.conf: it sets
    # background and foreground to the SAME #eaeaea and relies on
    # background_opacity 0.2 plus compositor blur to make text legible. With
    # software rendering and no blur that is white on white -- so even the
    # kitty that does start is not the terminal in the screenshots.
    #
    # foot is Wayland-native, renders on the CPU by design, is about a tenth
    # of the size, and starts in a fraction of the time. It is the terminal
    # this desktop should have had. kitty goes on afterwards as an optional --
    # it is what upstream themes, it is right on a machine with a real GPU,
    # and nothing here uninstalls it -- but it is no longer what Super+Return
    # opens and no longer what a failed install takes the desktop down with.
    say "Installing Hyprland, foot and mako"
    apk add hyprland foot mako || {
        warn "the core packages did not install -- see apk's message above."
        note "hyprland lives in the community repository; check /etc/apk/repositories."
        return 1
    }
    # Optional, and after the spine: a machine with no kitty is a working
    # desktop, which was the entire problem with it being on the spine.
    add_optional kitty
    # copal-gui (Super+A) and what makes it an overlay rather than a window
    # Hyprland would tile: gtk-layer-shell. Without it the menu still opens.
    add_optional python3 py3-gobject3 gtk+3.0 gtk-layer-shell

    # The seat and the bus. A Wayland compositor needs permission to open the
    # DRM device and the input devices; on a systemd distro logind brokers
    # that, on Alpine it is seatd -- a 100 kB daemon -- plus membership of
    # three groups. dbus is the session bus mako and the polkit agent talk
    # over; copal-session wraps the compositor in dbus-run-session.
    say "Installing the seat manager and the session bus"
    add_optional seatd dbus
    if apk info -e seatd >/dev/null 2>&1; then
        rc-update add seatd default >/dev/null 2>&1 || true
        rc-service seatd start >/dev/null 2>&1 || true
        note "seatd running and enabled at boot"
    fi
    if apk info -e dbus >/dev/null 2>&1; then
        rc-update add dbus default >/dev/null 2>&1 || true
        rc-service dbus start >/dev/null 2>&1 || true
    fi
    for _g in seat input video; do
        addgroup "$PI_USER" "$_g" 2>/dev/null || true
    done
    note "'$PI_USER' is in seat, input and video -- what a compositor needs"

    # The GPU's userspace half. apk resolves shared-library dependencies by
    # itself but Mesa DRIVERS are runtime-loaded, not linked, so nothing pulls
    # them in. Alpine has renamed these packages across releases; each name is
    # asked for separately and a missing one is not an error.
    say "Installing the Mesa drivers"
    add_optional mesa-dri-gallium
    add_optional mesa-egl
    add_optional mesa-gles
    add_optional mesa-gbm

    # Everything else the theme names, each surviving its own absence.
    # xwayland keeps stage 4's and stage 12's X programs runnable inside the
    # compositor -- without it every X application on the machine goes dark
    # the moment the session switches.
    say "Installing the theme's supporting cast"
    # xset for the font path exec-once above, and the X11 core fonts it names.
    add_optional xwayland xset font-misc-misc font-adobe-75dpi font-adobe-100dpi
    add_optional hyprpolkitagent polkit
    add_optional nemo
    add_optional wofi
    add_optional grim slurp
    add_optional swaybg
    # xclip alongside wl-clipboard: the Wayland desktop has two selections and
    # 'copal-clip bridge' needs a tool for each to join them to the host's.
    add_optional wl-clipboard xclip
    add_optional jq socat
    add_optional font-dejavu
    add_optional font-jetbrains-mono
    # The upstream tools, asked for by name so the day Alpine packages them
    # this stage starts using them without being edited -- the wrappers below
    # already prefer them. Today all three are expected to be missing.
    try_add hyprpaper  || note "hyprpaper is not packaged -- swaybg paints the wallpaper instead"
    try_add hyprshot   || note "hyprshot is not packaged -- grim + slurp take the screenshots"
    # hyprland-guiutils is hyprland-qtutils renamed; both are asked for so
    # whichever name a repository carries is the one that answers. It brings
    # hyprland-dialog, which is all the login-time warning is looking for --
    # and the .conf silences that warning either way, so this is a nicety.
    try_add hyprland-guiutils || try_add hyprland-qtutils \
        || note "hyprland-guiutils is not packaged -- its dialogs are unused here"
    if ! try_add quickshell; then
        warn "quickshell is not packaged in this Alpine release -- not even edge has it."
        note "The theme's radial taskbar, widgets and launcher are quickshell; without"
        note "it you get Antiquity's windows, terminal, notifications and wallpaper,"
        note "with wofi as the launcher. The quickshell configs are installed anyway:"
        note "the moment a quickshell binary appears on this machine (apk or a source"
        note "build -- see docs/THEME.md), the next login uses it, nothing to redo."
    fi

    # ------------------------------------------------------------------
    # The theme itself. From the card first -- copal-prep.sh staged it next to
    # Mini vMac -- and GitHub only as the fallback, so an unattended install
    # does not hang on a web server for a theme it is already carrying.
    say "Installing the Linux Antiquity configs"
    _theme_tgz=""
    for _c in "$BOOT/antiquity/linux-antiquity.tar.gz" /media/*/antiquity/linux-antiquity.tar.gz; do
        [ -f "$_c" ] && { _theme_tgz="$_c"; break; }
    done
    _tdir="/tmp/antiquity.$$"
    rm -rf "$_tdir"; mkdir -p "$_tdir"
    if [ -n "$_theme_tgz" ]; then
        tar -xzf "$_theme_tgz" -C "$_tdir" || { warn "could not unpack $_theme_tgz"; return 1; }
        note "theme from the card: $_theme_tgz"
    else
        note "no staged theme on the boot partition -- fetching from GitHub"
        if wget -q -O "$_tdir/main.tar.gz" \
                "https://github.com/diinki/linux-antiquity/archive/refs/heads/main.tar.gz"; then
            tar -xzf "$_tdir/main.tar.gz" -C "$_tdir" && rm -f "$_tdir/main.tar.gz"
        else
            warn "could not fetch the theme -- no card copy, no network copy. Stopping here."
            rm -rf "$_tdir"
            return 1
        fi
    fi
    # The staged tarball unpacks to configs/; the GitHub one to
    # linux-antiquity-main/configs. Point at whichever appeared.
    [ -d "$_tdir/configs" ] || _tdir="$_tdir/linux-antiquity-main"
    [ -d "$_tdir/configs" ] || { warn "no configs/ in the theme archive -- corrupt download?"; rm -rf "/tmp/antiquity.$$"; return 1; }

    # The copy is upstream install.sh's behaviour, kept because its simplicity
    # is the point: each config directory goes to ~/.config/<name> whole, and
    # anything already there is MOVED ASIDE first, timestamped, never merged
    # and never deleted. Reimplemented in POSIX sh (upstream is bash), and
    # into both homes, the same two install_home_file writes to.
    for _h in /root "$(user_home)"; do
        [ -n "$_h" ] && [ -d "$_h" ] || continue
        _bak="$_h/copal-theme-backups"
        for _d in "$_tdir/configs"/*/; do
            [ -d "$_d" ] || continue
            _name=$(basename "$_d")
            _tgt="$_h/.config/$_name"
            if [ -d "$_tgt" ]; then
                mkdir -p "$_bak"
                _b="$_bak/$_name"
                [ -e "$_b" ] && _b="${_b}_$(date +%Y%m%d_%H%M%S)"
                mv "$_tgt" "$_b"
                note "moved aside: $_tgt -> $_b"
            fi
            mkdir -p "$_h/.config"
            cp -r "$_d" "$_tgt"
            # WHAT COMES BACK ACROSS THE MOVE. Two kinds of file in the
            # directory just moved aside are not the theme's to replace:
            #
            #   local.conf     the person's -- created once by this stage
            #                  and never rewritten, see install_home_once.
            #                  The second VM run reported it "created once"
            #                  a second time, which is how this was found.
            #   what THIS wrote the last time, by the record install_home_file
            #                  keeps. hyprland.conf and hyprpaper.conf are
            #                  about to be written again by this stage; if the
            #                  theme's copy is left in their place first, the
            #                  record no longer matches and the "you had
            #                  changed this" note speaks about a change nobody
            #                  made. Bringing the installer's own last copy
            #                  back keeps that note honest.
            #
            # Both copied with -p, so the person's own edits and their dates
            # travel intact.
            if [ -d "${_b:-}" ]; then
                if [ -f "$_b/local.conf" ]; then
                    cp -p "$_b/local.conf" "$_tgt/local.conf"
                    note "kept: $_tgt/local.conf (yours)"
                fi
                awk -v d="$_tgt/" 'index($2, d) == 1 { print substr($2, length(d) + 1) }' \
                    "$WRITTEN_RECORD" 2>/dev/null | while read -r _rf; do
                    [ -n "$_rf" ] && [ -f "$_b/$_rf" ] || continue
                    mkdir -p "$(dirname "$_tgt/$_rf")"
                    cp -p "$_b/$_rf" "$_tgt/$_rf"
                done
            fi
        done
        # The licence travels with what it licenses.
        cp "$_tdir/LICENSE" "$_h/.config/hypr/LICENSE.linux-antiquity" 2>/dev/null || true
        _own=$(stat -c '%u:%g' "$_h" 2>/dev/null) \
            && chown -R "$_own" "$_h/.config" "$_bak" 2>/dev/null || true
        note "$_h/.config -- hypr, kitty, mako, quickshell"
    done
    rm -rf "/tmp/antiquity.$$"

    # The editor follows the desktop. Stage 7 wrote both theme directories and
    # pointed the symlink at tokyo-night, which is stage 4's palette; this
    # desktop is the other one. Written here rather than assumed, because
    # stage 17 can be run on a machine that never ran stage 7 -- and if it was
    # run, an editor that is open right now repaints within three seconds
    # without being restarted. See dev_write_nvim_ui() and ~/.config/nvim/theme.lua.
    [ -d "$copal_theme_dir/antiquity" ] || copal_write_themes
    # The theme itself is applied at the very end of this stage (see "Stage
    # 16 complete"), after the bar's stylesheet, mako's config, hyprland.conf
    # and foot.ini exist for it to edit.

    # Same reasoning: this desktop binds four keys to copal-clip, and stage 4
    # -- which is where the script is normally written -- may never have run
    # on this machine. Writing it twice costs nothing; not having it costs
    # four dead keys.
    write_copal_clip

    # ------------------------------------------------------------------
    # The transformations. Everything Arch-shaped or newer-than-Alpine in the
    # vendored configs is corrected here, in generated files, so the vendored
    # tree stays byte-identical to upstream and every deviation is readable
    # in this stage rather than hidden in edited copies.

    # Three small wrappers before the compositor config that binds them.
    # Each one prefers the tool the theme wants and falls back to the tool
    # Alpine has, so the binds never point at a binary that is not there.
    say "Writing copal-launcher, copal-shot and copal-wallpaper"
    cat > /usr/local/bin/copal-launcher <<'ANTIQLAUNCH'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-launcher -- Super+Space, Super+D and Super+Z on the Antiquity desktop.
#
# ONE MENU, WHICH IS THE POINT OF THIS FILE NOW. It used to be a second menu:
# 'wofi --show drun' if quickshell was absent, which is a flat searchable list
# of .desktop files and nothing else -- no categories, no settings, no way to
# log out -- while Super+Z opened copal-menu, which had all of that and no
# search across the applications. Two menus, each missing the other's half,
# on adjacent keys. Omarchy ships that same split; there is no reason to
# inherit it.
#
# So every launcher key now opens copal-menu, whose left pane IS the drun list
# (plus the terminal programs drun cannot see) and whose right pane is the
# structure. Left and Right move between them.
#
# The quickshell radial launcher is deliberately not preferred any more, even
# where quickshell exists: it is the third menu, and it knows about neither
# pane.
command -v copal-menu >/dev/null 2>&1 && exec copal-menu
command -v wofi >/dev/null 2>&1 && exec wofi --show drun
command -v dmenu_run >/dev/null 2>&1 && exec dmenu_run
echo "copal-launcher: no launcher installed (copal-menu, wofi, dmenu)" >&2
exit 1
ANTIQLAUNCH
    chmod 0755 /usr/local/bin/copal-launcher

    cat > /usr/local/bin/copal-shot <<'ANTIQSHOT'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-shot -- Super+Shift+S: screenshot a region you draw.
#
# hyprshot is what the theme binds; Alpine does not package it, and grim +
# slurp are the same two verbs (grab, select) it is built from. Saved under
# ~/Pictures when it exists, /tmp when it does not -- upstream used /tmp.
if command -v hyprshot >/dev/null 2>&1; then
    exec hyprshot --mode region --output-folder "${XDG_PICTURES_DIR:-/tmp}"
fi
if command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1; then
    _dir="$HOME/Pictures"; [ -d "$_dir" ] || _dir=/tmp
    _geom=$(slurp) || exit 1
    exec grim -g "$_geom" "$_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
fi
echo "copal-shot: neither hyprshot nor grim+slurp installed" >&2
exit 1
ANTIQSHOT
    chmod 0755 /usr/local/bin/copal-shot

    cat > /usr/local/bin/copal-wallpaper <<'ANTIQWALL'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-wallpaper -- paint the wallpaper, choose one, or fetch more.
#
#   copal-wallpaper              paint the chosen one and stay running.
#                                This is what hyprland.conf exec-once's.
#   copal-wallpaper --pick       choose one, with thumbnails.
#   copal-wallpaper set FILE     use FILE from now on.
#   copal-wallpaper --list       what is available, and where it came from.
#   copal-wallpaper --fetch      download diinki's published collection.
#
# hyprpaper is what the theme uses and Alpine does not package it; swaybg
# shows one image just as well.
set -u
have() { command -v "$1" >/dev/null 2>&1; }
wayland() { [ -n "${WAYLAND_DISPLAY:-}" ]; }

# WHERE THE CHOICE LIVES. One line naming a file, in the config directory
# rather than in a dotfile of its own, so 'what is my wallpaper' has one
# answer that both the picker and the session-start path read.
STATE="${XDG_CONFIG_HOME:-$HOME/.config}/copal/wallpaper"
BUNDLED="$HOME/.config/hypr/wallpapers_bundled"
EXTRA="$HOME/Pictures/wallpapers"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/copal/wallpaper-thumbs"
DEFAULT="$BUNDLED/georges_riom_collage.png"

# Every image in both places, deduplicated by name, newest directory last.
# Nothing recursive: a wallpaper directory with a tree in it is somebody's
# photo library and this is not a file manager.
list_papers() {
    for _d in "$BUNDLED" "$EXTRA"; do
        [ -d "$_d" ] || continue
        for _f in "$_d"/*.png "$_d"/*.jpg "$_d"/*.jpeg "$_d"/*.webp; do
            [ -f "$_f" ] && printf '%s\n' "$_f"
        done
    done
}

current() {
    if [ -s "$STATE" ]; then
        _c=$(head -1 "$STATE")
        [ -f "$_c" ] && { printf '%s\n' "$_c"; return 0; }
    fi
    [ -f "$DEFAULT" ] && { printf '%s\n' "$DEFAULT"; return 0; }
    list_papers | head -1
}

# ---------------------------------------------------------------------------
# Thumbnails. The pictures are 4K PNGs of twenty megabytes; handing twenty of
# those to a launcher on a machine with 512 MB of RAM is how you find out what
# the OOM killer does to a compositor. 240px versions, made once, kept in the
# cache directory where they can be deleted without losing anything.
thumb_for() {  # <image> -> path to its thumbnail (which may be the image)
    have magick || have convert || { printf '%s\n' "$1"; return 0; }
    _im=$(have magick && echo magick || echo convert)
    mkdir -p "$THUMBS" 2>/dev/null || { printf '%s\n' "$1"; return 0; }
    # Named after the source so the cache is self-cleaning by inspection, and
    # regenerated only when the source is newer.
    _t="$THUMBS/$(printf '%s' "$1" | md5sum 2>/dev/null | cut -c1-16).png"
    [ -z "${_t##*/.png}" ] && { printf '%s\n' "$1"; return 0; }
    if [ ! -f "$_t" ] || [ "$1" -nt "$_t" ]; then
        "$_im" "$1" -thumbnail 240x135^ -gravity center -extent 240x135 \
               "$_t" 2>/dev/null || { printf '%s\n' "$1"; return 0; }
    fi
    printf '%s\n' "$_t"
}

# ---------------------------------------------------------------------------
# THE PICKER, and there are two because there is no one program that draws a
# thumbnail on both desktops.
#
#   Wayland: wofi --allow-images, which reads "img:PATH:text:LABEL" and draws
#            the picture beside the name. Same launcher as the menu, so it is
#            already styled and already familiar.
#
#            HOW BIG THE PICTURE IS, is a config key and not a flag. wofi
#            1.5.3 has --allow-images (-I) and no --image-size at all: the
#            size is image_size, default 32, reachable only through the
#            config file or -D/--define. Written as --image-size it is
#            ignored in silence, which produces a picker whose thumbnails
#            are the height of the text. Seen on a screenshot of the real
#            thing; fixed here.
#   X11:     feh -t, which IS a thumbnail browser -- a grid of pictures, and
#            --action turns a click into a command. Nicer than the Wayland
#            one, and it is the older desktop that gets it, which is a
#            pleasant change.
#
# Neither is required: with no image-capable picker this falls back to the
# plain list, which still works and still sets the wallpaper.
pick() {
    _n=$(list_papers | grep -c . || true)
    [ "${_n:-0}" -gt 0 ] || {
        echo "copal-wallpaper: no images in $BUNDLED or $EXTRA" >&2
        echo "  'copal-wallpaper --fetch' downloads diinki's published set." >&2
        return 1
    }

    if ! wayland && have feh; then
        # feh runs the action itself, so this returns as soon as the grid is
        # up and the setting happens on the click.
        exec feh -t -y 200 -E 200 --index-info "%n" \
                 --action "copal-wallpaper set %f" $(list_papers)
    fi

    if wayland && have wofi && { have magick || have convert; }; then
        _sel=$(list_papers | while IFS= read -r _f; do
                   printf 'img:%s:text:%s\n' "$(thumb_for "$_f")" "$(basename "$_f")"
               done | wofi --dmenu --allow-images --define image_size=96 \
                           --insensitive --prompt wallpaper \
                           --lines 6 --width 660) || return 0
        # wofi gives back the text half, which is the basename.
        [ -n "$_sel" ] || return 0
        _f=$(list_papers | awk -v b="$_sel" '{ n=$0; sub(/.*\//,"",n); if (n==b) { print; exit } }')
        [ -n "$_f" ] && set_paper "$_f"
        return 0
    fi

    # No pictures, then. Still a picker.
    _sel=$(list_papers | while IFS= read -r _f; do basename "$_f"; done \
           | { if wayland && have wofi; then wofi --dmenu --prompt wallpaper --lines 12
               elif have dmenu; then dmenu -i -l 12 -p wallpaper
               else cat; fi; }) || return 0
    [ -n "$_sel" ] || return 0
    _f=$(list_papers | awk -v b="$_sel" '{ n=$0; sub(/.*\//,"",n); if (n==b) { print; exit } }')
    [ -n "$_f" ] && set_paper "$_f"
}

# Remember it, then repaint without restarting the session. swaybg has no IPC,
# so repainting means replacing the process -- which is why this kills only
# the swaybg it started rather than every swaybg on the machine.
set_paper() {  # <image>
    [ -f "$1" ] || { echo "copal-wallpaper: no such file: $1" >&2; return 1; }
    mkdir -p "$(dirname "$STATE")"
    printf '%s\n' "$1" > "$STATE"
    echo "wallpaper: $1"
    if have hyprctl && hyprctl version >/dev/null 2>&1 && have hyprpaper; then
        hyprctl hyprpaper reload ,"$1" >/dev/null 2>&1 && return 0
    fi
    if have swaybg; then
        pkill -x -U "$(id -u)" swaybg 2>/dev/null
        (setsid swaybg -i "$1" -m fill >/dev/null 2>&1 &)
        return 0
    fi
    have feh && exec feh --bg-fill "$1"
    return 0
}

# ---------------------------------------------------------------------------
# FETCHING THE PUBLISHED SET, and the two warnings below are the reason this
# is a command you run rather than something an install stage does.
#
# LICENCE. github.com/diinki/wallpapers carries NO LICENCE FILE. Its README
# says "These are the wallpapers that I've made & published, in case any of
# you want to use them!" -- which is the author inviting you to use them, and
# is not a grant to redistribute. So Copal does not ship them, does not put
# them in the image, and does not vendor them into its repository the way it
# vendors the theme, which IS MIT-licensed and can be. What it does is fetch
# them onto YOUR machine at YOUR request, which is the same act as clicking
# the pictures in that README. If you want to redistribute them, that is a
# question for the author -- the Discord and Ko-fi links are in the README.
#
# SIZE. Twenty images, 240 MB, and they are 4K PNGs. On a Pi Zero with a
# 720p framebuffer and 512 MB of RAM that is neither useful nor survivable,
# so each one is downscaled to the screen and the original is discarded. The
# download is still 240 MB over the wire if you take all of them, which is
# why the default is to ask which.
UPSTREAM="https://raw.githubusercontent.com/diinki/wallpapers/main"
PAPERS="june2026/carnation_collage.png
june2026/georges_riom_collage.png
june2026/oc_the_blackboard.png
may2025/2CB.png
may2025/ALCHEMY-dark.png
may2025/ALCHEMY-pink.png
may2025/AQUARIUM.png
may2025/ARCHPOOL.png
may2025/HEART_NEBULA.png
may2025/HIRAETH.png
may2025/STRAY_KITTY_CLUB-beige.png
may2025/STRAY_KITTY_CLUB-mint.png
may2025/STRAY_KITTY_CLUB-pink.png
may2025/STRAY_KITTY_CLUB-teal.png
may2025/SYSTEMA.png
may2025/colorshift.png
april2026/terminal_glossary_4k_pastel-green.png
april2026/terminal_glossary_4k_pastel-pink.png
april2026/terminal_glossary_4k_pastel-purple.png
april2026/terminal_glossary_4k_paw.png"

screen_geom() {
    if have hyprctl && hyprctl monitors -j >/dev/null 2>&1 && have jq; then
        hyprctl monitors -j 2>/dev/null \
            | jq -r '.[0] | "\(.width)x\(.height)"' 2>/dev/null && return 0
    fi
    have xrandr && xrandr 2>/dev/null | awk '/\*/ {print $1; exit}' && return 0
    echo 1920x1080
}

fetch() {  # [name-fragment ...]
    have curl || { echo "copal-wallpaper: curl is not installed." >&2; return 1; }
    cat <<'NOTE'
diinki's wallpapers -- https://github.com/diinki/wallpapers

  That repository has NO LICENCE FILE. Its README says they are published
  "in case any of you want to use them", which is an invitation to use them
  and not a grant to redistribute them. Copal therefore does not ship them;
  this fetches them onto this machine at your request, which is the same act
  as saving them from the page yourself. Redistribution is a question for the
  author -- his Discord and Ko-fi are linked in that README.

  They are 4K PNGs, about 240 MB for the set. Each is downscaled to this
  screen after download and the original is discarded, because a 22 MB image
  on a machine with 512 MB of RAM is not a wallpaper, it is an incident.

NOTE
    _geom=$(screen_geom)
    _want="$*"
    mkdir -p "$EXTRA" || return 1
    _got=0 _fail=0
    for _p in $PAPERS; do
        _name=$(basename "$_p")
        # No arguments means all of them; otherwise match any fragment given.
        if [ -n "$_want" ]; then
            _hit=0
            for _w in $_want; do
                case "$_name" in *"$_w"*) _hit=1 ;; esac
                # Case-insensitively too: nobody types STRAY_KITTY_CLUB.
                case "$(echo "$_name" | tr 'A-Z' 'a-z')" in
                    *"$(echo "$_w" | tr 'A-Z' 'a-z')"*) _hit=1 ;;
                esac
            done
            [ "$_hit" = 1 ] || continue
        fi
        _out="$EXTRA/$_name"
        [ -f "$_out" ] && { echo "  have    $_name"; continue; }
        printf '  fetch   %s ... ' "$_name"
        if curl -fsSL --max-time 300 -o "$_out.part" "$UPSTREAM/$_p"; then
            if have magick || have convert; then
                _im=$(have magick && echo magick || echo convert)
                # >  means "only shrink": a picture already smaller than the
                # screen is left alone rather than blown up into mush.
                "$_im" "$_out.part" -resize "${_geom}^>" -strip "$_out" 2>/dev/null \
                    || mv "$_out.part" "$_out"
                rm -f "$_out.part"
            else
                mv "$_out.part" "$_out"
            fi
            echo "ok ($(du -h "$_out" 2>/dev/null | cut -f1))"
            _got=$((_got + 1))
        else
            rm -f "$_out.part"
            echo "FAILED"
            _fail=$((_fail + 1))
        fi
    done
    echo
    echo "$_got fetched into $EXTRA (${_fail} failed), scaled to $_geom."
    echo "Choose one with:  copal-wallpaper --pick"
}

case "${1:---paint}" in
    --paint|'')
        WP=$(current)
        # hyprpaper reads its own config and is what the theme expects.
        have hyprpaper && exec hyprpaper
        [ -n "${WP:-}" ] && [ -f "$WP" ] || exit 0
        have swaybg && exec swaybg -i "$WP" -m fill
        have feh && exec feh --bg-fill "$WP"
        exit 0 ;;
    --pick|-p)   pick ;;
    set)         shift; [ $# -ge 1 ] || { echo "usage: copal-wallpaper set FILE" >&2; exit 2; }
                 set_paper "$1" ;;
    --list|-l)
        printf 'current: %s\n\n' "$(current)"
        list_papers | while IFS= read -r _f; do
            case "$_f" in
                "$BUNDLED"/*) printf '  %-46s (bundled with the theme)\n' "$(basename "$_f")" ;;
                *)            printf '  %-46s (%s)\n' "$(basename "$_f")" "$(dirname "$_f")" ;;
            esac
        done ;;
    --fetch|-f)  shift; fetch "$@" ;;
    -h|--help)   sed -n '5,14p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)           echo "copal-wallpaper: unknown option '$1' -- try --help" >&2; exit 2 ;;
esac
ANTIQWALL
    chmod 0755 /usr/local/bin/copal-wallpaper

    # The compositor config: upstream's hyprland.lua translated value-for-
    # value into the .conf dialect that Hyprland 0.54 -- the one Alpine
    # ships -- actually reads. Hyprland looks for ~/.config/hypr/
    # hyprland.conf first and reads .lua only from 0.55; both files being
    # present is therefore not a conflict today and self-resolves the day it
    # could be: a Hyprland new enough to read the .lua is new enough that
    # whoever upgrades it can delete this .conf and get upstream's config,
    # monitors and all. The mapping table lives in docs/THEME.md.
    #
    # What changed in translation, and why -- everything else is upstream's
    # value verbatim:
    #   monitors      DP-2/DP-4 at the author's desk -> one auto rule. The
    #                 only portable answer, and hyprctl monitors tells you
    #                 what to pin if you want the upstream shape back.
    #   kb_layout     us,se with alt-shift toggle -> us. A surprise layout
    #                 switch on a machine with one keyboard is a trap.
    #   autostart     nm-applet dropped (no NetworkManager here);
    #                 systemctl --user hyprpolkitagent -> exec'd directly;
    #                 hyprpaper -> copal-wallpaper; qs kept but guarded;
    #                 hyprctl setcursor dropped (theme not vendored).
    #   launcher      the quickshell IPC one-liner -> copal-launcher.
    #   screenshot    hyprshot -> copal-shot.
    #   power         Copal's own additions: Super+Shift+P and the keyboard
    #                 power key end the day through copal-halt, exactly as
    #                 they do in i3 -- one habit, both desktops.
    say "Writing ~/.config/hypr/hyprland.conf (the Alpine translation)"
    cat > /tmp/hyprconf.$$ <<'ANTIQHYPR'
# hyprland.conf -- generated by copal-init.sh (stage 17).
# A translation of Linux Antiquity's hyprland.lua (upstream: diinki, MIT) for
# the Hyprland Alpine packages -- 0.54 reads only this dialect. The original
# .lua sits beside this file; on Hyprland >= 0.55 you may delete this .conf
# to use it, after pinning your monitors in it. See docs/THEME.md.

# One rule, every monitor: native mode, automatic placement, no scaling.
# `hyprctl monitors all` shows what you have; pin specific outputs here the
# way upstream's hyprland.lua does if you want more than one arranged.
monitor = , preferred, auto, 1

# foot, not the kitty upstream names here: kitty needs OpenGL and this desktop
# may well be compositing in software ('copal-gpu' says which), where it opens
# and exits within the second. foot renders on the CPU and always comes up.
# kitty is still installed where it could be -- 'kitty' at this prompt.
$terminal = foot
$fileManager = FILEMGR_PLACEHOLDER
$menu = copal-launcher

# Autostart. Each guarded or wrapped -- see copal-wallpaper and copal-launcher
# for the reasoning; the polkit agent is exec'd directly because there is no
# systemd --user on Alpine to start it.
exec-once = copal-wallpaper
exec-once = mako
# The clipboard history recorder, so Super+Ctrl+V has something to show.
# Under Wayland it hands over to wl-paste --watch where cliphist exists.
exec-once = copal-clip watch
# The shell: quickshell if this machine has it, waybar if not. copal-bar
# decides, so this line never has to change. Without it there is no bar,
# no clock, no workspace indicator and no window list.
exec-once = copal-bar
# The Geiger monitor, if stage 10 installed radbeeper. 'radbeeper hotplug' sits
# in the session and opens the monitor when a counter appears -- at login if one
# is already plugged in, and on plug-in at any point after. It is deliberately
# silent when there is no counter, because a window that opens at every login to
# say "nothing is plugged in" gets closed at every login and then gets deleted.
#
# THIS LINE WAS WRITTEN FOR i3 AND NOWHERE ELSE FOR TOO LONG. The i3 config has
# carried it since stage 10 landed; the Hyprland one never did, so on the
# desktop this distribution actually boots into, the monitor could not open at
# login however well the logger was working. Both sessions get it or neither
# means anything.
exec-once = sh -c 'command -v radbeeper >/dev/null 2>&1 && exec radbeeper hotplug'
# Copal Apps' slideshow, only while programs queued by the full monty are
# being installed (stage 18); otherwise it exits at once.
exec-once = sh -c 'command -v copal-apps >/dev/null 2>&1 && exec copal-apps --follow'
exec-once = sh -c '[ -x /usr/libexec/hyprpolkitagent ] && exec /usr/libexec/hyprpolkitagent'
# X11 core fonts for Xwayland clients. Xwayland starts with a font path of
# "built-ins" alone -- X.org's default already lists these directories -- so
# xboard died with "Unable to create font set" and xfig warned about
# -misc-fixed-*. Found by the application sweep (docs/app-integration-plan.md
# on gfx-lab); adding the directories fixed both.
exec-once = sh -c 'xset +fp /usr/share/fonts/misc,/usr/share/fonts/75dpi,/usr/share/fonts/100dpi; xset fp rehash'

# THE SHARED CLIPBOARD, WAYLAND HALF. spice-vdagentd owns the virtio port and
# stage 7 starts it; this is the per-session agent that actually syncs the
# selection, and nothing here was starting it. /etc/xdg/autostart carries a
# spice-vdagent.desktop and Hyprland does not read it -- there is no XDG
# autostart implementation in this session -- so the file sat there being
# correct and inert, and UTM's "Enable Clipboard Sharing" stayed a switch
# wired to nothing. The i3 session has launched the agent from ~/.xinitrc
# since the beginning; the Wayland session never did.
#
# IT WAITS FOR XWAYLAND. vdagent 0.23 is an X11 program -- "Spice session
# guest agent: X11" is its own version banner -- and it reads the selection
# off an X server, so it needs DISPLAY and a socket to connect to. Hyprland
# keeps the Xwayland and Wayland clipboards in step, so the X11 agent covers
# both and no wlr-data-control build is needed. But exec-once fires before
# Xwayland has bound its socket, and an agent started that early gives up
# with "Screen count is zero, are we on wayland?" and never retries. Thirty
# seconds of looking, then it gives up quietly.
#
# Guarded on the port as well as the binary, so this costs a Pi one failed
# test at login and nothing else.
exec-once = sh -c '[ -x /usr/bin/spice-vdagent ] && [ -e /dev/virtio-ports/com.redhat.spice.0 ] || exit 0; _i=0; while [ $_i -lt 30 ]; do for _s in /tmp/.X11-unix/X*; do [ -S "$_s" ] || continue; [ -n "${DISPLAY:-}" ] || DISPLAY=":${_s##*/X}"; export DISPLAY; exec /usr/bin/spice-vdagent -x; done; _i=$((_i+1)); sleep 1; done'
# ...and the wire between the two clipboards, which the agent above does not
# provide on its own. vdagent shares the XWAYLAND selection; Hyprland does not
# mirror that to the Wayland one, so without this the host's clipboard reaches
# xterm and nothing else. Same guard, same wait for Xwayland -- copal-clip
# refuses without a DISPLAY, and correctly.
exec-once = sh -c '[ -x /usr/bin/spice-vdagent ] && [ -e /dev/virtio-ports/com.redhat.spice.0 ] || exit 0; _i=0; while [ $_i -lt 30 ]; do for _s in /tmp/.X11-unix/X*; do [ -S "$_s" ] || continue; [ -n "${DISPLAY:-}" ] || DISPLAY=":${_s##*/X}"; export DISPLAY; exec copal-clip bridge; done; _i=$((_i+1)); sleep 1; done'

# COLOUR MANAGEMENT, OFF WHERE THE RENDERER IS SOFTWARE. Hyprland's cm render
# pass returns zero RGB for every alpha-carrying layer-shell surface once Mesa
# has fallen back to llvmpipe: the bar, the desktop widgets and every overlay
# come out as solid black rectangles, which is what a first login on a UTM
# guest looked like. Alpine's mesa is built without the virgl driver on every
# architecture, so every VM target lands in software whatever the host offers.
# Detected, never assumed -- a machine with a real GL driver keeps the pass and
# the colour accuracy that comes with it. aquamarine names the renderer in its
# log, one line, which is the whole test. See docs/visual-debugging-lab-report.md.
exec-once = sh -c 'for _i in 1 2 3 4 5; do _l=$(ls -t "${XDG_RUNTIME_DIR:-/tmp}"/hypr/*/hyprland.log /run/user/*/hypr/*/hyprland.log 2>/dev/null | head -1); case "$(sed -n "s/.*Renderer: //p" "$_l" 2>/dev/null | tail -1)" in *llvmpipe*|*softpipe*|*swrast*) exec hyprctl keyword render:cm_enabled 0;; ?*) exit 0;; esac; sleep 1; done'

env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    # SCROLLING DIRECTION. Upstream's config says false here and so did this
    # one, which is libinput's own default: the wheel moves the SCROLLBAR, so
    # rolling away sends the page up. Every touch device and every Mac moves
    # the CONTENT instead, and this desktop is most often a VM on a Mac --
    # where the host has already applied that direction and the guest was
    # undoing it again. Both lines, because a mouse does not read the
    # touchpad block: the outer one is the wheel, the inner one is fingers.
    #
    # Set both to false to go back. Stage 4's X session has the same setting
    # in /etc/X11/xorg.conf.d/30-scrolling.conf, and the two should agree.
    natural_scroll = true
    touchpad {
        natural_scroll = true
    }
}

# Upstream sets this against cursor glitches; in a VM it is not optional --
# virtio-gpu has no hardware cursor plane worth trusting.
cursor {
    no_hardware_cursors = true
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 1
    col.active_border = rgb(1c1c1c)
    col.inactive_border = rgb(1c1c1c)
    resize_on_border = false
    layout = dwindle
    allow_tearing = false
}

decoration {
    rounding = 9
    rounding_power = 4
    active_opacity = 1.0
    inactive_opacity = 1.0
    shadow {
        enabled = true
        range = 12
        render_power = 6
        sharp = false
        color = rgba(00000030)
        offset = 0 0
        scale = 1
    }
    blur {
        enabled = true
        size = 3
        passes = 2
        noise = 0.023
        contrast = 0.9
        new_optimizations = true
    }
}

animations {
    enabled = true
    bezier = smooth, 0.22, 1, 0.36, 1
    animation = workspaces, 1, 8, smooth, slide
    animation = windows, 1, 3, smooth
    animation = fade, 1, 3, smooth
}

dwindle {
    preserve_split = true
}

master {
    new_status = master
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    # The toast that says "Your system does not have hyprland-guiutils
    # installed. This is a runtime dependency for some dialogs." Alpine
    # packages no such thing -- hyprland-qt-support is the QML style, not
    # the binaries, and nothing in any repository provides hyprland-dialog,
    # which is the program the check looks for. What it gates is the update
    # and donate screens plus the app-not-responding dialog; Copal updates
    # through 'copal -U' and shows its own key list. So the warning is about
    # a component this system does not use and cannot obtain, and it is
    # switched off rather than displayed at every login.
    #
    # THE OPTION IS SPELLED guiutils, NOT qtutils. Upstream renamed the
    # package (and this variable with it); 0.54.3 registers only
    # misc:disable_hyprland_guiutils_check and answers "no such option" to
    # the old qtutils name, which is what made this look unsilenceable.
    disable_hyprland_guiutils_check = true
}

$mainMod = SUPER

bind = $mainMod, Return, exec, $terminal
bind = $mainMod, Q, killactive,
# Three ways to be rid of a window, and they are not the same operation.
#
#   killactive       asks the window to close, the way its own X button does.
#                    The program gets to run its "save changes?" and may
#                    refuse. This is what you want almost every time.
#   forcekillactive  SIGKILLs the client. Nothing is asked and nothing is
#                    saved -- it is 'kill -9' aimed with the mouse, for the
#                    program that has stopped answering.
#
# Super+Escape is the second close binding, and Super+Shift+Escape is the
# hard one -- the same pair on the same key, with Shift as the difference,
# because the unrecoverable action should cost an extra finger rather than
# sit on a key of its own that can be hit by accident.
bind = $mainMod, Escape, killactive,
bind = $mainMod SHIFT, Escape, forcekillactive,
bind = $mainMod SHIFT, S, exec, copal-shot
bind = $mainMod, E, exec, $fileManager
bind = $mainMod SHIFT, SPACE, togglefloating,
bind = $mainMod, F, fullscreen,
bind = $mainMod, D, exec, $menu
# Omarchy's launcher key as well as upstream's, because Super+Space is the one
# people arrive already knowing and stage 4's i3 config binds it too.
bind = $mainMod, SPACE, exec, $menu
# Super+Z, which stage 4 binds and this desktop's own key list advertised for
# some time while nothing here bound it at all. All three keys are now the
# same menu, so which one somebody remembers no longer decides what they get.
bind = $mainMod, Z, exec, copal-menu --system
# The other menu, Linux Mint's: favourites, categories, icons, search. It is
# a layer over the screen, so a click anywhere else closes it; so does
# pressing Super+A again.
bind = $mainMod, A, exec, copal-gui
# THE MENU'S ARROW KEYS. copal-menu shows its two panes in wofi, one at a
# time, and Left/Right swap them. wofi 1.5 cannot do that by itself: a
# user-bound key only arms an exit status for whenever Enter or Escape is
# eventually pressed, and the picker stays up. So while its picker is on
# screen copal-menu enters this submap, and Hyprland answers the arrows:
# each ends the picker with a signal the menu reads as "the other pane"
# (inside a category, Left is Back). Every other key passes through, so
# typing still filters. copal-menu leaves the submap on every way out, and
# Escape here closes the picker and leaves it too, so a menu that died
# cannot keep the arrows.
submap = menu
bind = , Left,   exec, pkill -USR1 -x wofi
bind = , Right,  exec, pkill -USR2 -x wofi
bind = , Escape, exec, pkill -x wofi
bind = , Escape, submap, reset
submap = reset
# THE DESK, laid out the same way every time: copal-desk opens the editor and
# a terminal on 2, an agent on 3, the browser on 5, and leaves you on an empty
# 1. Muscle memory needs things to be in the same place; see the essay above
# copal-desk in stage 4.
bind = $mainMod SHIFT, D, exec, copal-desk

# THE STORE, on the key i3 gives the Copal Center: copal-center opens the
# store when stage 18 has installed it, and the catalogue window when not.
bind = $mainMod SHIFT, C, exec, copal-center

# MOVING BETWEEN WINDOWS, which this config did not bind AT ALL until now.
# Upstream's hyprland.conf assumes you will add your own; the result on a
# fresh install is a tiling compositor in which the keyboard cannot change
# which window has focus, so the only way to reach a window is the mouse.
# That is the single biggest gap between this desktop and stage 4's i3, which
# has had these since the beginning.
#
# Both spellings, exactly as the i3 config does it: arrows for people who
# want arrows, hjkl for people with vi in their fingers.
bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d

# And moving the window itself, rather than the focus.
bind = $mainMod SHIFT, left,  movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up,    movewindow, u
bind = $mainMod SHIFT, down,  movewindow, d
bind = $mainMod SHIFT, H, movewindow, l
bind = $mainMod SHIFT, L, movewindow, r
bind = $mainMod SHIFT, K, movewindow, u
bind = $mainMod SHIFT, J, movewindow, d

# Resizing, on the same keys as the i3 config's resize mode but without the
# mode -- Hyprland has no modal resize, so Ctrl is the modifier.
binde = $mainMod CTRL, left,  resizeactive, -40 0
binde = $mainMod CTRL, right, resizeactive,  40 0
binde = $mainMod CTRL, up,    resizeactive,  0 -40
binde = $mainMod CTRL, down,  resizeactive,  0  40

# THE APPLICATION SWITCHER. Alt+Tab is the one every person who has ever used
# a computer tries first, and it did not exist here either. cyclenext walks
# the windows on the active workspace; bringactivetotop keeps the one you
# land on visible while you are cycling through floating windows.
bind = ALT, Tab, cyclenext,
bind = ALT, Tab, bringactivetotop,
bind = ALT SHIFT, Tab, cyclenext, prev
bind = ALT SHIFT, Tab, bringactivetotop,
# The same thing on Super, because under UTM the Mac eats Alt+Tab before this
# machine sees it -- the same reason stage 4's i3 config carries a second set
# of bindings on Ctrl+Alt.
bind = $mainMod, Tab, cyclenext,
bind = $mainMod, Tab, bringactivetotop,

# Workspaces on the scroll wheel, and the bar out of the way when you want
# the whole screen. Super+B for the bar: Super+Shift+Space is togglefloating
# here, unlike Omarchy, and moving an existing binding to match a different
# system is how people lose muscle memory.
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up,   workspace, e-1
bind = $mainMod, B, exec, pkill -SIGUSR1 waybar

# THE UNIFIED CLIPBOARD -- the same four keys stage 4's i3 config binds, so
# the two desktops do not disagree about copy and paste.
#
# Omarchy writes these as pairs of 'sendshortcut' binds with a class filter,
# which is Hyprland-only and repeats the list of terminal emulators four
# times. copal-clip asks hyprctl what has focus and dispatches sendshortcut
# itself, so there is one list, it is shared with the X desktop, and this
# file stays four lines long. See write_copal_clip() in copal-prep.sh.
bind = $mainMod, C, exec, copal-clip copy
bind = $mainMod, X, exec, copal-clip cut
bind = $mainMod, V, exec, copal-clip paste
bind = $mainMod CTRL, V, exec, copal-clip history

# System controls, on Omarchy's chords, with the programs this system has.
bind = $mainMod CTRL, A, exec, $terminal -e alsamixer
bind = $mainMod CTRL, T, exec, $terminal -e sh -c 'command -v btop >/dev/null && exec btop; exec htop'
bind = $mainMod SHIFT, M, exec, $terminal -e sh -c 'command -v cmus >/dev/null && exec cmus; exec mpv --no-video ~/Music'
# The camera: birdshot, or $CAMERA. Same key as stage 4's i3 binding, and the
# same resolver, so the two desktops cannot disagree about what it opens.
bind = $mainMod SHIFT, B, exec, copal-camera
bind = $mainMod SHIFT, N, exec, $terminal -e sh -c 'command -v nvim >/dev/null && exec nvim; exec vi'
# The download queue, on the same chord as stage 4's i3 config: queue the URL
# on the clipboard. It downloads by itself once ~/.config/ytq/auto exists.
bind = $mainMod SHIFT, Y, exec, sh -c 'command -v ytq >/dev/null && exec ytq clip'
# The Workspace, on the same chord as stage 4's i3 config: a Browser over the
# folder the queue archives into, with the queue as one more column. It is a
# terminal program, so unlike the chord above it is given a terminal -- and
# $terminal is left at the front of the exec, where every other binding here
# uses it, rather than nested inside the sh -c where stage 4's TERMEMU note
# says not to trust somebody else's expansion. The cost is that on a machine
# where copal-build has not run yet the terminal opens and shuts again.
bind = $mainMod SHIFT, A, exec, $terminal -e sh -c 'command -v sstr-workspace >/dev/null && exec sstr-workspace'
# The wallpaper picker, with thumbnails. Also in the menu under Style, and on
# the same chord as stage 4's i3 config so the two desktops agree.
bind = $mainMod SHIFT, W, exec, copal-wallpaper --pick
# THE KEY LIST, on the same two keys stage 4's i3 config uses. It opens the
# ANTIQUITY list, not i3's: same modifier, almost nothing else the same.
bind = $mainMod, slash, exec, $terminal -e copal-guide antiquity-keys
bind = $mainMod, F1,    exec, $terminal -e copal-guide antiquity-keys

# Copal's additions, so both desktops end the day the same way: copal-halt
# asks, closes the session, syncs, powers down. The keyboard power key
# arrives as a key event, and the compositor is the only thing placed to
# catch it -- same story as the i3 binding.
bind = $mainMod SHIFT, P, exec, copal-halt
bind = , XF86PowerOff, exec, copal-halt
bind = $mainMod SHIFT, Delete, exec, copal-halt reboot
bind = $mainMod SHIFT, E, exit,

# Workspaces 1-10 -- upstream generates these with a Lua loop; unrolled here
# because the .conf dialect has no loops.
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Move / resize with the mouse, upstream's binds.
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Media keys, upstream's binds kept verbatim. wpctl is wireplumber's tool and
# arrives with stage 10's audio work; until then these keys do nothing, which
# is what they did before this file existed.
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl s 10%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl s 10%-

# WHEN THE HOST STEALS A KEY -- the short version of the essay in stage 4's
# i3 config: under UTM the Mac eats several Super chords before this guest
# sees them, so the most-reached actions get a second binding on Ctrl+Alt,
# which macOS reserves nothing on. Harmless on real hardware; delete freely.
# The Super twins are not listed here. They are GENERATED from the $mainMod
# binds above, by the awk pass that runs just after this file is written --
# stage 4's i3 config does the same thing for the same reason, and a
# hand-kept copy of a list is a list that drifts. Two rules, and they are the
# rules the i3 side uses so the two desktops can be described in one sentence:
#
#     $mainMod        ->  CTRL ALT
#     $mainMod SHIFT  ->  CTRL ALT SHIFT
#     $mainMod CTRL   ->  CTRL ALT SHIFT
#
# Plain Ctrl+Space and Alt+Space for the launcher stay hand-written, because
# neither follows from the rules: they are there because the launcher is
# reached more often than anything else and Cmd+Space is the chord Spotlight
# takes most reliably. Alt is Option on a Mac keyboard, right beside Command,
# and macOS reserves nothing on it.
bind = CTRL, SPACE, exec, $menu
bind = ALT, SPACE, exec, $menu

# The theme's own layer rules: quickshell's bars ask for blur behind their
# translucent regions, by the namespaces the QML declares.
#
# THE STRUCTURED SYNTAX, and it is not optional on this version. An earlier
# draft used the older positional form -- `layerrule = blur, <namespace>` --
# and Hyprland 0.54.3 rejected all four lines on a real install:
#
#     invalid field blur: missing a value
#     invalid field type ignorealpha
#
# which is the parser saying both halves of what is wrong: `blur` is a field
# that takes a value (`blur on`), and the field is spelled `ignore_alpha`,
# not `ignorealpha`. Upstream's hyprland.lua had it right all along --
# `blur = true, ignore_alpha = 0.19, match = { namespace = ... }` -- so this
# is the faithful translation of it and the older form was the mistake.
# Both properties belong to one rule per namespace, as they do in the Lua.
layerrule = blur on, ignore_alpha 0.19, match:namespace diinki_celestialantiquity:bars
layerrule = blur on, ignore_alpha 0.19, match:namespace diinki_celestialantiquity:no_blur
# And the same for the bar that is actually running. waybar's layer surface is
# called "waybar"; where quickshell is absent this is the rule that does the
# work, and where it is present this one simply matches nothing. Both are
# listed so the file does not have to know which shell started.
layerrule = blur on, ignore_alpha 0.19, match:namespace waybar
ANTIQHYPR
    # ----------------------------------------------------------------------
    # THE KEY LIST FOR THIS DESKTOP, which did not exist.
    #
    # Stage 4 writes ~/.config/i3/keys.txt and binds Super+/ to it, and that
    # file is the i3 key list. On the Antiquity desktop it is the WRONG list:
    # the modifier is the same and almost nothing else is -- Super+Q closes a
    # window here and quits nothing there, Super+E is the file manager rather
    # than exit, the resize mode does not exist, and Alt+Tab does. Somebody
    # pressing Super+/ on this desktop and getting the i3 list is worse off
    # than somebody who found no list at all, because now they have one they
    # believe.
    #
    # So: a second list, for this desktop, bound to the same key. Written from
    # the binds in the file above -- if you add one there, add it here.
    say "Writing the Antiquity key list"
    mkdir -p /usr/local/share/copal/guides
    cat > /usr/local/share/copal/guides/antiquity-keys.txt <<'GUIDE'
 ======================================================================
   THE ANTIQUITY DESKTOP -- key bindings
 ======================================================================
                                                     press q to close

 "Super" is the Windows key, and Caps Lock is a second one -- see the
 note at the end if this machine is a VM on a Mac.

 Show this list again:   Super + /      or   copal-guide antiquity-keys
 The menu:               Super + Space, Super + D or Super + Z, and the
                         button in the top-left. One menu, two sides:
                         applications on the left, everything else on the
                         right, LEFT and RIGHT between them.

 START SOMETHING
   Super + Space        THE MENU. Super + D and Super + Z are the same key.
                        It opens on the applications: type to search, and
                        every program is there, the terminal ones included.
                        LEFT and RIGHT move to the other side -- the
                        categories, the settings, install, and log out.
   Super + Return       a terminal
   Super + E            the file manager
   Super + Z            the same menu, opened on the right-hand side
   Super + A            the Mint-style menu: favourites, categories, icons,
                        search. Right-click a program to make it a favourite.
   Super + Shift + N    the editor (nvim)
   Super + Shift + M    music (cmus, or mpv on ~/Music)
   Super + Shift + Y    queue the clipboard's video URL (ytq)
   Super + Shift + A    the Static Stream Workspace (archive and queue)
   Super + Shift + B    the camera (birdshot, built from ~/code; or $CAMERA)
   Super + Shift + W    the wallpaper picker, with thumbnails
   Super + Shift + T    the theme picker
   Super + Alt + Space  the menu's System side; Super + Ctrl + Space the
                        wallpaper picker -- Omarchy's chords, kept as doors
   Super + Ctrl + A     volume (alsamixer)
   Super + Ctrl + T     what the machine is doing (btop, or htop)
   Super + Shift + D    LAY THE DESK OUT. Editor and terminal on 2, a
                        Claude session in ~/code on 3, the browser on 5,
                        and you are left on an empty 1. 'copal-desk --list'
                        for the layouts; write your own into
                        ~/.config/copal/layouts/NAME.layout

 COPY AND PASTE -- THE SAME KEYS EVERYWHERE, TERMINAL INCLUDED
   Super + C            copy
   Super + X            cut
   Super + V            paste
   Super + Ctrl + V     the clipboard history -- the last hundred things

 WINDOWS
   Super + Q            close this window. Super + Escape does the same.
   Super + Shift + Esc  KILL this window -- no "save changes?", nothing
                        asked. For the program that has stopped answering.
   Alt + Tab            switch window   (Super + Tab does the same)
   Alt + Shift + Tab    switch backwards
   Super + arrows       move focus
   Super + H J K L      move focus, on the home row
   Super + Shift +      move the WINDOW rather than the focus
     arrows or HJKL
   Super + Ctrl +       resize. Hold it down; there is no resize mode
     arrows             here the way there is in i3.
   Super + F            fullscreen
   Super + Shift + Space  float this window / put it back

 WORKSPACES
   Super + 1 .. 0       go to workspace 1 to 10
   Super + Shift + 1..0 send this window there
   Super + scroll       next / previous workspace

   The numbers along the top-left of the bar are these. All five of the
   first five are shown whether or not anything is on them.

 THE BAR AND THE SCREEN
   Super + B            hide / show the bar
   Super + Shift + S    screenshot
   Super + Shift + W    change the wallpaper

 ENDING THINGS
   Super + Shift + P    power down (asks first)
   Super + Shift + Del  reboot
   Super + Shift + E    log out of the desktop

 IF THIS IS A VM ON A MAC
   The Mac's Command key arrives here as Super, so every binding above is
   also a macOS shortcut -- and three of them end the session before this
   machine ever sees the key: Cmd+W closes the VM window, Cmd+Q quits UTM,
   Cmd+Shift+Q logs out of macOS.

   Press CAPS LOCK instead of Super. It is a second Super here and macOS
   reserves nothing on it.

   Failing that, EVERY binding above has a second one, by two rules:

       WHERE SUPER IS EATEN, PRESS CTRL+ALT INSTEAD.
       WHERE THE BINDING ALSO HAS CTRL IN IT, PRESS CTRL+ALT+SHIFT.

   So Super+Space is Ctrl+Alt+Space, Super+Shift+Q is Ctrl+Alt+Shift+Q,
   and Super+Ctrl+V is Ctrl+Alt+Shift+V. The launcher also answers to
   plain Alt+Space and plain Ctrl+Space, because it is reached more often
   than anything else.

 WHERE THINGS ARE
   ~/.config/hypr/hyprland.conf    these bindings
   ~/.config/waybar/config         what is on the bar
   ~/.config/waybar/desktop.json   the clock and weather ON the wallpaper
   ~/.config/wofi/style.css        the launcher and the menu
   copal-guide widgets             how to change the bar and the
                                   widgets on the wallpaper
   copal-guide wallpapers          how to change the wallpaper
GUIDE

    # The file manager the theme wants, if this machine has it; the one stage
    # 4 installed otherwise. Substituted here, not left for Hyprland to
    # expand, for the same reason as stage 4's TERMEMU_PLACEHOLDER.
    _fm=pcmanfm
    command -v nemo >/dev/null 2>&1 && _fm=nemo
    sed -i "s|FILEMGR_PLACEHOLDER|$_fm|" /tmp/hyprconf.$$

    # ----------------------------------------------------------------------
    # THE CTRL+ALT TWINS -- the Wayland half of what stage 4 does to the i3
    # config, generated the same way and by the same two rules, so "where
    # Super is eaten, press Ctrl+Alt; where the binding has Ctrl in it, press
    # Ctrl+Alt+Shift" describes both desktops rather than one of them.
    #
    # Hyprland's grammar makes this easier than i3's: the modifier set is the
    # first comma-separated field, so it is swapped without touching the key
    # or the dispatcher. bind, binde, bindm and bindl are all rewritten --
    # bindm is the mouse drag, and a drag that only works with a key macOS has
    # taken is no better than a binding that does.
    #
    # THE ARROWS ARE THE ONE COLLISION. Super+Shift+arrow (move the window)
    # and Super+Ctrl+arrow (resize it) both want Ctrl+Alt+Shift+arrow. Resize
    # takes it, because moving a window has Ctrl+Alt+Shift+H/J/K/L already and
    # resizing would have nothing -- the same call stage 4 makes. Hyprland
    # runs BOTH binds on a duplicated chord rather than picking one, so this
    # has to be settled here; left alone it would move and resize at once.
    awk '
        /^bind[elm]* = \$mainMod/ {
            eq   = index($0, "=")
            head = substr($0, 1, eq)
            rest = substr($0, eq + 1)
            c    = index(rest, ",")
            if (c == 0) next
            mods = substr(rest, 1, c - 1)
            tail = substr(rest, c)
            sub(/^[ \t]+/, "", mods); sub(/[ \t]+$/, "", mods)
            # The key is the field after the modifiers; needed only to spot
            # collisions, so case is normalised rather than preserved.
            key = substr(tail, 2)
            if (index(key, ",") > 0) key = substr(key, 1, index(key, ",") - 1)
            sub(/^[ \t]+/, "", key); sub(/[ \t]+$/, "", key)
            key = toupper(key)

            if      (mods == "$mainMod")       twin = "CTRL ALT"
            else if (mods == "$mainMod SHIFT") twin = "CTRL ALT SHIFT"
            else if (mods == "$mainMod CTRL")  twin = "CTRL ALT SHIFT"
            else next

            # Move-window gives up the arrows to resize; it keeps H/J/K/L.
            if (mods == "$mainMod SHIFT" \
                && (key == "LEFT" || key == "RIGHT" || key == "UP" || key == "DOWN")) next

            # Two binds on one chord is legal and sometimes deliberate --
            # Super+Tab is cyclenext AND bringactivetotop, and both must
            # survive. So a repeat is only a collision when it comes from a
            # DIFFERENT modifier set; from the same one it was always a pair.
            chord = twin "," key
            if (chord in from && from[chord] != mods) {
                printf "# SKIPPED (%s+%s already bound): %s\n", twin, key, mods
                next
            }
            from[chord] = mods
            printf "%s %s%s\n", head, twin, tail
        }
    ' /tmp/hyprconf.$$ > /tmp/hypralt.$$
    {
        printf '\n# ---- Ctrl+Alt twins, generated from the Super binds above ----\n'
        printf '# Where Super is eaten by the Mac, press Ctrl+Alt. Where the bind also\n'
        printf '# has Ctrl in it, press Ctrl+Alt+Shift. Delete this block on hardware.\n'
        cat /tmp/hypralt.$$
    } >> /tmp/hyprconf.$$
    rm -f /tmp/hypralt.$$
    if grep -q '^# SKIPPED' /tmp/hyprconf.$$; then
        warn "some Ctrl+Alt twins collided and were skipped:"
        grep '^# SKIPPED' /tmp/hyprconf.$$ | sed 's/^/      /'
    fi
    # AFTER the twins, deliberately, and for the same reason stage 4 does it:
    # Super+Shift+T's twin is Super+Ctrl+T's, and Super+Ctrl+Space's is
    # Super+Shift+Space's. The generator would skip them with a warning on
    # every install. They are doors, not verbs -- each runs something the
    # file already binds elsewhere -- so they do not need twins of their own.
    # And local.conf LAST of all, after the twins, so that "sourced last, so
    # it wins" stays true of the whole file rather than of the part above the
    # generated block.
    cat >> /tmp/hyprconf.$$ <<'ANTIQDOORS'

# ---- more doors ---------------------------------------------------------
# The theme picker. Two themes today, and a picker over two is still the
# door that does not need a terminal.
bind = $mainMod SHIFT, T, exec, copal-theme --pick
# Light <-> dark, the whole desktop: the current theme's partner.
bind = $mainMod SHIFT, N, exec, copal-theme --toggle
# Doors from Omarchy, for hands that learned them there: its system menu is
# Super+Alt+Space and its wallpaper picker Super+Ctrl+Space. The same one
# implementation behind each; one more way in, which is what a door is.
bind = $mainMod ALT, SPACE, exec, copal-menu --system
bind = $mainMod CTRL, SPACE, exec, copal-wallpaper --pick

# ---- yours --------------------------------------------------------------
# Everything above this line is rewritten whenever stage 17 runs, and the
# copy it replaces goes to hyprland.conf.bak. local.conf is not: the
# installer creates it empty once and never opens it again. A binding, a
# monitor line, a display scale -- anything you would otherwise edit above
# -- goes there and survives every re-run. Sourced last, so it wins.
# The theme's borders, written by copal-theme (re-run it rather than edit).
source = ~/.config/hypr/copal-theme.conf
source = ~/.config/hypr/local.conf
ANTIQDOORS

    install_home_file .config/hypr/hyprland.conf /tmp/hyprconf.$$
    cat > /tmp/hyprlocal.$$ <<'HYPRLOCAL'
# ~/.config/hypr/local.conf -- yours.
#
# Copal created this file empty, once, and will not write to it again.
# ~/.config/hypr/hyprland.conf is rewritten every time stage 17 runs and
# sources this file last, so anything here wins over anything there.
# Hyprland reloads on save. Some starting points:
#
#   monitor = , preferred, auto, 1.5          a display scale
#   bind = $mainMod SHIFT, F8, exec, foo      a binding of your own
#   exec-once = copal-desk                    the desk, laid out at login
HYPRLOCAL
    install_home_once .config/hypr/local.conf /tmp/hyprlocal.$$
    rm -f /tmp/hyprlocal.$$
    rm -f /tmp/hyprconf.$$

    # hyprpaper.conf named the author's two monitors. An empty monitor field
    # means every monitor, which is the only shape that survives contact with
    # other people's hardware. Only read if hyprpaper ever appears -- swaybg
    # takes its orders from copal-wallpaper -- but corrected now, once.
    say "Writing ~/.config/hypr/hyprpaper.conf (all monitors)"
    cat > /tmp/hyprpaper.$$ <<'ANTIQPAPER'
# hyprpaper.conf -- rewritten by copal-init.sh (stage 17); upstream's file
# named the author's DP-2 and DP-4. Empty monitor = every monitor.
wallpaper {
  monitor =
  path = ~/.config/hypr/wallpapers_bundled/georges_riom_collage.png
  fit_mode = cover
}
splash = false
ANTIQPAPER
    install_home_file .config/hypr/hyprpaper.conf /tmp/hyprpaper.$$
    rm -f /tmp/hyprpaper.$$

    # foot.ini -- the theme's palette, on the terminal this desktop opens.
    #
    # Upstream ships no foot config, so this is a translation of its
    # kitty/hades.conf rather than a design of its own: the sixteen colours
    # are copied across unchanged, and so is the 0.2 alpha.
    #
    # ONE DELIBERATE DEPARTURE, and it is the reason this file is written by
    # hand instead of converted mechanically. hades.conf sets background AND
    # foreground to the same #eaeaea and lets background_opacity 0.2 plus the
    # compositor's blur pull the text out of it. That is a real look on a
    # machine with a GPU; on one compositing in llvmpipe -- no blur, and the
    # alpha flattened against whatever is behind -- it is white on white, a
    # terminal you cannot read. So foreground takes #000000, which is not an
    # invention: it is hades.conf's own selection_foreground, the colour the
    # theme already puts on top of #eaeaea. Everything else is upstream's.
    say "Writing ~/.config/foot/foot.ini (font, padding, keys; the palette follows the theme)"
    cat > /tmp/footini.$$ <<'ANTIQFOOT'
# foot.ini -- written by copal-init.sh (stage 17).
#
# foot is the terminal this desktop opens because it renders on the CPU:
# where the compositor is on llvmpipe, kitty's OpenGL window does not survive.
# 'copal-gpu' says which case this machine is.
#
# THE COLOURS ARE NOT HERE. copal-terminal-theme appends [colors-light] and
# [colors-dark] (and [cursor]) for the current theme -- Antiquity's helios
# opaque-ish at alpha 0.9, or Tokyo Night, or whichever 'copal-theme' set --
# and rewrites them on every switch. The theme's own kitty palette is one
# neon set for a pane of glass at 20 % opacity; opaque it is unreadable
# (docs/THEME.md). Everything below is the theme's terminal style, kept.
#
# font: the theme asks for Maple Mono, which Alpine does not package.
# JetBrains Mono is the packaged cousin, and the same substitution kitty gets.
font=JetBrains Mono:size=11
pad=12x12

[scrollback]
lines=3000

[key-bindings]
# The two kitty binds the theme documents (ctrl+shift+plus, ctrl+shift+minus),
# kept on the same keys. foot's spelling differs: modifier names are
# case-sensitive, and 'plus' already means the shifted key, so naming Shift
# as well is refused as a double shift. Control+plus is Ctrl with whatever
# key produces '+' -- on a US layout, Ctrl+Shift+=. minus is unshifted, so
# there Shift is spelled out.
font-increase=Control+plus
font-decrease=Control+Shift+minus
ANTIQFOOT
    install_home_file .config/foot/foot.ini /tmp/footini.$$
    rm -f /tmp/footini.$$

    # The theme's kitty.conf asks for Maple Mono, which Alpine does not
    # package. kitty falls back to its default monospace without complaint,
    # but JetBrains Mono is a close cousin and IS packaged -- when it landed
    # above, point the config at it. sed on the installed copies, not the
    # vendored tree: the vendored tree stays upstream's.
    if apk info -e font-jetbrains-mono >/dev/null 2>&1; then
        for _h in /root "$(user_home)"; do
            [ -n "$_h" ] && [ -f "$_h/.config/kitty/kitty.conf" ] || continue
            sed -i 's/^font_family maple mono/font_family JetBrains Mono/' \
                "$_h/.config/kitty/kitty.conf" 2>/dev/null || true
        done
        note "kitty: Maple Mono is not packaged -- JetBrains Mono substituted"
    fi

    # ------------------------------------------------------------------
    # THE LAYERS THE THEME DOES NOT REACH BY ITSELF.
    #
    # A theme is not the window manager; it is every layer that draws. The
    # vendored configs cover four of them -- compositor, shell, terminal,
    # notifications -- and stop, because upstream deliberately leaves GTK,
    # icons and cursors to the user (its README says so). That leaves a
    # desktop where kitty and the shell are Antiquity and the file manager is
    # stock Adwaita, which is the exact failure diinki demonstrates in the
    # ricing guide: "if we open up our file explorer, you may notice it
    # doesn't adhere to our theme at all."
    #
    # It matters more here than in a one-person rice. Copal's catalogue is
    # 329 programs and most of the graphical ones are GTK, so this is the
    # difference between a themed desktop and a themed compositor with 300
    # unthemed windows in it.
    say "Theming the layers the configs do not reach: fonts, GTK, cursor"

    # 1. FONTS, SYSTEM-WIDE. The theme bundles its display faces -- Boska,
    #    Recia, Charcoal, Monaco, Quilon, Dominica and Material Symbols --
    #    and quickshell loads them from its own config tree with FontLoader,
    #    which is why the shell's type is right even on a machine with no
    #    fonts installed. Nothing else can see them that way. Installing them
    #    where fontconfig looks is what lets kitty, GTK applications and the
    #    X desktop use the same faces, which is the difference between a
    #    themed shell and a themed system.
    #
    #    Copied from the installed copy rather than the archive, so this is
    #    the same set the shell is using.
    _fontsrc="$(user_home)/.config/quickshell/fonts"
    [ -d "$_fontsrc" ] || _fontsrc=/root/.config/quickshell/fonts
    if [ -d "$_fontsrc" ]; then
        add_optional fontconfig
        mkdir -p /usr/share/fonts/copal-antiquity
        # -f: a re-run should replace, not fail. The .TTF spelling is
        # upstream's on one of the files, and a case-sensitive filesystem
        # will not match it against *.ttf.
        cp -f "$_fontsrc"/*.ttf "$_fontsrc"/*.TTF \
              /usr/share/fonts/copal-antiquity/ 2>/dev/null || true
        chmod 0644 /usr/share/fonts/copal-antiquity/* 2>/dev/null || true
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f >/dev/null 2>&1 || true
            note "fonts installed system-wide: $(ls /usr/share/fonts/copal-antiquity 2>/dev/null | wc -l | tr -d ' ') faces, cache rebuilt"
        else
            note "fonts copied to /usr/share/fonts/copal-antiquity (no fc-cache to refresh)"
        fi
    fi

    # 2. GTK. There is no Antiquity GTK theme to install -- upstream does not
    #    ship one, and writing a GTK4 theme is, as the guide puts it, "a very
    #    extensive task". So this does the honest, portable half: dark
    #    preference, a matching icon and cursor theme, and the theme's own
    #    font. adw-gtk3 IS packaged here and is the closest neutral dark that
    #    does not fight the palette; where it is missing, the dark preference
    #    alone still stops a white file manager on a dark desktop.
    #
    #    BOTH VERSIONS, and that is the point of writing two files. GTK3 and
    #    GTK4 read separate settings.ini and a GTK3-only answer leaves every
    #    newer application unthemed -- the second half of the guide's GTK
    #    chapter, and the thing its author had to solve with a hand-written
    #    GTK4 theme.
    _gtktheme=Adwaita-dark
    try_add adw-gtk3 && _gtktheme=adw-gtk3-dark
    add_optional adwaita-icon-theme
    # Alpine packages no Hackneyed (upstream's choice), so the cursor is
    # whatever Adwaita provides -- named explicitly rather than left unset,
    # because an unset cursor theme under Wayland is the one that renders as
    # a black X on some drivers.
    for _h in /root "$(user_home)"; do
        [ -n "$_h" ] && [ -d "$_h" ] || continue
        for _v in 3.0 4.0; do
            mkdir -p "$_h/.config/gtk-$_v"
            cat > "$_h/.config/gtk-$_v/settings.ini" <<GTKINI
# Written by copal-init.sh (stage 17). GTK3 and GTK4 read separate copies of
# this file; both are written so newer applications are themed too.
[Settings]
gtk-theme-name=$_gtktheme
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-font-name=Recia 11
GTKINI
        done
        _own=$(stat -c '%u:%g' "$_h" 2>/dev/null) \
            && chown -R "$_own" "$_h/.config/gtk-3.0" "$_h/.config/gtk-4.0" 2>/dev/null || true
    done
    note "GTK 3 and 4: $_gtktheme, dark, Adwaita icons and cursor"

    # gsettings is what GTK4 and libadwaita actually consult at runtime on a
    # machine with dconf; settings.ini is the fallback for everything else.
    # Writing both is belt and braces, and neither is fatal if absent.
    if command -v gsettings >/dev/null 2>&1; then
        for _k in "gtk-theme $_gtktheme" "icon-theme Adwaita" "cursor-theme Adwaita" "font-name 'Recia 11'"; do
            gsettings set org.gnome.desktop.interface ${_k%% *} "${_k#* }" 2>/dev/null || true
        done
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    fi

    # 3. THE CURSOR, for the compositor itself rather than for GTK. Hyprland
    #    reads these from the environment, and the generated hyprland.conf
    #    already exports the sizes; the theme name goes here so an X session
    #    on the same machine agrees with the Wayland one.
    cat > /etc/profile.d/copal-cursor.sh <<'CURSORENV'
# Written by copal-init.sh. One cursor theme for both sessions.
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24
CURSORENV
    chmod 0644 /etc/profile.d/copal-cursor.sh

    # 4. AND THE X DESKTOP, which is still installed and still one word away.
    #    Stage 4 dresses i3 and the terminal in Tokyo Night; leaving it that
    #    way means flipping the session also flips the entire palette, which
    #    makes the fallback feel like a different machine rather than the
    #    same one without a compositor. Recolouring by hex substitution is
    #    exact and idempotent -- every one of these is a literal that stage 4
    #    wrote, so running this twice changes nothing the second time.
    #
    #    Tokyo Night          ->  Antiquity helios
    #      #7aa2f7 blue           #fccf8a  accent      (focused border)
    #      #7dcfff cyan           #fccf8a  accent      (indicator)
    #      #1a1b26 bg             #181818  base
    #      #16161e bar bg         #121212  shadow
    #      #292e42 inactive       #2a2a2a  highlight
    #      #c0caf5 fg             #d0daed  textLight
    #      #565f89 dim            #87704f  accentDark
    #      #f7768e red            #ff723e  urgent
    if [ -f "$(user_home)/.config/i3/config" ] || [ -f /root/.config/i3/config ]; then
        for _h in /root "$(user_home)"; do
            [ -n "$_h" ] && [ -d "$_h" ] || continue
            for _f in "$_h/.config/i3/config" "$_h/.Xresources"; do
                [ -f "$_f" ] || continue
                sed -i -e 's/#7aa2f7/#fccf8a/g' -e 's/#7dcfff/#fccf8a/g' \
                       -e 's/#1a1b26/#181818/g' -e 's/#16161e/#121212/g' \
                       -e 's/#292e42/#2a2a2a/g' -e 's/#c0caf5/#d0daed/g' \
                       -e 's/#565f89/#87704f/g' -e 's/#f7768e/#ff723e/g' \
                       -e 's/#9ece6a/#a0675d/g' -e 's/#bb9af7/#666c93/g' \
                       "$_f" 2>/dev/null || true
            done
            # The X session's own background, so the first frame before i3
            # starts is the theme's ground rather than Tokyo Night's.
            [ -f "$_h/.xinitrc" ] && sed -i 's/xsetroot -solid .#1a1b26./xsetroot -solid "#181818"/' \
                "$_h/.xinitrc" 2>/dev/null || true
        done
        note "the X desktop recoloured to match -- i3, Xresources and the root window"
        note "  so switching session changes the compositor, not the palette"
    fi

    # ------------------------------------------------------------------
    # Claim the session -- but only if there is something to claim it FOR.
    # This is the one exclusive act in the whole stage: from the next boot
    # (or the next copal-session) the console belongs to Hyprland, and
    # re-running stage 4 hands it back to X.
    #
    # ASKED OF THE MACHINE, NOT ASSUMED. The full level chooses Wayland by
    # itself when Wayland is actually available, which is exactly what the
    # binary being on PATH means -- so this tests for it rather than trusting
    # that the apk add above did what it was told. A stage that wrote
    # 'wayland' after a failed install would hand the console to a compositor
    # that is not there; copal-session would fall back to startx and the word
    # in the file would be a lie about the machine. Better to say so here,
    # once, while someone is reading the output.
    mkdir -p /etc/copal
    if command -v Hyprland >/dev/null 2>&1; then
        # Through copal-desktop, which also disarms X's setuid server -- see
        # the long note above that script. Nothing about the X desktop is
        # uninstalled; the privileged path is simply taken away while nothing
        # is using it, and `doas copal-desktop x11` puts both back together.
        copal-desktop wayland >/dev/null 2>&1 || printf 'wayland\n' > /etc/copal/session
        note "/etc/copal/session = wayland -- 'doas copal-desktop x11' switches back"
        if [ -e /usr/libexec/Xorg.wrap ] && [ ! -u /usr/libexec/Xorg.wrap ]; then
            note "X's setuid server disarmed while Wayland has the screen"
            note "  (Xwayland is a different binary and keeps every X program working)"
        fi
        configure_desktop_autostart Hyprland
        # THE TOAST THAT USED TO APPEAR AT EVERY LOGIN, and why it no longer
        # does:
        #
        #     Your system does not have hyprland-guiutils installed. This is a
        #     runtime dependency for some dialogs. Consider installing it.
        #
        # There is still nothing to install. Neither hyprland-guiutils nor its
        # old name hyprland-qtutils is packaged in any Alpine repository --
        # not community, not edge/testing. apk has hyprland-qt-support, which
        # is the QML style and NOT the binaries, and hyprpolkitagent, which is
        # something else again. Neither provides hyprland-dialog, which is the
        # program the check looks for.
        #
        # But it CAN be switched off, which an earlier reading of this got
        # wrong. The knob is misc:disable_hyprland_guiutils_check, and it is
        # spelled guiutils: upstream renamed the package and the variable
        # together, so 0.54.3 registers only the guiutils name and answers
        # "no such option" to qtutils -- which is exactly what made the
        # warning look permanent. The .conf written above sets it.
        #
        # What it costs is nothing that is used here. The dialogs are the
        # update screen, the donate screen and the app-not-responding prompt;
        # Copal updates through 'copal -U' and shows its own key list.
        if ! command -v hyprland-dialog >/dev/null 2>&1; then
            note "hyprland-guiutils is not packaged by Alpine and is not installed."
            note "  The login-time warning about it is switched off in hyprland.conf"
            note "  (misc:disable_hyprland_guiutils_check); nothing here uses the"
            note "  dialogs it provides."
        fi
    else
        warn "Hyprland is not on PATH -- the session is being left as it was."
        note "The theme's configs are installed and will be used the moment a"
        note "compositor exists; nothing here needs re-running but stage 17."
        [ -s /etc/copal/session ] || printf 'x11\n' > /etc/copal/session
        note "/etc/copal/session = $(cat /etc/copal/session 2>/dev/null)"
    fi

    # Last: the whole look, antiquity, on every layer this stage just wrote
    # -- and it is what adds the Themes-menu hook to Config.qml, so that
    # switching in quickshell's own menu carries the rest of the desktop.
    copal_apply_theme antiquity
    note "light <-> dark at any time:  copal-theme --toggle  (Super+Shift+N)"

    say "Stage 17 complete."
    cat <<MSG
    The Antiquity desktop runs as '$PI_USER', not as root. So:

        exit                     leave this root shell
        login as $PI_USER        at the console
        copal-session

    /etc/copal/session now says 'wayland', so copal-session starts Hyprland;
    stage 4's X desktop is still installed, and one word in that file (or
    re-running stage 4) brings it back. The two cannot run at once -- one
    seat, one compositor -- which is why it is a switch and not a menu.

    THE BAR IS WAYBAR, NOT QUICKSHELL. The Antiquity theme's bar, radial
    taskbar, widgets and launcher are 99 QML files for quickshell, and no
    Alpine repository packages quickshell -- so without a stand-in this
    desktop is the wallpaper and your windows, with no clock, no workspace
    indicator and no list of what is open. waybar fills that in, in the
    theme's own helios palette, with a real window list on the left. The day
    quickshell is packaged, copal-bar prefers it and nothing here changes.

        Super+b            hide and show the bar
        waybar -l debug    why the bar did not appear, if it did not

    COPAL-SESSION, NOT START-HYPRLAND. Alpine's hyprland package puts its own
    launcher on PATH, and it tab-completes from 'start' next to startx, so it
    is easy to find first. It starts the compositor with no session bus, so
    notifications, the portal and the polkit agent have nothing to talk over.
    copal-session wraps it in dbus-run-session, which is the difference.
    (It will no longer FAIL, at least: XDG_RUNTIME_DIR is now set for every
    login shell, which is what start-hyprland used to die without.)

    Super+Return terminal (foot)    Super+d/Space launcher
    Super+e      file manager       Super+Shift+s screenshot region
    Super+q · Super+\`  close window Super+f      fullscreen
    Super+Esc    force-quit program (SIGKILL -- nothing is saved)
    Super+1..9,0 workspaces         Super+Shift+p power down (copal-halt)
    Super+arrows move focus         Super+Shift+arrows move the window
    Alt+Tab      switch window      Super+Ctrl+arrows resize
    Super+c/v    copy / paste       Super+Ctrl+v clipboard history
    Super+b      hide/show the bar

    What is missing, honestly: quickshell -- the theme's radial taskbar and
    widgets -- has no Alpine package yet. Its configs are in place and
    copal-launcher already prefers it, so a future 'apk add quickshell' (or a
    source build: docs/THEME.md) completes the theme with no re-run of this
    stage. Until then wofi launches, mako notifies, the wallpaper hangs.

    If the screen stays black: 'dmesg | grep -i drm' first -- a compositor
    with no DRM device is the usual cause in a VM without a virtio GPU.
MSG
    install_manuals
    commit_reminder
}
