# command:  alpine
# purpose:  The pine mail reader, continued: menus on screen, IMAP and SMTP built in.
# why:      The catalogue's gentlest terminal mail client, and the heir to elm,
#           which Alpine no longer packages. Every key it takes is listed at the
#           foot of the screen.
# see:      mutt, aerc, mail

## Use
Set up your account once in Setup, then read, write and file mail with
the single-letter commands shown at the bottom of every screen. It talks
to an IMAP server for reading and an SMTP server for sending, so the mail
stays on the server.

## Examples
    alpine                               # start; the main menu
    alpine you@example.org               # straight to composing a message
    alpine -f INBOX                      # open a folder directly
    alpine -i                            # straight to the message index

    S  C           (in alpine) Setup, then Config: server names, your address
    I  L           the message index / the folder list
    C  R  F        compose / reply / forward
    Ctrl-X         send, from the composer;  Q  quit

## Options
ADDRESS      start composing to ADDRESS
-f FOLDER    open FOLDER
-i           start in the index
-I KEYS      type these keys at start (a script of commands)
-p FILE      use FILE as the configuration instead of ~/.pinerc
-d N         debug level

## Notes
- Server names go in Setup > Config: `inbox-path` as
  `{imap.example.org/ssl/user=you}INBOX`, and `smtp-server` as
  `smtp.example.org/submit/user=you` -- the braces and slashes are
  alpine's own syntax.
- The configuration is `~/.pinerc`; the Setup screens write it for you.
- Gmail and most large providers want an app password, not your normal
  one, for a program like this.
