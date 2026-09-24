# command:  copal-ssh
# purpose:  Read and change this machine's SSH login policy: passwords, root, and who may log in.
# why:      Copal writes its SSH policy as one marked block in sshd_config. This
#           edits only that block, tests the result with `sshd -t` before
#           reloading, and puts the old file back if sshd rejects it -- so a
#           typo cannot lock you out of a machine you can only reach by SSH.
# see:      sshd, ssh-keygen, ssh-copy-id

## Use
`copal-ssh` shows the policy. The other forms need doas; each changes one
setting and reloads sshd.

## Examples
    doas copal-ssh                       # what is in force
    doas copal-ssh password off          # keys only (refused if you have no key)
    doas copal-ssh password on           # allow passwords again
    doas copal-ssh root off              # no root login over SSH
    doas copal-ssh users paul anna       # only these accounts may log in

## Options
status               password login, root login, allowed users, public keys
password on|off      allow or refuse password (and keyboard-interactive) login
root on|off          root by key only (prohibit-password), or refused
users NAME...        replace the AllowUsers list

## Notes
- `password off` refuses to act if the admin user has no
  `~/.ssh/authorized_keys`, because it would lock the machine off the
  network. Copy a key in first (`ssh-copy-id` from your computer).
- The block runs from `# >>> copal ssh policy >>>` to
  `# <<< copal ssh policy <<<`; delete it by hand and OpenSSH's own
  defaults apply. Every change leaves the previous file as
  `sshd_config.copal.bak`.
- Every form, even `status`, needs root: sshd_config is not readable
  otherwise.
