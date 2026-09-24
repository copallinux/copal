# command:  pipe-viewer
# purpose:  Search and play YouTube from the terminal, through mpv, without a browser.
# why:      The store's YouTube client: searches, channels and playlists at a
#           prompt, played in mpv -- far lighter than a browser tab on a Pi.
# see:      ytq, mpv

## Use
Give it search words; it lists the results, numbered. Type a number to
play it in mpv; `:n` goes to the next page. With `-n` it plays sound
only.

## Examples
    pipe-viewer alpine linux tutorial    # search, then pick by number
    pipe-viewer -n lofi                  # audio only
    pipe-viewer --resolution=720p cats   # cap the video resolution
    pipe-viewer -id dQw4w9WgXcQ          # play one video by its ID
    pipe-viewer -sc copal                # search for channels

## Options
-n, --novideo        audio only
--resolution=RES     the highest resolution: 1080p, 720p, 480p...
-id, --videoids=IDS  play these video IDs
-sc, --channels      search channels
-sp, --search-pl     search playlists
--player=NAME        mpv (default), vlc
-A, --all            play all the results in order

## Notes
- On a small Pi, `--resolution=480p` or `-n` keeps playback smooth: the
  decoding is the cost, not the download.
- To keep a video, `ytq add URL` queues it for download instead.
