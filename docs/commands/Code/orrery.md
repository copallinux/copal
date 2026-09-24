# command:  orrery
# purpose:  The console for a fleet of Copal machines: the wall, the seat, and the museum interface.
# why:      Stage 16's fleet -- a room of Copal machines -- is watched and run
#           from it: every machine at once on the wall, one of them full screen
#           in the seat. Built by copal-build from the orrery checkout.
# see:      copal-fleet, ssh

## Use
Three faces. The wall is a web page of every machine in the fleet,
served on a port. The seat is one machine, observed and controlled over
VNC, full screen in this terminal. The native window (`--gui`) is the
museum interface. Without `--operator` it only observes; with it, the
verbs that act on machines are enabled.

## Examples
    orrery --demo                        # the wall, from a fixture: no fleet needed
    orrery --gui --demo --operator x     # the museum interface, from the fixture
    orrery                               # the wall, on 127.0.0.1:8080
    orrery --listen 0.0.0.0:8080         # the wall, for the room's gallery screen
    orrery --gui --operator TOKEN        # the window, with the write verbs on
    orrery --seat museum-01              # one node, full screen, over VNC

## Options
--listen HOST:PORT   where the wall is served (default 127.0.0.1:8080)
--operator TOKEN     enable the verbs that change machines
--fleet NAME         which fleet (passed to copal fleet)
--demo               serve from a fixture instead of a fleet
--gui                the native window instead of a web page
--seat NODE          one node over VNC; --fps N, --vnc-port N
--frame PATH         render one frame to a PPM and exit (works headless)
--dark               the night palette
--quiet              do not log requests

## Notes
- The default listens on loopback only. The gallery screen needs
  `--listen 0.0.0.0:8080`, which puts the wall on the LAN: a LAN you
  trust.
- Read-mostly by default is deliberate. `--operator` is what turns a
  display into a control panel.
- The seat asks a node for 6 frames a second, because frame rate is the
  expensive axis; `--fps` raises it.
