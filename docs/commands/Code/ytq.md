# command:  ytq
# purpose:  A download queue that watches the clipboard, and keeps what it fetches as Static Stream.
# why:      Copy a video's link, press Super+Shift+Y, and it is queued. Built by
#           copal-build from the staticstream checkout in ~/code; the Rust ytq
#           replaced the Python one Copal used to write.
# see:      sstr, sstr-workspace, copal-build

## Use
Queue links, then download them one at a time with yt-dlp, best video and
audio merged. The queue is one file shared by every ytq at once, so
`ytq add` works while `ytq run` is downloading. Each download also gets a
`.txt` beside it: the full title, author, URL, dates, the description and
the captions, so it can be cited later.

## Examples
    ytq                                  # the queue window; queues the clipboard's URL
    ytq clip                             # queue what is on the clipboard (Super+Shift+Y)
    ytq add https://youtu.be/dQw4w9WgXcQ # queue a URL from the shell
    ytq run                              # download everything queued, here
    ytq status                           # what is downloading, and what is left
    ytq list                             # every entry: queued, done, waiting, failed
    ytq transcript URL                   # only the captions, as text
    ytq cookies                          # retry what waited for a Brave sign-in
    touch ~/.config/ytq/auto             # start downloading by itself from now on

## Options
clip              queue the clipboard's URL, or every YouTube link in it
add URL...        queue URLs
run               download the queue in this terminal
status / list     the current download / every entry
retry URL         put an entry back (r in the window)
forget URL        take one out; the downloaded file stays (d)
clear             forget finished and failed entries; files and log stay
cookies           retry the entries waiting on a sign-in (c)
--mp4             keep the video file, write no capture
--sstr            keep a Static Stream capture, remove the video once checked
--both            keep the two
--run / --no-run  start a runner this once / never

## Notes
- Nothing downloads until something runs the queue: `ytq run`, the
  window, or autostart (`~/.config/ytq/auto`). Without that file, clip and
  add only queue.
- A login, age gate or "confirm you are not a bot" page opens Brave on
  the URL: sign in there, then `ytq cookies`. A second failure is final.
- What it keeps by default is a `.sstr` capture, not a video file.
  `sstr export DIR` turns a folder of them back into ordinary files.
- The log is `~/.local/share/ytq/ytq.log`; the queue is
  `~/.local/share/ytq/queue.json`.
