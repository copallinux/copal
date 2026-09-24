# command:  x11vnc
# purpose:  Share a running X11 desktop over VNC, so another machine can see and control it.
# why:      The catalogue's screen sharing for Copal's i3 desktop (X11): help
#           someone at the Pi from your Mac, with a VNC viewer. It shares the
#           session already on screen rather than starting a new one.
# see:      ssh, orrery

## Use
Run it inside the X session you want to share; it listens on port 5900.
Connect with a VNC viewer -- macOS has one built in: `vnc://pi` in
Finder's Connect to Server. Set a password first, and prefer an SSH
tunnel to the open port.

## Examples
    x11vnc -storepasswd                  # set a password (in ~/.vnc/passwd)
    x11vnc -rfbauth ~/.vnc/passwd -display :0 -forever
    x11vnc -localhost -rfbauth ~/.vnc/passwd -display :0   # only through a tunnel
    ssh -L 5900:localhost:5900 pi        # the tunnel, from the other machine

## Options
-display :0        the X display to share
-rfbauth FILE      require the password stored in FILE
-storepasswd       store a VNC password
-localhost         accept only local connections (use an SSH tunnel)
-forever           keep serving after a viewer disconnects
-shared            allow several viewers at once
-viewonly          viewers can watch, not control

## Notes
- It shares X11 only. The Hyprland desktop is Wayland, where it sees
  nothing useful; share the i3 session, or reach the Pi over SSH.
- Without `-rfbauth`, anyone who can reach port 5900 gets the desktop.
  With `-localhost` and an SSH tunnel, only someone who can log in by
  SSH can.
