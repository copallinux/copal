# command:  ssh-keygen
# purpose:  Make SSH keys, and inspect, fix or forget them.
# why:      A key is what lets this machine push to GitHub and log in to the
#           others without a password. Stage 7 tells you to make one when a
#           checkout falls back to HTTPS; stage 16's fleet reads its host
#           certificates with it.
# see:      ssh, git

## Use
Make a key pair: a private half that stays in `~/.ssh` and a `.pub`
half you give away. Beyond that it answers questions about keys --
fingerprints, certificates -- and removes stale hosts from
`known_hosts`.

## Examples
    ssh-keygen -t ed25519 -C "$(hostname)"   # a new key (Enter for the defaults)
    cat ~/.ssh/id_ed25519.pub            # the half to paste into GitHub
    ssh-keygen -l -f ~/.ssh/id_ed25519.pub   # its fingerprint
    ssh-keygen -R 192.168.1.20           # forget a host whose key changed
    ssh-keygen -p -f ~/.ssh/id_ed25519   # add or change the passphrase
    ssh-keygen -y -f ~/.ssh/id_ed25519   # rebuild a lost .pub from the private key

## Options
-t TYPE         the key type: ed25519 (use this), rsa, ecdsa
-C COMMENT      a label stored in the key: who and where
-f FILE         the key file to make or read
-N PHRASE       the passphrase, given on the command line ('' for none)
-l              show a key's fingerprint
-R HOST         remove HOST from known_hosts
-F HOST         find HOST in known_hosts
-p              change a key's passphrase
-y              print the public key of a private one
-L              show a certificate's contents

## Notes
- The private file (`id_ed25519`, no `.pub`) never leaves the machine.
  If it is ever pasted anywhere, make a new pair.
- ssh refuses a private key others can read: "UNPROTECTED PRIVATE KEY
  FILE". `chmod 600 ~/.ssh/id_ed25519` and `chmod 700 ~/.ssh`.
- Use ed25519: short, fast, and accepted everywhere Copal connects to.
  Only very old servers need `-t rsa -b 4096`.
- Running it again over an existing key asks before overwriting -- say no
  unless you mean to replace the key everywhere it is installed.
