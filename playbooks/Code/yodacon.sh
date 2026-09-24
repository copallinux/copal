# playbook: yodacon
# source:   clone https://github.com/yodacon/yodacon.git
# origin:   code
# build:    git go build-base pkgconf make cmake alsa-lib-dev libx11-dev libxcursor-dev libxi-dev
#           libxinerama-dev libxrandr-dev libxxf86vm-dev mesa-dev glu-dev
#
# program:  -
# label:    Yodacon (the plugin, the suites, the engines)
# shelf:    Code
# install:  yodacon@clone
# mode:     -
# gate:     *
# home:     https://github.com/yodacon/yodacon
# about:    Team Yodacon's centre: the 1997 ConEx plugin, its exporters and test suites, with the
#           game and the 2005 engine it ports as submodules. Its Makefile round-trips the plugin and
#           builds the game.
