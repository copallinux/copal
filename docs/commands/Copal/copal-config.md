# command:  copal-config
# purpose:  System settings for Copal: users, host name, time zone, keyboard, SSH, services, boot and storage.
# why:      raspi-config's job, done with Copal's own tools: the settings a
#           Pi owner changes, in one place, in a window on the desktop or in
#           the terminal on a console.
# see:      copal-ssh, setup-alpine, rc-update

## Use
Run it; it opens a window where there is a display and terminal menus
where there is not. Choose a screen, change a setting. Most settings
write to /etc, so it asks for doas when it needs to.

## Examples
    copal-config                         # the settings, in a window or the terminal
    copal-config --tui                   # the terminal menus, even on a desktop

## Options
--tui        the terminal interface, even with a display
--help       the usage

## Notes
- Its screens: users (add one, groups), hostname, timezone, keymap,
  ssh, services (what starts at boot), boot, storage, and about.
- Each screen uses the same tools a shell would -- `setup-timezone`,
  `rc-update`, `copal-ssh` -- so a change made here and one made by hand
  agree.
- It works with GTK (yad), curses (dialog), or plain prompts, whichever
  the machine has.
