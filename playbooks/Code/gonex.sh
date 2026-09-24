# playbook: gonex
# source:   clone https://github.com/yodacon/gonex.git
# origin:   code
# build:    git go build-base pkgconf make cmake alsa-lib-dev libx11-dev libxcursor-dev libxi-dev
#           libxinerama-dev libxrandr-dev libxxf86vm-dev mesa-dev glu-dev
#
# program:  gonex
# label:    Gonex (Team Yodacon's game)
# shelf:    Code
# install:  gonex@clone
# mode:     x
# gate:     *
# home:     https://github.com/yodacon/gonex
# about:    Team Yodacon's game, written in Go on the Ebitengine engine. A port of the 2005 Konex
#           engine, built from its own checkout.
