# playbook: smc
# source:   github hakandundar34coding/system-monitoring-center
# build:    meson samurai gettext
# runs:     python3 python3-tkinter py3-gobject3 py3-cairo gtk4.0 libadwaita dmidecode
#           util-linux-misc
#
# program:  system-monitoring-center
# label:    System Monitoring Center
# shelf:    System
# install:  smc@source
# mode:     x
# gate:     *
# home:     https://github.com/hakandundar34coding/system-monitoring-center
# about:    A task manager in the style of Windows'. CPU, memory, disks, network, sensors and
#           processes on tabs, with graphs.

# System Monitoring Center: GTK4 and libadwaita, meson. It keeps its modules
# in share/, not in a Python library directory, so needs no launcher.
SMC_VER=3.4.1
smc_install() {
    _s=$(gh_source hakandundar34coding/system-monitoring-center "v$SMC_VER" \
         abe601aaa8f6a3beea2874292931d8b0bf43ecb17a75f605feb8b4b08b4708e5) || return 1
    # Its modules go to share/system-monitoring-center, and the script meson
    # writes puts that directory on sys.path itself.
    meson setup "$W/build" "$_s" --prefix="$PREFIX"
    meson compile -C "$W/build"
    DESTDIR="$DEST" meson install -C "$W/build"
}
