# command:  mutt
# purpose:  A terminal mail reader configured entirely in text: IMAP, SMTP, and every key rebindable.
# why:      The catalogue's configurable terminal mail client, built here with
#           IMAP, SMTP and TLS, so one config file makes it a complete client.
# see:      aerc, alpine, mail, vim

## Use
Write a `muttrc` with your servers, start it, and read mail from an
index of messages. Replies and new messages open in your editor
(`$EDITOR`), and are sent when you leave it and confirm.

## Examples
    mutt                                 # the inbox, from the config
    mutt -f imaps://you@imap.example.org/   # an IMAP mailbox without a config
    mutt -s 'Report' you@example.org < report.txt   # send from a script
    mutt -s 'Photos' -a pic.jpg -- you@example.org < note.txt   # with an attachment
    mutt -v                              # the version, and what it was built with

    j  k  Enter    (in mutt) move / open a message
    m  r  g        compose / reply / reply to all
    c              change to another mailbox;  q  quit

## Options
-f MAILBOX     open MAILBOX: a path, or imaps://user@host/
-s SUBJECT     the subject, when sending from the command line
-a FILE -- TO  attach FILE (the -- ends the attachments)
-F FILE        use FILE as the muttrc
-n             ignore the system configuration
-v             version and build options

## Notes
- The whole configuration is `~/.muttrc` (or `~/.config/mutt/muttrc`).
  The minimum: `set folder`, `set spoolfile`, `set smtp_url` and
  `set from`, with the servers as `imaps://` and `smtps://` URLs.
- This build has IMAP, SMTP and OpenSSL but not SASL, so exotic
  sign-in methods are out; a password or app password works.
- Its editor is `$EDITOR` -- nvim on a Copal machine with stage 7.
