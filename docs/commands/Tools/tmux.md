# command:  tmux
# purpose:  Several shells in one terminal, and sessions that outlive the connection.
# why:      Stage 7 installs it for work over SSH: a build or an install left
#           running in tmux survives the laptop closing, and a Pi with no
#           desktop gets split panes on its one console.
# see:      ssh, abduco

## Use
Start a session, run things in its windows and panes, detach, and attach
again later -- from the same machine or over SSH from another. Every key
starts with the prefix, Ctrl-b.

## Examples
    tmux                                 # a new session
    tmux new -s build                    # a new session called build
    tmux attach -t build                 # back into it, from anywhere
    tmux ls                              # the sessions running
    tmux kill-session -t build           # end one

## Options
Ctrl-b d      detach: the session keeps running
Ctrl-b c      a new window
Ctrl-b %      split into left and right panes
Ctrl-b "      split into top and bottom panes
Ctrl-b z      zoom the pane to the full window, and back
Ctrl-b [      copy mode: scroll back with the arrows, q to leave
Ctrl-b s      choose a session from a list
Ctrl-b ?      every key binding

## Notes
- Scrolling with the mouse wheel shows the terminal's scrollback, not the
  pane's, until `set -g mouse on` is in `~/.tmux.conf` (or
  `~/.config/tmux/tmux.conf`). Copal writes no tmux config: these are
  tmux's defaults.
- A session survives a lost SSH connection, not a reboot.
- Inside Neovim, Escape feels slow under tmux: `set -sg escape-time 10`
  in the config fixes it.
