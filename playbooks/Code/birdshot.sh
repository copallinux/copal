# playbook: birdshot
# source:   clone https://github.com/vonglurt/birdshot.git
# origin:   code
# build:    git build-base cmake samurai pkgconf qt6-qtbase-dev
#
# program:  birdshot-gui
# label:    birdshot (bird and sky camera)
# shelf:    Code
# install:  birdshot@clone
# mode:     x
# gate:     *
# home:     https://github.com/vonglurt/birdshot
# about:    Bird and sky capture for the Raspberry Pi HQ Camera: a C++17 camera pipeline with a Qt
#           window over it. Copal's camera command uses it first when it is there.
#
# program:  birdshot
# label:    birdshot (camera, command line)
# shelf:    Code
# install:  birdshot@clone
# mode:     h
# gate:     *
# home:     https://github.com/vonglurt/birdshot
# about:    The birdshot pipeline without its window, for capture from a script or over SSH. The
#           same program the window drives.
