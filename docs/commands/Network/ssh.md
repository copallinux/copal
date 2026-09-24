# command:  ssh
# purpose:  Log in to another machine, or run one command on it, over an encrypted connection.
# why:      How a Copal machine is reached from the Mac, and how it reaches
#           GitHub and the others. Stage 1 turns on sshd; stage 6 authorises
#           the Mac's key, so the first login needs no password.
# see:      ssh-keygen, rsync, tmux, curl

## Use
`ssh user@host` opens a shell there; `ssh host command` runs one command
and returns. The same connection carries files (`scp`, `rsync`,
`sshfs`) and ports (`-L`). A key instead of a password is set up once,
with `ssh-keygen` and `ssh-copy-id`.

## Examples
    ssh you@192.168.1.20                 # a shell on another machine
    ssh pi 'df -h /'                     # one command, then back
    ssh -p 2222 you@example.org          # sshd on another port
    ssh -L 8080:localhost:80 pi          # the Pi's port 80 as localhost:8080 here
    ssh -J gateway you@inside            # through a machine in between
    ssh-copy-id you@192.168.1.20         # install your key there, once
    ssh -v pi                            # say why a connection fails

## Options
-p PORT           connect to this port
-i FILE           use this private key
-L L:HOST:R       forward local port L to HOST:R, from the far side
-R R:HOST:L       the reverse: a port there comes back here
-J HOST           jump through HOST first
-N                no command: just hold the forwards open
-t                force a terminal, for an interactive program: ssh -t pi htop
-o KEY=VALUE      any config option, for once
-v                debug output; -vvv for more

## Notes
- `~/.ssh/config` saves typing: a `Host pi` block with `HostName`,
  `User` and `Port` makes `ssh pi` enough, and scp, rsync and git use
  it too.
- "REMOTE HOST IDENTIFICATION HAS CHANGED" after reinstalling a card is
  expected: the new system made new host keys. Remove the old one with
  `ssh-keygen -R HOST`, then connect again. Anywhere else, stop and ask why.
- A frozen session (the far side went away) does not answer Ctrl-C.
  Type Enter, then `~.` -- ssh's escape -- and it closes.
- Password refused although it is right? Copal can turn password logins
  off: `copal-ssh status` says what is in force on the machine you are
  connecting to.
