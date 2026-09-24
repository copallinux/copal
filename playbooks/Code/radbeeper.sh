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
