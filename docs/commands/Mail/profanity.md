# command:  profanity
# purpose:  A terminal XMPP (Jabber) chat client, with OMEMO encryption.
# why:      The catalogue's XMPP client: chat on a federated network from a
#           terminal, end to end encrypted, on any machine -- over SSH too.
# see:      irssi, weechat

## Use
Connect with your XMPP address, then chat with contacts or join rooms.
Each conversation is a window, switched with Alt and a number. `/help`
lists every command.

## Examples
    profanity                            # start
    profanity -a you@example.org         # connect as that account at once

    /connect you@example.org   (in profanity) sign in
    /msg friend@example.org    open a chat
    /join room@conference.example.org   join a room
    /omemo gen                 make this device's encryption keys
    /quit                      leave

## Options
-a ACCOUNT     connect with a saved account
-l LEVEL       log level
-v             the version

## Notes
- `/account add NAME` saves an account so `-a NAME` and `/connect NAME`
  work; settings go to `~/.config/profanity/profrc`.
- OMEMO is per device: after `/omemo gen`, start it in a chat with
  `/omemo start`, and trust the other side's fingerprints when asked.
