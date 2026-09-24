# command:  copal-install
# purpose:  Install packages from the menu's Install branch, in a terminal that stays open to say how it went.
# why:      What the menus run when you choose a program you do not have yet.
#           It installs the packages, then -- where Copal Apps is present --
#           their man pages, optionals and group access, and refreshes the
#           menu so the program is there the next time it opens.
# see:      copal-store, copal-menu, apk

## Use
You rarely type it: the menus open a terminal running it. By hand, name
the packages; a name ending `@testing` comes from Alpine's testing
repository, and one ending `@flathub` from Flathub.

## Examples
    doas copal-install htop              # one package
    doas copal-install maxima@testing    # from the testing repository
    doas copal-install com.brave.Browser@flathub   # a Flatpak (~500 MB runtime first)

## Options
PKG...          Alpine packages to install
NAME@testing    from edge/testing (the repository tag is added if needed)
NAME@flathub    a Flatpak from Flathub

## Notes
- The window waits for Enter at the end, so a failure's message can be
  read: the usual causes are no network, or a package this board's
  architecture does not have.
- It needs root, and says so: run it with doas.
- On a RAM-resident system it reminds you to `lbu commit`; an installed
  Copal machine does not need that.
