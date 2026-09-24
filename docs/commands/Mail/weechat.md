# command:  weechat
# purpose:  A terminal chat client for IRC, with a nick list, mouse support and plugins.
# why:      The catalogue's other IRC client: more on screen than irssi -- a
#           buffer list, a nick list -- and the same life in tmux on a machine
#           that stays on.
# see:      irssi, tmux, profanity

## Use
Add a server once, connect, join channels. Every channel and private
conversation is a buffer; Alt with the arrows, or Alt and a number,
moves between them.

## Examples
    weechat                              # start

    /server add oftc irc.oftc.net/6697 -tls   (in weechat) add a network
    /connect oftc                        connect to it
    /join #alpine-linux                  join a channel
    /buffer 3   or Alt-3                 switch buffer
    /set irc.server.oftc.autoconnect on   connect at every start
    /quit                                leave

## Options
-d DIR       another configuration directory
-r COMMAND   run a command after starting
-a           do not connect automatically this time
-v           the version

## Notes
- Settings are saved as they change, in `~/.config/weechat`; `/save`
  forces it.
- `/fset` is the settings browser: search a word and change it in place,
  instead of hunting through `/set`.
- Passwords belong in `/secure`, which encrypts them, not in plain
  `/set` values.
