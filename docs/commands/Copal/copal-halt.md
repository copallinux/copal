# command:  copal-halt
# purpose:  End the session, and the machine, in one step: shut down, restart or log out, asking first.
# why:      Super+Shift+P and Session in the menu both run it. It closes the
#           desktop properly first, so programs are asked to quit, then powers
#           down -- from a terminal, a console or SSH alike, without typing the
#           root password.
# see:      doas, rc-service

## Use
With no argument it asks, then shuts down. `reboot` restarts, `logout`
leaves the desktop and keeps the machine running. `-y` skips the
question.

## Examples
    copal-halt                           # shut down (asks first)
    copal-halt reboot                    # restart
    copal-halt logout                    # leave the desktop
    copal-halt -y reboot                 # restart without asking

## Options
(none)        shut down, after asking
reboot        restart
logout        end the desktop session only
-y, --yes     do not ask
-h, --help    the usage

## Notes
- It needs no password: a narrow doas rule, `zz-copal-halt.conf`, lets
  your account run only this. That rule is named to sort after the
  general wheel rule, because in doas the last match wins.
- Inside i3 it closes the session first, so unsaved work gets its
  prompt before the power goes.
