# command:  copal-autologin
# purpose:  What tty1 runs instead of the login prompt when the desktop starts at boot.
# why:      Autologin without a display manager: getty skips the name, this
#           logs the admin user straight in. It also raises the memory-lock and
#           real-time limits audio programs want, which nothing else on Copal
#           can do, because logins here do not go through PAM.
# see:      copal-session, getty, ulimit

## Use
You do not run it. Stage 4 offers to start the desktop at boot; saying yes
writes this and points tty1 at it in `/etc/inittab`.

## Examples
    grep tty1 /etc/inittab               # is autologin on?
    doas rm /etc/copal/autostart-desktop # stop the desktop starting itself
    ls /etc/inittab.bak                  # the inittab from before autologin

## Options
(none)

## Notes
- The inittab line is `getty -n -l /usr/local/bin/copal-autologin`; it
  runs `login -f` for the admin user, so no password is asked on tty1.
  That is the point, and also the cost: whoever is at the keyboard is in.
- It sets `ulimit -l unlimited` (locked memory, which keeps Ardour's and
  JACK's buffers out of swap) and `ulimit -r 95` (real-time priority); the
  desktop inherits both.
- After logging in, `~/.profile` waits five seconds and runs copal-session;
  Ctrl-C in those seconds gives you a shell instead.
- Deleting `/etc/copal/autostart-desktop` stops the desktop starting at
  boot, but the autologin stays: tty1 logs in to a shell. Undoing that
  means putting tty1's getty line in `/etc/inittab` back.
