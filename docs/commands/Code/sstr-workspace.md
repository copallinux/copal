# command:  sstr-workspace
# purpose:  One terminal window over the download queue and the archive: browse, play, verify, export.
# why:      Super+Shift+A. The Workspace over ytq's queue and the folders of
#           Static Stream captures it fills, from the staticstream checkout --
#           every action one key, and every action a command line you can read.
# see:      ytq, sstr

## Use
A column browser. Move through folders and the queue, look at a capture
in the Inspector, and send it a Service -- play, verify, export -- with one
key. Each Service is written into the Transcript as a command line before
it runs, so you see exactly what was done and can type it again.

## Examples
    sstr-workspace                       # the download queue, live
    sstr-workspace ~/Videos/archive      # browse a folder of captures

    up/down  j/k     (in the window) move
    Enter  l         open a folder;  h  back out
    Space            put the selection on the Shelf, or take it off
    p  P  s  v       play / play paced / serve / verify
    x  t  a          export / text / armor
    r  f             retry / forget a queue entry
    Q                ytq's queue as one more column;  q  leave

## Options
DIR           browse DIR instead of the queue
Space         the Shelf: a Service then goes to everything on it
d             one line per queue entry, or two

## Notes
- The archive folder is `ARCHIVE_DIR` in `~/.config/copal/media.conf`,
  then `~/.config/ytq/config` -- where ytq reads it. The player (mpv) and
  the serve address come from the same files.
- A Service that prints takes the terminal until a key is pressed; the
  window comes back after it.
