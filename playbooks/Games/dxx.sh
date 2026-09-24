# playbook: dxx
# source:   github dxx-rebirth/dxx-rebirth
# build:    build-base scons pkgconf sdl2-dev sdl2_mixer-dev sdl2_image-dev physfs-dev libpng-dev
#           glu-dev mesa-dev
# runs:
#
# program:  d1x-rebirth
# label:    Descent 1 (shareware, DXX-Rebirth)
# shelf:    Games
# install:  dxx@source
# mode:     x
# gate:     64
# home:     https://github.com/dxx-rebirth/dxx-rebirth
# about:    The 1995 shooter flown in six degrees of freedom through mines taken over by robots. The
#           shareware episode; copy the full game's files into ~/.d1x-rebirth to play the rest.
#
# program:  d2x-rebirth
# label:    Descent 2 (demo, DXX-Rebirth)
# shelf:    Games
# install:  dxx@source
# mode:     x
# gate:     64
# home:     https://github.com/dxx-rebirth/dxx-rebirth
# about:    Descent's sequel: more robots, a guide-bot, afterburners. The demo levels; the full
#           game's files go in ~/.d2x-rebirth. Installed together with Descent 1.

# Descent 1 and 2, on DXX-Rebirth, which builds both engines from one tree.
# Its last tag is 2018 and the work has gone on since, so this pins a commit.
# The data are the shareware Descent and the Descent 2 demo, both freely
# distributable, as dxx-rebirth.com served them until 2022 -- that site now
# holds only its final release, so the copies come from the Wayback Machine,
# the same place Pi-Apps takes them from, pinned here by checksum. The full
# games' data dropped into ~/.d1x-rebirth or ~/.d2x-rebirth play instead.
DXX_COMMIT=e0165250820d0e11f4cb29890eb68017ea4bbb64
DXX_DATA=https://web.archive.org/web/20221208193117if_/https://www.dxx-rebirth.com/download/dxx/content
dxx_install() {
    _s=$(gh_source dxx-rebirth/dxx-rebirth "$DXX_COMMIT" \
         4e43938f718548dadbded1c0ea3687ef0ba3cef65bf894becb93c04bdd53edcb) || return 1
    # builddir stays the default, inside the tree: scons's default target is
    # '.', and a build directory elsewhere is outside it and never built.
    (cd "$_s" && nice -n 10 scons -j "$JOBS" sdl2=1 opengl=1 d1x=1 d2x=1)
    _d="$PREFIX/lib/copal-store/dxx-rebirth"
    mkdir -p "$DEST$_d/d1" "$DEST$_d/d2"
    cp "$(find "$_s/build" -type f -name d1x-rebirth | head -n1)" \
       "$(find "$_s/build" -type f -name d2x-rebirth | head -n1)" "$DEST$_d/"
    for _z in "descent-pc-shareware.zip:744b7f29043e977e7702173b150db7a6a3c253cacc9f608a0b3709acb46b51f1:d1" \
              "descent2-pc-demo.zip:b842cf983d0f393cede5cb6703186ec6eedac9bc5732dc577966f6f3122b9130:d2"; do
        _n=${_z%%:*}; _x=${_z#*:}; _sum=${_x%%:*}; _to=${_x#*:}
        _f="$CACHE/dxx-$_n"
        [ -s "$_f" ] || curl -fL --retry 3 -o "$_f" "$DXX_DATA/$_n"
        verify_sum "$_f" "$_sum"
        unzip -q -o "$_f" -d "$DEST$_d/$_to"
    done
    for _g in "d1x-rebirth:d1:Descent (shareware)" "d2x-rebirth:d2:Descent 2 (demo)"; do
        _b=${_g%%:*}; _x=${_g#*:}; _h=${_x%%:*}; _name=${_x#*:}
        launcher "$_b" <<EOF
exec "$_d/$_b" -hogdir "$_d/$_h" "\$@"
EOF
        desktop_entry "$_b" "$_name" "$_b" applications-games "Game;ActionGame;" "Six-degrees-of-freedom shooter in the mines"
    done
}
