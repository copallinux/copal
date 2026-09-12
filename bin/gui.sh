#!/bin/sh
# The native console -- the window an operator stands in front of.
#
# `make fleet-web` serves the same read model on a port; this opens a window,
# which means it needs a display and cannot be run over ssh. DEMO=1 draws the
# lab report's museum with no fleet at all.
exec make fleet-gui "$@"
