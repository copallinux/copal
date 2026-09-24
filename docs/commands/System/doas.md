# command:  doas
# purpose:  Run one command as root, or as another user.
# why:      Copal's only way to root after stage 13 locks the root account. It
#           is OpenBSD's small replacement for sudo; stage 1 installs it and
#           makes your account an administrator by putting it in wheel.
# see:      apk, rc-service

## Use
Prefix a command that needs root. The rules in `/etc/doas.conf` and
`/etc/doas.d/*.conf` say who may run what; Copal's say that anyone in
`wheel` may run anything, and asks for the password once per session.

## Examples
    doas apk add htop                    # one command as root
    doas -s                              # a root shell, for several
    doas -u radbeeper id                 # a command as another user
    doas -C /etc/doas.conf               # check a rule file for mistakes
    doas -L                              # forget the remembered password now

## Options
-s          run the shell from SHELL as the target user
-u USER     run as USER instead of root
-n          never ask: fail if the rule needs a password
-L          clear the remembered authentication (the persist rules)
-C FILE     parse FILE and report errors; with a command, say permit or deny

## Notes
- The LAST matching rule wins. Rule files in `/etc/doas.d` are read in
  alphabetical order -- setup-alpine writes `20-wheel.conf` -- which is why
  Copal names its narrow no-password rules `zz-copal-halt.conf` and
  `zz-radbeeper.conf`: after the general wheel rule, so they match.
- A new group takes effect at the next login. After `adduser you wheel`,
  log out and back in before `doas` will let you through.
- `sudo` exists too: `doas-sudo-shim` turns the usual `sudo` spellings into
  doas, for scripts and habits that say sudo. There is no `/etc/sudoers`.
- Always check an edited rule with `doas -C FILE` before logging out: a
  syntax error denies everything, and with root locked that means a rescue
  from another machine.
