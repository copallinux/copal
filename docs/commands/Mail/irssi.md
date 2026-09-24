# command:  irssi
# purpose:  A terminal IRC client: one window per channel, scriptable in Perl.
# why:      One of the catalogue's chat clients. IRC is where many free
#           software projects still talk -- Alpine's own channels are on OFTC --
#           and irssi runs happily in tmux on a machine that stays on.
# see:      weechat, tmux, profanity

## Use
Start it, connect to a network, join channels. Each channel is a
numbered window: Alt and a number, or `/window N`, switches to it. Run it
inside tmux and detach, and you stay in the channels while you are away.

## Examples
    irssi                                # start
    irssi -c irc.oftc.net -n yournick    # connect straight to a network

    /connect irc.oftc.net            (in irssi) connect
    /join #alpine-linux              join a channel
    /msg nick hello                  a private message
    /window 2   or Alt-2             switch window
    /quit                            leave

## Options
-c SERVER      connect to SERVER at start
-n NICK        use NICK
-p PORT        the port
--home DIR     another configuration directory

## Notes
- `/save` writes what you set up to `~/.irssi/config`; without it, a
  network added with `/network add` is gone next time.
- Networks increasingly want a registered nick: `/msg NickServ help` on
  the network explains its steps.
- Alt-number may be taken by the terminal or the desktop; `/window N`
  always works.
