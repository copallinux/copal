# command:  aerc
# purpose:  A modern terminal mail client: tabs, vim-style keys, and a setup wizard.
# why:      The catalogue's newest terminal mail client: it walks you through
#           the account on first start, keeps several mailboxes in tabs, and
#           opens the editor in a terminal inside itself.
# see:      mutt, alpine, vim

## Use
Start it; the first time, a wizard asks for your address and servers and
writes the account file. After that it is tabs of mailboxes and messages,
with the keys and `:commands` of vim.

## Examples
    aerc                                 # start; the wizard on first run
    aerc mailto:you@example.org          # compose to an address

    j  k  Enter    (in aerc) move / open a message
    C  Rr  rr      compose / reply / reply to all
    :new-account   run the wizard for another account
    Ctrl-N Ctrl-P  next / previous tab;  q  close a message, or quit

## Options
-A FILE        another accounts.conf
-C FILE        another aerc.conf
-v             the version
mailto:URL     start composing to that address

## Notes
- Accounts are in `~/.config/aerc/accounts.conf`, passwords included
  unless a `source-cred-cmd` fetches them: keep that file private
  (`chmod 600`).
- The keys are its `binds.conf`; `:help keys` lists what is bound.
- HTML mail shows as text only when a filter is configured; the
  default filters are in `aerc.conf`'s `[filters]` section.
