# Grabbing Every YouTube Link from the Clipboard: A Regex Front Door for the ytq Download Queue

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

---

## Abstract

`ytq`, the yt-dlp queue that stage 10 installs, took exactly one URL from the
clipboard: `ytq clip` (Super+Shift+Y) matched the whole clipboard against a
URL pattern and gave up on anything else. The owner's real need was a browser
bookmarks export — a Netscape `bookmarks.html` of several hundred YouTube
videos, Shorts, radio mixes, channel pages and unrelated sites, with a base64
favicon on nearly every line. `ytq clip` was changed to search the clipboard
text with a regular expression that recognises YouTube *videos* anywhere in
it, reduce each hit to its 11-character video id, and queue each id once as a
plain watch URL. Channel and playlist pages are deliberately not matched. On
the owner's own export the change queued 455 distinct videos in one keypress,
and yt-dlp's check accepted each of the first ten at about 2.4 s apiece. In
the same session the queue's default download folder was moved from `~/Videos`
to `~/Downloads/SharedVM`, the guest's link to the Mac's shared folder, when
that share is mounted. Section V records the limits: the regex needs the
page's *source*, a copied rendered page carries no links, and 455 checks is a
quarter of an hour of requests.

## I. Objective

1. Let one Super+Shift+Y queue every YouTube video in whatever text is on the
   clipboard — a bookmarks export above all — rather than only a clipboard
   that is itself one URL.
2. Queue each video once, however many times and in however many forms it
   appears (`&t=`, `&list=`, `youtu.be`, Shorts).
3. Not turn one bookmark into hundreds of downloads: channels and playlists
   stay out.
4. Keep the old behaviour for a clipboard holding a single non-YouTube URL.
5. Put the files where the owner can use them from the Mac without copying.

## II. Materials

| Item | Value |
|---|---|
| Guest | Copal aarch64 under UTM on Apple Silicon; Alpine 3.24.1, kernel 6.18.50-0-virt, Hyprland |
| Interpreter | Python 3.14.7 (`ytq` is one Python file written by `install_ytq`) |
| Downloader | yt-dlp 2026.08.19, with `yt-brave` for the cookie retry |
| Clipboard | `wl-paste -n --type text/plain` (Wayland), `xclip -o -selection clipboard` (X11) |
| Shared folder | 9p over virtio at `/mnt/share`; `~/Downloads/SharedVM -> /mnt/share`, made by the shared-folder stage |
| Real input | the owner's Brave bookmarks export, pasted into the session |
| Test input | a 15-link excerpt of that export with hand-added edge cases (below) |
| Agent access | an unprivileged shell in the guest with the live Wayland display; no root |

## III. Method

The installed script was not edited in place. Every change went into the
`ytq` heredoc inside `copal-prep.sh`; the script was then cut back out of the
installer with

```sh
awk '/cat > \/usr\/local\/bin\/ytq <<.YTQ./{f=1;next} /^YTQ$/{f=0} f' copal-prep.sh > ytq.new
```

and exercised from a scratch directory, so the file that was tested is the
file a clean install writes. Two harnesses were used:

- **The extractor alone.** The script was loaded as a module with its
  `main()` call disabled and `youtube_urls()` fed the test excerpt; the output
  list was compared with the expected ids in order.
- **The command end to end.** A stub `wl-paste` on `PATH` printed a chosen
  file, and `ytq clip --no-run` ran with `HOME` and `XDG_DATA_HOME` pointed at
  a throwaway directory, so the queue file, lock and log were real but not the
  owner's. The queue file and `ytq.log` were read afterwards.

The download folder was tested through `ytq --help`, whose "in effect" line
prints the resolved `DIR`, under four homes: the real one, one whose
`Downloads/SharedVM` links to an unmounted directory, one with no link, and
one with `DIR=` in its config. A write to `/mnt/share` as the user confirmed
the share accepts files. `make lint` was run after each change. The real
bookmarks were then queued by the owner, and the outcome was read from their
`ytq.log` and `queue.json`.

## IV. Results

### A. The expression

```python
YT_RE = re.compile(r"https?://(?:(?:www|m|music)\.)?"
                   r"(?:youtube\.com/(?:watch\?(?:[^\s\"'<>#]*?&)?v=|shorts/|live/|embed/)|youtu\.be/)"
                   r"([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])")
```

Read left to right:

- `https?://(?:(?:www|m|music)\.)?` — the desktop, mobile and Music hosts.
- `watch\?(?:[^\s"'<>#]*?&)?v=` — a watch page whose `v=` is the first
  parameter or a later one (`watch?t=807&v=…`). The lazy run stops at the
  first `&v=` and cannot cross a space, a quote, `<`, `>` or `#`, so it never
  reaches out of one `HREF="…"` into the next attribute.
- `shorts/`, `live/`, `embed/`, `youtu\.be/` — the other shapes a single
  video's link takes.
- `([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])` — the id, captured, and required to
  end there: eleven id characters followed by a twelfth is not an id.

The captured group is the only part kept. `youtube_urls()` runs `findall`
over `html.unescape(text)`, drops ids already seen, and returns
`https://www.youtube.com/watch?v=ID` for each in order of first appearance.

### B. The test excerpt

| Link in the excerpt | Expected | Got |
|---|---|---|
| `watch?v=sK99WuaU_k8` (with a base64 `ICON=` on the line) | queued | queued |
| `shorts/3mxgcs10PoI` | queued as `watch?v=` | queued as `watch?v=` |
| `watch?v=EmFV-A5E5hk&list=RDu64NgDuis6g&index=2` (radio mix) | the video only | the video only |
| `watch?v=6xlmaorRY0w`, then `…6xlmaorRY0w&t=5330s` | one entry | one entry |
| `watch?t=807&v=s6rGdKY2xWo&feature=youtu.be` (`v` not first) | queued | queued |
| `watch?feature=share&amp;v=_m_jwz5hzzw` (escaped HTML) | queued | queued |
| `youtu.be/-yKLnpqfwSQ?si=abc` | queued | queued |
| `watch?v=WXpWwY4kDgI&list=RDp29-4ymTv94&index=10` | the video only | the video only |
| `/@bernadettebanner` (channel handle) | skipped | skipped |
| `/channel/UCCND6a0H56zHL4YuY226ZOQ` | skipped | skipped |
| `watch?v=tooShort` (8 characters) | skipped | skipped |
| `watch?v=0eFTrOpueYEX` (12 characters) | skipped | skipped |
| `https://www.seangoedecke.com/…`, `chrome://newtab/` | skipped | skipped |

Eight ids came out, in bookmark order. End to end, `ytq clip --no-run`
queued the eight and exited 0; a second run queued nothing ("queued 0 of 8
links; the other 8 were already in the queue"); a clipboard of
`https://vimeo.com/12345` was queued as before; plain words exited 1 with
"the clipboard holds no URL and no YouTube link".

### C. The owner's bookmarks

One Super+Shift+Y on the full export logged, at 16:56:45:

```
queued 455 of 455 links; the other 0 were already in the queue
```

Every one of the 455 entries is a plain `watch?v=` URL. The checker then
asked yt-dlp about them one at a time; the first ten were accepted between
16:56:47 and 16:57:09 — about 2.4 s each — at heights from 480p to 1920p,
with titles taken from YouTube rather than from the bookmark (`EmFV-A5E5hk`,
bookmarked as "Trim - Boat Remix", came back as "Rican Rackz - All Dis A$$").
The window doing the checking was closed at that point, which left 445
entries in `checking` for the next runner; none had been rejected.

### D. The download folder

| Home | `ytq --help` "in effect" |
|---|---|
| the guest's own, share mounted at `/mnt/share` | `DIR=~/Downloads/SharedVM` |
| `Downloads/SharedVM` linking to an unmounted directory | `DIR=~/Videos` |
| no `Downloads/SharedVM` | `DIR=~/Videos` |
| `DIR=~/Elsewhere` in `~/.config/ytq/config` | `DIR=~/Elsewhere` |

The eight files downloaded before the change were written to `~/Videos` and
had since been moved into the share by hand; `~/Videos` was empty.

## V. Discussion

**Why the id and nothing else.** A bookmarks file names the same video in
several spellings, and two of them change what yt-dlp does: `&list=` would
make the link a playlist without `--no-playlist`, and a queue keyed on the
raw URL would hold `…6xlmaorRY0w` and `…6xlmaorRY0w&t=5330s` as two jobs.
Keeping only the id and rebuilding the URL makes the queue's existing
duplicate check (`find(items, url)`) do the right thing with no change to the
queue. The cost is that a timestamp is lost, which a download never needed.

**Why channels and playlists are out.** In the owner's export they are a
handful of lines, but each one is an unbounded download. Queuing them on a
keypress meant for "these videos" would surprise; a person who wants a whole
channel can hand that URL to `ytq add` or to yt-dlp directly.

**The clipboard must hold the source.** `read_clipboard()` asks for
`text/plain`. Copying `bookmarks.html` in a file manager offers a file URI;
copying the page as Brave renders it offers the titles without their `HREF`s.
Neither contains a single match. What works is the file's text:
`wl-copy < bookmarks.html`, or select-all in a text editor. The failure is
honest — "the clipboard holds no URL and no YouTube link" — but it does not
say *why*, and that is the first thing an owner will hit.

**The size of the input is not the problem; the checks are.** The export is
mostly base64 favicons, and the whole clip — read, scan and queue — was one
log line from the keypress (its time was not measured separately). What
follows is 455 `yt-dlp --simulate` calls in series: at 2.4 s each, about
eighteen minutes before the last is marked queued, and every deleted or
private video among them sends its own "not downloadable" notification. The
queue survives the window closing (C above), so this is slow rather than
fragile.

**One notification, not 455.** `report()` used to print one line per URL.
Above five URLs it now prints one count; `ytq.log` keeps the per-URL lines.

**What is not matched.** `youtube-nocookie.com/embed/`, the old `/v/ID` form
and `attribution_link` redirects do not match, and nor do bare ids with no
URL around them. None occurred in the export. The window's clipboard watcher
and its `a` key still take a single URL; only `ytq clip` searches.

**The shared folder only when it is really there.** `~/Downloads/SharedVM`
is a symlink, and a symlink to an unmounted `/mnt/share` still resolves to a
directory — the empty mount point on the guest's disk. Downloads written
there would be hidden the moment the share mounts over them. The test is
therefore `os.path.ismount(os.path.realpath(link))`, not `os.path.isdir`.

## VI. Procedures

**Queue a bookmarks export:**

```sh
wl-copy < bookmarks.html          # X11: xclip -selection clipboard < bookmarks.html
ytq clip                          # or Super+Shift+Y
ytq run                           # unless ~/.config/ytq/auto exists
ytq status
```

**See where files will go, and change it:**

```sh
ytq --help | grep 'in effect'
echo 'DIR=~/somewhere' >> ~/.config/ytq/config
```

**Test the extractor without touching the real queue:**

```sh
awk '/cat > \/usr\/local\/bin\/ytq <<.YTQ./{f=1;next} /^YTQ$/{f=0} f' copal-prep.sh > /tmp/ytq
mkdir -p /tmp/ytqhome /tmp/ytqbin
printf '#!/bin/sh\ncat "$YTQ_CLIP"\n' > /tmp/ytqbin/wl-paste; chmod +x /tmp/ytqbin/wl-paste
HOME=/tmp/ytqhome XDG_DATA_HOME=/tmp/ytqhome/.local/share PATH=/tmp/ytqbin:$PATH \
    YTQ_CLIP=bookmarks.html python3 /tmp/ytq clip --no-run
tail -2 /tmp/ytqhome/.local/share/ytq/ytq.log
```

**Install only ytq on a running guest** (root; the rest of stage 10 is left
alone):

```sh
doas install -m 0755 -o root -g root /tmp/ytq /usr/local/bin/ytq
ytq --help | grep 'in effect'     # the new default folder confirms the new file
```

## VII. Files touched

| File | Change |
|---|---|
| `copal-prep.sh` | `install_ytq`: `YT_RE`, `youtube_urls()`, `clipboard_urls()` replacing `clipboard_url()`, `import html`, the count summary in `report()`, the `clip` branch of `main()`; `videos_dir()` prefers a mounted `~/Downloads/SharedVM`; the `ytq` header and the stage-10 guide text. Commits `5aca715`, `41aa7b0` |
| `docs/ytq-clipboard-lab-report.md` | this report |
