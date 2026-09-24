# playbook: stage-gui
# source:   copal
# origin:   stage
# stage:    4
# category: Desktop
# step:     X.Org, i3, a terminal and a browser
# weight:   9
# levels:   medium full
# summary:  Installs X.Org, the i3 tiling window manager, a terminal, a browser and Copal's desktop
#           helpers. The desktop every board can run, and the fallback on the ones that run
#           Hyprland.

stage_gui() {
    say "Stage 4: X.Org and a window manager"

    require_disk_root "X.Org and a desktop" || return 0
    require_network || return 1

    # The video and input drivers, and this is the one place where a VM and a
    # Pi want genuinely different answers.
    #
    # ON A PI there is no accelerated X driver for VideoCore worth using, so X
    # renders on the CPU straight into the framebuffer via fbdev. That has
    # been true since the first line of this script and it stays true.
    #
    # IN A VM fbdev is the wrong driver and it is the reason the display feels
    # like treacle. The hypervisor hands the guest a virtio-gpu, which is a
    # real KMS device; fbdev does not talk to it. It talks to /dev/fb0, which
    # on a KMS device is an EMULATION layer -- the kernel keeps a shadow copy
    # of the screen in ordinary memory, write-protects its pages, takes a page
    # fault on every write X makes, and periodically copies the dirtied
    # regions into the real scanout buffer. Every pixel is therefore drawn
    # twice and travels through a page-fault handler on the way. That is what
    # "the video buffer is slow" is: not the host, not Metal, not the window
    # scaling -- deferred-IO framebuffer emulation, sitting under a driver
    # from 1999.
    #
    # The modesetting driver, which is part of xorg-server and needs no
    # package of its own, drives the KMS device directly: X allocates the
    # scanout buffer itself and draws into it once. With mesa's DRI drivers
    # present it goes further and uses glamor, which puts the drawing on the
    # virtio-gpu instead of the CPU.
    #
    # So: modesetting wherever there is a KMS device AND this is a guest, and
    # the historical fbdev path everywhere else. Both conditions, on purpose.
    # is_vm() returns false for a Pi before it looks at anything else, which
    # is what keeps a Pi with vc4 KMS enabled on the path that has been
    # tested on it.
    say "Installing the X server"
    setup-xorg-base
    apk add xf86-input-libinput

    # SCROLLING DIRECTION, which X gets backwards on every machine this
    # script targets. libinput's default is the 1990s one: the wheel moves
    # the SCROLLBAR, so rolling it away from you sends the page up. Every
    # touch device made since, and macOS since Lion, moves the CONTENT
    # instead -- roll away, the page goes away from you -- and this desktop
    # is most often run in a VM on a Mac, where the host has already done it
    # that way and the guest then undoes it halfway down the same gesture.
    #
    # Set for pointers and touchpads alike, and the two need separate
    # InputClass sections: MatchIsTouchpad and MatchIsPointer are both
    # "matches" rather than a filter, so one section carrying both options
    # would apply the touchpad's to a mouse that has no touchpad options.
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/30-scrolling.conf <<'XORGSCROLL'
# Written by copal-init.sh, stage 4.
#
# Natural scrolling: rolling the wheel (or pushing two fingers) away from you
# moves the CONTENT away from you, which is what the page appears to follow.
# This is macOS's default and every phone's, and it is the direction the host
# has already applied when this is a VM on a Mac.
#
# To go back to the old direction, set both to "false" -- or delete this file,
# because false is what libinput does with no configuration at all.
Section "InputClass"
    Identifier  "copal natural scrolling (pointers)"
    MatchIsPointer  "on"
    Driver      "libinput"
    Option      "NaturalScrolling" "true"
EndSection

Section "InputClass"
    Identifier  "copal natural scrolling (touchpads)"
    MatchIsTouchpad "on"
    Driver      "libinput"
    Option      "NaturalScrolling" "true"
    Option      "Tapping" "on"
EndSection
XORGSCROLL
    note "/etc/X11/xorg.conf.d/30-scrolling.conf -- scrolling direction lives here"
    if is_vm && [ -e /dev/dri/card0 ]; then
        say "This is a guest with a KMS display -- using modesetting, not fbdev"
        # The DRI drivers. Without them modesetting still works and is still
        # far quicker than fbdev, but falls back to drawing on the CPU; with
        # them glamor hands the drawing to the virtual GPU. mesa-dri-gallium
        # carries virgl, which is the driver for virtio-gpu.
        add_optional mesa-dri-gallium mesa-gl
        # glxinfo, and it earns its couple of megabytes: it is the only way to
        # see the layer that lies most convincingly. Everything else can be
        # correct and mesa still fall back to llvmpipe, which is software
        # rendering with a hardware-sounding name. copal-gpu reads it.
        add_optional mesa-demos
        # Written rather than left to autodetection. X does prefer modesetting
        # over fbdev on a KMS device, but "does" is a property of one version
        # of one autoconfig heuristic, and the cost of being wrong is the slow
        # path silently coming back. Say it.
        mkdir -p /etc/X11/xorg.conf.d
        cat > /etc/X11/xorg.conf.d/20-modesetting.conf <<'XORGKMS'
# Written by copal-init.sh, stage 4. See the essay in stage_desktop().
#
# This machine is a guest with a KMS display (virtio-gpu, or whatever the
# hypervisor offered). modesetting draws into the scanout buffer directly;
# fbdev would go through the kernel's framebuffer emulation and copy every
# pixel twice. Delete this file to go back to autodetection.
Section "Device"
    Identifier  "kms"
    Driver      "modesetting"
    # glamor is the accelerated path -- it needs a working DRI driver, which
    # is what mesa-dri-gallium provides. If the display is BLACK or X exits
    # with an EGL error, this is the line to comment out first: without it
    # modesetting draws on the CPU, which is still much faster than fbdev.
    Option      "AccelMethod" "glamor"
EndSection
XORGKMS
        note "/etc/X11/xorg.conf.d/20-modesetting.conf -- delete it to autodetect"
        note "A black screen after this? Comment out the AccelMethod line in it."
    else
        say "Installing the framebuffer driver"
        apk add xf86-video-fbdev
    fi

    # i3 tiles, so windows never overlap and the CPU never redraws an occluded
    # region. On a board with no acceleration, where every pixel is pushed by
    # the CPU, that is a performance decision as much as an ergonomic one.
    say "Installing i3 and friends"
    # dmenu is not optional: without it Super+space does nothing and i3 has no
    # way to launch anything at all. It is the launcher, not a nicety.
    apk add i3wm i3status dmenu
    # font-dejavu, not ttf-dejavu: Alpine renamed the font packages to the
    # font-* prefix and the old name resolves to nothing.
    add_optional i3lock xterm font-terminus font-dejavu xsetroot jgmenu
    # What every GTK application assumes is already there, and which nothing
    # in the dependency chain actually installs.
    #
    # gtk+3.0 does not depend on an icon theme. Neither does wxwidgets, nor
    # codeblocks, nor any of the GTK programs in the catalogue -- so a desktop
    # built from those alone has NO icon theme at all, not even the empty
    # directory skeleton that icon lookups expect to find. What that produces
    # is not a missing picture: an icon lookup that fails hands the toolkit an
    # invalid bitmap, and wxWidgets asserts on it --
    #
    #     assert "IsOk()" failed in GetHeight(): invalid bitmap
    #     assert "IsOk()" failed in DoDrawText(): invalid DC
    #
    # -- and its assert handler raises SIGTRAP, so Code::Blocks does not
    # degrade, it dies on startup.
    #
    # hicolor is the skeleton and index every theme inherits from; adwaita is
    # the one that actually contains icons. gsettings-desktop-schemas is the
    # other silent assumption -- GTK reads settings out of it and misbehaves
    # in less obvious ways when it is absent.
    #
    # 0.3 MB for the two small ones, and adwaita is 12.6 MB. Worth it: the
    # alternative is a desktop where GTK and wx applications fail in ways that
    # look like bugs in the applications.
    add_optional hicolor-icon-theme gsettings-desktop-schemas
    add_optional adwaita-icon-theme

    # Both remap Caps Lock to Super in .xinitrc -- see the comment there for
    # why that key matters more than it looks. Either one is enough; they are
    # a few kilobytes each and setup-xorg-base does not guarantee them.
    add_optional setxkbmap xmodmap

    # A terminal, a file manager, a task manager. pcmanfm is the lightest of
    # the GTK file managers; htop is the task manager -- a GUI one would cost
    # more RAM than it saves in convenience on 512 MB.
    say "Installing a file manager and a task manager"
    add_optional pcmanfm htop ncdu mc jgmenu
    # yad drives the Copal Center, dialog is its terminal fallback; feh and
    # ImageMagick paint the key bindings onto the root window. All four are
    # small, and all four are guarded at runtime -- none is required.
    add_optional yad dialog feh imagemagick
    # copal-gui, the Mint-style menu (Super+A), is Python over GTK 3 -- which
    # yad has already brought in, so this is the bindings and nothing else.
    add_optional python3 py3-gobject3 gtk+3.0

    # THE UNIFIED CLIPBOARD's X half. Omarchy's best small idea is that
    # Super+C and Super+V copy and paste EVERYWHERE, including the terminal,
    # instead of the terminal needing Ctrl+Shift and everything else needing
    # Ctrl. Making that true on X needs two programs: xclip owns the
    # selection, and xdotool sends the chord the focused window actually
    # wants. copal-clip is guarded at runtime and says which one is missing,
    # so a board without them keeps Ctrl+Shift+C and loses nothing else.
    add_optional xclip xdotool
    # urxvt starts faster and uses less RAM than xterm; fall back if absent.
    if try_add rxvt-unicode && command -v urxvt >/dev/null 2>&1; then
        TERMEMU=urxvt
    else
        TERMEMU=xterm
    fi
    note "terminal: $TERMEMU"

    # ------------------------------------------------------------------
    # Shared clipboard with the Mac, on a VM that offers one.
    #
    # UTM already attaches the SPICE agent channel -- it is there as
    # /dev/virtio-ports/com.redhat.spice.0 on a machine created by utm-vm.sh,
    # without anything being asked for. What is missing is the guest half, and
    # without it "Enable Clipboard Sharing" in UTM's settings is a switch wired
    # to nothing: the host offers a channel and no one answers.
    #
    # DETECTED BY THE PORT, not by asking what kind of machine this is. The
    # port exists exactly when a hypervisor is offering the channel, which is
    # the actual question -- so this installs itself on a UTM or QEMU guest and
    # is skipped in silence on a Pi, with no VM check to keep in step with
    # reality. Same shape as the 9p share: the thing that can answer is asked.
    #
    # TWO PROCESSES, and both are needed. spice-vdagentd is the system daemon
    # that owns the virtio port; spice-vdagent is a per-session program that
    # runs inside X and is what actually syncs the selection. The daemon is
    # started here; the session half is launched by whichever desktop comes
    # up -- ~/.xinitrc for i3, an exec-once in hyprland.conf for Hyprland --
    # because a clipboard agent with no session to read a selection from has
    # nothing to do. That is also why this cannot help a machine whose desktop
    # will not start: there is no selection to share until there is one.
    #
    # BOTH ENDS ARE X11, including the Wayland one. vdagent is an X11 program
    # and Hyprland keeps the Xwayland selection in step with the Wayland one,
    # so the agent talks to Xwayland and the whole desktop sees the result.
    # Do not assume the Wayland session covers itself: it went a full release
    # with the daemon running, the channel open and no agent to answer it.
    #
    # It brings dynamic resolution with it, which on a VM window that gets
    # dragged around is worth as much as the clipboard.
    if ! is_vm; then
        # Belt and braces. The port test below is already impossible to pass on
        # a Pi -- virtio ports come from a device a hypervisor creates, and
        # there is no hypervisor -- but a guest-only package refusing to
        # install on hardware should say so for a reason anyone can check,
        # rather than by silently failing a test whose meaning is not obvious.
        note "real hardware -- no clipboard agent (that is a guest-only thing)"
    elif [ -e /dev/virtio-ports/com.redhat.spice.0 ]; then
        say "This machine is offered a clipboard channel -- installing the agent"
        if add_optional spice-vdagent; then
            rc-update add spice-vdagentd default >/dev/null 2>&1 || true
            rc-service spice-vdagentd restart >/dev/null 2>&1 \
                || rc-service spice-vdagentd start >/dev/null 2>&1 || true
            if rc-service spice-vdagentd status >/dev/null 2>&1; then
                note "spice-vdagentd running -- copy and paste both ways once the desktop is up"
            else
                warn "spice-vdagentd did not start -- 'rc-service spice-vdagentd start' to see why"
            fi
            note "UTM must also have Edit > Sharing > Enable Clipboard Sharing on"
            note "Files go through /mnt/share instead -- the clipboard is text, not files"
        else
            warn "spice-vdagent is not available -- no shared clipboard"
            note "it lives in the community repository; check /etc/apk/repositories"
        fi
    else
        note "no clipboard channel offered by the host -- skipping the agent"
    fi

    say "Writing ~/.xinitrc"
    cat > /tmp/xinitrc.$$ <<'XINIT'
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
# The session half of the shared clipboard. Guarded twice: the binary may not
# be installed (a Pi, or a VM offering no channel), and the port may not exist
# even where it is. Backgrounded because it does not exit -- it runs for as
# long as the session does.
if [ -x /usr/bin/spice-vdagent ] && [ -e /dev/virtio-ports/com.redhat.spice.0 ]; then
    /usr/bin/spice-vdagent &
fi
# A flat colour rather than a wallpaper: an image costs framebuffer bandwidth
# this board does not have to spare.
# A solid colour before i3 starts, so the first frame is never the X root
# weave. i3 then runs copal-splash, which paints the key bindings over it.
# Caps Lock becomes a second Super key.
#
# On a Mac host this is the difference between a usable desktop and a
# minefield. The Mac's Command key arrives in this guest as Super, so every
# Super binding in i3 is simultaneously a macOS shortcut -- and three of them
# end the session outright: Cmd+W stops the VM mid-write, Cmd+Q quits UTM and
# every machine in it, Cmd+Shift+Q logs out of macOS. Nothing inside the guest
# can defend against that, because the key is taken by the host before this
# machine is offered it.
#
# Pressing Caps Lock instead sends a key macOS reserves nothing on. The whole
# binding set becomes reachable AND safe, and not one binding has to move.
#
# UTM has to be told to pass the key through rather than sync it as a host
# toggle. Once, on the Mac:
#
#     defaults write com.utmapp.UTM IsCapsLockKey -bool true
#
# On real hardware it costs a Caps Lock nobody wanted and gains a large key
# under the left pinky, so it is done unconditionally rather than guessing at
# the host from inside the guest.
if command -v setxkbmap >/dev/null 2>&1; then
    setxkbmap -option caps:super 2>/dev/null || true
fi
# Verified, not assumed. setxkbmap exits 0 even when xkbcomp rejected the
# option, so on an xkeyboard-config too old or too trimmed to carry
# caps:super the keyboard would be left silently unchanged -- which is worse
# than either outcome, because the failure only shows up as a VM that stopped
# itself. If the Caps_Lock keysym is still bound anywhere, it did not take,
# and the xmodmap form works on any X there has ever been.
if command -v xmodmap >/dev/null 2>&1 && xmodmap -pke 2>/dev/null | grep -q Caps_Lock; then
    xmodmap -e 'clear lock' \
            -e 'keysym Caps_Lock = Super_L' \
            -e 'add mod4 = Super_L' 2>/dev/null || true
fi
command -v xsetroot >/dev/null && xsetroot -solid '#1a1b26'
# The per-user sound server (PipeWire), if stage 10 installed it.
command -v copal-audio-start >/dev/null 2>&1 && copal-audio-start
exec i3
XINIT
    install_home_file .xinitrc /tmp/xinitrc.$$; rm -f /tmp/xinitrc.$$

    # i3 would otherwise run its config wizard on first launch and block on a
    # question. Writing the config skips that and pins Super as the modifier,
    # so Alt stays free for the terminal.
    # Written before the i3 config, because the config binds four keys to it.
    write_copal_clip

    # The bar, the window list and the widgets. Without this the desktop is
    # the wallpaper and nothing else -- see the essay above hypr_write_waybar().
    hypr_write_waybar

    say "Writing ~/.config/i3/config"
    {
        cat <<'I3A'
# i3 config -- generated by copal-init.sh
set $mod Mod4
font pango:DejaVu Sans Mono 9

I3A
        printf 'set $term %s\n\n' "$TERMEMU"
        cat <<'I3B'
# i3 has no desktop icons and no start menu -- that is the design, not a
# failure. dmenu is the launcher: it takes over the top of the screen, you
# type a few letters of a program name, Enter runs it. Super+space matches
# where Omarchy puts its launcher.
bindsym $mod+d      exec dmenu_run
bindsym $mod+space  exec dmenu_run
# Alt+space as well. On a Mac keyboard Alt is the Option key, which sits
# next to the Space bar and is next to Command -- the muscle memory for
# "launcher" ends up on whichever of the two the host has not eaten. macOS
# reserves Option+Space for nothing, so under UTM it arrives intact.
#
# The cost is the same shape as the Ctrl+Space one further down: i3 grabs it
# globally, so Alt+Space stops reaching applications. What it reaches there
# is the window menu in a few GTK/Qt programs and just-one-space in emacs --
# less than Ctrl+Space costs, which is why this one is not hedged about.
bindsym Mod1+space  exec dmenu_run
bindsym $mod+Return exec $term
bindsym $mod+e      exec pcmanfm
bindsym $mod+t      exec $term -e htop
# The camera -- birdshot, built from ~/code by stage 7, or whatever $CAMERA
# names. copal-camera is the one place that decision is made.
bindsym $mod+Shift+b exec copal-camera
bindsym $mod+Shift+q kill
# A clickable menu, built from what is actually installed. Falls back to
# dmenu over the same list when jgmenu is absent, so it always works.
bindsym $mod+z      exec copal-menu
# The other menu: Linux Mint's, for the mouse -- favourites, categories,
# icons, search. Built from the .desktop files; see copal-gui.
bindsym $mod+a      exec copal-gui
# The desk, laid out the same way every time -- see copal-desk.
bindsym $mod+Shift+d exec --no-startup-id copal-desk
# And the same menu on a right-click on the desktop, which is where everyone
# who has ever used a computer looks for it first. i3 has no desktop of its
# own -- what you are clicking is the X root window, visible wherever no
# window covers it -- but i3 does deliver root-window button presses to
# bindings, so this is a one-liner rather than a second daemon.
#
# WITHOUT --whole-window on purpose. A bare button binding matches the root
# window and window decorations only; add --whole-window and every
# right-click inside every application would open this menu instead of the
# application's own context menu, which would be unusable.
#
# --release, so the menu opens when the button comes back up. jgmenu grabs
# the pointer as it maps, and a menu that appears under a button already
# held down takes the release as a click on whatever entry is under the
# cursor. --at-pointer puts it where the click was rather than at the
# corner the config would otherwise pin it to.
bindsym --release button3 exec --no-startup-id copal-menu --at-pointer
# One window listing the whole catalogue -- what is installed and what is
# not -- with a button that either runs it or fetches it.
#
# This used to be Super+C. It moved because Super+C is now COPY -- see the
# unified clipboard block below, which is the one Omarchy convention worth
# breaking an existing binding for.
bindsym $mod+Shift+c exec copal-center
# The wallpaper picker. feh's thumbnail grid on X, which is the nicer of the
# two pickers -- a wall of pictures, click one. Also in the menu under Style.
bindsym $mod+Shift+w exec --no-startup-id copal-wallpaper --pick
# System settings: users and groups, hostname, services, SSH, boot options.
# It asks doas for the root it needs rather than assuming it has it.
bindsym $mod+comma  exec copal-config

# THE UNIFIED CLIPBOARD -- Omarchy's convention, and the single change in this
# file most likely to be noticed on day one.
#
# One set of keys for copy, cut and paste in every window, terminal included,
# instead of Ctrl+Shift+C here and Ctrl+C there. copal-clip looks at what has
# focus and sends the chord that window wants; see the essay above
# write_copal_clip() in copal-prep.sh for why the terminal is the exception
# that makes this necessary.
#
# AND: Caps Lock is a second Super on this machine. So this is CapsLock+C and
# CapsLock+V -- which is, under the fingers, Cmd+C and Cmd+V. That is the
# whole reason to prefer these over the ones you already know.
bindsym $mod+c      exec --no-startup-id copal-clip copy
bindsym $mod+x      exec --no-startup-id copal-clip cut
bindsym $mod+v      exec --no-startup-id copal-clip paste
bindsym $mod+Ctrl+v exec --no-startup-id copal-clip history

# System controls, on Omarchy's chords, using the programs this machine has
# rather than the ones it does not. Each is a terminal program in a floating
# window, which is the whole of a "control panel" on a board this size.
bindsym $mod+Ctrl+a exec $term -title copal-panel -e alsamixer
bindsym $mod+Ctrl+t exec $term -title copal-panel -e sh -c 'command -v btop >/dev/null && exec btop; exec htop'
# Omarchy has Super+Ctrl+W for wifi (impala) and Super+Ctrl+B for bluetooth.
# Neither program is packaged for this hardware and neither is the way this
# system does networking -- wifi here is wpa_supplicant, configured in stage
# 10 and in copal-config on Super+comma. A binding that opened something that
# could not change the setting would be worse than no binding, so there is
# none, and this comment is where you would add yours.
# Music. Omarchy puts Spotify here; there is no Spotify for this hardware and
# there does not need to be -- cmus is a better music player on 512 MB than
# anything with a web browser inside it. mpv is the fallback, on the same key,
# because between them they play everything on the machine.
bindsym $mod+Shift+m exec $term -title copal-panel -e sh -c 'command -v cmus >/dev/null && exec cmus; exec mpv --no-video ~/Music'
# The editor, on Omarchy's key.
bindsym $mod+Shift+n exec $term -title nvim -e sh -c 'command -v nvim >/dev/null && exec nvim; exec vi'
# The download queue: the URL on the clipboard is queued ('ytq clip'). It
# downloads by itself once ~/.config/ytq/auto exists; otherwise 'ytq run'.
# ytq is built from ~/code/staticstream by copal-build, into ~/.local/bin;
# until something on PATH is called ytq, the key does nothing.
bindsym $mod+Shift+y exec --no-startup-id sh -c 'command -v ytq >/dev/null && exec ytq clip'
# The Workspace: a Browser over the folder the queue archives into, with the
# queue itself as one more column (Q). Same crate as ytq, same checkout, so
# the same "until it is on PATH the key does nothing" applies. A terminal
# program, so it is opened in one -- unlike Super+Shift+Y, which takes the
# clipboard and needs no window at all.
bindsym $mod+Shift+a exec --no-startup-id sh -c 'command -v sstr-workspace >/dev/null && exec TERMEMU_PLACEHOLDER -title sstr-workspace -e sstr-workspace'
for_window [title="copal-panel"] floating enable, resize set 760 520, move position center
# The key list, in a floating window. Shown once at login and on Super+/,
# because a tiling WM with no menus is unusable until you know the bindings.
set $helpcmd TERMEMU_PLACEHOLDER -title i3-keys -e less ~/.config/i3/keys.txt
bindsym $mod+slash exec $helpcmd
bindsym $mod+F1    exec $helpcmd
# The other guides -- the small web, and whatever else lands in
# /usr/local/share/copal/guides. Super+g is taken by the layout toggle.
bindsym $mod+Shift+g exec $term -title i3-keys -e guide
for_window [title="guide"] floating enable, resize set 740 560, move position center
for_window [title="i3-keys"] floating enable, resize set 740 560, move position center, border pixel 2
# The Copal Center is a dialog, not a tiled window -- let it float.
for_window [title="Copal Center"] floating enable, resize set 700 520, move position center

# Both run at i3 startup only, not on reload. copal-splash paints the key
# bindings onto the root window, so they are there whenever nothing is open;
# $helpcmd shows the scrollable version once. Delete either line to stop it.
exec --no-startup-id copal-splash
exec --no-startup-id $helpcmd
# The Geiger monitor, if stage 10 installed radbeeper. 'radbeeper hotplug' sits
# in the session and opens the monitor when a counter appears -- at login if one
# is already plugged in, and on plug-in at any point after. It is deliberately
# silent when there is no counter, because a window that opens at every login to
# say "nothing is plugged in" gets closed at every login and then gets deleted.
# It watches for a device NODE and never opens the port itself, so it does not
# fight the monitor for the device once one is running.
exec --no-startup-id sh -c 'command -v radbeeper >/dev/null 2>&1 && exec radbeeper hotplug'
# Copal Apps' slideshow, only while programs queued by the full monty are
# being installed (stage 18); otherwise it exits at once.
exec --no-startup-id sh -c 'command -v copal-apps >/dev/null 2>&1 && exec copal-apps --follow'

# The clipboard history recorder. One xclip call a second; it is what makes
# Super+Ctrl+V have anything to show. Delete this line to stop recording.
exec --no-startup-id copal-clip watch
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"
# The whole of ending the day: it asks, closes the session so applications are
# asked to quit rather than killed, syncs, and powers down. Super+Shift+E above
# only leaves i3, which is the step people mistake for a shutdown.
bindsym $mod+Shift+p exec copal-halt
# The keyboard's power key. A USB keyboard sends KEY_POWER as an INPUT event,
# not an ACPI one, and X grabs the keyboard -- so acpid never sees this one and
# the binding is the only thing that catches it. The ACPI power button, and
# UTM's Request Power Down, are handled by acpid instead and need nothing here.
bindsym XF86PowerOff exec copal-halt
bindsym $mod+Shift+Delete exec copal-halt reboot

# focus / move, arrows and hjkl both
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

bindsym $mod+b splith
# Super+V is PASTE now (the unified clipboard, below), so "split downwards"
# moved one key over. Super+B is still "split rightwards" and is the one of
# the pair anybody actually presses.
bindsym $mod+Shift+v splitv
bindsym $mod+f fullscreen toggle
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+g layout toggle split
bindsym $mod+Shift+space floating toggle
bindsym $mod+Tab focus mode_toggle

# Resize -- the tiling answer to dragging a window edge.
mode "resize" {
        bindsym h resize shrink width 8 px or 8 ppt
        bindsym j resize grow height 8 px or 8 ppt
        bindsym k resize shrink height 8 px or 8 ppt
        bindsym l resize grow width 8 px or 8 ppt
        bindsym Left  resize shrink width 8 px or 8 ppt
        bindsym Down  resize grow height 8 px or 8 ppt
        bindsym Up    resize shrink height 8 px or 8 ppt
        bindsym Right resize grow width 8 px or 8 ppt
        bindsym Return mode "default"
        bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Five workspaces. Not ten: on 512 MB you will run out of RAM long before you
# run out of workspaces, and a row of empty numbers in the bar is just noise.
# Super+1..5 switches, Super+Shift+1..5 throws the focused window there.
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
# Cycle without leaving the home row, for when you have forgotten which is
# which -- Super+Tab is taken by the split/tabbed toggle above.
bindsym $mod+Ctrl+Right workspace next
bindsym $mod+Ctrl+Left  workspace prev

# ---------------------------------------------------------------------------
# WHEN THE HOST STEALS A KEY
#
# Under UTM on a Mac, some of the bindings above never arrive. The Mac's
# Command key reaches this guest as Super, so every shortcut macOS reserves
# for itself is a Super binding that quietly does nothing here -- and does
# something on the Mac instead, which is the worse half of the problem:
#
# THREE OF THEM DESTROY THE SESSION, and no binding in this file can stop
# that. The key is taken by macOS before the guest is offered it, so i3 never
# gets a chance to grab it, ignore it, or bind it to nothing. An alternate
# binding gives you another way to do the thing -- it does NOT take the
# dangerous key away. Only the Mac can do that; see the last paragraph.
#
#   Super + W              CLOSES THE VM WINDOW, which stops the machine.
#                          If UTM's quit confirmation has been turned off it
#                          happens with no dialog and no warning -- the same
#                          as pulling the power, mid-write.
#   Super + Q              QUITS UTM. Every running VM, not just this one.
#   Super + Shift + Q      LOGS OUT OF macOS.
#
# The rest merely go missing, which is the harmless half:
#
#   Super + Space          Spotlight opens on the Mac. The launcher -- the
#                          most used binding in this config -- never runs.
#   Super + Tab            the Mac's application switcher.
#   Super + Shift + 3/4/5  macOS screenshots. Cmd+Shift+3 photographs the
#                          screen; it does not move a window to workspace 3.
#   Super + H              Hide the front application.
#   Super + M              Minimise the window.
#   Super + comma          Preferences -- UTM's own settings window opens.
#   Super + F1             toggles display mirroring.
#   Super + Ctrl + arrows  Mission Control, moving between Mac desktops.
#
# So each of those gets a SECOND binding on a modifier macOS does not
# reserve -- and not only those: EVERY Super binding in this file has one, so
# the rule never runs out halfway through. Two lines, not a table to memorise:
#
#     WHERE SUPER IS EATEN, PRESS CTRL+ALT INSTEAD.
#     WHERE THE BINDING ALSO HAS CTRL IN IT, PRESS CTRL+ALT+SHIFT.
#
# The rest of the binding stays exactly where it was. The second line exists
# because a modifier set has no duplicates -- Super+Ctrl+V cannot become
# Ctrl+Alt with a Ctrl in it -- and the generated block at the end of this
# file is where the two rules are actually applied.
#
# Ctrl+Alt rather than plain Ctrl, because i3 grabs a binding globally and
# system-wide: Ctrl+W and Ctrl+H bound here would stop being kill-word and
# backspace in every terminal on the machine, for good. Ctrl+Alt is claimed
# by nothing in i3 and nothing in a shell. On the Mac side it is claimed only
# by VoiceOver, which is off unless you turned it on -- if it is on, these
# are the bindings it will take.
#
# These are additions, not replacements. The Super bindings above still work,
# and on real hardware -- a Pi, a PC -- nothing steals them, so nothing here
# is needed. Extra grabs cost a few bytes of i3's key table. Delete the block
# if you want them gone.
#
# For the three destructive ones the fix is not here, it is on the Mac, and it
# is worth doing once:
#
#   defaults write com.utmapp.UTM NoQuitConfirmation -bool false
#       Puts back the "are you sure" dialog on closing a VM window. If
#       Super + W has already stopped a machine out from under you without
#       asking, this preference is why.
#
#   System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > +
#       Application UTM, menu title "Close", new shortcut Cmd+Shift+W.
#       Moving the menu item's key is what actually takes Cmd+W away from
#       UTM; nothing inside the guest can.
# The list itself is not written here. Every one of these bindings is a copy
# of a Super binding above with the modifier swapped, and a hand-kept copy of
# a list is a list that drifts: add a binding, forget the twin, and the rule
# stops being true exactly where somebody is relying on it. So the twins are
# GENERATED from the Super bindings, by the awk pass that runs just after this
# file is assembled -- see the block after the closing brace of this heredoc
# in copal-prep.sh. Add a bindsym above and its Ctrl+Alt twin appears by
# itself; delete one and the twin goes with it.

# The launcher gets plain Ctrl+Space on top of the Ctrl+Alt one. It is the
# binding reached most often and the one Spotlight takes most reliably, and
# two extra fingers on the most frequent action of the day is a bad trade.
#
# This line DOES cost something, unlike the block above: i3 grabs Ctrl+Space
# globally, so it stops reaching emacs as set-mark and IBus as its input
# switcher. If either matters more than the launcher does, delete this line
# and use Ctrl+Alt+Space, which does the same job and takes nothing away.
bindsym Ctrl+space exec dmenu_run

floating_modifier $mod
bindsym $mod+Shift+s exec i3lock -c 1c1c1c

# 1px borders: every pixel of decoration is CPU-drawn here.
default_border pixel 1
default_floating_border pixel 1
hide_edge_borders smart

# Tokyo Night. One palette across i3, the terminal, nvim and btop -- the
# omakase idea that a coherent system is a motivating one.
# class                 border  bg      text    indicator child_border
client.focused          #7aa2f7 #7aa2f7 #1a1b26 #7dcfff   #7aa2f7
client.focused_inactive #292e42 #292e42 #c0caf5 #292e42   #292e42
client.unfocused        #1a1b26 #1a1b26 #565f89 #1a1b26   #1a1b26
client.urgent           #f7768e #f7768e #1a1b26 #f7768e   #f7768e
# The current theme's colours, written by copal-theme; included so they win
# over the four lines above when the theme is not this one.
include ~/.config/copal/current/i3-colors.conf

bar {
        status_command i3status
        position top
        # The tray, on the primary output. nm-applet and blueman-applet from
        # the catalogue live there, and qBittorrent "minimises to the tray":
        # with tray_output none those had nowhere to appear and a window
        # closed to the tray was gone until the process was killed.
        tray_output primary
        colors {
                background #16161e
                statusline #c0caf5
                separator  #565f89
                focused_workspace  #7aa2f7 #7aa2f7 #1a1b26
                inactive_workspace #16161e #16161e #565f89
                urgent_workspace   #f7768e #f7768e #1a1b26
        }
}
I3B
    } > /tmp/i3cfg.$$

    # ----------------------------------------------------------------------
    # THE CTRL+ALT TWINS, generated rather than written.
    #
    # Under UTM every Super chord is a macOS shortcut first, so the config
    # above carries a second modifier for the whole binding set. Doing that by
    # hand covered the dozen bindings somebody remembered on the day; this
    # walks the file that was just written and gives EVERY Super binding a
    # twin, so the promise "where Super is eaten, press Ctrl+Alt" is true of
    # all of them rather than most of them. A binding added above gets its
    # twin for free, which is the whole point of generating it.
    #
    # The mapping, and there are only two rules:
    #
    #     $mod+KEY            ->  Ctrl+Mod1+KEY
    #     $mod+Shift+KEY      ->  Ctrl+Mod1+Shift+KEY
    #     $mod+Ctrl+KEY       ->  Ctrl+Mod1+Shift+KEY
    #
    # The third line is the one that needs explaining. A modifier set has no
    # order and no duplicates, so Super+Ctrl+V cannot become "Ctrl+Alt with a
    # Ctrl in it" -- that is just Ctrl+Alt+V, which the plain rule has already
    # given to Super+V. The Super+Ctrl family needs a modifier of its own, and
    # Shift is the only one left. Hence: WHERE THE BINDING HAS CTRL IN IT,
    # PRESS CTRL+ALT+SHIFT.
    #
    # That collides with the Super+Shift family in exactly three places, and
    # all three are resolved here rather than left for i3 to arbitrate -- i3
    # takes the FIRST of a duplicated binding and logs the second as an error
    # nobody reads, so an unmanaged collision is a binding that silently does
    # the wrong thing.
    #
    #   Ctrl+Alt+Shift+Left/Right go to workspace prev/next (Super+Ctrl+arrow,
    #       the pair macOS eats for Mission Control -- the reason any of this
    #       exists). Moving a window left and right loses its arrow twin and
    #       keeps its letter one, Ctrl+Alt+Shift+H and +L, which is the same
    #       action on the keys i3 was designed around.
    #   Ctrl+Alt+Shift+V goes to the clipboard history (Super+Ctrl+V), which
    #       is reached daily. splitv, which would otherwise have had it, is
    #       given Ctrl+Alt+Shift+B instead -- splith is on B already, so the
    #       vertical one lands next to the horizontal one rather than nowhere.
    #
    # Written to a second file and appended, not edited in place: awk reading
    # a file it is also appending to is a loop, not a program.
    awk '
        /^bindsym \$mod\+/ {
            key = $2
            # The three collisions above: the Super+Ctrl claimant wins the
            # chord, so these Super+Shift ones are skipped and re-placed by
            # hand below.
            if (key == "$mod+Shift+Left" || key == "$mod+Shift+Right" \
                || key == "$mod+Shift+v") next
            rest = substr($0, index($0, key) + length(key))
            sub(/^[ \t]+/, "", rest)
            twin = key
            if (sub(/^\$mod\+Ctrl\+/,  "Ctrl+Mod1+Shift+", twin)) { }
            else if (sub(/^\$mod\+Shift\+/, "Ctrl+Mod1+Shift+", twin)) { }
            else sub(/^\$mod\+/, "Ctrl+Mod1+", twin)
            # Belt and braces against a future collision nobody predicted:
            # first claimant keeps the chord, and the loser is reported at
            # install time rather than discovered as a dead key months later.
            if (twin in seen) {
                printf "# SKIPPED (%s already bound): %s\n", twin, key
                next
            }
            seen[twin] = 1
            printf "bindsym %-26s %s\n", twin, rest
        }
    ' /tmp/i3cfg.$$ > /tmp/i3alt.$$
    {
        printf '\n# ---- Ctrl+Alt twins, generated from the Super bindings above ----\n'
        printf '# One rule: where Super is eaten by the Mac, press Ctrl+Alt. Where the\n'
        printf '# binding already has Ctrl in it, press Ctrl+Alt+Shift. Delete this\n'
        printf '# whole block on a machine that is not a guest; nothing depends on it.\n'
        cat /tmp/i3alt.$$
        printf 'bindsym Ctrl+Mod1+Shift+b  splitv\n'
    } >> /tmp/i3cfg.$$
    rm -f /tmp/i3alt.$$
    # Loud, because a collision report inside a generated file is a comment
    # nobody will ever open the file to read.
    if grep -q '^# SKIPPED' /tmp/i3cfg.$$; then
        warn "some Ctrl+Alt twins collided and were skipped:"
        grep '^# SKIPPED' /tmp/i3cfg.$$ | sed 's/^/      /'
    fi
    # AFTER the twins, deliberately. Each of these would collide with a twin
    # the block above already generated (Super+Ctrl+Space's twin is
    # Super+Shift+Space's; Super+Shift+T's is Super+Ctrl+T's) or produce a
    # meaningless one (Ctrl+Alt+Alt). They are doors, not verbs: the one
    # implementation behind each is bound elsewhere in this file already.
    {
        printf '\n# ---- more doors ---------------------------------------------------\n'
        printf '# The theme picker; and the two chords Omarchy uses for its system menu\n'
        printf '# and wallpaper picker, so hands that learned them there land somewhere.\n'
        printf 'bindsym $mod+Shift+t     exec --no-startup-id copal-theme --pick\n'
        printf 'bindsym $mod+Shift+n     exec --no-startup-id copal-theme --toggle\n'
        printf 'bindsym $mod+Mod1+space  exec copal-menu --system\n'
        printf 'bindsym $mod+Ctrl+space  exec --no-startup-id copal-wallpaper --pick\n'
        printf '\n# ---- yours ---------------------------------------------------------\n'
        printf '# Everything above is rewritten whenever stage 4 runs; local.conf is not.\n'
        printf '# Included last, so it wins.\n'
        printf 'include ~/.config/i3/local.conf\n'
    } >> /tmp/i3cfg.$$

    # $helpcmd holds a command line, and it is built here rather than left as
    # "$term -title ..." for i3 to expand.
    #
    # i3 substitutes a variable used inside ANOTHER variable's definition, and
    # this used to rely on that. It also produced, at login and only at login:
    #
    #     /bin/sh: -title: not found
    #
    # which is what you get when $term expands to nothing and the first word
    # of the command becomes the option after it. The config was correct --
    # `set $term urxvt` on line 5, `set $helpcmd $term ...` on line 28, in
    # that order, urxvt installed, and the same command run by hand works.
    # Rather than depend on the ordering rules of somebody else's parser for
    # something we already know the value of, put the value in.
    sed -i "s|TERMEMU_PLACEHOLDER|$TERMEMU|" /tmp/i3cfg.$$
    install_home_file .config/i3/config /tmp/i3cfg.$$; rm -f /tmp/i3cfg.$$
    cat > /tmp/i3local.$$ <<'I3LOCAL'
# ~/.config/i3/local.conf -- yours.
#
# Copal created this file empty, once, and will not write to it again.
# ~/.config/i3/config is rewritten every time stage 4 runs and includes this
# file last, so anything here wins over anything there. Super+Shift+R
# reloads. A binding of your own looks like:
#
#   bindsym $mod+Shift+F8 exec foo
I3LOCAL
    install_home_once .config/i3/local.conf /tmp/i3local.$$
    rm -f /tmp/i3local.$$

    # The cheat sheet. i3 has no menus, no icons and no discoverable UI at
    # all, so without this the desktop is a grey rectangle that ignores you.
    # A clickable menu that builds itself from what is actually installed, so
    # it never lists something that is not there and never misses something
    # added by a later stage. Regenerated on every launch rather than cached.
    write_catalogue

    # copal-install: the menu's Install branch runs this. Split out so the same
    # thing works from a terminal, and so a failed install leaves its error on
    # screen instead of a window that vanishes.
    say "Installing /usr/local/bin/copal-install"
    cat > /usr/local/bin/copal-install <<'COPALINSTALL'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-install PKG...  -- install packages and keep the window open to say so.
set -u
[ "$#" -gt 0 ] || { echo "usage: copal-install PKG..."; exit 2; }
if [ "$(id -u)" != 0 ]; then
    echo "copal-install needs root. Re-run as: doas copal-install $*" >&2
    command -v doas >/dev/null 2>&1 && exec doas "$0" "$@"
    exit 1
fi
printf 'Installing: %s\n\n' "$*"
# A catalogue entry may name a package as 'foo@testing' -- one package out of
# Alpine's unstable branch, which is where VICE, MilkyTracker, Maxima and a
# few others live. apk only understands that suffix if the tagged repository
# is registered, so register it on demand rather than at install time for
# everyone. Tagged means it is consulted ONLY for @testing names, so the rest
# of the system stays on stable.
case " $* " in
    *@testing*)
        if ! grep -q '^@testing[[:space:]]' /etc/apk/repositories 2>/dev/null; then
            m=$(sed -n 's|^\(https\?://.*\)/v[0-9][0-9.]*/main[[:space:]]*$|\1|p' \
                    /etc/apk/repositories | head -n1)
            [ -n "$m" ] || m="https://dl-cdn.alpinelinux.org/alpine"
            printf 'Adding %s/edge/testing as @testing\n\n' "$m"
            printf '@testing %s/edge/testing\n' "$m" >> /etc/apk/repositories
            apk update >/dev/null 2>&1 || true
        fi ;;
esac
# The other suffix. 'app.id@flathub' is a Flathub application, not an apk, and
# handing one to apk produces "package not found" for something that exists --
# the most misleading answer available. Split the argument list in two and
# send each half where it can actually be resolved; a row is one or the other
# and an install of several may be both.
FLATPAKS=""
APKS=""
for a in "$@"; do
    case "$a" in
        *@flathub) FLATPAKS="$FLATPAKS ${a%@flathub}" ;;
        *)         APKS="$APKS $a" ;;
    esac
done
ok=1
if [ -n "$FLATPAKS" ]; then
    printf 'From Flathub:%s\n' "$FLATPAKS"
    printf 'A Flatpak brings its own runtime -- the first one costs ~500 MB\n'
    printf 'extra, beside the system rather than in it.\n\n'
    if ! command -v flatpak >/dev/null 2>&1 && ! apk add flatpak; then
        printf '\nCould not install flatpak.\n'; ok=0
    fi
    if [ "$ok" = 1 ]; then
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 \
            || printf 'warning: could not add the flathub remote\n'
        for f in $FLATPAKS; do
            flatpak install -y --noninteractive flathub "$f" || { ok=0; continue; }
            # A wrapper under the name the application answers to inside the
            # sandbox, so the catalogue's 'bin' column is true and the thing
            # is reachable without typing a reverse-DNS id. 'command=' comes
            # from the Flatpak's own metadata -- guessing from the id gives
            # 'browser' for com.brave.Browser.
            c=$(flatpak info --show-metadata "$f" 2>/dev/null \
                | sed -n 's/^command=//p' | head -n1)
            c=${c##*/}
            [ -n "$c" ] || continue
            if ! command -v "$c" >/dev/null 2>&1 \
               || [ "$(command -v "$c")" = "/usr/local/bin/$c" ]; then
                mkdir -p /usr/local/bin
                printf '#!/bin/sh\nexec flatpak run %s "$@"\n' "$f" > "/usr/local/bin/$c"
                chmod 0755 "/usr/local/bin/$c"
                printf 'run it with:  %s\n' "$c"
            fi
        done
    fi
fi
# shellcheck disable=SC2086 -- deliberate word splitting, these are names
if [ -n "$APKS" ] && ! apk add $APKS; then ok=0; fi
if [ "$ok" = 1 ]; then
    # Its manual and its optionals -- plugins, codecs, helpers -- as Copal
    # Apps would bring them (copal-store's man_pages_for and optionals
    # table). Where the store is not installed, the program alone.
    if [ -n "$APKS" ] && command -v copal-store >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        copal-store manpages $APKS
        # shellcheck disable=SC2086
        copal-store optionals $APKS
        copal-store access "${DOAS_USER:-}"
    fi
    printf '\n\nDone. The menu will show it next time you open it.\n'
    # The menu opens from a cached list; rebuild it now, as the person who
    # asked (doas hands their name over in DOAS_USER), so the new program is
    # there the next time the menu opens rather than the time after. Both
    # sessions' lists, because root cannot tell which desktop asked.
    if [ -n "${DOAS_USER:-}" ] && command -v copal-menu >/dev/null 2>&1; then
        su "$DOAS_USER" -s /bin/sh -c 'copal-menu --rebuild-all' >/dev/null 2>&1 &
    fi
    # Packages live on the ext4 root once stage 3 has run, but a diskless
    # system loses them at reboot unless the overlay is committed.
    if [ "$(awk '$2 == "/" { print $3 }' /proc/mounts)" = tmpfs ]; then
        printf 'This root is RAM-resident -- run "lbu commit -d" to keep it.\n'
    fi
else
    printf '\n\nFailed. The usual causes are no network, or the package not\n'
    printf 'existing for this architecture (%s).\n' \
           "$(apk --print-arch 2>/dev/null || echo unknown)"
    [ -n "$APKS" ]     && printf 'Look a name up with:  apk search -v NAME\n'
    [ -n "$FLATPAKS" ] && printf 'Or from Flathub with: flatpak search NAME\n'
fi
printf '\nPress Enter to close.\n'; read -r _
COPALINSTALL
    chmod 0755 /usr/local/bin/copal-install

    # ----------------------------------------------------------------------
    # copal-halt.
    #
    # "Log out of i3, then find a console, then type poweroff" is three steps
    # and two mental models for the one thing every session ends with. This is
    # the one command, and it is the same command from the menu, from a key
    # binding, and from a shell -- inside X or at the console.
    #
    # Two things have to be true for it to work as $PI_USER, and neither is
    # automatic:
    #
    #   - poweroff has to actually reach init. busybox's poweroff signals PID
    #     1 and only root may do that, so an unprivileged 'poweroff' fails
    #     silently-ish in a menu entry -- which is exactly what a Session menu
    #     that appears to do nothing looks like. admin_ensure_doas writes the
    #     nopass rule that fixes it; see /etc/doas.d/zz-copal-halt.conf.
    #
    #   - the process that calls it has to outlive the session it is ending.
    #     Launched from an i3 binding, this script is i3's child; telling i3 to
    #     exit and then calling poweroff from the same process is a race with
    #     its own death. setsid puts the tail of the job in its own session
    #     first, so the power-off happens whatever becomes of X.
    say "Installing /usr/local/bin/copal-halt"
    cat > /usr/local/bin/copal-halt <<'COPALHALT'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-halt -- end the session, and the machine, in one step.
set -eu

have() { command -v "$1" >/dev/null 2>&1; }

ACTION=poweroff
ASK=1

usage() {
    cat <<'USAGE'
copal-halt -- end the session, and the machine, in one step.

  copal-halt            turn the machine off (asks first)
  copal-halt reboot     restart it
  copal-halt logout     leave the desktop, keep the machine running
  copal-halt -y ...     do not ask

Run it from anywhere: a terminal in X, a console, or ssh. Inside i3 it
closes the session first so windows are asked to quit, then powers down.
Super + Shift + P is the same thing, and so is Session > Shut down in the
menu (Super + Z).
USAGE
}

for a in "$@"; do
    case "$a" in
        -y|--yes|-f)                    ASK=0 ;;
        ""|off|poweroff|shutdown|halt)  ACTION=poweroff ;;
        reboot|restart)                 ACTION=reboot ;;
        logout|logoff|exit)             ACTION=logout ;;
        -h|--help)                      usage; exit 0 ;;
        *) printf 'copal-halt: unknown argument "%s"\n\n' "$a" >&2
           usage >&2; exit 2 ;;
    esac
done

case "$ACTION" in
    poweroff) QUESTION="Shut down this machine?" ;;
    reboot)   QUESTION="Restart this machine?" ;;
    logout)   QUESTION="Log out of the desktop?" ;;
esac

# Asking. In X the question is a nagbar across the top of the screen, because
# a dialog that needs a window manager to place it is a poor thing to trust at
# the moment you are shutting the window manager down; the nagbar answers by
# re-running this script with -y. At a console it is a plain read.
#
# If there is neither -- output piped somewhere, no terminal, no X -- it
# REFUSES rather than assuming yes. "It could not ask, so it went ahead and
# powered the machine off" is the wrong way round for the one command here
# that cannot be undone.
# ON WAYLAND THE QUESTION IS A WOFI LIST, No above Yes, and it is asked
# BEFORE the i3 branch is considered: Hyprland sets DISPLAY for Xwayland, so
# the i3 test alone would pick i3-nagbar, which comes up through Xwayland
# unable to find an output and hangs -- which is what "Shut down does
# nothing" was on the Antiquity desktop.
if [ "$ASK" = 1 ]; then
    if [ -n "${WAYLAND_DISPLAY:-}" ] && have wofi; then
        reply=$(printf 'No\nYes\n' | wofi --dmenu --prompt "$QUESTION" \
                    --height 130 --width 380 2>/dev/null || true)
        [ "$reply" = Yes ] || { echo "Cancelled."; exit 0; }
    elif [ -n "${DISPLAY:-}" ] && have i3-nagbar; then
        exec i3-nagbar -t warning -m "$QUESTION" \
             -B 'Yes' "copal-halt -y $ACTION" -B 'No' 'true'
    elif [ -t 0 ]; then
        printf '%s [y/N] ' "$QUESTION"
        read -r reply || reply=n
        case "$reply" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0 ;; esac
    else
        echo "copal-halt: nothing to ask on -- re-run as: copal-halt -y $ACTION" >&2
        exit 1
    fi
fi

# root needs no help; anyone else goes through doas, which has a nopass rule
# for exactly these three commands and nothing else.
priv() {
    if [ "$(id -u)" = 0 ]; then "$@"
    elif have doas;  then doas "$@"
    elif have sudo;  then sudo "$@"
    else printf 'copal-halt: not root, and no doas -- log in as root and run %s\n' "$1" >&2
         exit 1
    fi
}

# Ending an i3 session before the machine goes down is not required -- OpenRC
# will stop X either way -- but it is the difference between applications being
# asked to quit and applications being killed.
# Asked of the session, like everything else here: Hyprland's exit is
# 'hyprctl dispatch exit', and it is checked first for the Xwayland reason
# above.
end_session() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && have hyprctl; then
        hyprctl dispatch exit >/dev/null 2>&1 || true
    elif [ -n "${DISPLAY:-}" ] && have i3-msg; then
        i3-msg exit >/dev/null 2>&1 || true
    else
        return 0
    fi
    sleep 1
}

if [ "$ACTION" = logout ]; then
    if [ -n "${WAYLAND_DISPLAY:-}" ] && have hyprctl; then
        exec hyprctl dispatch exit
    fi
    [ -n "${DISPLAY:-}" ] || { echo "copal-halt: not in a desktop session." >&2; exit 1; }
    have i3-msg || { echo "copal-halt: no i3-msg." >&2; exit 1; }
    exec i3-msg exit
fi

# sync twice, deliberately: this is a machine whose disk is an SD card and
# whose power switch is usually the cable.
# The ABSOLUTE path, deliberately. doas matches its 'cmd' rule against the
# command as typed, not against what it resolves to, so `doas poweroff` does
# not match `permit nopass :wheel cmd /sbin/poweroff` -- it falls through to
# the general wheel rule and asks for a password, from a menu entry with no
# terminal to type one into. On Alpine these are all busybox symlinks in
# /sbin; command -v is the fallback for anywhere they are not.
CMD="/sbin/$ACTION"
[ -x "$CMD" ] || CMD=$(command -v "$ACTION" 2>/dev/null || echo "$ACTION")

do_halt() {
    end_session
    sync; sync
    priv "$CMD"
}

# Detach before ending the session. Launched from an i3 binding this script is
# i3's child, and "tell i3 to exit, then power off" from a single process is a
# race with its own death: if X takes its children down, the power-off never
# happens and you are left at a console wondering why. setsid re-runs this in a
# session of its own; COPAL_HALT_INNER is what stops the copy doing it again.
if [ -z "${COPAL_HALT_INNER:-}" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && have setsid; then
    COPAL_HALT_INNER=1 setsid "$0" -y "$ACTION" >/dev/null 2>&1 &
    exit 0
fi

do_halt
COPALHALT
    chmod 0755 /usr/local/bin/copal-halt

    # ----------------------------------------------------------------------
    # "SAFE TO UNPLUG." A Pi has no power button and no light that means
    # "off": the red one is mains, the green one is disk activity, and the
    # kernel's last words on the console -- "reboot: Power down" -- are true
    # but addressed to nobody. So on a Pi one more OpenRC service sits in the
    # shutdown runlevel, after mount-ro, and says it in words on the console,
    # where the HDMI screen shows it once the desktop has gone. Not installed
    # on a PC or a VM: those cut their own power and the screen is dark before
    # anyone could read it.
    #
    # Alpine's inittab runs 'openrc shutdown' for a reboot as well as a halt
    # and does not say which, so the notice covers both rather than claiming
    # to know.
    if grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
        say "Installing /etc/init.d/copal-unplug (the safe-to-unplug notice)"
        cat > /etc/init.d/copal-unplug <<'UNPLUG'
#!/sbin/openrc-run
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-unplug -- the last words on the console when a Raspberry Pi halts.
#
# OpenRC "starts" the shutdown runlevel's services on the way down; this one
# runs after mount-ro, so it speaks once the filesystems are read-only and
# there is nothing left to lose. The kernel then prints "reboot: Power down",
# the green light goes dark, and the notice stays on the screen.
description="Says on the console when it is safe to unplug the Pi"

depend() {
    after killprocs savecache mount-ro
}

start() {
    if [ "${RC_REBOOT:-no}" = yes ]; then
        printf '\n   Restarting -- leave the power alone.\n\n' > /dev/console
    else
        printf '\n   The Raspberry Pi has halted.\n' > /dev/console
        printf '   If you asked for a restart it will come back by itself.\n' > /dev/console
        printf '   Otherwise it is SAFE TO UNPLUG once the green light stays off.\n\n' > /dev/console
    fi
    return 0
}
UNPLUG
        chmod 0755 /etc/init.d/copal-unplug
        if rc-update add copal-unplug shutdown >/dev/null 2>&1; then
            note "copal-unplug -- 'safe to unplug' on the console when the Pi halts"
        else
            warn "could not add copal-unplug to the shutdown runlevel -- rc-update add copal-unplug shutdown, by hand"
        fi
    fi

    # ----------------------------------------------------------------------
    # copal-logs.
    #
    # Logs on this machine come from three places that have nothing to do with
    # each other, live in three directories, and are cleaned up by three
    # different mechanisms -- or by none. That is how a 512 MB board with an SD
    # card ends up with a full /var and no obvious culprit.
    #
    #   ~/.local/state/copal/   desktop sessions, written by copal-startx.
    #                           Rotated by copal-startx itself, five deep.
    #   /boot/copal.log         the install transcript. Small, precious, and
    #                           the one thing here worth keeping: it is the
    #                           record of what every stage actually did.
    #   /var/log/               the system's own, on tmpfs unless stage 15 has
    #                           been run, in which case copal-logflush copies
    #                           it down to the card hourly.
    #
    # This is one command that can see all three, so "what is using space" and
    # "throw away what I do not need" stop being a research project.
    #
    # NOTHING IS DELETED WITHOUT BEING NAMED FIRST. clean prints what it is
    # about to remove and how much that frees, and the install transcript is
    # never touched by it -- an installer's own record of itself is not
    # garbage, and on a machine being rebuilt it is the only history there is.

    say "Installing /usr/local/bin/copal-menu"
    cat > /usr/local/bin/copal-menu <<'COPALMENU'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-menu -- the desktop's menu: applications on the left, everything else
# on the right, and Left/Right to cross between them.
#
# The keyboard launcher a desktop like this usually ships (dmenu, wofi's drun)
# covers what is on PATH and nothing else. This exists for the things whose
# names you would have to know first -- the emulator profiles, the snapshot
# tool, the disk-image helpers -- and for the one thing a flat launcher can
# never do: show you what you could install but have not. Software you do not
# have is not discoverable by definition, so the menu carries an Install
# branch listing the rest of the catalogue.
#
# TWO PANES, ONE MENU. Super+Space, Super+D and the bar's menu button open on
# the LEFT pane: every application on the machine, flat, sorted, type to
# search -- what drun would show, plus the terminal programs drun cannot see.
# Super+Z opens on the RIGHT pane: the same programs by category, the
# settings, Style and Install, and the session -- lock, log out, reboot,
# shut down -- under their own heading. Left and Right move between the two
# panes; inside a category, Left is Back and Right goes to the applications.
# Structure is borrowed from Omarchy, then tightened: nothing here is more
# than two levels deep, because on a 720p framebuffer a third level is a
# scroll bar.
#
# CACHED, AND WHY. Building the list means reading the catalogue (300 rows),
# asking PATH about every one of them, and parsing every .desktop file on the
# machine. Done from scratch on every keypress, that was four seconds on the
# UTM guest -- long enough to press the key again, at which point two copies
# raced to truncate one file and the second pane came up empty. So the list
# is built once, into ~/.cache/copal/, and every open reads the file: the
# menu appears in the time wofi takes to draw, a sixth of a second here.
#
# The file is rebuilt in the background when something it was built from is
# newer than it -- a directory on PATH, the .desktop directories, the
# catalogue, this script -- so what you see is at worst one open behind what
# is installed, and never a blank. 'copal-menu --rebuild' forces it, and
# copal-install runs that for you after every install.
set -eu
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/copal"
CATFILE=/usr/local/share/copal/catalogue
GUIDES=/usr/local/share/copal/guides
CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# The programs copal-build made from ~/code, in the same label|command|mode
# shape as a catalogue row. The file is copal-build's; it is read here and
# edited nowhere.
PROJFILE="${XDG_DATA_HOME:-$HOME/.local/share}/copal/projects"

usage() {
    echo "usage: copal-menu [--at-pointer|--system|--rebuild|--rebuild-all]" >&2
    exit 2
}

# --at-pointer: open where the mouse is, which is what the right-click-on-the-
# desktop binding wants. Only jgmenu can honour it; the list pickers are a
# fixed panel with nowhere to put it, so there the flag is simply dropped.
#
# --system: open on the right-hand pane rather than the applications. Super+Z
# used to open a menu that WAS the structure, so it still arrives there.
#
# --rebuild: build the cached list for this session and exit. --rebuild-all
# builds both the Wayland and the X11 list, for a caller -- copal-install --
# that runs as root and cannot tell which desktop asked.
AT_POINTER=""
START_PANE="apps"
MODE="open"
case "${1:-}" in
    --at-pointer)  AT_POINTER="--at-pointer" ;;
    --system)      START_PANE="" ;;
    --rebuild)     MODE="rebuild" ;;
    --rebuild-all) MODE="rebuild-all" ;;
    "") ;;
    *) usage ;;
esac
[ "$#" -le 1 ] || usage

have() { command -v "$1" >/dev/null 2>&1; }
# Which session this is. WAYLAND_DISPLAY is set by the compositor for its own
# clients and by nothing else, so it answers the question without asking what
# is installed. The list differs by session -- the terminal, the lock and
# log-out entries -- so each session has its own cache file.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then SESSION=wayland; else SESSION=x11; fi
wayland() { [ "$SESSION" = wayland ]; }
csv_for() { echo "$CACHE_DIR/menu-$1.csv"; }
CSV=$(csv_for "$SESSION")

# Section names are one word so they can be pasted into jgmenu tag names;
# this is where they get a readable form for the part people see.
pretty() { case "$1" in Smallweb) echo "Small Web" ;; *) echo "$1" ;; esac; }

# ===========================================================================
# BUILDING THE LIST. Everything from here to the ruler writes one CSV in
# jgmenu's dialect: 'label,command' rows, ^tag(x) opening a section,
# ^checkout(x) entering one, ^back() leaving it, ^sep(title) a heading.
# jgmenu reads it as-is on X11; walk() below turns the same markers into a
# keyboard-driven picker everywhere else.
#
# Forks are the cost on a board this size, so the builder avoids them: the
# catalogue is walked once, in shell built-ins, into a table that carries the
# installed/missing answer, and every later question is one awk over that
# table rather than a loop that forks twice per row. Half a second where the
# first version took four.
# ===========================================================================
out() { printf '%s\n' "$*" >> "$OUT"; }

build_csv() {  # <wayland|x11>
    _sess="$1"
    _csv=$(csv_for "$_sess")
    mkdir -p "$CACHE_DIR"
    OUT="$_csv.$$.tmp"
    TABLE="$CACHE_DIR/.table.$$"
    trap 'rm -f "$OUT" "$TABLE"' EXIT
    : > "$OUT"

    # The terminal, and on Wayland it cannot be an X one. xterm and urxvt
    # would come up through Xwayland if it happens to be installed and not at
    # all if it is not, so the Wayland session asks for the terminals that
    # session has. foot first, for the reason stage 17 installs it first: it
    # is the one that comes up on a compositor drawing in software. kitty and
    # alacritty both want GL.
    if [ "$_sess" = wayland ]; then
        TERM_EMU="${TERMINAL:-$(have foot && echo foot \
                                || (have kitty && echo kitty) \
                                || (have alacritty && echo alacritty) \
                                || echo xterm)}"
    else
        TERM_EMU="${TERMINAL:-$(have urxvt && echo urxvt || echo xterm)}"
    fi

    # One entry: run it directly, wrap a terminal around it, or -- for the
    # tools that would exit before you could read anything -- show the help
    # and hand over a shell in the same window.
    cmd_for() {  # <binary> <mode>
        case "$2" in
            t) printf '%s -e %s' "$TERM_EMU" "$1" ;;
            h) printf "%s -e sh -c '%s --help 2>&1 | head -40; echo; echo \"-- shell in this directory; Ctrl-D to close --\"; exec sh'" \
                      "$TERM_EMU" "$1" ;;
            *) printf '%s' "$1" ;;
        esac
    }

    # The catalogue, annotated: section|label|packages|binary|mode|installed.
    # 'command -v' is a built-in, so the whole pass is fork-free; the one tr
    # at the end strips commas from every label at once, because jgmenu's
    # CSV splits on commas and a comma in a label silently eats the command.
    : > "$TABLE"
    if [ -f "$CATFILE" ]; then
        while IFS='|' read -r _sec _label _pkgs _bin _mode; do
            case "${_sec:-}" in ''|'#'*) continue ;; esac
            if have "$_bin"; then _i=1; else _i=0; fi
            printf '%s|%s|%s|%s|%s|%s\n' "$_sec" "$_label" "$_pkgs" "$_bin" "$_mode" "$_i"
        done < "$CATFILE" | tr ',' ';' > "$TABLE"
    fi
    # The rows of one section that are (1) or are not (0) installed.
    rows() {  # <section> <1|0>
        awk -F'|' -v s="$1" -v w="$2" '$1 == s && $6 == w { print $2 "|" $3 "|" $4 "|" $5 }' "$TABLE"
    }
    # The sections, in catalogue order, that have at least one such row.
    HAVE_SECS=$(awk -F'|' '$6 == 1 && !s[$1]++ { print $1 }' "$TABLE")
    MISS_SECS=$(awk -F'|' '$6 == 0 && !s[$1]++ { print $1 }' "$TABLE")

    # copal-build's projects, filtered the same way: only what is on PATH.
    PROJECTS=""
    if [ -f "$PROJFILE" ]; then
        PROJECTS=$(while IFS='|' read -r _name _label _cmd _mode; do
            case "${_name:-}" in ''|'#'*) continue ;; esac
            have "${_cmd%% *}" || continue
            printf '%s|%s|%s\n' "$_label" "$_cmd" "$_mode"
        done < "$PROJFILE" | tr ',' ';')
    fi

    # Is an emulator actually built? Only then is there a top-level entry.
    HAVE_EMU=0
    if [ -n "$(ls "$HOME"/minivmac/run-*.sh /root/minivmac/run-*.sh 2>/dev/null || true)" ] \
       || have BasiliskII || have x64sc || have x64; then
        HAVE_EMU=1
    fi
    HAVE_GUIDES=0
    [ -n "$(ls "$GUIDES"/*.txt 2>/dev/null || true)" ] && HAVE_GUIDES=1

    # ----- the right pane: the structure -----
    #
    # THE KEY LIST FIRST. This is a desktop with no menus and no icons; the
    # list of what the keys do is the single most useful thing in here and
    # it used to be three levels down inside System. Omarchy puts its
    # keybindings under Learn, near the top, for the same reason.
    #
    # WHICH LIST, asked of the session. Stage 4 writes the i3 one and stage
    # 16 writes the Antiquity one, and offering the wrong one is worse than
    # offering none.
    if [ "$_sess" = wayland ] && [ -f "$GUIDES/antiquity-keys.txt" ]; then
        out "Key bindings,$TERM_EMU -e copal-guide antiquity-keys"
    elif [ -f "$HOME/.config/i3/keys.txt" ]; then
        out "Key bindings,$TERM_EMU -e less $HOME/.config/i3/keys.txt"
    elif [ -f "$GUIDES/i3-keys.txt" ]; then
        out "Key bindings,$TERM_EMU -e copal-guide i3-keys"
    fi
    # The other pane, for somebody who reached the menu with the mouse and
    # has no arrow keys to cross with.
    out "All applications  <,^checkout(apps)"
    out "Terminal,$TERM_EMU"
    # THE CAMERA, at the top rather than as a row in a section, because a
    # machine built around an HQ Camera has one application that is the point
    # of it. With no camera program there is no entry, rather than a dead one.
    have copal-camera && copal-camera --which >/dev/null 2>&1 && out "Camera,copal-camera" || true
    # THE STORE, when stage 18 has written it: the catalogue AND the programs
    # nothing installs until they are picked. It supersedes the Center, which
    # stays listed only on a machine without it.
    if have copal-store; then out "Copal Store,copal-store"
    elif have copal-center; then out "Copal Center,copal-center"; fi
    have copal-config && out "System Settings,copal-config" || true

    # THE SESSION, under its own heading and at the top level rather than in
    # a submenu: shutting down and logging out are the two things people
    # hunt for in a menu, and they were two levels in. Asked of the session,
    # not written once for i3: "Reload i3" cannot work on Hyprland and
    # i3lock is an X program with no Wayland session to lock.
    out '^sep(Session)'
    if [ "$_sess" = wayland ]; then
        out "Reload Hyprland,hyprctl reload"
        have hyprlock && out "Lock screen,hyprlock" || true
        out "Log out,hyprctl dispatch exit"
    else
        out "Reload i3,i3-msg restart"
        have i3lock && out "Lock screen,i3lock -c 1a1b26" || true
        out "Log out,i3-msg exit"
    fi
    # copal-halt rather than a bare poweroff: as $PI_USER the bare one cannot
    # signal init at all, and from a menu there is no terminal for doas to ask
    # in. It asks before it acts.
    out "Reboot,copal-halt reboot"
    out "Shut down,copal-halt"

    # The applications by category: one submenu per catalogue section that
    # has something installed, then the sections the catalogue does not know.
    out '^sep(Categories)'
    for s in $HAVE_SECS; do
        out "$(pretty "$s")  >,^checkout(have_$s)"
    done
    out "Development  >,^checkout(devel)"
    [ -n "$PROJECTS" ] && out "Projects  >,^checkout(projects)" || true
    [ "$HAVE_EMU" = 1 ] && out "Emulators  >,^checkout(emu)" || true

    # STYLE is Omarchy's own top-level entry and the one Copal did not have.
    # Everything under it changes how the machine LOOKS rather than what is on
    # it, which is why it is a sibling of Install rather than an entry inside.
    out '^sep(Setup)'
    out "Style  >,^checkout(style)"
    out "Install software  >,^checkout(install)"
    [ "$HAVE_GUIDES" = 1 ] && out "Guides  >,^checkout(guides)" || true
    out "System  >,^checkout(system)"

    # ----- the left pane: everything runnable, flat and searchable -----
    #
    # Every .desktop file the system advertises, which is what drun would
    # have shown, PLUS every installed row of the catalogue, which is what
    # drun cannot show -- the terminal programs, which have no .desktop file
    # and are most of what is on a machine this size. Deduplicated by label,
    # sorted case-insensitively, so it reads as one list rather than two.
    out '^tag(apps)'
    out "System menu  >,^back()"
    out '^sep(Applications)'
    {
        # The catalogue half, through the same cmd_for() the submenus use --
        # so a terminal program still gets a terminal wrapped around it here.
        awk -F'|' '$6 == 1 { print $2 "|" $4 "|" $5 }' "$TABLE" \
        | while IFS='|' read -r label bin mode; do
            printf '%s,%s\n' "$label" "$(cmd_for "$bin" "$mode")"
        done
        # The built checkouts, which have neither a .desktop file nor a row.
        [ -n "$PROJECTS" ] && printf '%s\n' "$PROJECTS" | while IFS='|' read -r label cmd mode; do
            printf '%s,%s\n' "$label" "$(cmd_for "$cmd" "$mode")"
        done
        # The .desktop half, in one awk over every file rather than one awk
        # per file. Only the [Desktop Entry] group is read (an Action group
        # has its own Name and Exec and would otherwise overwrite the real
        # ones), NoDisplay and Hidden entries are dropped the way every
        # launcher drops them, and the field codes -- %U, %f and the rest --
        # are stripped, because they are meant to be replaced with a filename
        # and a shell would take them literally. Flatpak's export directory
        # is in the list because that is where Brave's entry lives.
        for _d in /usr/share/applications /usr/local/share/applications \
                  /var/lib/flatpak/exports/share/applications \
                  "$HOME/.local/share/flatpak/exports/share/applications" \
                  "$HOME/.local/share/applications"; do
            [ -d "$_d" ] || continue
            find "$_d" -maxdepth 1 -name '*.desktop' 2>/dev/null
        done | tr '\n' '\0' | xargs -0 -r awk -v term="$TERM_EMU" '
            function emit(   c) {
                if (skip || name == "" || cmd == "" || (type != "" && type != "Application"))
                    return
                gsub(/%[a-zA-Z]/, "", cmd)
                sub(/[ \t]+$/, "", cmd)
                gsub(/,/, ";", name)
                c = isterm ? (term " -e " cmd) : cmd
                print name "," c
            }
            FNR == 1 { emit(); name = ""; cmd = ""; type = ""; skip = 0; isterm = 0; grp = 0 }
            /^\[/   { grp = ($0 ~ /^\[Desktop Entry\]/); next }
            !grp    { next }
            /^Name=/      && name == "" { name = substr($0, 6) }
            /^Exec=/      && cmd  == "" { cmd  = substr($0, 6) }
            /^Type=/      && type == "" { type = substr($0, 6) }
            /^Terminal=[Tt]rue/         { isterm = 1 }
            /^NoDisplay=[Tt]rue/        { skip = 1 }
            /^Hidden=[Tt]rue/           { skip = 1 }
            END { emit() }
        ' 2>/dev/null
    } | awk -F, 'NF && !seen[tolower($1)]++' | sort -f -t, -k1,1 >> "$OUT"

    # ----- one submenu per catalogue section, installed entries only -----
    for s in $HAVE_SECS; do
        out "^tag(have_$s)"
        out "<  Back,^back()"
        out "^sep($(pretty "$s"))"
        rows "$s" 1 | while IFS='|' read -r label pkgs bin mode; do
            out "$label,$(cmd_for "$bin" "$mode")"
        done
    done

    # ----- Install: the same table, inverted -----
    out '^tag(install)'
    out "<  Back,^back()"
    out '^sep(Not installed yet)'
    for s in $MISS_SECS; do
        out "$(pretty "$s")  >,^checkout(get_$s)"
    done
    for s in $MISS_SECS; do
        out "^tag(get_$s)"
        out "<  Back,^checkout(install)"
        out "^sep(Install: $(pretty "$s"))"
        rows "$s" 0 | while IFS='|' read -r label pkgs bin mode; do
            out "$label,$TERM_EMU -e copal-install $pkgs"
        done
    done

    # ----- Guides: one entry per .txt, titled by its own first line -----
    # Built from the directory rather than a list, so dropping a new guide in
    # /usr/local/share/copal/guides is the whole of "adding it to the menu".
    if [ "$HAVE_GUIDES" = 1 ]; then
        out '^tag(guides)'
        out "<  Back,^back()"
        out '^sep(Guides)'
        for g in "$GUIDES"/*.txt; do
            [ -f "$g" ] || continue
            gn=$(basename "$g" .txt)
            # The first line with letters in it -- guides that open with a
            # '=====' ruler would otherwise be titled with the ruler.
            gt=$(awk 'NF && /[A-Za-z]/ {sub(/^ +/, ""); gsub(/,/, ";"); print; exit}' "$g")
            [ -n "$gt" ] || gt="$gn"
            out "$gt,$TERM_EMU -e copal-guide $gn"
        done
    fi

    # ----- Development: not in the catalogue, it arrives with stage 7 -----
    out '^tag(devel)'
    out "<  Back,^back()"
    out '^sep(Development)'
    have nvim    && out "Neovim,$TERM_EMU -e nvim" || true
    have vim     && out "Vim,$TERM_EMU -e vim" || true
    have geany   && out "Geany,geany" || true
    have python3 && out "Python,$TERM_EMU -e python3" || true
    have claude  && out "Claude Code,$TERM_EMU -e claude" || true
    have lazygit && out "Lazygit,$TERM_EMU -e lazygit" || true
    have bvi     && out "Hex editor (bvi),$TERM_EMU -e bvi" || true
    have radare2 && out "radare2,$TERM_EMU -e r2" || true

    # ----- Projects: what copal-build made from ~/code -----
    if [ -n "$PROJECTS" ]; then
        out '^tag(projects)'
        out "<  Back,^back()"
        out '^sep(Projects -- built from ~/code)'
        printf '%s\n' "$PROJECTS" | while IFS='|' read -r label cmd mode; do
            out "$label,$(cmd_for "$cmd" "$mode")"
        done
        out '^sep()'
        out "Pull and rebuild them all,$TERM_EMU -e sh -c 'copal-code; echo; echo Press Enter to close; read x'"
        out "What each one made,$TERM_EMU -e sh -c 'copal-build list; echo; echo Press Enter to close; read x'"
    fi

    # ----- Emulators: profiles are files on disk, not packages -----
    # VICE ships both x64sc (accurate) and x64 (fast); on this board the fast
    # one is the only one worth offering, but take whichever exists.
    if [ "$HAVE_EMU" = 1 ]; then
        out '^tag(emu)'
        out "<  Back,^back()"
        out '^sep(Emulators)'
        for p in "$HOME"/minivmac/run-*.sh /root/minivmac/run-*.sh; do
            [ -x "$p" ] || continue
            n=$(basename "$p" .sh | sed 's/^run-//')
            out "Mini vMac: $n,$p"
        done
        have BasiliskII && out "Basilisk II,BasiliskII" || true
        if have x64sc;   then out "VICE (C64),x64sc"
        elif have x64;   then out "VICE (C64),x64"
        fi
    fi

    # ----- Style -----
    out '^tag(style)'
    out "<  Back,^back()"
    out '^sep(Style)'
    have copal-desk && out "Lay the desk out (workspaces 1-5),copal-desk" || true
    have copal-desk && out "Which desk layouts exist,$TERM_EMU -e sh -c 'copal-desk --list; echo; echo Press Enter to close; read x'" || true
    have copal-wallpaper && out "Wallpaper...,copal-wallpaper --pick" || true
    have copal-wallpaper && out "Get more wallpapers,$TERM_EMU -e sh -c 'copal-wallpaper --fetch; echo; echo Press Enter to close; read x'" || true
    have copal-theme && out "Theme...,copal-theme --pick" || true
    # The desktop widgets, shown as whichever of the two things it would do
    # next: an entry called "toggle" makes somebody guess which way it points.
    if have copal-widgets && [ -f "$CONFDIR/waybar/desktop.json" ]; then
        if [ -e "$CONFDIR/copal/no-desktop-widgets" ]; then
            out "Show the desktop widgets,copal-widgets --on"
        else
            out "Hide the desktop widgets,copal-widgets --off"
        fi
    fi
    [ -f "$GUIDES/widgets.txt" ] \
        && out "Configure the bar and widgets,$TERM_EMU -e copal-guide widgets" || true

    # ----- System -----
    out '^tag(system)'
    out "<  Back,^back()"
    out '^sep(System)'
    have htop && out "Task manager,$TERM_EMU -e htop" || true
    have btop && out "System monitor,$TERM_EMU -e btop" || true
    have snapshot && out "Snapshots,$TERM_EMU -e sh -c 'snapshot list; read x'" || true
    have mountdsk && out "Mount disk image,$TERM_EMU -e sh -c 'mountdsk --help; read x'" || true
    have tcpdump  && out "Network capture,$TERM_EMU -e sh -c 'tcpdump -i eth0 -nn'" || true
    have bluetoothctl && out "Bluetooth,$TERM_EMU -e bluetoothctl" || true
    have iw && out "Wifi scan,$TERM_EMU -e sh -c 'iw dev wlan0 scan | grep SSID; read x'" || true
    have alsamixer && out "Volume,$TERM_EMU -e alsamixer" || true
    out "Logs,$TERM_EMU -e sh -c 'copal-logs; echo; echo Press Enter to close; read x'"
    out "Setup and stages,$TERM_EMU -e sh -c 'copal; echo; echo Press Enter to close; read x'"
    out "Update Copal,$TERM_EMU -e sh -c 'copal -U; echo; echo Press Enter to close; read x'"
    have copal-gpu && out "Display and acceleration,$TERM_EMU -e sh -c 'copal-gpu; echo; echo Press Enter to close; read x'" || true
    have copal-fonts && out "Fonts,$TERM_EMU -e sh -c 'copal-fonts; echo; echo Press Enter to close; read x'" || true
    # The cache, for the one case the freshness check cannot see.
    out "Rebuild this menu now,copal-menu --rebuild"

    # Into place in one step, so a menu opening mid-rebuild reads the old
    # list whole rather than the new one half-written.
    mv -f "$OUT" "$_csv"
    rm -f "$TABLE"
    trap - EXIT
}

# The list is stale when anything it was built from is newer than it. Every
# test here is a stat, so the whole check costs less than one fork. A
# directory's mtime moves when a file is added to or removed from it, which
# is exactly what installing a program does to /usr/bin.
stale() {
    [ -s "$CSV" ] || return 0
    for _p in "$0" "$CATFILE" "$PROJFILE" "$GUIDES" \
              /usr/share/applications /usr/local/share/applications \
              /var/lib/flatpak/exports/share/applications \
              "$HOME/.local/share/flatpak/exports/share/applications" \
              "$HOME/.local/share/applications" \
              /usr/bin /usr/local/bin /usr/sbin "$HOME/.local/bin" "$HOME/bin" \
              "$CONFDIR/copal" "$CONFDIR/waybar" "$HOME/minivmac"; do
        [ -e "$_p" ] && [ "$_p" -nt "$CSV" ] && return 0
    done
    # Once a day regardless: cheap insurance for whatever the list misses.
    [ -n "$(find "$CSV" -mmin +1440 2>/dev/null)" ]
}

# One rebuild at a time. mkdir is the atomic test-and-set; a lock older than
# five minutes belongs to a rebuild that died, and is taken over.
rebuild() {  # <session>...
    mkdir -p "$CACHE_DIR"
    _lock="$CACHE_DIR/menu.lock"
    [ -n "$(find "$_lock" -maxdepth 0 -mmin +5 2>/dev/null)" ] && rmdir "$_lock" 2>/dev/null || true
    mkdir "$_lock" 2>/dev/null || return 0
    for _s in "$@"; do build_csv "$_s"; done
    rmdir "$_lock"
}
# Detached, quiet, and polite about the CPU: it runs while the menu is on
# screen, on a machine that may be drawing that menu in software.
rebuild_in_background() {
    ( nice -n 10 "$0" --rebuild >/dev/null 2>&1 </dev/null & )
}

case "$MODE" in
    rebuild)     rebuild "$SESSION"; exit 0 ;;
    rebuild-all) rebuild wayland x11; exit 0 ;;
esac

if [ -s "$CSV" ]; then
    # The common case: show what is cached now, and if anything has changed
    # since, have the next open be current. walk() re-reads the file on every
    # pane change, so a rebuild that finishes while the menu is open is
    # already visible on the next Left or Right.
    ! stale || rebuild_in_background
else
    # The first open, or a cleared cache: nothing to show yet, so build it
    # here and take the one slow open.
    rebuild "$SESSION"
    [ -s "$CSV" ] || { echo "copal-menu: could not build $CSV" >&2; exit 1; }
fi

# ===========================================================================
# PRESENTING IT. jgmenu is a pointer menu and an X11 program; on Wayland
# there is no jgmenu and there never will be, so the same CSV has to be
# walkable from a keyboard-driven list as well.
#
# THE LIST WALKER IS THE OMARCHY SHAPE: a flat picker shown ONE LEVEL AT A
# TIME, where choosing a category redraws the same picker with that
# category's entries and a Back at the top. Arrow keys and Enter, type to
# filter. ^tag(x) opens a section, ^checkout(x) enters one, ^back() leaves
# it, and the loop below turns those three markers into the walk. The CSV is
# unchanged and jgmenu still reads it the way it always did.
#
# HEADINGS ARE ROWS. wofi and dmenu have no separators, so a ^sep(title)
# becomes a '-- title --' row of its own; choosing one does nothing but
# redraw. That is what makes the right pane read as categorised rather than
# as forty entries in a heap, and typing still filters straight past them.
#
# LEFT AND RIGHT MOVE BETWEEN THE PANES. wofi draws one list, so the two
# panes are one list shown twice and the arrow keys swap which. Inside a
# category, Left is Back and Right is the applications.
#
# HOW THE ARROWS REACH US, because wofi cannot deliver them. wofi 1.5's
# user-bound keys (key_custom_n) do not end the picker: they only arm an exit
# status for whenever Enter or Escape is eventually pressed, and the arrows
# themselves go to the search box as cursor movement. So while the picker is
# up this script enters a Hyprland submap (stage 17 writes it into
# hyprland.conf) in which Left and Right are Hyprland's: each ends the picker
# with a signal -- USR1 for Left, USR2 for Right -- and the shell reports
# that as status 138 or 140, which is the pane switch. Every other key passes
# through the submap to wofi, so typing still filters. The submap is left on
# every way out of this script, and its own Escape binding closes the picker
# and leaves it, so a menu that died cannot keep the arrows. Where there is
# no submap (an older hyprland.conf, or X11) the arrows do nothing and the
# first row of each pane -- 'System menu  >', 'All applications  <' -- is the
# way across.
#
# The cost is real and worth stating: Left and Right no longer move the
# cursor inside the search box. Typing, backspace and Ctrl-W still edit the
# query; the arrows navigate the menu.
# ===========================================================================
RULE="$(printf '\342\224\200\342\224\200')"   # two box-drawing dashes

# The rows of one section, headings turned into rows.
items_for() {  # <tag>
    awk -v want="$1" -v rule="$RULE" '
        /^\^tag\(/  { cur = $0; sub(/^\^tag\(/, "", cur); sub(/\)$/, "", cur); next }
        cur != want { next }
        /^\^sep\(\)$/ { next }
        /^\^sep\(/  { t = $0; sub(/^\^sep\(/, "", t); sub(/\)$/, "", t)
                      print rule " " t " " rule ",^sep"; next }
        NF
    ' "$CSV"
}

# What the search box says before you type: which pane this is, and where
# the arrows go. The pair reads as two tabs with the current one in brackets.
prompt_for() {  # <tag> <items>
    case "$1" in
        apps) echo "[ Applications ]   System  >" ;;
        "")   echo "<  Applications   [ System ]" ;;
        *)    _t=$(printf '%s\n' "$2" | sed -n "s/^$RULE \(.*\) $RULE,^sep\$/\1/p" | head -n1)
              echo "<  Back   [ ${_t:-$1} ]" ;;
    esac
}

# The submap, entered while the picker is up and left on every way out. Both
# are no-ops where there is no Hyprland to ask.
keys_on()  { wayland && have hyprctl && hyprctl dispatch submap menu  >/dev/null 2>&1 || true; }
keys_off() { wayland && have hyprctl && hyprctl dispatch submap reset >/dev/null 2>&1 || true; }

walk() {
    _tag="$START_PANE"            # the applications pane unless --system
    trap keys_off EXIT INT TERM HUP
    while :; do
        _items=$(items_for "$_tag")
        [ -n "$_items" ] || return 0

        # Labels only for the picker; the command half is looked up after.
        # The exit status matters as much as the selection here: 138 and 140
        # are the picker ended by the submap's Left and Right (128 + USR1,
        # 128 + USR2), and 10..29 is a wofi that exits on a custom key itself
        # -- either is the pane switch. Anything else with no selection is
        # Escape, and Escape closes.
        _rc=0
        keys_on
        _sel=$(printf '%s\n' "$_items" | cut -d, -f1 | menu_cmd "$(prompt_for "$_tag" "$_items")") || _rc=$?
        _dir=""
        case "$_rc" in
            138|10) _dir=left ;;
            140|11) _dir=right ;;
        esac
        if [ -n "$_dir" ]; then
            case "$_tag" in
                apps) _tag="" ;;
                "")   _tag="apps" ;;
                *)    if [ "$_dir" = left ]; then
                          # Left: what this section's Back row would do.
                          _back=$(printf '%s\n' "$_items" | awk -F, '$2 ~ /^\^(back|checkout)\(/ { print $2; exit }')
                          case "$_back" in
                              '^checkout('*) _tag=$(printf '%s' "$_back" | sed 's/^\^checkout(//; s/)$//') ;;
                              *)             _tag="" ;;
                          esac
                      else
                          _tag="apps"
                      fi ;;
            esac
            continue
        fi
        [ -n "$_sel" ] || return 0

        # First match wins, and it is matched against the label field alone --
        # a command containing a comma would otherwise be split by cut.
        _line=$(printf '%s\n' "$_items" | awk -F, -v s="$_sel" '$1 == s { print; exit }')
        _act=$(printf '%s' "$_line" | cut -d, -f2-)
        case "$_act" in
            '^sep')        continue ;;
            '^checkout('*) _tag=$(printf '%s' "$_act" | sed 's/^\^checkout(//; s/)$//') ;;
            '^back()')     _tag="" ;;
            '')            return 0 ;;
            # exec replaces this process, so the trap will not run: leave the
            # submap first, or the arrows would stay Hyprland's.
            *)             keys_off; exec sh -c "$_act" ;;
        esac
    done
}

# The picker itself, chosen by what the session actually is rather than by
# what is installed: wofi is a Wayland client and does not run on X, dmenu is
# an X client and does not run on Wayland, and both are frequently present at
# once on a machine that has had both desktops installed.
menu_cmd() {  # <prompt>
    if wayland && have wofi; then
        # key_custom_0/1 are wofi's user-bound keys; it exits with status 10
        # and 11 when they are pressed. Passed with --define rather than a
        # config file so nothing has to be installed for it, and harmless on
        # a wofi too old to know the keys -- an unknown define is ignored and
        # the arrows simply keep editing the query.
        #
        # --height IN PIXELS, NEVER --lines. With --lines, wofi 1.5 sizes the
        # window from its rows and then re-sizes as the rows arrive; past
        # about a hundred rows it never settles -- the surface stays a
        # stretched, empty frame and no key is answered, Escape included.
        # The applications pane is five hundred rows. That stall, after the
        # four-second build, was the whole of "the menu is broken". A fixed
        # height is laid out once; 540px is twenty rows at this font.
        wofi --dmenu --insensitive --prompt "${1:-menu}" --height 540 --width 520 \
             --define key_custom_0=Left --define key_custom_1=Right
    elif have dmenu; then
        dmenu -i -l 18 -p "${1:-menu}"
    else
        echo "copal-menu: no menu program (jgmenu, wofi or dmenu)" >&2
        return 1
    fi
}

# jgmenu draws the whole tree with the mouse and is the nicer thing when it is
# there AND this is X. On Wayland it is skipped even when installed: it would
# open through Xwayland, on the wrong output, with the wrong scale.
if have jgmenu && ! wayland; then
    exec jgmenu --simple $AT_POINTER --csv-file="$CSV"
fi
walk
COPALMENU
    chmod 0755 /usr/local/bin/copal-menu
    # ----------------------------------------------------------------------
    # copal-gui: the second menu, laid out like Linux Mint's Cinnamon menu --
    # favourites down the left with lock, log out and shut down under them,
    # the programs by category with their icons, a search box, and a line
    # saying what the program under the pointer is. copal-menu stays the
    # keyboard's menu; this is the mouse's, and fills itself from every
    # .desktop file, so nothing is listed by hand. The copy of record is
    # tools/copal-gui; 'make sync-gui' writes it here and lint compares.
    cat > /usr/local/bin/copal-gui <<'COPALGUI'
#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""copal-gui -- the other menu: Linux Mint's Cinnamon menu, for the mouse.

copal-menu is the keyboard's menu: two panes of text in wofi or jgmenu, fast,
and it knows the terminal programs and the Install branch.  This one is the
menu people arrive from Mint already knowing how to use, so it is laid out
the way Cinnamon's is:

    +------+----------------------------------------------+
    | fav  | [ search                                  ]  |
    | fav  | All Applications  |  [icon] Firefox          |
    | fav  | Favourites        |  [icon] GIMP             |
    | ...  | Accessories       |  [icon] ...              |
    |      | Games       <-hover switches                 |
    | lock | ...               |                          |
    | out  +----------------------------------------------+
    | boot | Name                                         |
    | off  | the program's own one-line description       |
    +------+----------------------------------------------+

NOTHING IS WRITTEN BY HAND.  Every entry is a .desktop file the system
already advertises, read through GIO, so NoDisplay, Hidden, OnlyShowIn and
TryExec are honoured the way every desktop honours them, and a program
installed a minute ago -- by apk, the store, or a Flatpak -- is in the menu
the next time it opens.  Its Categories= line decides the section, in the
order below; the first match wins, so a game that is also Education is a
game.  Terminal=true entries open in the same terminal copal-menu uses.

FAVOURITES are the column on the left, as in Mint.  Right-click any program
to add or remove it; the list is ~/.config/copal/gui-favourites, one desktop
id per line, and until that file exists a starter set is picked from what is
installed.

ONE AT A TIME.  Pressing the key while the menu is open closes it, the way
the Mint menu's button does.  The pid is kept in $XDG_RUNTIME_DIR.

ON HYPRLAND it is a layer-shell overlay covering the screen below the bar,
transparent except for the menu, so a click anywhere else closes it and the
keyboard is its own while it is up.  ON i3, or without gtk-layer-shell, it is
an undecorated dialog, which i3 floats; losing focus closes it.

  copal-gui            open the menu (or close it, if it is open)
  copal-gui --list     print section|name|desktop-id for every entry
"""

import os
import shlex
import shutil
import signal
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

# GLib 2.86 moved DesktopAppInfo to GioUnix and deprecated the old name.
try:
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix  # noqa: E402
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ValueError, ImportError):
    DesktopAppInfo = Gio.DesktopAppInfo

# Cinnamon's sections, with the icons each may show -- the first the theme
# has; GNOME's Adwaita dropped most of the full-colour category icons, so
# each carries a symbolic one it does have -- and the Categories= words that
# land a program there.  Checked top to bottom; first match wins.
SECTIONS = [
    ("Preferences",    ("preferences-desktop", "preferences-system-symbolic"), {"Settings", "DesktopSettings", "Screensaver"}),
    ("Games",          ("applications-games",), {"Game"}),
    ("Programming",    ("applications-development", "utilities-terminal-symbolic"), {"Development"}),
    ("Office",         ("applications-office", "x-office-document-symbolic"), {"Office"}),
    ("Graphics",       ("applications-graphics",), {"Graphics"}),
    ("Education",      ("applications-education", "applications-science-symbolic"), {"Education", "Science"}),
    ("Sound & Video",  ("applications-multimedia",), {"AudioVideo", "Audio", "Video"}),
    ("Internet",       ("applications-internet", "web-browser-symbolic"), {"Network"}),
    ("System Tools",   ("applications-system", "applications-system-symbolic"), {"System", "Monitor", "PackageManager"}),
    ("Accessories",    ("applications-accessories", "applications-utilities-symbolic"), {"Utility", "Accessibility"}),
]
OTHER = ("Other", ("applications-other", "view-more-symbolic", "view-list-symbolic"))
# The order they are listed in, which is Mint's, not the matching order.
SHOWN = ["Accessories", "Education", "Games", "Graphics", "Internet", "Office",
         "Programming", "Sound & Video", "System Tools", "Preferences", "Other"]

CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "copal")
FAVFILE = os.path.join(CONF, "gui-favourites")
PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "copal-gui.%d.pid" % os.getuid())

# Tried in order until each role has one, for a first open with no file yet.
STARTER = [
    ("foot.desktop", "kitty.desktop", "Alacritty.desktop", "xterm.desktop"),
    ("pcmanfm.desktop", "thunar.desktop", "org.gnome.Nautilus.desktop"),
    ("firefox-esr.desktop", "firefox.desktop", "com.brave.Browser.desktop", "chromium.desktop"),
    ("org.gnome.TextEditor.desktop", "mousepad.desktop", "l3afpad.desktop", "geany.desktop"),
    ("copal-store.desktop",),
]


def wayland():
    return bool(os.environ.get("WAYLAND_DISPLAY"))


def have(prog):
    return shutil.which(prog) is not None


def terminal():
    """The same choice copal-menu makes, so both menus open the same one."""
    if os.environ.get("TERMINAL"):
        return os.environ["TERMINAL"]
    for t in (("foot", "kitty", "alacritty", "xterm") if wayland() else ("urxvt", "xterm")):
        if have(t):
            return t
    return "xterm"


def section_of(app):
    cats = set(filter(None, (app.get_categories() or "").split(";")))
    for name, _icon, words in SECTIONS:
        if cats & words:
            return name
    return OTHER[0]


def section_icon(name):
    for n, icon, _w in SECTIONS:
        if n == name:
            return icon
    return OTHER[1]


def load_apps():
    """Every entry a launcher should show, deduplicated by name, sorted."""
    seen, apps = set(), []
    for a in Gio.AppInfo.get_all():
        if not isinstance(a, DesktopAppInfo) or not a.should_show():
            continue
        key = a.get_display_name().casefold()
        if key in seen:
            continue
        seen.add(key)
        apps.append(a)
    apps.sort(key=lambda a: a.get_display_name().casefold())
    return apps


def read_favourites(by_id):
    try:
        with open(FAVFILE) as f:
            ids = [l.strip() for l in f if l.strip() and not l.startswith("#")]
    except OSError:
        ids = [next(i for i in role if i in by_id) for role in STARTER if any(i in by_id for i in role)]
    return [i for i in ids if i in by_id]


def write_favourites(ids):
    os.makedirs(CONF, exist_ok=True)
    with open(FAVFILE + ".tmp", "w") as f:
        f.write("# copal-gui favourites: one desktop id per line, in order\n")
        f.writelines(i + "\n" for i in ids)
    os.replace(FAVFILE + ".tmp", FAVFILE)


LOCK = ("system-lock-screen", "system-lock-screen-symbolic")
LOGOUT = ("system-log-out", "system-log-out-symbolic")


def session_actions():
    """Lock, log out, reboot, shut down -- the commands copal-menu uses."""
    if wayland():
        acts = [("Lock screen", LOCK, ["hyprlock"] if have("hyprlock") else None),
                ("Log out", LOGOUT, ["hyprctl", "dispatch", "exit"])]
    else:
        acts = [("Lock screen", LOCK, ["i3lock", "-c", "1a1b26"] if have("i3lock") else None),
                ("Log out", LOGOUT, ["i3-msg", "exit"])]
    # copal-halt asks before it acts; a bare poweroff cannot signal init as a user.
    # Adwaita draws reboot as a second power symbol; a circular arrow first.
    acts += [("Restart", ("view-refresh-symbolic", "system-reboot"), ["copal-halt", "reboot"]),
             ("Shut down", ("system-shutdown", "system-shutdown-symbolic"), ["copal-halt"])]
    return [a for a in acts if a[2]]


def spawn(argv):
    # Its own session, so the program outlives the menu that started it.
    subprocess.Popen(argv, start_new_session=True, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def launch(app):
    if app.get_boolean("Terminal"):
        # Field codes (%U, %f...) stand for files we are not passing.
        cmd = [w for w in shlex.split(app.get_commandline() or "") if not (len(w) == 2 and w[0] == "%")]
        spawn([terminal(), "-e"] + cmd)
        return
    from gi.repository import Gdk
    app.launch([], Gdk.Display.get_default().get_app_launch_context())


# --------------------------------------------------------------------------
# One at a time: a second copal-gui closes the first and exits.
def toggle_existing():
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        with open("/proc/%d/cmdline" % pid, "rb") as f:
            if b"copal-gui" not in f.read():
                return False
        os.kill(pid, signal.SIGTERM)
        return True
    except (OSError, ValueError):
        return False


# THE PANEL'S GROUND is the theme's menu ground, the one the keyboard menu
# (Super+Z, wofi) and the launcher draw on: an opaque panel of its own rather
# than the GTK window colour, which on a light theme was the colour of the
# terminal behind it and the menu all but vanished. The tokens come from
# ~/.config/copal/current/colors.css, which copal-theme rewrites; without
# that file they fall back to the GTK theme's own colours.
THEME_COLORS = os.path.expanduser("~/.config/copal/current/colors.css")
FALLBACK = b"""
@define-color menu-bg @theme_base_color;
@define-color shadow shade(@theme_base_color, 0.92);
@define-color highlight @theme_selected_bg_color;
@define-color accent @theme_selected_fg_color;
@define-color accent-dark alpha(@theme_fg_color, 0.35);
@define-color text-light @theme_fg_color;
"""
CSS = b"""
#backdrop, #backdrop > * { background: transparent; }
#panel {
    background: @menu-bg;
    color: @text-light;
    border: 1px solid @accent-dark;
    border-radius: 8px;
    box-shadow: 0 8px 28px alpha(black, 0.45);
    margin: 0 14px 14px 0;            /* room for the shadow */
}
#panel label, #panel image { color: @text-light; }
#sidebar {
    background: @shadow;
    border-right: 1px solid @highlight;
    border-radius: 8px 0 0 8px;
    padding: 8px 4px;
}
#sidebar button { padding: 6px; margin: 1px 2px; }
#sidebar button:hover { background: @highlight; }
#panel entry {
    background: @shadow;
    color: @text-light;
    caret-color: @accent;
    border: 1px solid @accent-dark;
    box-shadow: none;
}
#panel entry:focus { border-color: @accent; }
#sections row { padding: 5px 10px; border-radius: 5px; }
#apps row { padding: 3px 8px; border-radius: 5px; }
#sections row:hover, #apps row:hover { background: alpha(@highlight, 0.6); }
#sections row:selected, #apps row:selected { background: @highlight; }
#sections row:selected label, #apps row:selected label { color: @accent; }
#sections, #apps { background: transparent; }
#panel separator { background: @highlight; }
#appname { font-weight: bold; }
#appdesc { opacity: 0.75; }
"""


def menu_css():
    """The fallback tokens, then the theme's, then the rules: a later
    @define-color replaces an earlier one of the same name."""
    theme = b""
    try:
        with open(THEME_COLORS, "rb") as f:
            theme = f.read()
    except OSError:
        pass
    return FALLBACK + theme + CSS


def run_gui():
    if toggle_existing():
        return 0
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    from gi.repository import Gdk, Gtk
    try:
        gi.require_version("GtkLayerShell", "0.1")
        from gi.repository import GtkLayerShell
    except (ValueError, ImportError):
        GtkLayerShell = None

    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))

    apps = load_apps()
    by_id = {a.get_id(): a for a in apps}
    favs = read_favourites(by_id)
    term = terminal()

    prov = Gtk.CssProvider()
    prov.load_from_data(menu_css())
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    win = Gtk.Window(title="Menu")
    win.set_name("backdrop")
    layered = bool(wayland() and GtkLayerShell and GtkLayerShell.is_supported())

    def quit_(*_a):
        try:
            os.unlink(PIDFILE)
        except OSError:
            pass
        Gtk.main_quit()
        return False

    try:
        gi.require_version("GLibUnix", "2.0")
        from gi.repository import GLibUnix
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, quit_)
    except (ValueError, ImportError):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, quit_)
    win.connect("destroy", quit_)

    # ----- the panel -----
    panel = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    panel.set_name("panel")

    sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    sidebar.set_name("sidebar")
    favbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    sidebar.pack_start(favbox, False, False, 0)
    sessbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    sidebar.pack_end(sessbox, False, False, 0)
    panel.pack_start(sidebar, False, False, 0)

    main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    main.set_border_width(10)
    panel.pack_start(main, True, True, 0)

    search = Gtk.SearchEntry()
    search.set_placeholder_text("Type to search")
    main.pack_start(search, False, False, 0)

    body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    main.pack_start(body, True, True, 0)

    sections = Gtk.ListBox()
    sections.set_name("sections")
    sections.set_selection_mode(Gtk.SelectionMode.BROWSE)
    body.pack_start(sections, False, False, 0)

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    applist = Gtk.ListBox()
    applist.set_name("apps")
    applist.set_selection_mode(Gtk.SelectionMode.BROWSE)
    applist.set_activate_on_single_click(True)
    scroll.add(applist)
    body.pack_start(scroll, True, True, 0)

    name_l = Gtk.Label(xalign=0)
    name_l.set_name("appname")
    desc_l = Gtk.Label(xalign=0)
    desc_l.set_name("appdesc")
    desc_l.set_ellipsize(3)  # Pango.EllipsizeMode.END
    main.pack_start(Gtk.Separator(), False, False, 0)
    main.pack_start(name_l, False, False, 0)
    main.pack_start(desc_l, False, False, 0)

    def describe(app=None, text=None):
        if app is not None:
            name_l.set_text(app.get_display_name())
            desc_l.set_text(app.get_description() or app.get_generic_name() or "")
        else:
            name_l.set_text(text or "")
            desc_l.set_text("")

    theme = Gtk.IconTheme.get_default()

    def icon_for(gicon, fallback, px):
        # A .desktop file may name an icon the theme does not have (ARandR).
        if gicon is None or theme.lookup_by_gicon(gicon, px, 0) is None:
            gicon = Gio.ThemedIcon.new(fallback)
        img = Gtk.Image.new_from_gicon(gicon, Gtk.IconSize.DND)
        img.set_pixel_size(px)
        return img

    def go(app):
        try:
            launch(app)
        except GLib.Error as e:
            describe(text="Could not start %s: %s" % (app.get_display_name(), e.message))
            return
        quit_()

    # ----- favourites and the session -----
    def fav_menu(app, event):
        m = Gtk.Menu()
        i = app.get_id()
        item = Gtk.MenuItem(label="Remove from favourites" if i in favs else "Add to favourites")

        def flip(_w):
            favs.remove(i) if i in favs else favs.append(i)
            write_favourites(favs)
            fill_favs()
            applist.invalidate_filter()
        item.connect("activate", flip)
        m.append(item)
        m.show_all()
        m.attach_to_widget(win)
        m.popup_at_pointer(event)

    def fill_favs():
        for c in favbox.get_children():
            favbox.remove(c)
        for i in favs:
            app = by_id[i]
            b = Gtk.Button()
            b.set_relief(Gtk.ReliefStyle.NONE)
            b.add(icon_for(app.get_icon(), "application-x-executable", 32))
            b.set_tooltip_text(app.get_display_name())
            b.connect("clicked", lambda _b, a=app: go(a))
            b.connect("enter-notify-event", lambda *_x, a=app: describe(a))
            b.connect("button-press-event",
                      lambda _b, e, a=app: (fav_menu(a, e), True)[1] if e.button == 3 else False)
            favbox.pack_start(b, False, False, 0)
        favbox.show_all()

    for label, icon, argv in session_actions():
        b = Gtk.Button()
        b.set_relief(Gtk.ReliefStyle.NONE)
        b.add(Gtk.Image.new_from_gicon(Gio.ThemedIcon.new_from_names(icon), Gtk.IconSize.LARGE_TOOLBAR))
        b.set_tooltip_text(label)
        b.connect("clicked", lambda _b, a=argv: (spawn(a), quit_()))
        b.connect("enter-notify-event", lambda *_x, t=label: describe(text=t))
        sessbox.pack_start(b, False, False, 0)
    fill_favs()

    # ----- sections -----
    sec_of = {a.get_id(): section_of(a) for a in apps}
    present = set(sec_of.values())
    state = {"section": "All Applications", "rank": None}
    for name, icon in [("All Applications", ("view-app-grid-symbolic",)),
                       ("Favourites", ("starred", "starred-symbolic"))] + \
            [(s, section_icon(s)) for s in SHOWN if s in present]:
        row = Gtk.ListBoxRow()
        row.section = name
        h = Gtk.Box(spacing=8)
        h.pack_start(Gtk.Image.new_from_gicon(Gio.ThemedIcon.new_from_names(icon),
                                              Gtk.IconSize.LARGE_TOOLBAR), False, False, 0)
        h.pack_start(Gtk.Label(label=name, xalign=0), True, True, 0)
        row.add(h)
        sections.add(row)

    # ----- the programs -----
    for app in apps:
        row = Gtk.ListBoxRow()
        row.app = app
        h = Gtk.Box(spacing=10)
        h.pack_start(icon_for(app.get_icon(), "application-x-executable", 24), False, False, 0)
        h.pack_start(Gtk.Label(label=app.get_display_name(), xalign=0), True, True, 0)
        row.add(h)
        applist.add(row)

    def visible(row):
        i = row.app.get_id()
        if state["rank"] is not None:
            return i in state["rank"]
        s = state["section"]
        return s == "All Applications" or (s == "Favourites" and i in favs) or sec_of[i] == s
    applist.set_filter_func(visible)

    def order(r1, r2):
        rk = state["rank"]
        if rk is not None:
            d = rk[r1.app.get_id()] - rk[r2.app.get_id()]
            if d:
                return d
        a, b = r1.app.get_display_name().casefold(), r2.app.get_display_name().casefold()
        return (a > b) - (a < b)
    applist.set_sort_func(order)

    def select_section(row):
        if row is None or state["section"] == row.section and state["rank"] is None:
            return
        state["section"] = row.section
        if search.get_text():
            search.set_text("")  # its changed handler refilters
        else:
            applist.invalidate_filter()
        scroll.get_vadjustment().set_value(0)

    sections.connect("row-selected", lambda _l, r: select_section(r))

    # Hover switches the section, as in Cinnamon -- after a short pause, so
    # sweeping the pointer across the list towards the programs does not
    # flick through every section on the way.
    hover = {"id": 0}

    def on_sections_motion(_w, ev):
        row = sections.get_row_at_y(int(ev.y))
        if hover["id"]:
            GLib.source_remove(hover["id"])
            hover["id"] = 0
        if row is not None and row is not sections.get_selected_row():
            def fire():
                hover["id"] = 0
                sections.select_row(row)
                return False
            hover["id"] = GLib.timeout_add(120, fire)
        return False
    sections.add_events(Gdk.EventMask.POINTER_MOTION_MASK)
    sections.connect("motion-notify-event", on_sections_motion)

    # SCROLLING BY THE EDGES. Hover selects the row under the pointer and
    # never moves the list -- selecting a half-visible row made GTK scroll it
    # into view, which put a new row under the pointer, which was selected
    # and scrolled again: the list ran away fast from the bottom row and
    # slower from the one above it. Now the rows between the edges stay
    # still, so a click lands on what was aimed at, and the list moves only
    # while the pointer rests in a strip one row high at the top or bottom,
    # at one steady speed. The wheel and the scrollbar work as always.
    EDGE, STEP, TICK = 24, 3, 16          # px of strip, px per tick, ms per tick
    edge = {"dir": 0, "id": 0, "y": 0}

    def edge_tick():
        adj = scroll.get_vadjustment()
        v = adj.get_value() + edge["dir"] * STEP
        v = max(adj.get_lower(), min(v, adj.get_upper() - adj.get_page_size()))
        if v == adj.get_value():
            edge["id"] = 0
            return False                  # at the end: stop until the pointer moves
        adj.set_value(v)
        # The row under the resting pointer changes as the list slides.
        row = applist.get_row_at_y(int(v + edge["y"]))
        if row is not None and row is not applist.get_selected_row():
            select_still(row)
        return True

    def select_still(row):
        adj = scroll.get_vadjustment()
        v = adj.get_value()
        applist.select_row(row)
        adj.set_value(v)

    def on_apps_motion(_w, ev):
        adj = scroll.get_vadjustment()
        row = applist.get_row_at_y(int(ev.y))
        if row is not None and row is not applist.get_selected_row():
            select_still(row)
        y = ev.y - adj.get_value()        # the pointer, within the visible part
        d = -1 if y < EDGE else (1 if y > adj.get_page_size() - EDGE else 0)
        edge["y"] = y
        if d != edge["dir"] or (d and not edge["id"]):
            if edge["id"]:
                GLib.source_remove(edge["id"])
                edge["id"] = 0
            edge["dir"] = d
            if d:
                edge["id"] = GLib.timeout_add(TICK, edge_tick)
        return False

    def on_apps_leave(*_a):
        if edge["id"]:
            GLib.source_remove(edge["id"])
        edge["id"], edge["dir"] = 0, 0
        return False
    applist.add_events(Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
    applist.connect("motion-notify-event", on_apps_motion)
    applist.connect("leave-notify-event", on_apps_leave)
    applist.connect("row-selected", lambda _l, r: describe(r.app) if r else describe())
    applist.connect("row-activated", lambda _l, r: go(r.app))

    def on_apps_press(_w, ev):
        if ev.button == 3:
            row = applist.get_row_at_y(int(ev.y))
            if row is not None:
                fav_menu(row.app, ev)
                return True
        return False
    applist.connect("button-press-event", on_apps_press)

    # ----- search -----
    def on_search(_e):
        t = search.get_text().strip()
        if not t:
            state["rank"] = None
        else:
            rank, n = {}, 0
            for group in DesktopAppInfo.search(t):
                for i in group:
                    if i in by_id and i not in rank:
                        rank[i] = n
                        n += 1
            # Fall back to a plain substring on the name and command, for
            # the programs whose .desktop file carries no keywords at all.
            low = t.casefold()
            for a in apps:
                i = a.get_id()
                if i not in rank and (low in a.get_display_name().casefold()
                                      or low in (a.get_executable() or "").casefold()):
                    rank[i] = n
                    n += 1
            state["rank"] = rank
        applist.invalidate_filter()
        applist.invalidate_sort()
        scroll.get_vadjustment().set_value(0)
        for r in applist.get_children():
            if visible(r):
                applist.select_row(r)
                break
        else:
            describe(text="Nothing matches '%s'" % t if t else "")

    search.connect("search-changed", on_search)

    def on_search_activate(_e):
        r = applist.get_selected_row()
        if r is not None and visible(r):
            go(r.app)
    search.connect("activate", on_search_activate)

    def on_key(_w, ev):
        k = ev.keyval
        if k == Gdk.KEY_Escape:
            if search.get_text():
                search.set_text("")
            else:
                quit_()
            return True
        if k in (Gdk.KEY_Down, Gdk.KEY_Up) and search.has_focus():
            r = applist.get_selected_row()
            if r is not None:
                r.grab_focus()
            return False
        if k in (Gdk.KEY_Left, Gdk.KEY_Right) and not search.has_focus():
            return False
        # Type-to-search from anywhere in the menu.
        if not search.has_focus() and search.handle_event(ev):
            search.grab_focus_without_selecting()
            search.set_position(-1)
            return True
        return False
    win.connect("key-press-event", on_key)

    # ----- where it goes -----
    scroll.set_size_request(340, 400)
    if layered:
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_namespace(win, "copal-gui")
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM,
                     GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(win, edge, True)
        if hasattr(GtkLayerShell, "set_keyboard_mode"):
            GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        else:
            GtkLayerShell.set_keyboard_interactivity(win, True)
        visual = win.get_screen().get_rgba_visual()
        if visual is not None:
            win.set_visual(visual)
        win.set_app_paintable(True)
        # The screen below the bar, transparent; the menu in its top-left
        # corner, where the bar's menu button is. A click that reaches the
        # backdrop missed the menu, and closes it.
        backdrop = Gtk.EventBox()
        backdrop.set_visible_window(False)
        catcher = Gtk.EventBox()  # swallows clicks inside the menu
        catcher.add(panel)
        catcher.set_halign(Gtk.Align.START)
        catcher.set_valign(Gtk.Align.START)
        catcher.set_margin_start(6)
        catcher.set_margin_top(6)
        catcher.connect("button-press-event", lambda *_a: True)
        backdrop.add(catcher)
        backdrop.connect("button-press-event", lambda *_a: quit_())
        win.add(backdrop)
    else:
        win.set_decorated(False)
        win.set_type_hint(Gdk.WindowTypeHint.DIALOG)  # i3 floats dialogs
        win.set_skip_taskbar_hint(True)
        win.set_keep_above(True)
        win.set_position(Gtk.WindowPosition.MOUSE)
        win.add(panel)
        # Closing on focus-out, but not in the first instant: the window
        # manager may not have handed focus over yet.
        armed = {"on": False}
        GLib.timeout_add(400, lambda: armed.update(on=True) or False)
        win.connect("focus-out-event", lambda *_a: quit_() if armed["on"] else False)

    win.show_all()
    sections.select_row(sections.get_row_at_index(0))
    applist.invalidate_filter()
    search.grab_focus()
    Gtk.main()
    return 0


def main(argv):
    if len(argv) > 1 and argv[1] in ("-h", "--help"):
        print(__doc__.split("\n\n")[0].strip() + "\n")
        print("  copal-gui            open the menu (or close it, if it is open)")
        print("  copal-gui --list     print section|name|desktop-id for every entry")
        return 0
    if len(argv) > 1 and argv[1] == "--list":
        for a in load_apps():
            print("%s|%s|%s" % (section_of(a), a.get_display_name(), a.get_id()))
        return 0
    if len(argv) > 1:
        print("usage: copal-gui [--list|--help]", file=sys.stderr)
        return 2
    return run_gui()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
COPALGUI
    chmod 0755 /usr/local/bin/copal-gui
    # ----------------------------------------------------------------------
    # copal-desk: the desk, laid out the same way every time.
    #
    # WHY THIS EXISTS, and it is not tidiness. Competitive StarCraft has a
    # word for the thing a layout buys: the hands stop looking. Day[9]'s
    # macro/micro drills are the canonical statement of it -- you do not get
    # faster by thinking faster, you get faster by moving the decisions your
    # hands make into muscle memory, and muscle memory needs the thing to be
    # in the SAME PLACE every time. A tiling desktop with ten empty
    # workspaces is exactly the wrong shape for that: whatever you opened
    # first is on 1 today and on 3 tomorrow, so every switch begins with a
    # look. Omarchy's answer is numbered workspaces with fixed contents;
    # this is the same answer, plus one command that puts them there.
    #
    # The layout that ships is called 'code' and reads:
    #
    #   1  nothing -- the empty one you land on, and the one you throw a
    #      window onto when you need room to think
    #   2  the editor and a terminal, side by side, which is the work
    #   3  a Claude Code session, already in ~/code, ready for input
    #   5  the browser
    #
    # 4 and the rest are deliberately empty. A layout that fills every
    # workspace leaves nowhere to put the thing you did not plan for.
    #
    # It is a text file and there is nothing special about it -- write your
    # own into ~/.config/copal/layouts/NAME and copal-desk NAME runs it.
    say "Installing /usr/local/bin/copal-desk"
    mkdir -p /usr/local/share/copal/layouts
    cat > /usr/local/share/copal/layouts/code.layout <<'DESKCODE'
# The code desk. 'copal-desk' with no arguments runs this one.
#
#   <workspace>  <role>            put that program on that workspace
#   focus <workspace>              where to leave you at the end
#
# Roles are resolved to whatever this machine actually has: 'editor' is the
# graphical editor if one is installed and nvim in a terminal if not, and so
# on. Two escape hatches for anything not covered:
#
#   4  run: mpv --no-video ~/Music     run this command as it stands
#   4  term: ssh pi@fileserver         run it inside a terminal
#
# Lines are executed in order, so on a workspace with two windows the first
# line is the left-hand one.
focus 1
2 editor
2 terminal
3 claude
5 browser
DESKCODE

    cat > /usr/local/bin/copal-desk <<'COPALDESK'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-desk -- put the workspaces into a known shape, in one command.
#
# Reads a layout file and opens what it names on the workspace it names.
# Works on both desktops: Hyprland is told where a window goes before it
# opens ([workspace N silent] on the exec dispatcher, which places it without
# dragging your eyes to it), i3 is told by switching workspace first, which
# is the only mechanism it has.
#
# NOT AN AUTOSTART. It is a key (Super+Shift+D) and a menu entry, because a
# layout that runs itself at login is a layout you cannot decline on the
# morning you wanted an empty machine -- and on a board this size, five
# programs starting at once during login is the slowest possible moment for
# them to do it.
set -eu

LAYOUT_SYS=/usr/local/share/copal/layouts
LAYOUT_USR="${XDG_CONFIG_HOME:-$HOME/.config}/copal/layouts"
have() { command -v "$1" >/dev/null 2>&1; }
wayland() { [ -n "${WAYLAND_DISPLAY:-}" ]; }

usage() {
    cat <<USAGE
usage: copal-desk [NAME]      lay the desk out; NAME defaults to 'code'
       copal-desk --list      the layouts on this machine
       copal-desk --show NAME print one, without running it

Layouts live in $LAYOUT_SYS and in
$LAYOUT_USR, which wins where both have the name.
USAGE
}

layout_file() {  # <name> -> path, or nothing
    [ -f "$LAYOUT_USR/$1.layout" ] && { printf '%s\n' "$LAYOUT_USR/$1.layout"; return 0; }
    [ -f "$LAYOUT_SYS/$1.layout" ] && { printf '%s\n' "$LAYOUT_SYS/$1.layout"; return 0; }
    return 1
}

list_layouts() {
    for _d in "$LAYOUT_SYS" "$LAYOUT_USR"; do
        [ -d "$_d" ] || continue
        for _f in "$_d"/*.layout; do
            [ -f "$_f" ] || continue
            printf '  %-12s %s\n' "$(basename "$_f" .layout)" \
                   "$(awk 'NF && /^#/ { sub(/^# ?/, ""); print; exit }' "$_f")"
        done
    done
}

# ---- the roles, resolved against what is installed -------------------------
# Same preference orders the rest of Copal uses: foot first on Wayland because
# it is the terminal that comes up on a compositor drawing in software, and
# the browser list is the one /etc/profile.d/browser.sh picks $BROWSER from.
if wayland; then
    TERM_EMU="${TERMINAL:-$(have foot && echo foot || (have kitty && echo kitty) \
                            || (have alacritty && echo alacritty) || echo xterm)}"
else
    TERM_EMU="${TERMINAL:-$(have urxvt && echo urxvt || echo xterm)}"
fi

first_of() { for _c in "$@"; do have "$_c" && { printf '%s\n' "$_c"; return 0; }; done; return 1; }

role_cmd() {  # <role> -> a command line, or nothing if this machine cannot
    case "$1" in
        terminal) printf '%s\n' "$TERM_EMU" ;;
        # A graphical editor if there is one, and nvim in a terminal if not.
        # The terminal editor is not a lesser answer here -- on the small
        # boards it is the only one that opens in under a second.
        editor)
            _e=$(first_of lapce codium code kate geany mousepad 2>/dev/null || true)
            if [ -n "${_e:-}" ]; then printf '%s\n' "$_e"
            else _e=$(first_of nvim vim vi) && printf '%s -e %s\n' "$TERM_EMU" "$_e"
            fi ;;
        browser)
            _b=$(first_of "${BROWSER:-}" brave firefox-esr firefox chromium \
                          badwolf netsurf dillo 2>/dev/null || true)
            [ -n "${_b:-}" ] && printf '%s\n' "$_b" || return 1 ;;
        files|filemanager)
            _f=$(first_of thunar pcmanfm xfe 2>/dev/null || true)
            if [ -n "${_f:-}" ]; then printf '%s\n' "$_f"
            else _f=$(first_of mc nnn ranger) && printf '%s -e %s\n' "$TERM_EMU" "$_f"
            fi ;;
        # The one role with a working directory in it. ~/code is where Copal
        # puts a checkout and where the agent is most useful; it is created
        # if it is not there, because a shell that starts with 'cd: no such
        # file' has wasted the whole point of the workspace.
        claude)
            have claude || return 1
            printf "%s -e sh -c 'mkdir -p \"\$HOME/code\"; cd \"\$HOME/code\"; exec claude'\n" "$TERM_EMU" ;;
        music)
            _m=$(first_of cmus mocp 2>/dev/null || true)
            [ -n "${_m:-}" ] && printf '%s -e %s\n' "$TERM_EMU" "$_m" || return 1 ;;
        # The camera, whichever program copal-camera says that is on this
        # machine -- birdshot once stage 7 has built it. A layout for a
        # capture session is '2 camera' and '3 terminal' in a file of its own.
        camera)
            have copal-camera && copal-camera --which 2>/dev/null || return 1 ;;
        *) return 1 ;;
    esac
}

# ---- placing one window ----------------------------------------------------
# The pause is not decoration. Two windows opening on one workspace inside the
# same tenth of a second race to be the first child of the split, so the
# left-hand one in the layout file is whichever won -- which is the one thing
# a layout is supposed to decide. COPAL_DESK_DELAY tunes it; a Pi Zero
# starting a browser wants more than a laptop does.
DELAY="${COPAL_DESK_DELAY:-1}"

spawn() {  # <workspace> <command line>
    if wayland && have hyprctl; then
        # 'silent' places it without following it: the layout builds behind
        # you and the screen does not flick through five workspaces.
        hyprctl dispatch exec "[workspace $1 silent] $2" >/dev/null 2>&1 || return 1
    elif have i3-msg; then
        # i3 has no per-window placement on exec, so the workspace has to be
        # the current one when the window maps. The focus is put back at the
        # end, by the 'focus' line.
        i3-msg "workspace number $1" >/dev/null 2>&1 || true
        i3-msg "exec --no-startup-id $2" >/dev/null 2>&1 || return 1
    else
        echo "copal-desk: neither hyprctl nor i3-msg -- no window manager to ask" >&2
        exit 1
    fi
    sleep "$DELAY"
}

go_to() {  # <workspace>
    if wayland && have hyprctl; then hyprctl dispatch workspace "$1" >/dev/null 2>&1 || true
    elif have i3-msg;         then i3-msg "workspace number $1" >/dev/null 2>&1 || true
    fi
}

# ---- arguments -------------------------------------------------------------
NAME=code
SHOW=""
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --list) list_layouts; exit 0 ;;
    --show) SHOW=1; NAME="${2:?--show needs a layout name}" ;;
    -*) usage >&2; exit 2 ;;
    "") ;;
    *) NAME="$1" ;;
esac

FILE=$(layout_file "$NAME") || {
    echo "copal-desk: no layout called '$NAME'. There is:" >&2
    list_layouts >&2
    exit 1
}
[ -n "$SHOW" ] && { cat "$FILE"; exit 0; }

# ---- running it ------------------------------------------------------------
FOCUS=""
MISSING=""
while read -r ws rest; do
    case "${ws:-}" in ''|'#'*) continue ;; esac
    case "$ws" in
        focus) FOCUS="$rest"; continue ;;
    esac
    [ -n "${rest:-}" ] || continue
    case "$rest" in
        run:*)  cmd=$(printf '%s' "${rest#run:}"  | sed 's/^ *//') ;;
        term:*) cmd="$TERM_EMU -e sh -c '$(printf '%s' "${rest#term:}" | sed "s/^ *//; s/'/'\\\\''/g")'" ;;
        *)      cmd=$(role_cmd "$rest" || true)
                # A role this machine cannot fill is a note at the end, not a
                # failure: a layout naming a browser is still worth running on
                # the machine that has no browser yet.
                [ -n "${cmd:-}" ] || { MISSING="$MISSING $rest"; continue; } ;;
    esac
    spawn "$ws" "$cmd" || echo "copal-desk: could not start: $cmd" >&2
done < "$FILE"

[ -n "$FOCUS" ] && go_to "$FOCUS"
[ -n "$MISSING" ] && echo "copal-desk: not installed, so not opened:$MISSING" >&2
exit 0
COPALDESK
    chmod 0755 /usr/local/bin/copal-desk

    # copal-camera: which program "the camera" means on this machine.
    #
    # THE DEFAULT CAMERA APPLICATION IS BIRDSHOT -- the IMX477 capture
    # pipeline that is one of the checkouts stage 1 proposes, cloned and
    # compiled by stage 7 (copal-build). Three things want to open "the
    # camera" -- the Camera entry at the top of copal-menu, Super+Shift+B on
    # both desktops, the 'camera' role in a copal-desk layout -- and the
    # decision of which program that is lives here, once, the way $BROWSER
    # settles the browser. $CAMERA overrides it.
    say "Installing /usr/local/bin/copal-camera"
    cat > /usr/local/bin/copal-camera <<'COPALCAMERA'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-camera -- the camera application, whichever one this machine has.
#
#   copal-camera            open it
#   copal-camera --which    print the command it would run, and nothing else;
#                           exit 1 if there is no camera program here
#
# ONE ANSWER TO "THE CAMERA", asked from three places -- the Camera entry at
# the top of copal-menu, Super+Shift+B on both desktops, and the 'camera'
# role in a copal-desk layout -- so that changing which program that is means
# changing it here and nowhere else. $CAMERA overrides the search, the way
# $BROWSER does for the browser: set it in ~/.profile and every consumer
# follows.
#
# THE DEFAULT IS BIRDSHOT. It is one of the checkouts stage 1 proposes and
# stage 7 clones and builds, which is why ~/.local/bin is put on PATH here
# before looking: that is where copal-build installs, and a compositor that
# started without reading ~/.profile would not have it.
#
#   birdshot-gui     the Qt front end, built when Qt 6 was present. A window.
#   birdshot gui     the loopback viewfinder, served to the browser, for a
#                    build without Qt. It is a server, so it gets a terminal,
#                    and the browser is opened from here rather than by
#                    birdshot's own xdg-open, which this system does not
#                    install. The port is passed rather than trusted to a
#                    default so that the two sides cannot disagree.
#
# After those, the packaged webcam programs, for a machine that has one.
set -u
have()    { command -v "$1" >/dev/null 2>&1; }
wayland() { [ -n "${WAYLAND_DISPLAY:-}" ]; }
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH
# The terminal, chosen the way copal-menu chooses it: on Wayland the ones
# that session has, and foot first because it comes up without GL.
if wayland; then
    TERM_EMU="${TERMINAL:-$(have foot && echo foot \
                            || (have kitty && echo kitty) \
                            || (have alacritty && echo alacritty) \
                            || echo xterm)}"
else
    TERM_EMU="${TERMINAL:-$(have urxvt && echo urxvt || echo xterm)}"
fi

which_camera() {
    if [ -n "${CAMERA:-}" ]; then
        have "${CAMERA%% *}" && { printf '%s\n' "$CAMERA"; return 0; }
    fi
    if have birdshot-gui; then printf 'birdshot-gui\n'; return 0; fi
    if have birdshot; then
        printf "%s -e sh -c 'birdshot gui --port 8477 --no-open & sleep 2; \${BROWSER:-xdg-open} http://127.0.0.1:8477 >/dev/null 2>&1; wait'\n" "$TERM_EMU"
        return 0
    fi
    for _c in guvcview cheese qv4l2; do
        have "$_c" && { printf '%s\n' "$_c"; return 0; }
    done
    return 1
}

case "${1:-}" in
    --which) which_camera ;;
    '')
        _cmd=$(which_camera) || {
            echo "copal-camera: no camera program on this machine." >&2
            echo "  birdshot is built from ~/code by 'copal-build' (stage 7 runs it);" >&2
            echo "  or set CAMERA=<command> in ~/.profile." >&2
            exit 1
        }
        exec sh -c "$_cmd" ;;
    *) echo "usage: copal-camera [--which]" >&2; exit 2 ;;
esac
COPALCAMERA
    chmod 0755 /usr/local/bin/copal-camera
    note "copal-camera -- birdshot, or \$CAMERA; the menu, Super+Shift+B and copal-desk use it"

    # ----------------------------------------------------------------------
    # The Copal Center.
    #
    # A control panel in the sense the small distributions meant it: one
    # window that is the answer to "what is on this machine and what else
    # could be". Damn Small Linux had exactly this, and it is the piece a
    # tiling WM most obviously lacks -- i3 will happily run anything and tell
    # you about nothing.
    #
    # Same catalogue as the menu and stage 12, presented as a sortable list
    # with a status column, so Run and Install are one window rather than two
    # different mental models. yad is a 1 MB GTK dialog tool; if it is not
    # there this degrades to the same list under 'dialog' in a terminal, and
    # if that is missing too, to the app menu.
    say "Installing /usr/local/bin/copal-center"
    cat > /usr/local/bin/copal-center <<'COPALCENTER'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-center -- one window listing the whole catalogue, installed or not.
set -eu
CATFILE=/usr/local/share/copal/catalogue
have() { command -v "$1" >/dev/null 2>&1; }
TERM_EMU="${TERMINAL:-$(have urxvt && echo urxvt || echo xterm)}"

# The store (stage 18) lists this catalogue too, with the programs nothing
# installs until they are picked. Where it exists, Super+Shift+C opens it --
# Copal Apps, its window, and the store's own yad window where that is absent.
[ -n "${COPAL_CENTER_ONLY:-}" ] || ! have copal-apps || exec copal-apps
[ -n "${COPAL_CENTER_ONLY:-}" ] || ! have copal-store || exec copal-store

[ -f "$CATFILE" ] || { have copal-menu && exec copal-menu; echo "no catalogue" >&2; exit 1; }

# Rows for the dialog: status, section, program, and the action to take. The
# action is decided here rather than in the UI layer so both front ends stay
# dumb.
cmd_for() {  # <binary> <mode> -- kept identical to copal-menu's
    case "$2" in
        t) printf '%s -e %s' "$TERM_EMU" "$1" ;;
        h) printf "%s -e sh -c '%s --help 2>&1 | head -40; echo; echo \"-- shell in this directory; Ctrl-D to close --\"; exec sh'" \
                  "$TERM_EMU" "$1" ;;
        *) printf '%s' "$1" ;;
    esac
}

rows() {
    while IFS='|' read -r sec label pkgs bin mode; do
        [ -n "${sec:-}" ] || continue
        case "$sec" in '#'*) continue ;; esac
        if have "$bin"; then
            act=$(cmd_for "$bin" "$mode")
            printf '%s\t%s\t%s\t%s\n' "installed" "$sec" "$label" "$act"
        else
            printf '%s\t%s\t%s\t%s\n' "-" "$sec" "$label" "$TERM_EMU -e copal-install $pkgs"
        fi
    done < "$CATFILE"
}

if have yad; then
    # --print-column with a hidden action column: the user picks a readable
    # row, yad hands back something executable.
    sel=$(rows | tr '\t' '\n' | yad --list \
            --title="Copal Center" --width=700 --height=520 --center \
            --text="Everything this system can run. Pick a row and press Run.\nRows marked '-' are not installed yet; Run fetches them." \
            --column="Status" --column="Section" --column="Program" --column="Action" \
            --search-column=3 --expand-column=3 --hide-column=4 --print-column=4 \
            --button="Close:1" --button="Run:0" 2>/dev/null) || exit 0
    cmd=${sel%|}
    [ -n "$cmd" ] && exec sh -c "$cmd"
    exit 0
fi

if have dialog; then
    # dialog wants tag/description pairs. Tag is the line number so that two
    # programs sharing a label can never collide.
    _tmp="${TMPDIR:-/tmp}/copal-center.$$"
    rows > "$_tmp"
    set --
    _n=0
    while IFS="$(printf '\t')" read -r st sec label act; do
        _n=$((_n + 1))
        set -- "$@" "$_n" "[$st] $sec: $label"
    done < "$_tmp"
    _pick=$(dialog --clear --title "Copal Center" \
              --menu "Pick a program. Rows marked - are not installed yet." \
              22 74 16 "$@" 3>&1 1>&2 2>&3) || { rm -f "$_tmp"; exit 0; }
    _cmd=$(awk -F'\t' -v n="$_pick" 'NR==n {print $4}' "$_tmp")
    rm -f "$_tmp"
    [ -n "$_cmd" ] && exec sh -c "$_cmd"
    exit 0
fi

have copal-menu && exec copal-menu
echo "copal-center needs yad or dialog; neither is installed." >&2
exit 1
COPALCENTER
    chmod 0755 /usr/local/bin/copal-center

    # ----------------------------------------------------------------------
    # The settings tool.
    #
    # Every minimal distribution eventually grows one of these, and the ones
    # that are any good share a shape: raspi-config, Omarchy's menu, Alpine's
    # own setup-* scripts. A flat list of the things you actually change after
    # an install -- users, hostname, timezone, services, what starts at boot --
    # each of which is otherwise a command you have to already know.
    #
    # Alpine ships the pieces (adduser, setup-hostname, setup-timezone,
    # rc-update) and no front end at all. This is the front end. It calls those
    # tools rather than reimplementing them, so nothing here can drift from
    # what the system actually does.
    #
    # GUI first because that was asked for, and because a checklist is simply
    # the right shape for "which groups should this user be in" -- but the
    # terminal path is not an afterthought: it is the same screens under
    # dialog, so it works over SSH on a headless board.
    say "Installing /usr/local/bin/copal-config"
    cat > /usr/local/bin/copal-config <<'COPALCONFIG'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-config -- system settings for Copal. raspi-config's job, Copal's tools.
#
#   copal-config            GUI if there is a display, otherwise the terminal
#   copal-config --tui      force the terminal interface
#   copal-config --help
#
# Three front ends, one set of screens: yad (GTK), dialog (curses), and a
# plain read/printf fallback so this still works on a system with neither.
set -eu

have() { command -v "$1" >/dev/null 2>&1; }

case "${1:-}" in
    -h|--help) sed -n '2,${/^#/!q; /^# SPDX/d; /^# Copyright/d; p;}' "$0"; exit 0 ;;
    --tui) FORCE_TUI=1; shift ;;
    *) FORCE_TUI=0 ;;
esac

# Almost everything here writes to /etc. Re-exec rather than failing halfway
# through with a permission error on the third of five steps.
if [ "$(id -u)" != 0 ]; then
    have doas && exec doas "$0" ${FORCE_TUI:+--tui} "$@"
    echo "copal-config needs root:  doas copal-config" >&2
    exit 1
fi

# Which front end. A DISPLAY is not enough on its own -- running under doas
# from a terminal inherits DISPLAY but not necessarily the authority to use
# it -- so yad is probed rather than assumed.
UI=plain
if [ "$FORCE_TUI" = 0 ] && [ -n "${DISPLAY:-}" ] && have yad; then UI=yad
elif have dialog; then UI=dialog
fi

# ---------------------------------------------------------------- UI layer --
# Six primitives. Every screen below is written once against these, which is
# the only reason three front ends is maintainable rather than three copies.

ui_msg() {  # <text>
    case $UI in
        yad) printf '%s\n' "$1" | yad --text-info --width=620 --height=420 \
                 --title="Copal" --button="OK:0" --wrap 2>/dev/null || true ;;
        dialog) dialog --title "Copal" --msgbox "$1" 20 74 ;;
        *) printf '\n%s\n\n' "$1"; printf 'Press Enter. '; read -r _ ;;
    esac
}

ui_yesno() {  # <question> -- returns 0 for yes
    case $UI in
        yad) yad --question --title="Copal" --width=460 --center \
                 --text="$1" --button="No:1" --button="Yes:0" 2>/dev/null ;;
        dialog) dialog --title "Copal" --yesno "$1" 12 70 ;;
        *) printf '\n%s [y/N] ' "$1"; read -r _r; case "$_r" in [Yy]*) return 0 ;; *) return 1 ;; esac ;;
    esac
}

ui_input() {  # <prompt> [default] -- answer on stdout
    case $UI in
        yad) yad --entry --title="Copal" --width=460 --center \
                 --text="$1" --entry-text="${2:-}" 2>/dev/null || true ;;
        dialog) dialog --title "Copal" --inputbox "$1" 10 70 "${2:-}" 3>&1 1>&2 2>&3 || true ;;
        *) printf '\n%s ' "$1" >&2; read -r _r || _r=""; printf '%s' "${_r:-${2:-}}" ;;
    esac
}

ui_password() {  # <prompt>
    case $UI in
        yad) yad --entry --hide-text --title="Copal" --width=460 --center \
                 --text="$1" 2>/dev/null || true ;;
        dialog) dialog --title "Copal" --insecure --passwordbox "$1" 10 70 3>&1 1>&2 2>&3 || true ;;
        *) printf '\n%s ' "$1" >&2
           stty -echo 2>/dev/null || true; read -r _r || _r=""
           stty echo 2>/dev/null || true; printf '\n' >&2; printf '%s' "$_r" ;;
    esac
}

# ui_menu <title> <text> <tag> <label> [<tag> <label> ...] -- chosen tag on stdout
ui_menu() {
    _t="$1"; _x="$2"; shift 2
    case $UI in
        yad)
            _out=$(while [ "$#" -ge 2 ]; do printf '%s\n%s\n' "$1" "$2"; shift 2; done \
                   | yad --list --title="$_t" --text="$_x" --width=560 --height=440 \
                         --center --column="tag" --column="Setting" \
                         --hide-column=1 --print-column=1 --expand-column=2 \
                         --button="Back:1" --button="Choose:0" 2>/dev/null) || return 1
            printf '%s' "${_out%|}" ;;
        dialog)
            dialog --clear --title "$_t" --menu "$_x" 20 74 12 "$@" 3>&1 1>&2 2>&3 || return 1 ;;
        *)
            printf '\n== %s ==\n%s\n\n' "$_t" "$_x" >&2
            _i=0
            while [ "$#" -ge 2 ]; do _i=$((_i+1)); printf '  %s) %s\n' "$1" "$2" >&2; shift 2; done
            printf '\nChoice (blank to go back): ' >&2
            read -r _r || _r=""; [ -n "$_r" ] || return 1
            printf '%s' "$_r" ;;
    esac
}

# ui_check <title> <text> <tag> <label> <on|off> ... -- chosen tags, space separated
ui_check() {
    _t="$1"; _x="$2"; shift 2
    case $UI in
        yad)
            _out=$(while [ "$#" -ge 3 ]; do
                       case "$3" in on) printf 'TRUE\n' ;; *) printf 'FALSE\n' ;; esac
                       printf '%s\n%s\n' "$1" "$2"; shift 3
                   done | yad --list --checklist --title="$_t" --text="$_x" \
                         --width=560 --height=440 --center \
                         --column="Pick:CHK" --column="tag" --column="Meaning" \
                         --hide-column=2 --print-column=2 --expand-column=3 \
                         --button="Cancel:1" --button="Apply:0" 2>/dev/null) || return 1
            printf '%s' "$_out" | tr '|' ' ' ;;
        dialog)
            dialog --clear --title "$_t" --checklist "$_x" 20 74 12 "$@" 3>&1 1>&2 2>&3 \
                | tr -d '"' || return 1 ;;
        *)
            printf '\n== %s ==\n%s\n\n' "$_t" "$_x" >&2
            _sel=""
            while [ "$#" -ge 3 ]; do
                printf '  %-10s %-46s [%s] keep/add? [y/N] ' "$1" "$2" "$3" >&2
                read -r _r || _r=""
                case "$_r" in [Yy]*) _sel="$_sel $1" ;;
                              '') [ "$3" = on ] && _sel="$_sel $1" ;; esac
                shift 3
            done
            printf '%s' "$_sel" ;;
    esac
}

# ------------------------------------------------------------------ users ---
# The groups worth offering, with what each one actually grants. Only those
# that exist on this system are shown -- Alpine does not create Raspberry Pi
# OS's gpio/i2c/spi groups, and offering a group that does not exist produces
# a confusing failure rather than a useful one.
GROUPS_KNOWN="wheel|administrator -- may use doas to become root
audio|sound devices
video|framebuffer, X and the camera
input|keyboards, mice, joysticks
netdev|change network settings without root
dialout|serial ports -- the GPIO UART, an Arduino
plugdev|removable devices
usb|USB devices
users|the generic unprivileged group
disk|raw disk access -- dangerous, and rarely what you want"

group_exists() { getent group "$1" >/dev/null 2>&1; }
in_group() { id -Gn "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

# Real logins only: uid >= 1000 and a shell that is not nologin/false. Listing
# the two dozen system accounts would bury the one you came here to change.
human_users() {
    awk -F: '$3 >= 1000 && $3 < 65534 && $7 !~ /(nologin|false)$/ { print $1 }' /etc/passwd
}

screen_user_groups() {  # <username>
    _u="$1"
    set --
    _old=$IFS; IFS='
'
    for _line in $GROUPS_KNOWN; do
        IFS=$_old
        _g=${_line%%|*}; _d=${_line#*|}
        group_exists "$_g" || continue
        if in_group "$_u" "$_g"; then set -- "$@" "$_g" "$_d" on
        else set -- "$@" "$_g" "$_d" off; fi
        IFS='
'
    done
    IFS=$_old
    [ "$#" -gt 0 ] || { ui_msg "No configurable groups exist on this system."; return 0; }

    _want=$(ui_check "Groups for $_u" \
        "Tick the groups '$_u' should belong to. Unticking removes them.
wheel is the important one: it is what lets an account use doas." "$@") || return 0

    # Apply the difference in both directions, so unticking really removes.
    _old=$IFS; IFS='
'
    for _line in $GROUPS_KNOWN; do
        IFS=$_old
        _g=${_line%%|*}
        group_exists "$_g" || { IFS='
'; continue; }
        case " $_want " in
            *" $_g "*) in_group "$_u" "$_g" || adduser "$_u" "$_g" 2>/dev/null || true ;;
            *)         in_group "$_u" "$_g" && delgroup "$_u" "$_g" 2>/dev/null || true ;;
        esac
        IFS='
'
    done
    IFS=$_old
    ui_msg "Groups for $_u are now:

$(id -Gn "$_u" 2>/dev/null | tr ' ' '\n' | sed 's/^/  /')

A group change takes effect at the next login, not immediately."
}

screen_user_add() {
    _u=$(ui_input "New user name (lower case, no spaces):") || return 0
    [ -n "$_u" ] || return 0
    case "$_u" in
        *[!a-z0-9_-]*|[!a-z]*)
            ui_msg "'$_u' is not a usable user name.

Use lower-case letters, digits, dash and underscore, starting with a letter.
That is what adduser will accept and what every other tool expects."
            return 0 ;;
    esac
    if id "$_u" >/dev/null 2>&1; then
        ui_msg "'$_u' already exists."; return 0
    fi

    _p1=$(ui_password "Password for $_u:")
    [ -n "$_p1" ] || { ui_msg "No password given -- not creating the account.

An account with no password cannot log in, which is rarely what is wanted."; return 0; }
    _p2=$(ui_password "Repeat the password:")
    [ "$_p1" = "$_p2" ] || { ui_msg "The two passwords do not match. Nothing was changed."; return 0; }

    # -D means "do not run passwd interactively"; the password is set below.
    if ! adduser -D "$_u" >/dev/null 2>&1; then
        ui_msg "adduser failed for '$_u'."; return 0
    fi
    if ! printf '%s:%s\n' "$_u" "$_p1" | chpasswd >/dev/null 2>&1; then
        ui_msg "The account was created but the password could not be set.
Set it by hand:  doas passwd $_u"
    fi

    if ui_yesno "Make '$_u' an administrator?

That adds them to the wheel group, which is what lets an account use doas to
run commands as root. Say no for an ordinary account."; then
        adduser "$_u" wheel 2>/dev/null || true
    fi
    # Sensible defaults for a desktop account, where the groups exist.
    for _g in audio video input netdev; do
        group_exists "$_g" && adduser "$_u" "$_g" 2>/dev/null || true
    done

    ui_msg "Created '$_u'.

  home   : $(getent passwd "$_u" | cut -d: -f6)
  shell  : $(getent passwd "$_u" | cut -d: -f7)
  groups : $(id -Gn "$_u" 2>/dev/null)

Choose 'Groups' from the user menu to change any of that."
    screen_commit_hint
}

screen_user_del() {
    _u="$1"
    if [ "$_u" = root ]; then
        ui_msg "root cannot be deleted, and should not be.

uid 0 owns most of the filesystem and the kernel checks privilege by number,
so removing it produces a system that does not boot. To take root out of use,
lock it instead:  doas passwd -l root"
        return 0
    fi
    if [ "$_u" = "${SUDO_USER:-${DOAS_USER:-}}" ]; then
        ui_msg "'$_u' is the account you are logged in as. Refusing.

Log in as another administrator first if you really mean to remove it."
        return 0
    fi
    ui_yesno "Delete the user '$_u'?

This removes the account. Their home directory and everything in it goes too
if you say yes to the next question. Neither can be undone." || return 0
    if ui_yesno "Also delete their home directory, $(getent passwd "$_u" | cut -d: -f6)?"; then
        deluser --remove-home "$_u" >/dev/null 2>&1 || deluser "$_u" >/dev/null 2>&1 || true
    else
        deluser "$_u" >/dev/null 2>&1 || true
    fi
    id "$_u" >/dev/null 2>&1 && ui_msg "Could not delete '$_u'." || ui_msg "Deleted '$_u'."
    screen_commit_hint
}

screen_user_passwd() {
    _u="$1"
    _p1=$(ui_password "New password for $_u:"); [ -n "$_p1" ] || return 0
    _p2=$(ui_password "Repeat it:")
    [ "$_p1" = "$_p2" ] || { ui_msg "They do not match. Nothing was changed."; return 0; }
    if printf '%s:%s\n' "$_u" "$_p1" | chpasswd >/dev/null 2>&1; then
        ui_msg "Password changed for '$_u'."
        screen_commit_hint
    else
        ui_msg "Could not change the password for '$_u'."
    fi
}

screen_user_one() {  # <username>
    _u="$1"
    while :; do
        _c=$(ui_menu "User: $_u" \
             "uid $(id -u "$_u" 2>/dev/null)   groups: $(id -Gn "$_u" 2>/dev/null)" \
             groups   "Groups -- what this account is allowed to do" \
             passwd   "Change password" \
             delete   "Delete this user" \
             back     "Back") || return 0
        case "$_c" in
            groups) screen_user_groups "$_u" ;;
            passwd) screen_user_passwd "$_u" ;;
            delete) screen_user_del "$_u"; id "$_u" >/dev/null 2>&1 || return 0 ;;
            *) return 0 ;;
        esac
    done
}

screen_users() {
    while :; do
        set -- add "Add a user"
        for _u in $(human_users); do
            set -- "$@" "$_u" "$_u  --  $(id -Gn "$_u" 2>/dev/null | cut -c1-46)"
        done
        set -- "$@" back "Back"
        _c=$(ui_menu "Users and groups" \
             "Accounts you can log in as. System accounts are not listed." "$@") || return 0
        case "$_c" in
            add) screen_user_add ;;
            back|'') return 0 ;;
            *) screen_user_one "$_c" ;;
        esac
    done
}

# ----------------------------------------------------------------- system ---
screen_hostname() {
    _h=$(ui_input "Hostname:" "$(hostname)") || return 0
    [ -n "$_h" ] || return 0
    case "$_h" in *[!a-zA-Z0-9-]*) ui_msg "'$_h' is not a valid hostname: letters, digits and dashes only."; return 0 ;; esac
    # setup-hostname is Alpine's own, and also fixes /etc/hosts, which is the
    # bit people forget and then wonder why sudo/doas pauses for a second.
    if have setup-hostname && setup-hostname -n "$_h" >/dev/null 2>&1; then
        hostname "$_h" 2>/dev/null || true
        ui_msg "Hostname is now '$_h'.

Some things only notice at the next reboot."
        screen_commit_hint
    else
        ui_msg "Could not set the hostname."
    fi
}

screen_timezone() {
    _z=$(ui_input "Timezone (Region/City, e.g. Europe/London):" \
                  "$(cat /etc/timezone 2>/dev/null || echo UTC)") || return 0
    [ -n "$_z" ] || return 0
    if [ ! -f "/usr/share/zoneinfo/$_z" ]; then
        ui_msg "No such timezone: $_z

The names come from the tzdata database. Browse them with:
  ls /usr/share/zoneinfo"
        return 0
    fi
    if have setup-timezone && setup-timezone -z "$_z" >/dev/null 2>&1; then
        ui_msg "Timezone is now $_z.  ($(date))"
        screen_commit_hint
    else
        ui_msg "Could not set the timezone."
    fi
}

screen_keymap() {
    ui_msg "The keyboard map is set by Alpine's own setup-keymap, which is
interactive and lists every layout it has.

Run it in a terminal:   doas setup-keymap

It is not wrapped here because its list is long enough that a dialog box
would be worse than the tool itself."
}

# ---------------------------------------------------------------- services --
screen_services() {
    while :; do
        set --
        for _s in $(ls /etc/init.d 2>/dev/null | sort); do
            [ -x "/etc/init.d/$_s" ] || continue
            if rc-update show default 2>/dev/null | grep -q "^ *$_s "; then _st="at boot"
            else _st="-      "; fi
            if rc-service "$_s" status >/dev/null 2>&1; then _st="$_st running"
            else _st="$_st stopped"; fi
            set -- "$@" "$_s" "$_st"
        done
        [ "$#" -gt 0 ] || { ui_msg "No services found."; return 0; }
        set -- "$@" back "Back"
        _c=$(ui_menu "Services" \
            "What runs, and what starts at boot. Pick one to change it." "$@") || return 0
        [ "$_c" = back ] || [ -z "$_c" ] && return 0
        _a=$(ui_menu "Service: $_c" "$(rc-service "$_c" status 2>&1 | head -3)" \
             start "Start it now" \
             stop  "Stop it now" \
             enable  "Start it at boot" \
             disable "Do not start it at boot" \
             back  "Back") || continue
        case "$_a" in
            start)   rc-service "$_c" start   >/dev/null 2>&1 || ui_msg "Could not start $_c." ;;
            stop)    rc-service "$_c" stop    >/dev/null 2>&1 || ui_msg "Could not stop $_c." ;;
            enable)  rc-update add "$_c" default >/dev/null 2>&1 && screen_commit_hint ;;
            disable) rc-update del "$_c" default >/dev/null 2>&1 && screen_commit_hint ;;
        esac
    done
}

# ------------------------------------------------------------ boot/display --
# usercfg.txt, not config.txt: config.txt carries a "do not modify, will be
# overwritten on upgrade" banner and includes usercfg.txt last, so directives
# here win and survive. Same managed-block trick the SSH policy uses.
BOOTDIR=/boot
# Pre-stage-3 the boot partition is under /media rather than /boot. Detected by
# answers.txt, which exists on every platform -- config.txt is Pi-only.
for _b in /media/*; do
    [ -f "$_b/answers.txt" ] && [ ! -f /boot/answers.txt ] && BOOTDIR=$_b
done
USERCFG="$BOOTDIR/usercfg.txt"

boot_get() { sed -n "s/^$1=//p" "$USERCFG" 2>/dev/null | tail -n1; }
boot_set() {  # <key> <value|"">   empty value removes the line
    [ -f "$USERCFG" ] || { ui_msg "No $USERCFG on this system."; return 1; }
    mount -o remount,rw "$BOOTDIR" 2>/dev/null || true
    sed -i "/^$1=/d" "$USERCFG"
    [ -n "$2" ] && printf '%s=%s\n' "$1" "$2" >> "$USERCFG"
    sync
}

screen_boot() {
    while :; do
        _c=$(ui_menu "Boot and display" \
"Firmware settings, written to usercfg.txt so an Alpine upgrade cannot
overwrite them. All of these need a reboot.

  gpu_mem      $(boot_get gpu_mem || echo '(default 64)')
  hdmi_drive   $(boot_get hdmi_drive || echo '(unset)')
  overscan     $(boot_get disable_overscan || echo '(unset)')" \
            gpu    "GPU memory split" \
            hdmi   "HDMI audio (hdmi_drive)" \
            over   "Overscan -- black border round the screen" \
            uart   "Serial console on the GPIO header" \
            edit   "Open usercfg.txt in an editor" \
            back   "Back") || return 0
        case "$_c" in
            gpu)
                _v=$(ui_menu "GPU memory" \
"How much RAM is reserved for the GPU, before Linux sees any of it. On a
512 MB board this is real memory you are giving away.

DO NOT SET 16. At exactly 16 the firmware switches to start_cd.elf, which the
Alpine tarball does not ship -- the board then halts before HDMI comes up and
looks completely dead. 32 is the lowest safe value." \
                    32 "32 MB -- lowest safe value, best for a headless or light desktop" \
                    64 "64 MB -- the default" \
                    128 "128 MB -- only if you are doing video" \
                    back "Back") || continue
                case "$_v" in 32|64|128) boot_set gpu_mem "$_v" && ui_msg "gpu_mem=$_v. Reboot to apply." ;; esac ;;
            hdmi)
                if ui_yesno "Force HDMI signalling so sound goes out of the HDMI port?

This sets hdmi_drive=2. It is what carries audio over HDMI -- but on a display
connected through a DVI adapter it can blank the screen, because DVI has no
audio and some adapters refuse the signal."; then
                    boot_set hdmi_drive 2 && ui_msg "hdmi_drive=2. Reboot to apply."
                else
                    boot_set hdmi_drive "" && ui_msg "hdmi_drive removed. Reboot to apply."
                fi ;;
            over)
                if ui_yesno "Disable overscan?

Overscan is the black border some TVs need. Disabling it uses the whole
panel, which is right for a monitor and wrong for an older TV."; then
                    boot_set disable_overscan 1 && ui_msg "disable_overscan=1. Reboot to apply."
                else
                    boot_set disable_overscan "" && ui_msg "Overscan back to default. Reboot to apply."
                fi ;;
            uart)
                if ui_yesno "Enable the serial console on the GPIO header?

Harmless with nothing attached, and the only way to see early boot messages
if the board stops before userspace."; then
                    boot_set enable_uart 1 && ui_msg "enable_uart=1. Reboot to apply."
                else
                    boot_set enable_uart "" && ui_msg "enable_uart removed. Reboot to apply."
                fi ;;
            edit)
                _e="${EDITOR:-$(have nano && echo nano || echo vi)}"
                mount -o remount,rw "$BOOTDIR" 2>/dev/null || true
                "$_e" "$USERCFG" || true; sync ;;
            *) return 0 ;;
        esac
    done
}

# ------------------------------------------------------------------ misc ----
screen_ssh() {
    have copal-ssh || { ui_msg "copal-ssh is not installed -- run stage 6."; return 0; }
    while :; do
        _c=$(ui_menu "SSH" "$(copal-ssh status 2>&1)" \
             pwon  "Allow password logins" \
             pwoff "Keys only (refuses if no key is installed)" \
             rooton  "Allow root over SSH, by key only" \
             rootoff "Refuse root over SSH" \
             back  "Back") || return 0
        case "$_c" in
            pwon)   ui_msg "$(copal-ssh password on 2>&1)" ;;
            pwoff)  ui_msg "$(copal-ssh password off 2>&1)" ;;
            rooton) ui_msg "$(copal-ssh root on 2>&1)" ;;
            rootoff) ui_msg "$(copal-ssh root off 2>&1)" ;;
            *) return 0 ;;
        esac
    done
}

screen_storage() {
    ui_msg "Storage

$(df -h / /boot 2>/dev/null)

Memory
$(free -m 2>/dev/null | head -2)

If the root partition does not fill the card, stage 8 of the installer grows
it into the free space -- non-destructively, on a mounted root:
    doas copal        and choose 8"
}

screen_about() {
    ui_msg "Copal Linux

  host       : $(hostname)
  kernel     : $(uname -sr)
  arch       : $(apk --print-arch 2>/dev/null || uname -m)
  root fs    : $(awk '$2 == "/" { print $3 }' /proc/mounts)
  uptime     : $(uptime 2>/dev/null | sed 's/^ *//')
  memory     : $(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d MB total, %d MB free", t/1024, a/1024}' /proc/meminfo)
  users      : $(human_users | tr '\n' ' ')

  installer  : doas copal
  settings   : doas copal-config"
}

# A diskless system rebuilds / from the apkovl at every boot, so a change to
# /etc that is not committed is a change that disappears. Saying so once, at
# the moment of the change, is worth more than a note in a README.
screen_commit_hint() {
    [ "$(awk '$2 == "/" { print $3 }' /proc/mounts)" = tmpfs ] || return 0
    if ui_yesno "This system is running diskless: / is a tmpfs rebuilt at every
boot, so that change is currently only in RAM.

Save it now with 'lbu commit -d'?"; then
        if lbu commit -d >/dev/null 2>&1; then ui_msg "Saved."
        else ui_msg "lbu commit failed. Run it by hand and read the error."; fi
    fi
}

# ------------------------------------------------------------------ main ----
while :; do
    choice=$(ui_menu "Copal settings" \
        "$(hostname) -- $(apk --print-arch 2>/dev/null || uname -m)" \
        users    "Users and groups -- add, remove, permissions" \
        hostname "Hostname" \
        timezone "Timezone" \
        keymap   "Keyboard layout" \
        ssh      "SSH -- who may log in remotely, and how" \
        services "Services -- what runs, and what starts at boot" \
        boot     "Boot and display -- GPU memory, HDMI audio, overscan" \
        storage  "Storage and memory" \
        software "Install software (Copal Center)" \
        about    "About this system" \
        quit     "Quit") || break
    case "$choice" in
        users)    screen_users ;;
        hostname) screen_hostname ;;
        timezone) screen_timezone ;;
        keymap)   screen_keymap ;;
        ssh)      screen_ssh ;;
        services) screen_services ;;
        boot)     screen_boot ;;
        storage)  screen_storage ;;
        software) have copal-center && copal-center || ui_msg "copal-center is not installed." ;;
        about)    screen_about ;;
        *)        break ;;
    esac
done
exit 0
COPALCONFIG
    chmod 0755 /usr/local/bin/copal-config

    # ----------------------------------------------------------------------
    # The desktop splash.
    #
    # i3 starts as a blank rectangle that ignores you, and a cheat sheet you
    # have to summon is a cheat sheet you have to remember exists. Drawing the
    # bindings straight onto the root window costs nothing at runtime -- it is
    # one image, painted once -- and it is visible in exactly the situation
    # where you need it, which is when no window is open.
    say "Installing /usr/local/bin/copal-splash"
    cat > /usr/local/bin/copal-splash <<'COPALSPLASH'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-splash -- render ~/.config/i3/keys.txt onto the root window.
#
# Regenerates only when the key list is newer than the image, so this costs
# nothing on a normal login. ImageMagick and feh are both optional: without
# them the desktop is a plain colour, which is what it was before.
set -eu
KEYS="$HOME/.config/i3/keys.txt"
OUT="$HOME/.cache/copal-splash.png"
BG='#1a1b26'
FG='#a9b1d6'
have() { command -v "$1" >/dev/null 2>&1; }

mkdir -p "$(dirname "$OUT")"

# Screen size, if X will tell us. The Pi Zero's HDMI output is whatever the
# monitor asked for, so this is not a fixed number.
GEOM=$(xrandr 2>/dev/null | awk '/\*/ {print $1; exit}') || true
case "${GEOM:-}" in
    [0-9]*x[0-9]*) : ;;
    *) GEOM=1280x720 ;;
esac

# ImageMagick 7 installs both names; 6 only the first. Either will do.
IM=""
have magick  && IM=magick
[ -n "$IM" ] || { have convert && IM=convert; }

# Regenerate only when the key list has actually changed. Two separate tests
# rather than one '-o': the -o form is not portable and busybox test has been
# known to get the precedence wrong when combined with '!'.
NEED=no
[ -f "$OUT" ] || NEED=yes
[ "$KEYS" -nt "$OUT" ] 2>/dev/null && NEED=yes

if [ -n "$IM" ] && [ "$NEED" = yes ] && [ -f "$KEYS" ]; then
    # Bindings and group headings only. The explanatory prose belongs in the
    # scrollable window; a wallpaper you read at a glance wants the table.
    # Measured: this comes to 35 lines, which fits 720p at pointsize 14 with
    # room to spare. Adding a group to keys.txt is free; adding more than
    # about six bindings will start to run off the bottom.
    #
    # The filter takes group headings (a capital in column 2) and any line
    # naming a chord. 'Super' is not enough on its own any more: the launcher
    # answers to Alt+Space, and the app menu to a right-click on the desktop,
    # and a wallpaper that lists neither is a wallpaper that hides the two
    # easiest ways in.
    BODY=$(sed -n '/^ START SOMETHING/,/^ IF SOMETHING/p' "$KEYS" \
           | sed '$d' | awk '/^ [A-Z]/ || /Super \+/ || /Alt \+/ || /Right-click/')
    [ -n "$BODY" ] || BODY=$(cat "$KEYS")
    # A named font may not resolve without fontconfig knowing it, and a
    # failed -font aborts the whole command -- so try the nice one, then let
    # ImageMagick choose. Either way a failure just leaves the plain colour.
    for _f in "DejaVu Sans Mono" ""; do
        if [ -n "$_f" ]; then set -- -font "$_f"; else set --; fi
        if "$IM" -size "$GEOM" "xc:$BG" "$@" \
              -pointsize 14 -fill "$FG" -annotate +40+50 "$BODY" \
              -pointsize 12 -fill '#565f89' \
              -annotate +40-28 'Super + /  keys    Super + Z  menu    Super + C  copy    Super + V  paste    Super + Shift + G  guides' \
              "$OUT" 2>/dev/null; then
            break
        fi
        rm -f "$OUT"
    done
fi

if [ -f "$OUT" ] && have feh; then
    exec feh --no-fehbg --bg-scale "$OUT"
fi
have xsetroot && exec xsetroot -solid "$BG"
COPALSPLASH
    chmod 0755 /usr/local/bin/copal-splash

    # ----------------------------------------------------------------------
    # copal-gpu -- is the display accelerated, and if not, where did it stop?
    #
    # This exists because "the desktop feels slow" is a symptom with four
    # completely different causes and no way to tell them apart by looking:
    # the host may not have offered acceleration at all, the kernel may not
    # have bound the device, X may have picked the wrong driver, or mesa may
    # be falling back to software while everything else looks correct. Each
    # of those is visible somewhere in /sys, dmesg or a log; none of them is
    # visible on screen. So the report is four lines, one per layer, and the
    # first "no" going down the list is the answer.
    #
    # Deliberately readable with no desktop running and no packages beyond
    # busybox. The X half is read out of the log rather than by asking the
    # running server, so it works over ssh and after the session has exited.
    say "Installing /usr/local/bin/copal-gpu"
    cat > /usr/local/bin/copal-gpu <<'COPALGPU'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-gpu -- report the display stack, layer by layer, and say what is wrong.
#
# Exit status is the verdict, so this is usable in a script:
#   0  accelerated -- VirGL offered, taken, and X is using it
#   1  not accelerated -- working, but drawing on the CPU
#   2  cannot tell yet -- usually means X has not run since boot
set -u
have() { command -v "$1" >/dev/null 2>&1; }
row()  { printf '  %-14s %s\n' "$1" "$2"; }

VERDICT=0
WHY=""
# Only the first cause found is reported. A stack that failed at the kernel
# will also look wrong at every layer above it, and four complaints about one
# fault is how a report stops being read.
blame() { [ -n "$WHY" ] && return 0; WHY="$1"; VERDICT="$2"; return 0; }

echo "Display stack"

# ---- 1. the device the kernel found ----------------------------------------
# Every card, not just the first: virtio-ramfb-gl can present as two, and
# which one X lands on is exactly the sort of thing worth seeing.
CARDS=""
for _c in /sys/class/drm/card[0-9]*; do
    [ -d "$_c" ] || continue
    _n=$(basename "$_c")
    # card0-Virtual-1 is a connector on card0, not a second card. Matched on
    # the basename, not the path: a hyphen anywhere in the mount point above
    # /sys would otherwise make every card look like a connector.
    case "$_n" in *-*) continue ;; esac
    _drv=$(sed -n 's/^DRIVER=//p' "$_c/device/uevent" 2>/dev/null)
    [ -n "$_drv" ] || _drv=$(basename "$(readlink -f "$_c/device/driver" 2>/dev/null)" 2>/dev/null)
    [ -n "$_drv" ] || _drv="unknown"
    CARDS="$CARDS $_n:$_drv"
    row "${_n}" "$_drv"
done
if [ -z "$CARDS" ]; then
    row "kernel" "no DRM device at all"
    blame "The kernel found no KMS device. X can only use fbdev here, which is
the slow path. On a Pi that is normal and expected." 1
fi
# simpledrm is the ramfb half of virtio-ramfb-gl, and seeing it ALONE is
# informative rather than fatal: it means the firmware framebuffer is on
# screen and the virtio-gpu driver never took over.
case "$CARDS" in
    *virtio_gpu*) : ;;
    *simpledrm*|*simplefb*)
        blame "Only the firmware framebuffer is present -- the virtio-gpu driver
did not take over. The display works but nothing is accelerated." 1 ;;
esac

# ---- 2. did the host offer VirGL ----------------------------------------
# The virtio_gpu driver prints its negotiated feature bits at bind time.
# '+virgl' means the host agreed to render 3D; '-virgl' means it did not, and
# no amount of guest configuration will change that -- it is a host decision.
VIRGL=unknown
if have dmesg; then
    _f=$(dmesg 2>/dev/null | sed -n 's/.*\[drm\] features: //p' | tail -1)
    case "$_f" in
        *"+virgl"*) VIRGL=yes; row "3D (VirGL)" "yes -- host offered it ($_f)" ;;
        *"-virgl"*) VIRGL=no;  row "3D (VirGL)" "NO -- host did not offer it ($_f)"
                    blame "The host is not offering 3D. On UTM this is decided by the
display device, so it cannot be fixed from in here: re-create the machine and
let it take the default (virtio-ramfb-gl). See 'When the display is slow' in
the handbook." 1 ;;
        *) row "3D (VirGL)" "cannot tell -- no feature line in dmesg"
           # Not a verdict on its own: the ring buffer may simply have wrapped.
           ;;
    esac
else
    row "3D (VirGL)" "cannot tell -- no dmesg"
fi

# ---- 3. which compositor or server, and what it is drawing with ------------
#
# THE WAYLAND HALF COMES FIRST, because on this system it is the more likely
# answer and because the X half cannot see it at all. Hyprland never opens an
# X server, so a machine running the Wayland desktop has no Xorg.0.log and an
# X-only report says "cannot tell yet" on a desktop that is running perfectly
# well in front of you. That was this script's first real bug, found by
# running it against a live guest.
#
# aquamarine -- Hyprland's backend -- names the renderer it got in its log,
# and that one line is the whole answer:
#
#     Renderer: llvmpipe (LLVM 22.1.3, 128 bits)   -> software, drawing on CPU
#     Renderer: virgl (Apple M2)                   -> the host's GPU
#
# There is no glamor and no X driver in this path: the compositor talks to
# KMS and EGL itself, so the renderer line replaces both rows.
HLOG=$(ls -t "${XDG_RUNTIME_DIR:-/tmp}"/hypr/*/hyprland.log \
              /tmp/xdg-runtime-*/hypr/*/hyprland.log \
              /run/user/*/hypr/*/hyprland.log 2>/dev/null | head -1)
if [ -n "$HLOG" ]; then
    row "compositor" "Hyprland (Wayland)  ($HLOG)"
    _r=$(sed -n 's/.*Renderer: //p' "$HLOG" | tail -1)
    case "$_r" in
        "") row "renderer" "cannot tell -- no Renderer line in the log" ;;
        *llvmpipe*|*softpipe*|*swrast*)
            row "renderer" "$_r -- SOFTWARE, drawing on the CPU"
            blame "Hyprland is compositing in software. Every frame is drawn by the
CPU, which is what a slow desktop feels like. This is decided by the display
device the host offers, not by anything in here: re-create the machine and let
it take the default (virtio-ramfb-gl). See 'When the display is slow' in the
handbook." 1 ;;
        *) row "renderer" "$_r -- on the GPU" ;;
    esac
    echo
    case "$VERDICT" in
        0) echo "Accelerated. The drawing is happening on the host's GPU." ;;
        1) echo "NOT accelerated -- working, but drawing on the CPU."; echo; echo "$WHY" ;;
        2) echo "Cannot tell yet."; echo; echo "$WHY" ;;
    esac
    exit "$VERDICT"
fi

# ---- 3b. the X half: which driver X chose ---------------------------------
# Read from the log rather than from the running server, so this answers over
# ssh and after the session has exited.
XLOG=""
for _l in /var/log/Xorg.0.log "$HOME/.local/share/xorg/Xorg.0.log"; do
    [ -f "$_l" ] && XLOG="$_l"
done
if [ -z "$XLOG" ]; then
    row "X driver" "cannot tell -- X has not run yet"
    row "acceleration" "cannot tell -- X has not run yet"
    blame "Start the desktop and run this again: the X half of the answer does
not exist until X has written a log." 2
else
    if grep -q 'modesetting' "$XLOG" 2>/dev/null; then
        row "X driver" "modesetting  ($XLOG)"
    elif grep -q 'FBDEV\|fbdev' "$XLOG" 2>/dev/null; then
        row "X driver" "fbdev -- THE SLOW ONE  ($XLOG)"
        blame "X is on fbdev, which draws every pixel twice through the kernel's
framebuffer emulation. Re-run stage 4; in a guest it now installs the
modesetting driver instead." 1
    else
        row "X driver" "unrecognised  ($XLOG)"
    fi

    # glamor is the accelerated path. Its absence is not always a failure --
    # the config asks for it, and X says plainly when it could not have it.
    if grep -qi 'glamor initialized\|Using glamor' "$XLOG" 2>/dev/null; then
        row "acceleration" "glamor -- drawing on the GPU"
    elif grep -qi 'glamor' "$XLOG" 2>/dev/null; then
        row "acceleration" "glamor asked for, not confirmed -- see the log"
        blame "glamor is configured but X did not confirm it started. Search the
log for 'glamor' and 'EGL'; the usual cause is a missing DRI driver
(apk add mesa-dri-gallium)." 1
    else
        row "acceleration" "none -- X is drawing on the CPU"
        blame "X has no acceleration. If mesa-dri-gallium is missing, that is
why: apk add mesa-dri-gallium and restart the desktop." 1
    fi
fi

# ---- 4. what mesa actually resolved to ------------------------------------
# The layer that lies most convincingly: everything above can be correct and
# mesa still quietly fall back to llvmpipe, which is software rendering with
# a hardware-sounding name. glxinfo is optional, so its absence is not a
# verdict either way.
if have glxinfo && [ -n "${DISPLAY:-}" ]; then
    _r=$(glxinfo -B 2>/dev/null | sed -n 's/^OpenGL renderer string: //p')
    case "$_r" in
        "")          row "OpenGL" "cannot tell -- glxinfo said nothing" ;;
        *llvmpipe*|*softpipe*|*swrast*)
            row "OpenGL" "$_r -- SOFTWARE rendering"
            blame "mesa resolved to a software renderer. Everything above it may
look right and the drawing still happens on the CPU." 1 ;;
        *) row "OpenGL" "$_r" ;;
    esac
elif have glxinfo; then
    row "OpenGL" "cannot tell -- no DISPLAY (run this inside the desktop)"
else
    row "OpenGL" "cannot tell -- glxinfo not installed (apk add mesa-demos)"
fi

echo
case "$VERDICT" in
    0) echo "Accelerated. The drawing is happening on the host's GPU." ;;
    1) echo "NOT accelerated -- working, but drawing on the CPU."; echo; echo "$WHY" ;;
    2) echo "Cannot tell yet."; echo; echo "$WHY" ;;
esac
exit "$VERDICT"
COPALGPU
    chmod 0755 /usr/local/bin/copal-gpu
    note "copal-gpu -- says whether the display is accelerated, and where it stopped"

    # The kernel half of that answer is knowable right now, and this is the
    # moment somebody is watching. Not the X half: X has not run yet, so
    # copal-gpu would exit 2, which is not worth printing an install-time
    # verdict about. Report only what is settled.
    if is_vm; then
        _feat=$(dmesg 2>/dev/null | sed -n 's/.*\[drm\] features: //p' | tail -1)
        case "$_feat" in
            *"+virgl"*) note "the host is offering 3D acceleration ($_feat)" ;;
            *"-virgl"*)
                warn "the host is NOT offering 3D acceleration ($_feat)"
                note "The desktop will work and draw on the CPU. To fix it on the"
                note "Mac, re-create the VM: utm/utm-vm.sh create picks a display"
                note "device with VirGL by default. 'copal-gpu' reports either way." ;;
            *)  note "cannot tell whether the host offers 3D -- run 'copal-gpu' once the desktop is up" ;;
        esac
    fi

    say "Writing ~/.config/i3/keys.txt"
    # This file is the single source of truth for the bindings: the login
    # window shows it, Super+/ shows it, and copal-splash renders it onto
    # the wallpaper. Change a binding, change it here, and all three follow.
    # Grouped and worded after Omarchy's keybinding guide -- the useful idea
    # there is that the guide is organised by INTENT (start something, move
    # something, arrange something) rather than by modifier key.
    cat > /tmp/keys.$$ <<'KEYS'
 ======================================================================
   Copal Linux -- key bindings
 ======================================================================
                                                     press q to close

 "Super" is the Windows key. It is the modifier for everything here.
 Show this list again at any time with   Super + /   or   Super + F1

 START SOMETHING
   Super + Space        run a program (Alt + Space and Ctrl + Space do the
                        same -- see the UTM note below) -- type a few
                        letters, Enter.
                        Lists EVERY executable on your PATH, so anything
                        you install shows up here automatically.
   Alt + Space          the same launcher. Alt is Option on a Mac keyboard,
                        and macOS reserves nothing on it, so this one
                        always reaches the machine.
   Super + D            the same thing (dmenu)
   Super + Z            the app menu: everything installed, sorted into
                        categories. Its Install branch lists the programs
                        you have NOT installed yet and installs them.
   Right-click          the same app menu, opened where you clicked. The
     on the desktop     desktop is the empty background -- any part of the
                        screen with no window over it.
   Super + A            the Mint-style menu: favourites on the left, the
                        programs by category with their icons, and a search
                        box. Right-click a program to make it a favourite.
   Super + Shift + C    the Copal Center: one window listing every program
                        in the catalogue, installed or not, with a button
                        to run it or fetch it.
   Super + ,            system settings: add users and choose their
                        groups, hostname, timezone, services, SSH, and
                        the boot options. It asks doas for root itself.
   Super + Return       a terminal
   Super + E            file manager
   Super + T            task manager (htop)
   Super + Shift + G    the guides -- how to actually use what is here,
                        starting with Gopher and Gemini
   Super + Shift + N    the editor (nvim). Press SPACE in it and wait a
                        moment for its own key menu.
   Super + Shift + M    music -- cmus, or mpv on ~/Music if cmus is not
                        installed
   Super + Shift + Y    queue the video URL on the clipboard (ytq).
                        'ytq run' downloads; touch ~/.config/ytq/auto
                        and it starts by itself.
   Super + Shift + A    the Static Stream Workspace: a Browser over the
                        folder ytq archives into, the queue itself on Q,
                        and Play, Verify, Export and Text on one key --
                        and X over a folder to export every capture in it.
   Super + Shift + B    the camera -- birdshot, which stage 7 built from
                        ~/code, or whatever CAMERA= names in ~/.profile.
                        Also the Camera entry at the top of the menu.
   Super + Shift + W    the wallpaper picker, with thumbnails. Also in the
                        menu under Style, along with a way to download
                        twenty more.
   Super + Shift + T    the theme picker (tokyo-night, antiquity)
   Super + Alt + Space  the app menu, opened on its System side; and
   Super + Ctrl + Space the wallpaper picker. These are Omarchy's chords for
                        the same two things, kept so hands that learned
                        them there land somewhere.
   Super + Ctrl + A     volume (alsamixer)
   Super + Ctrl + T     what the machine is doing (btop, or htop)
   Super + Shift + D    lay the desk out: the editor and a terminal on
                        workspace 2, a Claude session in ~/code on 3, the
                        browser on 5, and you are left on an empty 1.
                        'copal-desk --list' shows the layouts.

 COPY AND PASTE -- THE SAME KEYS EVERYWHERE
   Super + C            copy
   Super + X            cut
   Super + V            paste
   Super + Ctrl + V     the clipboard history -- the last hundred things
                        you copied. Pick one and it goes on the clipboard,
                        ready for Super + V.

   Everywhere means everywhere: the terminal too. Normally a terminal needs
   Ctrl + Shift + C because Ctrl + C has meant "interrupt" since before X
   existed, and every other program needs Ctrl + C -- so you have to know
   which kind of window you are in before you can copy out of it. These keys
   remove that. copal-clip looks at what has focus and sends whichever chord
   that window actually wants.

   AND CAPS LOCK IS A SECOND SUPER ON THIS MACHINE. So this is CapsLock + C
   and CapsLock + V, under your left little finger, which is as close to a
   Mac's Cmd + C and Cmd + V as a PC keyboard gets. If you came from a Mac,
   these four are the reason to use this desktop rather than tolerate it.

   The one exception is cut in a terminal: the text on the screen is not
   yours to remove, so Super + X copies there and does not delete.

 WINDOWS
   Super + Shift + Q    close the focused window
   Super + H J K L      move focus left / down / up / right
   Super + arrows       the same, if you prefer arrows
   Super + Shift + HJKL move the window itself
   Super + F            fullscreen on / off
   Super + R            resize mode: h j k l or arrows, Enter to finish
   Super + Shift+Space  float this window (drag with Super + mouse)
   Super + Tab          switch focus between floating and tiled

 HOW WINDOWS ARRANGE THEMSELVES
   New windows split the space with the focused one. Nothing overlaps.
   That is the point: on a board with no graphics acceleration, every
   pixel is drawn by the CPU, so never redrawing a hidden window is a
   speed decision as much as a tidiness one.
   Super + B            next window opens to the RIGHT
   Super + Shift + V    next window opens BELOW  (Super + V is paste now)
   Super + W            tabbed layout -- one at a time, tabs on top
   Super + S            stacked layout -- one at a time, titles listed
   Super + G            back to a plain split

 WORKSPACES  (virtual desktops)
   Super + 1..5         switch to workspace 1-5
   Super + Shift + 1..5 send the focused window to that workspace
   Super + Ctrl + Left  previous workspace
   Super + Ctrl + Right next workspace
   Five, not ten: on 512 MB you run out of memory long before you run
   out of workspaces.

 SESSION
   Super + Shift + P    shut the machine down -- asks first, closes the
                        session, syncs the card, powers off. This is the
                        one to end the day with. From a shell it is
                        "copal-halt"; "copal-halt reboot" restarts.
   Super + Shift + Del  restart
   Super + Shift + R    reload i3 after editing its config
   Super + Shift + E    log out of i3 (back to the console) -- this leaves
                        the machine RUNNING. It is not a shutdown.
   Super + Shift + S    lock the screen, if i3lock is installed

 IF SOMETHING LOOKS WRONG
   The bar says "status_command process exited unexpectedly":
       i3status -c ~/.config/i3status/config -n 1
   That prints the actual parse error, which the bar will not tell you.

 IF YOU ARE RUNNING THIS IN UTM ON A MAC
   The Mac's Command key arrives here as Super, so macOS claims some of the
   bindings above before this machine ever sees them. Spotlight on Cmd+Space
   is the one you meet first, and it swallows the launcher.

   PRESS CAPS LOCK INSTEAD OF SUPER AND NONE OF THIS APPLIES. Caps Lock is
   set up as a second Super key on this machine, and macOS reserves nothing
   on it, so CapsLock+W is "tabbed layout" and not "stop the virtual
   machine". Every binding above works from it, unchanged. It needs UTM told
   to pass the key through, once, on the Mac:
       defaults write com.utmapp.UTM IsCapsLockKey -bool true
   The Fn / globe key cannot do this job: macOS handles it in the keyboard
   driver, there is no USB HID code for it, and UTM has no support for it --
   it never reaches this machine in any form.

   If you press the real Super key anyway, the rest of this section applies.

   THREE OF THEM END THE SESSION, and nothing in this system can prevent
   it -- macOS takes the key before this machine is offered it, so i3 never
   sees it to ignore. A second binding gives you another way in; it does
   not disarm the first. Do not press these on a Mac host:

     Super + W          closes the VM window and stops the machine, with
                        no dialog if UTM's confirmation has been switched
                        off. The same as pulling the power, mid-write.
     Super + Q          quits UTM, and every VM running in it.
     Super + Shift + Q  logs out of macOS.

   EVERY binding in this file has a second one -- not just the ones macOS
   eats -- so you never have to remember which is which. Two rules:

     WHERE SUPER IS EATEN, PRESS CTRL+ALT INSTEAD.
     WHERE THE BINDING ALSO HAS CTRL IN IT, PRESS CTRL+ALT+SHIFT.

   The rest of the binding does not move. Some examples:

     Super + Space        ->  Alt + Space, Ctrl + Space, or
                              Ctrl + Alt + Space
     Super + Return       ->  Ctrl + Alt + Return
     Super + Z            ->  Ctrl + Alt + Z
     Super + Tab          ->  Ctrl + Alt + Tab
     Super + H            ->  Ctrl + Alt + H
     Super + W            ->  Ctrl + Alt + W
     Super + ,            ->  Ctrl + Alt + ,
     Super + /            ->  Ctrl + Alt + /
     Super + 1..5         ->  Ctrl + Alt + 1..5
     Super + Shift + Q    ->  Ctrl + Alt + Shift + Q
     Super + Shift + P    ->  Ctrl + Alt + Shift + P
     Super + Shift + 1..5 ->  Ctrl + Alt + Shift + 1..5
     Super + Ctrl + V     ->  Ctrl + Alt + Shift + V   (the Ctrl rule)
     Super + Ctrl + A     ->  Ctrl + Alt + Shift + A
     Super + Ctrl + T     ->  Ctrl + Alt + Shift + T
     Super + Ctrl + arrow ->  Ctrl + Alt + Shift + Left / Right

   Two bindings could not keep both rules at once, and gave way to the
   Ctrl ones above:
     move window left/right   Ctrl+Alt+Shift+H and +L, not the arrows
     split vertical           Ctrl+Alt+Shift+B, next to splith on B

   What macOS is doing with them, so the behaviour is not a mystery:
     Cmd + Space          Spotlight
     Cmd + Tab            application switcher
     Cmd + Shift + 3/4/5  screenshots
     Cmd + Shift + Q      log out of macOS
     Cmd + H              hide the front application
     Cmd + ,              application preferences -- UTM's own
     Cmd + W              close the UTM window -- STOPS THIS MACHINE
     Cmd + Q              quit UTM -- stops every machine
     Cmd + F1             mirror displays
     Ctrl + arrows        Mission Control, switch Mac desktop

   Or take the keys back on the Mac side, which is the better fix on a
   machine that is yours to configure:
     System Settings > Keyboard > Keyboard Shortcuts > Spotlight
       untick "Show Spotlight search" and Cmd+Space is free for good
     UTM > Settings > Input
       "Capture input automatically when window is focused" hands more of
       the keyboard to the guest while its window has focus
     System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > +
       Application UTM, menu title "Close", shortcut Cmd+Shift+W. This is
       the only thing that genuinely takes Cmd+W away from UTM.
     On the Mac, to get the confirmation dialog back:
       defaults write com.utmapp.UTM NoQuitConfirmation -bool false

 KEEPING IT UP TO DATE
   copal                 the stage menu -- the same one the installer used
   copal --check         is there a newer Copal?  changes nothing
   copal -U              update to it. Fetches one file, checks it parses,
                         keeps the old copy as copal-init.sh.bak. It changes
                         what the stages WILL do -- re-run the ones you care
                         about afterwards, stage 1 being the cheap one.
   copal -U v1.2         or any branch, tag or commit -- how you pin a
                         version, or go back to one that worked.

 FILES
   ~/.config/i3/config          bindings and colours
   ~/.config/i3status/config    what the bar shows
   ~/.config/i3/keys.txt        this file -- also drawn on the wallpaper

 To stop this appearing at login, delete the line in ~/.config/i3/config
 that begins:   exec --no-startup-id $helpcmd
KEYS
    # ----------------------------------------------------------------------
    # Guides.
    #
    # A directory of plain-text documents and one command to read them. This
    # is the nested layer the menu was missing: the app menu can tell you a
    # program exists, but not what to type once it opens, and a Gopher client
    # is useless if you do not know a single Gopher address.
    #
    # Plain text on purpose. It is readable over serial, over ssh, from the
    # console when X will not start, and by 'less' on a machine with 512 MB.
    # Drop another .txt in the directory and it appears in the menu -- no
    # code change, same rule as the catalogue.
    say "Writing the guides"
    mkdir -p /usr/local/share/copal/guides
    cp /tmp/keys.$$ /usr/local/share/copal/guides/i3-keys.txt

    cat > /usr/local/share/copal/guides/small-web.txt <<'GUIDE'
 THE SMALL WEB -- Gopher and Gemini on this machine
 ======================================================================

 This is the one thing a Pi Zero does not do badly. Gopher and Gemini
 serve text without scripts, tracking or layout, so a 1 GHz core draws
 a page as fast as any machine you own. Nothing here is a compromise
 for slow hardware -- it is simply the right tool on the right box.

 WHAT THEY ARE
   Gopher (1991)  Menus of numbered items. You pick a number, you get
                  a document or another menu. Still running, still
                  maintained, and a lot of it is people's notebooks.
   Gemini (2019)  Deliberately between gopher and the web. One page,
                  one request, TLS required, no cookies, no scripts,
                  no inline images, and a markup with six line types.

 START HERE
   gopher://gopher.floodgap.com        the main gopher hub
   gopher://gopher.floodgap.com/1/v2   Veronica-2, the gopher search
   gemini://geminiprotocol.net         the protocol's own capsule
   gemini://kennedy.gemi.dev           Kennedy, a gemini search engine
   gemini://warmedal.se/~antenna       Antenna, an aggregator of feeds

 WHICH CLIENT
   bombadillo   Gopher AND Gemini AND finger in one terminal browser.
                If you install one thing, install this.
   amfora       Gemini only, and the most comfortable to read in.
   clagrange    Lagrange in a terminal.
   lagrange     Lagrange in a real window. It works here, but it is
                SDL2 and it is the heaviest thing in this guide.
   gmnlm        Gemini, line mode -- the ed of browsers.
   gmni         Fetch one Gemini page and print it. Gemini's curl.
   gemget       Download from Gemini; mirrors a whole capsule.

   You may already have a Gopher client: lynx and elinks both speak
   gopher:// with no extra software and no configuration. links does
   NOT, so do not waste time looking for the option.

 BOMBADILLO IN SIXTY SECONDS
   bombadillo gopher://gopher.floodgap.com

   j / k          scroll down / up
   0-9            follow one of the first ten links (0 means 10)
   b  or  h       back
   f  or  l       forward
   SPACE          command mode -- then type one of:
                    a URL                 go there
                    a number              follow that link
                    help                  the full manual
                    add . My bookmark     bookmark this page
                    quit                  leave
   Shift + B      show the bookmarks bar
   q              quit

 SERVING YOUR OWN
   gmnisrv is packaged and will serve a Gemini capsule off this Pi.
   Its config lives at /etc/gmnisrv.ini and it needs a TLS certificate,
   which it will generate for you on first run. Gemini requires TLS
   even for a public page -- that is not optional in the protocol.

 IN EDGE/TESTING ONLY
   Not installed by the menu, because mixing Alpine branches can drag
   in a newer libc than the rest of the system expects. If you want one
   anyway, the pattern is:

     apk add --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing sacc

   sacc, cgo      other gopher browsers for the terminal
   castor         a GTK Gemini window
   geomyidae      a gopher SERVER, if you would rather host gopher
   agate, gmid    other gemini servers

 SEE ALSO
   copal-guide i3-keys        the window manager key bindings
GUIDE

    # ----------------------------------------------------------------------
    # The widgets guide, written because "how do I configure the widgets" has
    # no answer anywhere else: the theme's widgets are QML for a shell that is
    # not installed, and waybar's own documentation is a man page organised by
    # module rather than by what somebody wants to change.
    cat > /usr/local/share/copal/guides/widgets.txt <<'GUIDE'
 ======================================================================
   THE BAR AND ITS WIDGETS -- reading it, changing it, adding to it
 ======================================================================

 WHAT THE BAR IS, AND WHY IT IS NOT THE ONE IN THE SCREENSHOTS

   Linux Antiquity's bar is 99 QML files for quickshell, and no Alpine
   repository packages quickshell. So Copal draws the bar with waybar
   instead, in the same palette, carrying the same information. The
   theme's own documentation names waybar as the alternative, so this is
   the supported substitution rather than an improvisation.

   copal-bar is the switch. It runs quickshell if a quickshell ever
   appears on PATH and waybar otherwise, so the day Alpine packages one
   you get the real bar and nothing here has to be edited.

   The QML is installed even though nothing reads it yet:
       ~/.config/quickshell/

 THE TWO FILES

   ~/.config/waybar/config      what is on the bar, and what each part does
   ~/.config/waybar/style.css   what it looks like

   Nothing regenerates either one after the install. They are yours.
   Both have comments in them; the config is JSON-with-comments, which is
   what waybar reads and the one place in this system that gets them.

 SEEING A CHANGE

   pkill waybar; copal-bar &

   waybar re-reads nothing on its own -- there is no reload signal for the
   config. If the bar does not come back:

       waybar -l debug

   which names the module that stopped it. Run it from a terminal INSIDE
   the desktop, not over ssh: waybar is a Wayland client and needs the
   session's WAYLAND_DISPLAY and its D-Bus address.

 WHAT IS ON IT NOW

   Left     the menu button, workspaces 1-5, the current submap, the
            window list
   Centre   nothing, so the window titles can take the width
   Right    temperature, cpu, memory, disk (small, one letter each),
            hostname, network, volume, battery, the system tray, and
            the time in the corner (and weather, which is off -- see below)

 MOVING THINGS

   The three lists at the top of the config are the layout, and moving a
   name between them moves the thing on screen:

       "modules-left":   ["custom/menu", "hyprland/workspaces", ...]
       "modules-right":  ["temperature", "cpu", "memory", ..., "clock"]

   There is no modules-center; add one to pin something to the middle.

   Delete a name from all three and that widget is gone. The block that
   configures it lower down can stay; an unlisted module is not drawn.

 THE ONES MOST WORTH CHANGING

   THE CLOCK. "format" is strftime:
       "format": "{:%a %d %b  %H:%M}"      Wed 26 Aug  14:40
       "format": "{:%H:%M}"                14:40
       "format": "{:%I:%M %p}"             02:40 PM

   THE WEATHER IS OFF. Its block is in the config, but its name is in no
   list, so it is not drawn and it asks nobody anything. It was on, and
   it was turned off because of what it does: it asks wttr.in, which
   geolocates the caller's IP -- so every half hour the machine told a
   third party where it was, to learn the weather. On a VM that is chatter
   for nothing. Nothing else in the bar contacts anything.

   To turn it on, add "custom/weather" to modules-right. To pin it to a
   place instead of your IP, put the city in the URL:

       "exec": "curl -sS --max-time 8 'https://wttr.in/Lisbon?format=%c%t'"

   %c is the condition glyph, %t the temperature. %f gives Fahrenheit,
   %C spells the condition out. The full list: curl wttr.in/:help

   THE INTERVAL IS 1800 SECONDS ON PURPOSE. Every tick is a request from
   this machine to somebody else's server. A weather widget on a
   one-minute interval phones out 1440 times a day for a number that
   changes hourly.

   THE TEMPERATURE. This is the one that shows nothing on some machines,
   and it is not broken when it does. waybar reads a sensor file, and
   which one differs per board -- a Pi has thermal_zone0, a PC has
   whatever its chipset registered, and a VM usually has no sensor at all.
   With none found the module removes itself and the rest of the bar is
   untouched. To see whether this machine has one:

       ls /sys/class/thermal/thermal_zone*/temp

   If that lists something and the widget is still absent, name it:

       "temperature": { "hwmon-path": "/sys/class/thermal/thermal_zone0/temp" }

   THE WORKSPACE NUMBERS. All five are shown whether or not anything is on
   them, which is what persistent-workspaces does:

       "persistent-workspaces": { "*": 5 }

   Without it waybar draws only the workspaces that already have a window,
   so a fresh session shows a single "1" and Super+2 looks like it does
   nothing. Change the 5 if you want more.

   THE MENU BUTTON. Left-click opens copal-menu, right-click shuts down.
   The glyph is the "format" line, written as an escape so the file stays
   plain ASCII. It is static on purpose -- an "exec" here costs a whole CPU,
   see docs/visual-debugging-lab-report.md IV.C:

       "format": "\u2261"

 ADDING ONE OF YOUR OWN

   Any command that prints one line is a widget. This is the whole of it:

       "custom/uptime": {
         "format": "up {}",
         "interval": 60,
         "exec": "uptime | sed 's/.*up //; s/,.*//'"
       }

   Then put "custom/uptime" in one of the three lists, and give it a rule
   in style.css if you want it coloured -- the id is the module name with
   the slash turned into a dash:

       #custom-uptime { color: #fccf8a; }

   A widget that needs to react rather than poll can use "signal": N and
   be refreshed with  pkill -RTMIN+N waybar  instead of an interval.

 COLOURS

   style.css carries the theme's palette at the top of this file's
   comments. The ones you are most likely to want:

       #181818   the bar itself          #fccf8a   accent (gold)
       #d0daed   ordinary text           #87704f   accent, dimmed
       #333333   hover highlight         #ff723e   urgent

   One rule covers every readout, so adding a module does not mean adding
   CSS unless you want it to look different from the rest.

 THE WIDGETS ON THE WALLPAPER

   The big clock and the date sitting ON the desktop -- under your
   windows, not on the bar -- are the theme's "desktop widgets", and
   this is the part people go looking for after seeing the screenshots.

       copal-widgets --off        hide them
       copal-widgets --on         bring them back
       copal-widgets --status     what is running, and from where

   ~/.config/waybar/desktop.json      what is drawn, and where
   ~/.config/waybar/desktop.css       the type and the colour

   It is a SECOND waybar, on the bottom layer -- below every window, above
   the wallpaper, and click-through, so the desktop underneath still
   behaves like the desktop. One file holds both rows because waybar reads
   a JSON array as several bars: the clock is the first, the date the
   second. "margin-top" is what moves them down the screen. A weather
   line sat beside the date and is off for the reason given above; add
   "custom/weather" to that row's modules-center to have it back.
   copal-bar starts it beside the ordinary bar at login.

   Same rules as the bar for the rest: a widget is any command that prints
   one line, "interval" is how often it runs, and the id in the CSS is the
   module name with the slash turned into a dash.

 WHY THE THEME'S OWN WIDGETS LOOK BROKEN (THEY ARE NOT)

   Linux Antiquity's desktop widgets are quickshell, which Alpine does not
   package -- but that is only half the reason you have never seen them.
   The other half is true on Arch too, and it catches everybody:

   UPSTREAM SHIPS NO widgets.json. WidgetScreen.qml opens a transparent
   window per monitor and fills it from Config.widgets[<monitor name>],
   which is read from ~/.config/quickshell/widgets.json. That file does not
   exist in the repository. It is written by the shell's own settings
   window -- the sidebar, then Settings, then the Widgets tab, then "+"  --
   and until somebody clicks that, the model is empty and the desktop draws
   nothing at all. Nothing is broken; nothing was ever placed.

   So Copal places them for you:

       copal-widgets --seed

   which writes a clock -- centred, upper third -- for every monitor
   hyprctl reports, and leaves alone any monitor that already has widgets.
   copal-bar runs it at login. On a machine with no quickshell it is a
   small JSON file and nothing else; the day a quickshell appears, the real
   widgets are already on the desktop.

   THE WEATHER ONE IS NOT SEEDED UNTIL YOU HAVE A KEY. It draws from
   OpenWeatherMap, which needs an account, and an unkeyed weather widget is
   an empty square. Put the key and your city in the theme's settings and
   run --seed again. The wallpaper weather above asks wttr.in instead,
   which needs no key but does geolocate by IP -- which is why it is off.

   ONLY TWO OF THE THEME'S WIDGETS ARE REAL, whatever the file names
   suggest: Clock and Weather. CPUTemperatureWidget.qml exists but is an
   unfinished sketch -- a red rectangle -- and RAM, GPU and Date are
   commented out in Config.qml. Nothing here can switch them on.

 THE WALLPAPER IS NOT A WIDGET

   It has its own command, because it is not on the bar:

       copal-wallpaper --pick     choose one, with thumbnails
       copal-wallpaper --list     what is here and where it came from
       copal-wallpaper --fetch    download diinki's published set

   See 'copal-guide wallpapers'.
GUIDE

    cat > /usr/local/share/copal/guides/wallpapers.txt <<'GUIDE'
 ======================================================================
   WALLPAPERS -- choosing one, and getting more
 ======================================================================

 THE COMMAND

   copal-wallpaper --pick     choose one, with thumbnails
   copal-wallpaper --list     what is here, and where each came from
   copal-wallpaper set FILE   use a particular file
   copal-wallpaper --fetch    download diinki's published collection
   copal-wallpaper            paint the chosen one (what the session runs)

   The choice is remembered in ~/.config/copal/wallpaper -- one line, the
   path. Delete it and the theme's default comes back.

 THE PICKER

   On the Wayland desktop it is wofi with the pictures turned on: a list
   with a thumbnail beside each name, type to filter, Enter to set. On X
   it is feh's thumbnail grid, which is nicer -- a wall of pictures, click
   one. Neither is required; with no image-capable picker you still get a
   plain list of names that still works.

   Thumbnails are made once, at 240x135, and kept in
   ~/.cache/copal/wallpaper-thumbs. That directory can be deleted at any
   time; it rebuilds. The reason it exists is that the source images are
   4K PNGs of twenty megabytes, and handing twenty of those to a launcher
   on a machine with 512 MB of RAM ends the session rather than the menu.

 WHAT IS ALREADY HERE

   Three, in ~/.config/hypr/wallpapers_bundled/ -- carnation_collage,
   georges_riom_collage and oc_the_blackboard. They arrive with the Linux
   Antiquity theme, which is MIT-licensed, and they are what the desktop
   looks like out of the box.

 GETTING THE REST

   The author publishes about twenty at github.com/diinki/wallpapers,
   including the three above. copal-wallpaper --fetch downloads them:

       copal-wallpaper --fetch                 all of them, ~240 MB
       copal-wallpaper --fetch HIRAETH         just that one
       copal-wallpaper --fetch kitty aquarium  anything matching either

   Matching is case-insensitive and on any part of the name, so you do not
   have to type STRAY_KITTY_CLUB-teal.png to get it.

   THEY ARE DOWNSCALED ON ARRIVAL, to this screen, and the original is
   discarded. A 4K PNG is between five and twenty-two megabytes; the same
   picture at 1280x800 is about one. On a Pi that is the difference
   between a wallpaper and a machine that swaps. If you want the originals
   at full size, save them from the repository yourself -- this command is
   not trying to be a download manager.

 THE LICENCE, WHICH IS WHY THIS IS A COMMAND AND NOT A STAGE

   That repository has NO LICENCE FILE. Its README says the wallpapers are
   published "in case any of you want to use them", which is the author
   inviting you to use them -- and is not a grant to redistribute them.

   So Copal does not ship them. They are not in the image, not in the
   repository, and not vendored the way the theme is (the theme IS MIT,
   which is why that one can be). What --fetch does is bring them to YOUR
   machine at YOUR request, which is the same act as saving them from that
   page in a browser.

   If you want to redistribute them -- put them in your own image, hand a
   card to somebody -- that is a question for the author, and his Discord
   and Ko-fi links are in that README. He also takes tips, which for
   twenty wallpapers and a desktop theme is not an unreasonable thing to
   consider.

 USING YOUR OWN

   Anything in ~/Pictures/wallpapers is offered by the picker: png, jpg,
   jpeg or webp. No subdirectories are searched -- one directory, so that
   a picture library dropped in there does not become the wallpaper menu.

 HOW IT IS PAINTED

   hyprpaper is what the theme uses and Alpine does not package it, so
   swaybg paints instead and hyprpaper is preferred automatically if it
   ever appears. swaybg has no IPC, so changing the wallpaper means
   replacing the process -- which is why setting one kills only the swaybg
   belonging to you and starts a new one.
GUIDE

    cat > /usr/local/share/copal/guides/cli-games.txt <<'GUIDE'
 GAMES IN A TERMINAL -- what is here and how to start it
 ======================================================================

 The menu lists the ones worth a menu entry. bsd-games alone installs
 eighteen commands, so most of them live here instead. All of these run
 in a terminal, which on this board is a feature: no OpenGL, no
 compositing, no swapping. They were written for machines slower than
 this one.

 BSD GAMES            apk add bsd-games   (all eighteen, one package)

   The famous ones
     adventure    Colossal Cave. The original text adventure, 1976.
                  "XYZZY" still works.
     hangman      hangman, against the system dictionary
     robots       escape the robots by making them collide
     snake        get the money, avoid yourself
     worm         the other snake
     atc          air traffic control. Genuinely hard.
     klondike     solitaire
     battlestar   a sci-fi text adventure, larger than it looks

   Card and board games
     cribbage     cribbage against the machine
     gofish       go fish
     gomoku       five in a row
     dab          dots and boxes
     drop4        four in a row

   The rest
     arithmetic   drills you on mental arithmetic
     sail         age-of-sail naval combat
     spirhunt     hunt something through a grid of space
     wump         hunt the wumpus
     caesar       not a game -- breaks Caesar ciphers

   Most have a man page: 'man robots', 'man atc'. atc especially --
   it is unplayable until you have read it, and excellent afterwards.

 ROGUELIKES
   nethack      the one. Deep beyond reason. 'nethack' to start.
   brogue       modern, far kinder to a newcomer, still a real game
   zangband     Angband variant. Long.

 INTERACTIVE FICTION
   frotz        a Z-machine interpreter -- it plays Infocom games and
                everything written since. It ships with no stories:
                  frotz story.z5
                The Interactive Fiction Archive has thousands, free and
                legal, and Zork I-III are freely distributed.

 CARDS AND PUZZLES
   ttysolitaire  solitaire, drawn with box characters

 CHESS
   gnuchess      the engine, playable on its own in a terminal
   xboard        a board for it, if X is running

 NOT GAMES BUT THE SAME SPIRIT
   asciiquarium  an aquarium
   cmatrix       the screen effect
   cbonsai       grows a bonsai tree, slowly
   sl            for when you type 'sl' instead of 'ls'
   fortune       a fortune. Pipe it: fortune | figlet
   figlet        big letters out of small ones

 WHAT IS NOT HERE, AND WILL NOT BE
   Alpine does not package Cataclysm-DDA, dungeon-crawl, ADOM, ToME4,
   moon-buggy, nsnake, ninvaders, bastet, vitetris or nbsdgames for
   armhf. moon-buggy, nsnake and nbsdgames exist in edge/testing:

     apk add --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing nsnake

   Anything needing OpenGL is a different problem -- see 'copal-guide i3-keys'
   for why this board renders on the CPU.

 SEE ALSO
   copal-guide small-web      gopher and gemini
   copal-guide i3-keys        the window manager key bindings
GUIDE

    cat > /usr/local/bin/copal-guide <<'COPALGUIDE'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# copal-guide [NAME]  -- read one of the plain-text guides, or list them all.
set -eu
DIR=/usr/local/share/copal/guides
have() { command -v "$1" >/dev/null 2>&1; }
if have less; then PAGE="less"; else PAGE="more"; fi

show() { exec $PAGE "$1"; }

if [ "$#" -ge 1 ]; then
    # Exact name first, then a substring, so 'guide small' finds small-web.
    if [ -f "$DIR/$1.txt" ]; then show "$DIR/$1.txt"; fi
    _hit=$(ls "$DIR"/*"$1"*.txt 2>/dev/null | head -n1 || true)
    [ -n "$_hit" ] && show "$_hit"
    echo "No guide called '$1'. Run 'copal-guide' with no arguments to list them." >&2
    exit 1
fi

# No argument: an index, then a choice. Each guide's first line is its title.
echo
echo "  Guides on this system"
echo "  ---------------------"
_n=0
for _f in "$DIR"/*.txt; do
    [ -f "$_f" ] || continue
    _n=$((_n + 1))
    # First line with letters in it -- skips a '=====' ruler.
    printf '  %2d) %-14s %s\n' "$_n" "$(basename "$_f" .txt)" \
           "$(awk 'NF && /[A-Za-z]/ {sub(/^ +/, ""); print; exit}' "$_f")"
done
if [ "$_n" = 0 ]; then echo "  (none installed)"; exit 0; fi
echo
printf '  Number, or Enter to quit: '
read -r _r || exit 0
case "${_r:-}" in
    ''|*[!0-9]*) exit 0 ;;
esac
_f=$(ls "$DIR"/*.txt 2>/dev/null | sed -n "${_r}p")
[ -n "$_f" ] && show "$_f"
exit 0
COPALGUIDE
    chmod 0755 /usr/local/bin/copal-guide

    # Into both homes, and only now delete the temporary copy -- the guides
    # directory above reads it too.
    install_home_file .config/i3/keys.txt /tmp/keys.$$; rm -f /tmp/keys.$$

    say "Writing ~/.config/i3status/config"
    cat > /tmp/i3status.$$ <<'I3S'
general {
        colors = true
        color_good = "#9ece6a"
        color_degraded = "#e0af68"
        color_bad = "#f7768e"
        interval = 5
}
order += "cpu_usage"
order += "memory"
order += "disk /"
order += "ethernet eth0"
order += "tztime local"

# One option per line. i3status does NOT accept ';' as a separator -- putting
# two options on one line makes it exit 1 at startup, and all i3bar reports is
# "status_command process exited unexpectedly".
cpu_usage {
        format = "cpu %usage"
}

memory {
        format = "mem %used/%total"
        threshold_degraded = "10%"
}

disk "/" {
        format = "sd %avail"
}

ethernet eth0 {
        format_up = "eth %ip"
        format_down = "eth down"
}

tztime local {
        format = "%Y-%m-%d %H:%M"
}
I3S
    # Prove it parses before shipping it. i3bar only ever reports
    # "status_command process exited unexpectedly", which says nothing useful.
    #
    # i3status has no "check and exit" mode: given a good config it runs
    # forever, printing a status line every interval. So the test is inverted
    # -- run it under a timeout and treat being killed as success. A bad
    # config makes it exit on its own, quickly, with the parse error.
    #
    # -s KILL, AND THAT IS THE WHOLE POINT OF THIS COMMENT. The first version
    # of this check sent the default SIGTERM and accepted 0 or 124. It cried
    # wolf on every single install:
    #
    #     warning: the generated i3status config does not parse (exit 1):
    #           i3status: exiting due to signal.
    #
    # i3status INSTALLS A SIGTERM HANDLER. Asked to stop, it says so and exits
    # 1 of its own accord -- so timeout has no timeout of its own to report
    # and passes the child's 1 straight through, which is indistinguishable
    # from a parse error. The config was correct the entire time; the test was
    # wrong. SIGKILL cannot be caught, so a survivor is always reported as
    # killed and never as a failure.
    #
    # And the accepted list is 0, 124 AND 137, because the two timeouts do not
    # agree: coreutils reports its own 124, busybox -- which is the timeout on
    # a default Alpine -- reports 128+9. Only accepting 124 would have swapped
    # this false alarm for a quieter one.
    if command -v i3status >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
        # The 'if' wrapper is required, not stylistic: under 'set -e' a bare
        # command that exits non-zero would abort the stage before $? is read.
        if timeout -s KILL 3 i3status -c /tmp/i3status.$$ \
                >/dev/null 2>/tmp/i3status.err.$$; then
            _rc=0
        else
            _rc=$?
        fi
        case "$_rc" in
            0|124|137) note "i3status config parses (ran until stopped at 3s)" ;;
            *)     warn "the generated i3status config does not parse (exit $_rc):"
                   sed 's/^/      /' /tmp/i3status.err.$$ >&2 ;;
        esac
        rm -f /tmp/i3status.err.$$
    fi
    install_home_file .config/i3status/config /tmp/i3status.$$; rm -f /tmp/i3status.$$

    # A readable terminal. Without a font package xterm falls back to a bitmap
    # that is painful at this resolution.
    say "Writing ~/.Xresources"
    cat > /tmp/xres.$$ <<'XRES'
! Tokyo Night
*background:           #1a1b26
*foreground:           #c0caf5
*cursorColor:          #c0caf5
*color0:  #15161e
*color8:  #414868
*color1:  #f7768e
*color9:  #f7768e
*color2:  #9ece6a
*color10: #9ece6a
*color3:  #e0af68
*color11: #e0af68
*color4:  #7aa2f7
*color12: #7aa2f7
*color5:  #bb9af7
*color13: #bb9af7
*color6:  #7dcfff
*color14: #7dcfff
*color7:  #a9b1d6
*color15: #c0caf5
XTerm*faceName:        Terminus
XTerm*faceSize:        12
XTerm*saveLines:       4096
XTerm*scrollBar:       false
XTerm*selectToClipboard: true
URxvt*font:            xft:Terminus:size=12
URxvt*saveLines:       4096
URxvt*scrollBar:       false
URxvt*internalBorder:  2
XRES
    install_home_file .Xresources /tmp/xres.$$; rm -f /tmp/xres.$$

    # The desktop's theme on every terminal, opaque. Linux Antiquity's
    # terminal is a pane of glass -- kitty at 20 % opacity over a blurred
    # wallpaper, one neon palette for all five themes ("black" #9400ff,
    # "white" #ff00ee) that only reads on that glass. Copied onto an opaque
    # foot it printed purple text and an invisible selection, found in half
    # the bench's pictures. copal-terminal-theme carries each theme -- helios,
    # eris, priapus, eros, hades -- as an opaque ground (the theme's glass
    # tint) with sixteen colours derived from the theme's own design tokens,
    # every one at 4.5:1 or better, plus Copal Sand. With no argument it
    # follows the theme the desktop is set to (helios until the Themes menu
    # says otherwise). helios's tint is faded toward white (the tint itself
    # was too yellow opaque). Alpha is 0.9, a hint of wallpaper: measured on
    # the bench, a redrawing foot at 0.9 cost Hyprland on llvmpipe the same
    # CPU as at 1.0, since blur is drawn once per frame for the bars anyway.
    # Nothing blinks: no idle redraws. The script writes each terminal's own
    # format and can be re-run by hand any time, with a theme name to switch
    # and --alpha 1 to go opaque.
    install -m 0755 "$(copal_src_dir)/tools/copal-terminal-theme" /usr/local/bin/copal-terminal-theme 2>/dev/null \
        || warn "tools/copal-terminal-theme not found in $(copal_src_dir); the terminal palette is not applied"
    # The terminal is one layer of the look. copal-theme switches all of
    # them -- terminals, bar, launcher, notifications, borders, wallpaper,
    # GTK, the prompt, mc, the editor -- from a theme directory, and it is
    # written here rather than in stage 7 so that a machine that stops at
    # the medium level still has the switch. tokyo-night is this desktop's
    # (i3, i3status and .Xresources already wear it); stage 17 applies
    # antiquity. Run last, after every file it edits has been written.
    [ -d "$copal_theme_dir/antiquity" ] || copal_write_themes
    copal_apply_theme tokyo-night
    note "switch the whole look at any time:  copal-theme --toggle  (Super+Shift+N)"
    note "                                    copal-theme --pick    (Super+Shift+T)"

    install_modern_browser
    configure_x_for_user

    # Claim the session for X11. Stage 17 writes 'wayland' over this if it
    # runs later -- last writer wins, see the note above copal-session.
    #
    # Through copal-desktop rather than by writing the file, because the word
    # is only half the state: this is also what re-arms X's setuid server if
    # a previous turn under Wayland disarmed it. Writing 'x11' by hand and
    # leaving the bit off produces a desktop that will not start and an error
    # message about console users that explains nothing.
    mkdir -p /etc/copal
    copal-desktop x11 >/dev/null 2>&1 || printf 'x11\n' > /etc/copal/session
    note "/etc/copal/session = x11$([ -u /usr/libexec/Xorg.wrap ] 2>/dev/null && printf ', X armed')"
    configure_desktop_autostart startx

    say "Stage 4 complete."
    cat <<MSG
    The desktop runs as '$PI_USER', not as root. So:

        exit                     leave this root shell
        login as $PI_USER        at the console
        startx

    If you said yes to starting the desktop at boot, none of that is needed
    after the next reboot -- tty1 logs '$PI_USER' in and startx runs. Delete
    /etc/copal/autostart-desktop to get the console back.

    If you are still root when you type startx, copal-startx will stop you and
    say so. That is the check, not a bug.

    Super+Return terminal      Super+d  run a program
    Super+e      file manager  Super+t  task manager (htop)
    Super+r      resize mode   Super+f  fullscreen
    Super+Shift+q close        Super+Shift+e exit i3

    If X fails, read /var/log/Xorg.0.log -- the useful lines are marked (EE).
    "no screens found" on this board is usually fbdev: check that
    /dev/fb0 exists and that '$PI_USER' is in the video group.
MSG
    commit_reminder
}
