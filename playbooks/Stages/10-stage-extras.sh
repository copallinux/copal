# playbook: stage-extras
# source:   copal
# origin:   stage
# stage:    10
# category: Hardware
# step:     Wireless, audio, capture and disks
# weight:   8
# levels:   medium full
# summary:  Wireless, Bluetooth, audio, video capture and disk tools, and the Geiger counter's
#           setup. What a desktop needs to talk to the things plugged into it.

stage_extras() {
    say "Stage 10: wireless, bluetooth, audio, capture, hex, graphics, disks"
    require_disk_root "This stage" || return 0
    require_network || return 1

    # --- wireless ----------------------------------------------------------
    say "Wireless tools"
    if [ -d /sys/class/ieee80211 ] && [ -n "$(ls -A /sys/class/ieee80211 2>/dev/null)" ]; then
        note "a wireless interface is present"
    else
        warn "no wireless hardware detected."
        note "The Pi Zero *1* has no onboard wifi -- only the Zero W and Zero 2 W do."
        note "Installing the tools anyway; they will work with a USB adapter."
    fi
    add_optional wireless-tools iw wpa_supplicant
    note "scan:    iw dev wlan0 scan | grep SSID"
    note "connect: setup-interfaces   (Alpine's own, writes /etc/network/interfaces)"

    # --- bluetooth ---------------------------------------------------------
    say "Bluetooth"
    if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
        note "a bluetooth controller is present"
    else
        warn "no bluetooth controller detected -- the Zero 1 has none onboard either."
    fi
    if try_add bluez bluez-openrc; then
        rc-update add bluetooth default >/dev/null 2>&1 || true
        rc-service bluetooth start >/dev/null 2>&1 || true
        note "pairing, from bluetoothctl:"
        note "    power on / agent on / default-agent"
        note "    scan on          -- wait for the MAC to appear"
        note "    pair AA:BB:CC:DD:EE:FF"
        note "    trust AA:BB:...  -- so it reconnects by itself"
        note "    connect AA:BB:..."
    fi
    add_optional bluez-alsa   # A2DP audio out over bluetooth, if packaged

    # --- audio over HDMI ---------------------------------------------------
    say "Audio"
    add_optional alsa-utils alsa-lib
    rc-update add alsa default >/dev/null 2>&1 || true

    # --- a sound server ----------------------------------------------------
    # ALSA alone is the card. Half the catalogue does not talk to the card:
    # Hydrogen asks JACK and then PulseAudio, gqrx and Firefox ask PulseAudio,
    # and with no server answering they open an error box or fall silent
    # (found on the bench, 2 Sep 2026, the day the VM got a sound card).
    # PipeWire answers all three names -- pipewire-pulse is the PulseAudio
    # socket, pipewire-jack the JACK library, pipewire-alsa the ALSA plugin
    # that routes plain ALSA programs through it -- and wireplumber is its
    # session manager. Per-user, not a system service: copal-audio-start
    # brings it up from the session (.xinitrc, or exec-once in Hyprland),
    # and is harmless where nothing is installed.
    say "Sound server (PipeWire)"
    add_optional pipewire wireplumber pipewire-pulse pipewire-alsa
    add_optional pipewire-jack
    cat > /usr/local/bin/copal-audio-start <<'AUDIO'
#!/bin/sh
# copal-audio-start -- bring up the per-user sound server, once per session.
# Safe to call from any session start: does nothing where PipeWire is not
# installed or is already running. Logs to $XDG_RUNTIME_DIR (or /tmp).
_log="${XDG_RUNTIME_DIR:-/tmp}/copal-audio.log"
_up() { pgrep -u "$(id -u)" -x "$1" >/dev/null 2>&1; }
command -v pipewire >/dev/null 2>&1 || exit 0
_up pipewire || { pipewire >>"$_log" 2>&1 & sleep 0.5; }
command -v wireplumber >/dev/null 2>&1 && ! _up wireplumber && { wireplumber >>"$_log" 2>&1 & }
command -v pipewire-pulse >/dev/null 2>&1 && ! _up pipewire-pulse && { pipewire-pulse >>"$_log" 2>&1 & }
exit 0
AUDIO
    chmod 0755 /usr/local/bin/copal-audio-start
    note "PipeWire starts with the session (copal-audio-start); check with:  wpctl status"

    # The ALSA sequencer: MIDI ports for MilkyTracker, FluidSynth, piano-midi.
    # On the virt kernel it is a module nobody loads, and MilkyTracker aborts
    # without it ("error creating ALSA sequencer client object").
    if [ ! -e /dev/snd/seq ] && modprobe snd-seq 2>/dev/null; then
        [ -f /etc/modules ] && ! grep -qx snd-seq /etc/modules 2>/dev/null && echo snd-seq >> /etc/modules
        note "snd-seq loaded and added to /etc/modules (the ALSA sequencer, for MIDI)"
    fi
    # A VM with a sound card the kernel cannot drive. Alpine's linux-virt
    # kernel ships one sound driver, virtio_snd, and UTM's default card is
    # intel-hda: the controller sits on the PCI bus with no driver, ALSA says
    # "cannot find card 0", and VICE refuses to start. Nothing to install on
    # this side -- it is a host setting, and utm/utm-vm.sh now defaults to
    # virtio-sound-pci for new machines. Say so here, where the person is.
    if [ ! -e /proc/asound/cards ] || ! grep -q '^ *[0-9]' /proc/asound/cards 2>/dev/null; then
        _hda=$(grep -l '^0x0403' /sys/bus/pci/devices/*/class 2>/dev/null | head -n1)
        if [ -n "$_hda" ] && [ ! -e "$(dirname "$_hda")/driver" ] && [ -e "/lib/modules/$(uname -r)/kernel/sound/virtio" ]; then
            warn "a sound card is offered by the host, but this kernel has no driver for it"
            note "  This kernel drives virtio sound only. In UTM: this VM -> Edit -> Sound ->"
            note "  Hardware: virtio-sound-pci, then restart the VM. New VMs from utm-vm.sh get it."
            note "  Until then a program that insists on a card can be told not to:  x64sc -sounddev dummy"
        else
            note "no sound card detected (a Pi's HDMI audio appears once dtparam=audio=on is honoured)"
        fi
    fi
    cat <<'MSG'
    HDMI audio on a Pi needs two things: the audio device enabled in firmware,
    and ALSA told to route to HDMI rather than the headphone jack.

    'dtparam=audio=on' is already in usercfg.txt and is safe.

    'hdmi_drive=2' forces HDMI mode (rather than DVI mode) which is what
    actually carries sound. It is NOT enabled by default here, because on a
    display connected through a DVI adapter it can result in no picture at
    all -- and a Pi with no video and no network is hard to recover.
MSG
    if confirm "Enable hdmi_drive=2 now?"; then
        mount -o remount,rw "$BOOT" 2>/dev/null || true
        if grep -q '^hdmi_drive=' "$BOOT/usercfg.txt" 2>/dev/null; then
            note "already set"
        else
            printf '\n# Force HDMI (not DVI) signalling, which is what carries audio.\nhdmi_drive=2\n' >> "$BOOT/usercfg.txt"
            note "added hdmi_drive=2 to $BOOT/usercfg.txt -- takes effect at the next boot"
            note "if the screen stays dark afterwards, delete that line from another machine"
        fi
    fi
    note "route ALSA to HDMI:  amixer cset numid=3 2     (1 = headphones, 0 = auto)"
    note "test:                speaker-test -c2 -twav"

    # --- packet capture ----------------------------------------------------
    say "Video and audio downloads"
    install_ytdlp || warn "yt-dlp not installed -- re-run stage 10 to try again"
    install_ytbrave
    staticstream_post
    # THE GUIDE IS WRITTEN WHATEVER THE THREE ABOVE DID, because it is a text
    # file and not a part of installing anything. It used to be the last line
    # of install_ytdlp, which returns early when there is no network, when the
    # package will not add, when python3 is missing, when the download fails,
    # and when the answer is to skip -- and staticstream_post, the other place it
    # might have been written from, returns at once if yt-dlp is not there.
    # So a machine that already had yt-dlp kept whichever guide it was given
    # the first time, however many times stage 10 was re-run. Found two days
    # stale, alone among the guides in /usr/local/share/copal/guides, every
    # one of which its own stage had just rewritten.
    #
    # /etc/yt-dlp.conf stays where it is, deliberately: a config for a program
    # only matters when the program is there. A guide is what someone reads to
    # decide whether to install it.
    write_ytdlp_guide

    say "Network capture"
    # Wireshark's GUI is out of the question here -- Qt plus a live capture
    # on 512 MB. tshark is the same dissectors without the interface.
    add_optional tcpdump
    try_add tshark || note "tshark unavailable; tcpdump alone is plenty"
    add_optional termshark
    note "capture to a file:  tcpdump -i eth0 -w /tmp/cap.pcap"
    note "read it back:       tshark -r /tmp/cap.pcap   (or open it on the Mac)"
    note "live, readable:     tcpdump -i eth0 -nn -s0 -A"

    # --- hex and binary ----------------------------------------------------
    say "Hex and binary editing"
    # hexedit is edge/testing only -- not in v3.24 stable. bvi is the stable
    # equivalent (vi keys over a hex view) and dhex diffs two binaries.
    add_optional bvi dhex xxd radare2
    note "bvi FILE         full-screen hex editor, vi key bindings"
    note "dhex A B         hex diff of two files, side by side"
    note "xxd FILE | less  hex dump; xxd -r turns an edited dump back into binary"
    note "in vim:  :%!xxd   to edit,  :%!xxd -r   to convert back"

    # --- graphics ----------------------------------------------------------
    say "Graphics"
    # mtpaint would have been the right size for this board, but Alpine no
    # longer packages it (nor xpaint, nor grafx2). What is left for actual
    # drawing is GIMP, which will thrash 512 MB -- so this stage installs the
    # viewers and the command-line converters, and leaves drawing to stage 12.
    add_optional imagemagick netpbm feh gpicview
    note "gpicview IMAGE     lightweight GTK image viewer"
    note "convert a.bmp b.png    format conversion (ImageMagick)"
    note "convert -depth 1 -monochrome in.png out.bmp    1-bit, for the Mac"
    note "feh IMAGE          quick viewer"

    # --- disk images -------------------------------------------------------
    say "Filesystem and disk-image tools"
    # hfsutils -- hmount/hcopy, the classic-HFS tools a Mac Plus image needs --
    # is no longer packaged by Alpine in any repository, stable or edge. That
    # is the one real gap in this stage: getting files into a Mini vMac disk
    # image now goes through the emulator itself (~/minivmac/shared.sh mounts
    # a second .dsk you drag files onto) rather than from the Alpine side.
    # hfsprogs is HFS+, a different filesystem -- later Macs, not the Plus.
    add_optional hfsprogs mtools dosfstools 7zip unzip
    note "hfsprogs : fsck.hfsplus, mkfs.hfsplus  -- HFS+, later Macs"
    note "no hfsutils: use ~/minivmac/shared.sh to move files in and out"
    note "mtools   : mdir/mcopy                  -- FAT images, no mounting needed"

    say "Installing /usr/local/bin/mountdsk"
    # Linux can loop-mount an HFS image directly, which beats any utility for
    # browsing: it is just a directory. Read-only by default because the
    # in-kernel HFS writer is old and lightly used.
    cat > /usr/local/bin/mountdsk <<'MOUNTDSK'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# mountdsk -- loop-mount a Mac disk image so you can browse it as a directory.
#   mountdsk IMAGE [MOUNTPOINT]     mount read-only (default /mnt/dsk)
#   mountdsk -w IMAGE [MOUNTPOINT]  mount read-write  (see the warning below)
#   mountdsk -u [MOUNTPOINT]        unmount
#
# Read-only is the default deliberately. The kernel's HFS write support is old
# and rarely exercised, and a corrupted image is easy to make and annoying to
# discover later. For writing, do it inside the emulator -- hfsutils (hcopy),
# which used to be the answer here, is no longer packaged by Alpine.
#
# NEVER mount an image read-write while Mini vMac has it open. Both sides
# cache metadata and neither expects the other.
set -eu
MODE=ro
case "${1:-}" in
    -w) MODE=rw; shift ;;
    -u) umount "${2:-/mnt/dsk}" && echo "unmounted ${2:-/mnt/dsk}"; exit 0 ;;
    ''|-h|--help) sed -n '2,${/^#/!q; /^# SPDX/d; /^# Copyright/d; p;}' "$0"; exit 0 ;;
esac
IMG="$1"; MNT="${2:-/mnt/dsk}"
[ -f "$IMG" ] || { echo "no such image: $IMG" >&2; exit 1; }
if pgrep -x minivmac >/dev/null 2>&1 && [ "$MODE" = rw ]; then
    echo "minivmac is running -- refusing to mount read-write" >&2; exit 1
fi
mkdir -p "$MNT"
for fs in hfsplus hfs vfat; do
    modprobe "$fs" 2>/dev/null || true
    if mount -t "$fs" -o loop,"$MODE" "$IMG" "$MNT" 2>/dev/null; then
        echo "mounted $IMG as $fs ($MODE) at $MNT"
        exit 0
    fi
done
echo "could not mount $IMG as hfsplus, hfs or vfat." >&2
echo "If it is a classic HFS image, try:  hmount '$IMG' && hdir" >&2
exit 1
MOUNTDSK
    chmod 0755 /usr/local/bin/mountdsk
    note "mountdsk IMAGE       browse a disk image as a directory (read-only)"
    note "mountdsk -u          unmount it again"

    radbeeper_pre
    install_manuals

    say "Stage 10 complete."
    note "Getting files in and out of a Mini vMac disk: ~/minivmac/shared.sh"
    note "or mountdsk for a read-only look at any image."
}
