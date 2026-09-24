# playbook: staticstream
# source:   clone https://github.com/vonglurt/staticstream.git
# origin:   code
# build:    git rust cargo
#
# program:  ytq
# label:    ytq (download queue)
# shelf:    Code
# install:  staticstream@clone
# mode:     t
# gate:     *
# home:     https://github.com/vonglurt/staticstream
# about:    A download queue that watches the clipboard: Super+Shift+Y queues the copied link, and
#           ytq run fetches it. What it downloads is kept as Static Stream.
#
# program:  sstr-workspace
# label:    sstr-workspace (stream archive)
# shelf:    Code
# install:  staticstream@clone
# mode:     t
# gate:     *
# home:     https://github.com/vonglurt/staticstream
# about:    The terminal Workspace over the archive and the download queue in one browser. Play,
#           verify, export and read a capture on one key each.
#
# program:  sstr
# label:    sstr (record and replay streams)
# shelf:    Code
# install:  staticstream@clone
# mode:     h
# gate:     *
# home:     https://github.com/vonglurt/staticstream
# about:    Records a stream into a .sstr file with its order, pace and damage tolerance intact, and
#           plays it back. sstr export turns a folder of them into ordinary files.

# ytq: a queue in front of yt-dlp, fed by the clipboard.
#
# The habit it replaces is the terminal with twelve yt-dlp commands pasted into
# it, each waiting on the last. Copy a link and press Super+Shift+Y ('ytq
# clip'), or copy it while the ytq window is focused, and it is checked (can
# yt-dlp get it, and at what resolution?) and queued. 'ytq run' or the window
# downloads; once ~/.config/ytq/auto exists, a background runner starts by
# itself and leaves again when the queue is empty. Autostart is the user's to
# switch on, so this installer does not create that file. Downloads run one at
# a time -- queue.json is shared under a lock and run.lock admits one
# downloader -- best video plus best audio, merged to MP4 by ffmpeg, and kept
# as a Static Stream capture unless OUTPUT says otherwise. A failure goes to
# the back of the queue for one more try; a failure that reads as a login, an
# age gate or a bot check opens Brave on the URL and, once you have signed in
# there and run 'ytq cookies' (or pressed 'c'), retries once through yt-brave.
#
# YTQ IS NO LONGER WRITTEN HERE. It was one Python file this function wrote
# into /usr/local/bin. It is Rust now, in the staticstream checkout at
# ~/code/staticstream, and copal-build compiles it into ~/.local/bin beside
# sstr and sstr-workspace. ~/.local/bin comes before /usr/local/bin on Copal's
# PATH, so that is the ytq Super+Shift+Y and every typed 'ytq' reach. The
# queue file, both locks, the log, the settings and the commands are the same
# ones, which is how the two were run side by side until the Rust one passed
# every comparison; what changed is that a download is kept as a .sstr by
# default. The Python ytq is kept as the specification those comparisons still
# run against, at staticstream's tests/reference/ytq.py.
#
# What is still this function's business is everything around ytq: yt-dlp
# itself, /etc/yt-dlp.conf so a yt-dlp run by hand names files the same way,
# yt-brave for the cookie retry, and the programs ytq calls out to --
# wl-clipboard and xclip to read the clipboard, xdotool to ask X11 which
# window has focus, libnotify to say a download is done.
staticstream_post() {
    command -v yt-dlp >/dev/null 2>&1 || return 0
    [ -x /usr/local/bin/yt-brave ] || install_ytbrave
    write_ytdlp_conf
    add_optional wl-clipboard xclip xdotool libnotify

    # The Python ytq this function used to write, retired. It is removed only
    # when it is the file Copal wrote -- its header is unmistakable -- so a ytq
    # someone put there themselves is left alone.
    if [ -f /usr/local/bin/ytq ] && \
       head -8 /usr/local/bin/ytq | grep -q 'a yt-dlp download queue that watches the clipboard'; then
        rm -f /usr/local/bin/ytq
        note "removed the Python ytq from /usr/local/bin -- ytq is Rust now, from ~/code/staticstream"
    fi

    write_media_conf

    note "ytq -- a download queue: Super+Shift+Y queues the clipboard's URL, 'ytq run' downloads"
    note "  it is built from ~/code/staticstream:  copal-build staticstream   (into ~/.local/bin)"
    note "  to have it start downloading by itself:  touch ~/.config/ytq/auto   (ytq --help)"
    note "  what a download leaves:  OUTPUT in ~/.config/copal/media.conf   (mp4 as installed)"
    note "  the Workspace over what it keeps:  Super+Shift+A, or 'sstr-workspace'  -- the archive"
    note "  and the queue in one Browser, with Play, Verify, Export and Text on one key;"
    note "  X over a folder exports every capture in it  (or 'sstr export DIR' in a shell)"
}
