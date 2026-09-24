# command:  sstr
# purpose:  Record a stream into a .sstr file, with its order, pace and damage tolerance kept, and play it back.
# why:      The archive format ytq keeps its downloads in. Built by copal-build
#           from the staticstream checkout; `sstr export` turns captures back
#           into ordinary files whenever you want them.
# see:      ytq, sstr-workspace

## Use
`sstr record` writes a stream -- a file, or stdin -- into a capture;
`sstr play` lets it out again: to a file, to stdout at the pace it was
recorded, or to VLC or mpv over the network. Every record carries
Reed-Solomon parity (about 21 % more bytes), so a damaged capture is
repaired as it is read. Nothing is encrypted and nothing is decoded.

## Examples
    sstr record talk.sstr --input talk.mp4       # capture a file
    sstr play talk.sstr -o talk.mp4              # and back out as the file
    sstr play talk.sstr --paced | mpv -          # at the pace it was recorded
    sstr play talk.sstr --serve :8080            # serve it to a player on the LAN
    sstr verify talk.sstr                        # check it; say what was repaired
    sstr export ~/Videos/archive                 # every capture in a folder, back to files
    sstr export . -n                             # what that would write, first
    sstr config list                             # the settings in force

## Options
record OUT         capture stdin, or --input FILE, into OUT
play IN            write the stream back; -o FILE, --paced, --speed N
play IN --serve A  serve it over HTTP at HOST:PORT
verify IN          check every record and signature
export PATH...     captures or folders back to files; -r, -n, --into DIR
config             list, get, set or unset a setting
--key KEY          sign the checkpoints with this SSH key
--allowed-signers F  trust signatures by these keys, when reading
-                  as IN or OUT: stdin or stdout

## Notes
- Checkpoints are signed with your SSH key, which proves who recorded
  it; they are not encrypted. Anyone with the file can play it.
- `export` with `--remove` deletes each capture once its file is out and
  checked; without it, both stay.
- A capture can be played or served while it is still being recorded:
  `--follow` keeps going as it grows, so mpv or VLC can watch it live.
