# playbook: radbeeper
# source:   clone https://github.com/vonglurt/radbeeper.git
# origin:   code
# build:    git rust cargo
#
# program:  radbeeper-gui
# label:    radbeeper (Geiger counter panel)
# shelf:    Code
# install:  radbeeper@clone
# mode:     x
# gate:     *
# home:     https://github.com/vonglurt/radbeeper
# about:    The instrument panel for a GQ GMC-320 Plus Geiger counter: two dials, a live chart and a
#           log, from one or two tubes at once. It also pulls the history the counter recorded while
#           unattended.
#
# program:  radbeeper
# label:    radbeeper (Geiger counter, terminal)
# shelf:    Code
# install:  radbeeper@clone
# mode:     t
# gate:     *
# home:     https://github.com/vonglurt/radbeeper
# about:    The same counter in a terminal: probe finds it, watch shows five time constants at once,
#           and log pull downloads its stored history. The command the panel is built on.

radbeeper_pre() {
    say "radbeeper -- a Geiger counter on USB"
    cat <<'MSG'

    A GQ GMC-320 and its relatives: what it is counting now, against five
    time constants at once, and the history it recorded while unattended.

      radbeeper probe        find the counter and say what it is
      radbeeper watch        the monitor: 3s / 30s / 5m / 50m / working day
      radbeeper log pull     download the stored history to .bin and .csv

    The counter's own <GETCPM>> is one number with one time constant. Five
    windows answer five questions -- 3s follows a source as you move it,
    30s reads the room, 300s is worth writing down -- so radbeeper counts the
    blips itself from the per-second heartbeat and averages them here.

    The program is built, not shipped:  copal-build radbeeper
    (from ~/code/radbeeper, which copal-code clones). This stage sets up the
    dialout group, the boot service, the udev rule and the autostart line.

MSG

    # THE KERNEL, WHICH IS THE THIRD FAILURE AND THE EXPENSIVE ONE. The
    # comment above this function sets it out: Alpine's linux-virt binds no
    # USB serial adapter at all, so a counter passed through to a VM running
    # it can never appear. The device enumerates -- lsusb shows the CH340 --
    # and there is simply no driver to claim it, so dmesg is silent and every
    # guide on the internet tells you to check the cable.
    #
    # This stage used to only DESCRIBE that. radbeeper's own README said
    # "Copal installs the linux-lts Alpine package, so a Copal machine has
    # the driver already", and nothing here installed any kernel at all. The
    # sentence is true now.
    #
    # ONLY IN A VM, AND ONLY WHEN linux-lts IS NOT ALREADY THERE. Real
    # hardware runs linux-lts or linux-rpi and both carry ch341, so there is
    # nothing to do -- and a Pi must NOT be handed linux-lts. The test is the
    # running kernel's own name, which ends in -virt exactly when this
    # matters. It does not reboot anything: a kernel takes effect when the
    # machine next starts, and choosing that moment is the operator's.
    case "$(uname -r)" in
        *-virt)
            if apk info -e linux-lts >/dev/null 2>&1; then
                note "linux-lts is installed"
                grub_default_lts
            elif apk add linux-lts >/dev/null 2>&1; then
                note "installed linux-lts -- linux-virt has no ch341, so a passed-through counter could never appear"
                grub_default_lts
            else
                warn "could not install linux-lts -- under linux-virt a USB counter cannot be found, however good the pass-through"
            fi ;;
    esac

    # The Python radbeeper this function used to write -- 3,741 lines of it --
    # retired. radbeeper is Rust now, one crate at the root of
    # ~/code/radbeeper, which copal-code clones and copal-build compiles.
    #
    # It is removed only when it is the file Copal wrote -- its header is
    # unmistakable -- so a radbeeper someone put there themselves is left
    # alone. The one-file Python is not lost either: it is still in that
    # checkout, beside the crate, as the oracle the port is checked against
    # and as the owner of export, site, recompute, hotplug, window, --plain
    # and --source sim, which have no Rust counterpart yet.
    if [ -f /usr/local/bin/radbeeper ] && \
       head -8 /usr/local/bin/radbeeper | grep -q 'a GQ GMC Geiger-Muller counter on the desk'; then
        rm -f /usr/local/bin/radbeeper
        note "removed the Python radbeeper from /usr/local/bin -- it is Rust now, from ~/code/radbeeper"
    fi

    # AND YET THE PATH STAYS. Three things here name /usr/local/bin/radbeeper
    # and none of them can name anything else: the OpenRC service runs as
    # root before any user's session exists, the udev rule fires as root, and
    # the autostart line runs as whoever is logged in. A per-user
    # ~/.local/bin is the wrong answer for the first two.
    #
    # So this writes a SHIM there, and the shim's whole job is to find the
    # native binary and exec it -- copal-build's ~/.local/bin first, then a
    # cargo install, then a static release binary dropped in by hand. Until
    # one of those exists the shim exits non-zero with a sentence saying how
    # to make it exist, which is exactly what the service's start_pre already
    # treats as "no counter": it records the reason and stays dormant. So a
    # machine that has never built radbeeper boots clean and says why.
    cat > /usr/local/bin/radbeeper <<'RADBEEPERSHIM'
#!/bin/sh
# Written by copal-prep.sh: find the native radbeeper and run it.
#
# radbeeper is a Rust crate at the root of ~/code/radbeeper. This shim exists
# because the boot service, the udev rule and the desktop autostart all have
# to name one absolute path, and the binary itself lives wherever it was
# built or installed.
set -eu
for c in \
    "${HOME:-}/.local/bin/radbeeper" \
    "${HOME:-}/.cargo/bin/radbeeper" \
    /home/*/.local/bin/radbeeper \
    /home/*/.cargo/bin/radbeeper \
    /usr/local/lib/radbeeper/radbeeper
do
    [ -n "$c" ] && [ -x "$c" ] && exec "$c" "$@"
done
echo "radbeeper: the native binary is not built yet." >&2
echo "  build it:    copal-build radbeeper        (from ~/code/radbeeper)" >&2
echo "  or fetch it: cargo install radbeeper" >&2
echo "  or take a static one: https://github.com/vonglurt/radbeeper/releases" >&2
exit 127
RADBEEPERSHIM
    chmod 0755 /usr/local/bin/radbeeper
    note "wrote the /usr/local/bin/radbeeper shim -- it runs the native build"

    # The serial node is root:dialout. Being in the group is the difference
    # between a working monitor and EACCES, and it takes a fresh login, which
    # is worth saying now rather than being discovered later.
    if [ -n "${PI_USER:-}" ] && id "$PI_USER" >/dev/null 2>&1; then
        if getent group dialout >/dev/null 2>&1; then
            if id -nG "$PI_USER" 2>/dev/null | tr ' ' '\n' | grep -qx dialout; then
                note "$PI_USER is already in the dialout group"
            else
                adduser "$PI_USER" dialout >/dev/null 2>&1 \
                    && note "$PI_USER added to dialout (takes effect at the next login)" \
                    || warn "could not add $PI_USER to dialout -- do it by hand: adduser $PI_USER dialout"
            fi
        else
            warn "no dialout group on this system -- the serial node may be owned by uucp instead"
        fi
    fi

    # The boot service. It probes once; finding nothing it records why and
    # does NOT start, which is the whole design: a USB device that is not
    # plugged in will not become plugged in because a daemon asked again four
    # seconds later. OpenRC reports it stopped and the next boot tries again.
    cat > /etc/init.d/radbeeper <<'RADBEEPERRC'
#!/sbin/openrc-run
# radbeeper -- the Geiger counter monitor.
#
# Dormant is the normal state on a machine with no counter plugged in: this
# service is STOPPED then, on purpose, having written the reason to
# /var/lib/radbeeper/status. It looks again at the next boot, and
# `rc-service radbeeper start` picks it up the moment you plug one in.
name="radbeeper"
description="Geiger counter monitor (dormant when no counter is present)"
command="/usr/local/bin/radbeeper"
command_args="service"
command_background=true
# THE SERVICE AND THE PERSON WRITE THE SAME LOG, so the service's files have
# to be writable by the group that person is in.
#
# This runs as root; `radbeeper watch` runs as you. Both log, deliberately --
# only one program can hold the serial port, so the monitor does the logging
# while it has it, and the log used to have a hole exactly where somebody was
# watching. That only works if watch can APPEND to the file the service
# created. Without this umask root's default 022 makes it rw-r--r--, being in
# dialout buys nothing, and watch comes up saying NOT LOGGING: Permission
# denied -- reopening the hole the shared log was built to close.
umask=002
pidfile="/run/radbeeper.pid"
output_log="/var/log/radbeeper/service.log"
error_log="/var/log/radbeeper/service.log"

depend() {
	after coldplug udev-postmount modules
	need localmount
}

start_pre() {
	checkpath -d -m 0755 /var/log/radbeeper
	# 2775: setgid, so every file created here belongs to dialout whoever
	# creates it -- the service as root, or a person running `radbeeper watch`.
	# With umask=002 above, that is what makes the one log writable by both.
	checkpath -d -m 2775 -o root:dialout /var/lib/radbeeper
	if /usr/local/bin/radbeeper probe >/dev/null 2>&1; then
		return 0
	fi
	# Record the reason where a person will find it, then decline to start.
	/usr/local/bin/radbeeper service >/dev/null 2>&1 || true
	einfo "No Geiger counter on USB -- radbeeper stays dormant."
	einfo "Why, in detail: cat /var/lib/radbeeper/status"
	einfo "It looks again at the next boot, or: rc-service radbeeper start"
	return 1
}
RADBEEPERRC
    chmod 0755 /etc/init.d/radbeeper
    rc-update add radbeeper default >/dev/null 2>&1 \
        && note "radbeeper added to the default runlevel" \
        || warn "could not add radbeeper to the default runlevel"

    # HANDING THE COUNTER OVER WITHOUT A PASSWORD. Only one program can hold
    # the serial port, so watching the counter yourself means stopping the
    # logger first, and `radbeeper --wait watch` waits in the other window
    # until it can have it. That handover is the one administrative act this
    # machine performs several times an evening, and a password prompt in the
    # middle of it is why people leave the service stopped instead -- which
    # costs the log every hour they are not watching.
    #
    # Named zz- because doas takes the LAST matching rule, and wheel.conf's
    # 'permit persist' would otherwise win on a plain alphabetical read of
    # /etc/doas.d. Same reason zz-copal-halt.conf is named that way.
    #
    # BOTH SPELLINGS, because doas matches 'cmd' against the command as typed
    # and not against what it resolves to -- the same trap copal-halt documents
    # for /sbin/poweroff. radbeeper's own error message and its README both say
    # `doas rc-service radbeeper stop`, and somebody who types the absolute
    # path instead should not be asked for a password for being more precise.
    # 'args' is matched in full, so these four lines permit exactly two verbs
    # on exactly one service and nothing else.
    if [ -d /etc/doas.d ] || mkdir -p /etc/doas.d; then
        cat > /etc/doas.d/zz-radbeeper.conf <<'RADBEEPERDOAS'
# Written by Copal stage 10: handing the counter between the logger and the
# monitor needs no password. Two verbs, one service, nothing else.
permit nopass :wheel cmd rc-service args radbeeper stop
permit nopass :wheel cmd rc-service args radbeeper start
permit nopass :wheel cmd /sbin/rc-service args radbeeper stop
permit nopass :wheel cmd /sbin/rc-service args radbeeper start
RADBEEPERDOAS
        chown root:root /etc/doas.d/zz-radbeeper.conf 2>/dev/null || true
        # doas refuses to read a config file anyone but root can write.
        chmod 0640 /etc/doas.d/zz-radbeeper.conf
        if doas -C /etc/doas.d/zz-radbeeper.conf >/dev/null 2>&1; then
            note "doas: rc-service radbeeper stop|start needs no password"
        else
            rm -f /etc/doas.d/zz-radbeeper.conf
            warn "doas rejected the radbeeper rule -- removed it rather than"
            warn "leave a file that makes doas refuse everything"
        fi
    fi

    # THE FILES AN EARLIER INSTALL ALREADY WROTE. umask=002 fixes every log
    # made from here on; it cannot reach the ones the service created under
    # root's default 022, which are rw-r--r-- and which `radbeeper watch`
    # therefore cannot append to. On a first install there is nothing here.
    if [ -d /var/lib/radbeeper ]; then
        chgrp dialout /var/lib/radbeeper 2>/dev/null || true
        chmod 2775 /var/lib/radbeeper 2>/dev/null || true
        for _f in /var/lib/radbeeper/*.tsv /var/lib/radbeeper/*.hex \
                  /var/lib/radbeeper/status; do
            [ -f "$_f" ] || continue
            chgrp dialout "$_f" 2>/dev/null || true
            chmod g+w "$_f" 2>/dev/null || true
        done
        note "/var/lib/radbeeper: the service and the monitor share the log"
    fi

    # Plugging a counter into a RUNNING machine. Two things should happen and
    # they want different privileges, so they are two mechanisms:
    #
    #   the log     a udev rule, as root, starting the service -- the counting
    #               begins whether or not anybody is logged in
    #   the window  `radbeeper hotplug` on the desktop autostart line, in the
    #               session, where the display and the person both are
    #
    # The rule deliberately does NOT try to open a window. udev fires as root
    # with no WAYLAND_DISPLAY, no session bus and no way to tell which of
    # several logged-in people a window would belong to; guessing at that is
    # how you get a monitor on the wrong screen, or none at all and nothing in
    # any log to say why. Starting a daemon asks none of those questions.
    cat > /usr/local/bin/radbeeper-plugged <<'RADBEEPERPLUG'
#!/bin/sh
# radbeeper-plugged -- what the udev rule runs when a counter appears.
#
# udev kills a RUN child that outlives its event, so nothing here may run in
# the foreground: the service is started by a detached shell udev has stopped
# caring about.
#
# THE SIX SECONDS ARE DELIBERATE, and they are two things at once.
#
# The first is the node's group: the device is root:root for a moment before
# udev's own tty rules hand it to dialout, and a probe landing in that moment
# gets EACCES and gives up.
#
# The second is who gets the port. Only one program can read a serial device
# sensibly -- two readers share the bytes between them and neither is told, so
# both undercount plausibly -- and radbeeper locks the port to make sure of it.
# The session's `radbeeper hotplug` opens its window about two seconds after a
# node appears. Waiting longer here means that when somebody IS logged in, the
# window they plugged the counter in to see is the thing that gets it, and this
# service waits and picks the log up the moment they close it. When nobody is
# logged in there is no window to lose to and the six seconds cost nothing.
[ -x /usr/local/bin/radbeeper ] || exit 0
setsid /bin/sh -c 'sleep 6
    rc-service radbeeper status >/dev/null 2>&1 && exit 0
    rc-service radbeeper start >/dev/null 2>&1' >/dev/null 2>&1 </dev/null &
exit 0
RADBEEPERPLUG
    chmod 0755 /usr/local/bin/radbeeper-plugged

    if [ -d /etc/udev/rules.d ]; then
        cat > /etc/udev/rules.d/60-radbeeper.rules <<'RADBEEPERUDEV'
# Start the Geiger logger when a counter is plugged into a running machine.
# Written by Copal stage 10. The window is the session's half, not this one:
# see /usr/local/bin/radbeeper-plugged for why udev does not open one.
#
# The three USB-serial bridges GQ has shipped behind: CH340 (1a86:7523, which
# is the GMC-320), CP210x (10c4:ea60) and PL2303 (067b:2303). Matching a
# little wide is safe here -- a rule that fires for some other CH340 cable
# costs one probe, which finds no counter, writes down why and stops. That is
# the dormant path working exactly as designed, not a failure.
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", RUN+="/usr/local/bin/radbeeper-plugged"
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", RUN+="/usr/local/bin/radbeeper-plugged"
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", RUN+="/usr/local/bin/radbeeper-plugged"
RADBEEPERUDEV
        udevadm control --reload >/dev/null 2>&1 || true
        note "udev rule: plugging a counter in starts the logger"
    else
        warn "no /etc/udev/rules.d -- plugging a counter in will not start the"
        warn "logger by itself. Install eudev, or start it by hand:"
        warn "    rc-service radbeeper start"
    fi

    # Say what this machine can actually do, now, rather than at the next
    # reboot when nobody is reading.
    if radbeeper probe >/dev/null 2>&1; then
        note "a counter is present:"
        radbeeper probe 2>&1 | sed 's/^/      /'
        rc-service radbeeper start >/dev/null 2>&1 \
            && note "the monitor is running -- log: /var/lib/radbeeper/cpm-<serial>-YYYY-MM.tsv" || true
    else
        warn "no counter is visible from here. radbeeper says why:"
        radbeeper probe 2>&1 | sed 's/^/      /'
        note "That is not an error in the install -- the service stays dormant"
        note "and looks again at the next boot."
    fi
    # DID THE SHARED LOG COME OUT SHARED? This failure is silent where it
    # happens. The service logs perfectly well as root; the hole only appears
    # on the evening somebody opens the monitor, and then only in a file
    # nobody reads until the page is rebuilt. So it is checked here, once, on
    # the thing that actually has to be true: the person who runs `radbeeper
    # watch` can append to the file the service writes.
    #
    # TWO WAYS THAT IS TRUE, and a backfill alternates between them. Filling
    # the log's gaps writes a temp file and renames it over the original
    # (radbeeper src/log.rs), so the file is remade by whoever ran the
    # backfill, under their umask: root:dialout rw-rw-r-- from the service,
    # $PI_USER:dialout rw-r--r-- from `radbeeper watch`. Both are writable by
    # both, because one of the two writers is always root and the other is
    # always the owner. Testing only the group bit calls the second one broken.
    if [ -d /var/lib/radbeeper ]; then
        _log=$(ls -1t /var/lib/radbeeper/cpm-*.tsv 2>/dev/null | head -1)
        if [ -z "$_log" ]; then
            note "no log written yet -- the first one will be group-writable"
        elif [ "$(stat -c %U "$_log" 2>/dev/null)" = "${PI_USER:-}" ] \
          || { [ "$(stat -c %G "$_log" 2>/dev/null)" = dialout ] \
            && [ "$(stat -c %A "$_log" 2>/dev/null | cut -c6)" = w ]; }; then
            note "the log is dialout and group-writable, so the monitor logs"
            note "while it holds the counter:  $(basename "$_log")"
        else
            warn "$(basename "$_log") is $(stat -c '%A %U:%G' "$_log" 2>/dev/null)"
            warn "'radbeeper watch' cannot append to that -- it will come up"
            warn "saying NOT LOGGING, and the log will have a hole for as long"
            warn "as the monitor is open. umask=002 in /etc/init.d/radbeeper"
            warn "covers files made from now on; this one predates it:"
            warn "    chmod g+w $_log"
        fi
    fi

    note "the monitor:   radbeeper watch          (Super+C -> Instruments)"
    note "busy port:     radbeeper --wait watch   (takes it when the service"
    note "               lets go; doas rc-service radbeeper stop, no password)"
    note "no hardware:   radbeeper --source sim --sim-cpm 400 watch"
}
