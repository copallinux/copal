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
