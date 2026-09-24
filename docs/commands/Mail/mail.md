# command:  mail
# purpose:  Send a message from a script, or read local mail, in a line or two.
# why:      The catalogue's mail for scripts (mailx), standing in for elm, which
#           Alpine no longer packages. A cron job or a build can mail a result.
# see:      mutt, alpine

## Use
Pipe a body into `mail -s SUBJECT ADDRESS` and it is handed to the
system's mail transport. Without arguments it reads the local mailbox,
`/var/mail/$USER`, the way system messages are delivered.

## Examples
    echo 'Build done' | mail -s 'copal' you@example.org   # send one line
    mail -s 'Log' you@example.org < build.log             # a file as the body
    mail -c boss@example.org -s 'Report' you@example.org < r.txt  # with a copy
    mail                                                  # read local mail
    doas apk add msmtp                                    # a way out to real servers

## Options
-s SUBJECT   the subject
-c ADDRS     carbon copies
-b ADDRS     blind carbon copies
-f FILE      read FILE as the mailbox
-v           show the delivery's conversation

## Notes
- On Copal nothing is sent until there is a way out. `mail` hands the
  message to `/usr/sbin/sendmail`, which is BusyBox's, and it only
  forwards to an SMTP server it is told about. Install `msmtp`, give it
  your server in `~/.config/msmtp/config`, and put
  `set sendmail=/usr/bin/msmtp` in `~/.mailrc`.
- This is BSD mail (mailx), not s-nail or Heirloom mailx: the `-S smtp=`
  recipes found online are for those, and do not work here.
