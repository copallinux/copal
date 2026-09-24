# command:  croc
# purpose:  Send a file or a folder to another computer, with a code phrase, from one command.
# why:      The catalogue's quickest way to hand a file to someone: no shared
#           network, accounts or server set-up. Encrypted end to end.
# see:      rsync, syncthing, darkhttpd

## Use
The sender runs `croc send FILE` and gets a code phrase. The receiver
runs croc with that phrase, on any machine with croc, and the file
arrives. Both sides meet through a relay, which never sees the contents.

## Examples
    croc send photo.jpg                  # prints a code phrase to pass on
    croc send ~/Documents/report         # a whole folder
    croc send --text 'meet at 3'         # a line of text
    CROC_SECRET=7-lemon-orbit-jazz croc  # receive, with the phrase you were given

## Options
send FILE...     send files or folders
send --text T    send a line of text instead of a file
send --code P    choose the phrase yourself
--yes            accept without asking (receiving)
--relay ADDR     use another relay, such as your own
--classic        accept the phrase as an argument (less safe)

## Notes
- On Linux the phrase goes in `CROC_SECRET`, not on the command line,
  where other users could see it in the process list: croc refuses it
  as an argument and says so. `--classic` restores the old way.
- The default relay is a public one run by croc's author; `croc relay`
  runs your own.
