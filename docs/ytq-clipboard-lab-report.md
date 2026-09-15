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

A day later, two more changes (Sections IV-E to IV-G). Filenames, from both
`ytq` and plain `yt-dlp`, are now the title and the video id in the URL-safe
base64 alphabet (`A-Z a-z 0-9 - _`) and nothing else before the extension,
done with yt-dlp's own metadata options rather than a rename. And a YouTube
download in `ytq` now leaves its captions as plain text in a `.txt` of the
same name. That fetch had to be a second yt-dlp run: a test showed that a
caption download which fails makes the whole run exit 1, `-i` or not, even
though the video was written.

The owner's first real download with those changes (Sections IV-H to IV-K)
sat on a merge for three minutes with nothing on screen and then stopped, and
the log said nothing past the command. The cause of the blank screen was
older than the day's work: `--print`, which `ytq` has long used for its
`FILE` line, puts yt-dlp in quiet mode, and quiet mode hides the progress
lines the window read. `ytq` now asks for them back (`--progress
--no-quiet`), keeps a live record of each download's step in the queue,
shows it above the window's list and in `ytq status`, and logs every yt-dlp
line, the time taken by each step, and why a download stopped. The caption
default also narrowed to exact names after `en.*` proved to select
machine translations.

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
6. Name every file, from `ytq` and from `yt-dlp` run by hand, with only the
   characters of the base64 alphabet, keeping the title and, for YouTube,
   the video id.
7. Keep a text transcript of each YouTube video, paired with its download.
8. Show, in the window, what a download under way is doing: which part, how
   far, merging, the transcript.
9. Log enough to tell afterwards what a download did and why it stopped.

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
| Filename input | twelve hand-written `.info.json` files (made-up titles and ids), read with `--load-info-json` so no network was involved |
| Caption input | a local `python3 -m http.server` for the failure test; YouTube's own captions for `jNQXAC9IVRw` (uploader's) and `Q2pe-7RNJRM` (automatic) |
| Stand-in yt-dlp | a Python script first on `PATH` that answers `--version`, `--simulate` and `--skip-download`, and for a download prints real yt-dlp lines slowly: two parts of 7.6 and 1.9 MiB, then a merge that grows `NAME.temp.mp4` by 1 MB every 0.5 s |
| Terminal capture | tmux, a detached 112 × 30 session, read with `capture-pane -p` |
| Agent access | an unprivileged shell in the guest with the live Wayland display; no root (the owner ran the `doas install` steps) |

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

The filename rule was first tried as bare command-line options, then as the
`/etc/yt-dlp.conf` body cut out of the installer the same way as `ytq`
(`awk "/cat > \/etc\/yt-dlp.conf <<'CONF'/{f=1;next} /^CONF\$/{f=0} f"`) and
loaded with `--ignore-config --config-locations`, printing `--print filename`
for each test title. That the real file is read was checked in yt-dlp's
source: `get_system_config_dirs()` yields `/etc/yt-dlp`, and the loader tries
`/etc/yt-dlp.conf` before `/etc/yt-dlp/config`. The agent had no root, so
`/etc` itself was not written.

Caption failure was tested with an info file whose one format was served by
the local HTTP server and whose `en` subtitle pointed at `127.0.0.1:9`, where
nothing listens; a second file pointed the subtitle at the server. Each ran
with `--write-subs`, with and without `-i`, and the exit code and the files
left were recorded. The caption format was taken from real downloads with
`--skip-download --write-subs --write-auto-subs`. The changed `ytq` was then
run end to end, as before, under a throwaway `HOME` whose config set `DIR`
to a scratch folder.

The stalled download was read after the fact from the owner's `ytq.log`,
`queue.json`, the files in `~/Downloads/SharedVM` and `pgrep`. yt-dlp's
output was then compared with and without `--progress --no-quiet`, on the
19-second video, with the command `ytq` runs.

The status display could not be tested on a real download: the one short
enough to fetch quickly finishes each step in well under the one second
between queue writes. The stand-in yt-dlp stretched the same lines over
about eleven seconds. It was used three ways, each with its own `HOME`:
`ytq run --quiet` with `ytq status` sampled at 4.5 s (mid-part) and 10.5 s
(mid-merge); the same run sent SIGTERM at 9.5 s; and the window itself in
tmux, captured at 5.0 s and 11.5 s and then sent `q`. A fake `wl-paste` that
prints nothing, and unset display variables, kept the window away from the
real clipboard. The real 19-second video was then run once more for its log.
Caption selection was read without fetching captions, from
`--simulate --print '%(requested_subtitles)j'` for each candidate `SUBS`.

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

### E. Filenames

The options, as `/etc/yt-dlp.conf` holds them (`ytq` passes the same list as
`NAME_OPTS`):

```
--parse-metadata '%(title)#S:(?s)(?P<safe_title>.+)'
--replace-in-metadata safe_title '[^A-Za-z0-9_-]+' _
--replace-in-metadata safe_title '[-_]*_[-_]*' _
--replace-in-metadata safe_title '(?<=^.{120}).+' ''
--replace-in-metadata safe_title '^[-_]+|[-_]+$' ''
--parse-metadata 'id:(?s)(?P<safe_id>.+)'
--replace-in-metadata safe_id '[^A-Za-z0-9_-]+' _
-o '%(safe_title&{}_|)s%(safe_id)s.%(ext)s'
```

`%(title)#S` is `--restrict-filenames` applied to one field: accented Latin
letters become ASCII, anything else outside ASCII is blanked. The regexes
then keep only the alphabet, turn each run of separators that contains a `_`
into one `_`, cut at 120 characters and trim both ends. `&{}_|` writes the
title and a `_` only when a title is left.

| Title (made up; ten of the twelve) | Id | Name |
|---|---|---|
| `Café Tour: Part 2/3 [4K]` | `dQw4w9WgXcQ` | `Cafe_Tour_Part_2_3_4K_dQw4w9WgXcQ.mp4` |
| `Beyoncé — Straße Œuvre: Ærø / façade? *100* "quoted" it's` | `-abcdEFGH_9` | `Beyonce_Strasse_OEuvre_AEro_facade_100_quoted_it_s_-abcdEFGH_9.mp4` |
| `Spider-Man: No Way Home -- Trailer!!!` | `FFFFFFFFFFF` | `Spider-Man_No_Way_Home_Trailer_FFFFFFFFFFF.mp4` |
| `Cafe` + U+0301 (decomposed é) + ` del Mar` | `CCCCCCCCCCC` | `Cafe_del_Mar_CCCCCCCCCCC.mp4` |
| `Tour 日本 × part—two ...` | `GGGGGGGGGGG` | `Tour_part_two_GGGGGGGGGGG.mp4` |
| `日本語のタイトル` | `AAAAAAAAAAA` | `AAAAAAAAAAA.mp4` |
| `- Title - ` | `_HHHHHHHHHH` | `Title__HHHHHHHHHH.mp4` (the second `_` is the id's) |
| `multi` newline `line` tab `title...  .hidden` | `BBBBBBBBBBB` | `multilinetitle_hidden_BBBBBBBBBBB.mp4` |
| 300 × `x` (Generic extractor) | `some.id+with/slash=` | 120 × `x` then `_some_id_with_slash_.mp4` |
| `A Vimeo clip: part 2/3` (Vimeo) | `123456789` | `A_Vimeo_clip_part_2_3_123456789.mp4` |

Across all twelve names, `grep '[^A-Za-z0-9_-]'` on the part before `.mp4`
found nothing. The same options given twice — the config and again on the
command line, as happens when `ytq` runs with `/etc/yt-dlp.conf` present —
gave identical names, a command-line `-o` with a directory won over the
config's, and `--print title` still printed the original title.

Two earlier versions failed. The first ran the regex *before* `#S` and let
`#S` squeeze and trim; it does neither in a template (the Café title came out
`Cafe_Tour_Part_2_3_4K__dQw4w9WgXcQ.mp4`, and an all-Japanese title
`__AAAAAAAAAAA.mp4`). Called directly, `sanitize_filename(s, restricted=True)`
trims only when `is_id=False` is also passed. The second step of that version
also needed a `̀-ͯ` range for decomposed accents, which the editing
tool wrote into the file as the raw combining characters: it still worked,
but the characters could not be seen. Running `#S` first removed the need for
both.

### F. A caption download that fails

| Subtitle URL | Flags | Exit | Files left |
|---|---|---|---|
| `127.0.0.1:9` (refused) | `--write-subs` | 1 | the `.mp4` |
| `127.0.0.1:9` (refused) | `--write-subs -i` | 1 | the `.mp4` |
| the local server | `--write-subs` | 0 | the `.mp4` and `.en.vtt` |
| the local server | `--write-subs -i` | 0 | the `.mp4` and `.en.vtt` |

The refused case retried ten times, then logged `ERROR: … Giving up after
10`. In `ytq`, exit 1 from a download means `retry` or, when the message has
a word like `403`, a Brave sign-in.

### G. Transcripts

The uploader's captions for `jNQXAC9IVRw` came as `en`, one cue per
subtitle. The automatic captions for `Q2pe-7RNJRM` came as two files,
`.en-orig.vtt` and `.en.vtt`. Each cue there repeats the line before it, a
10 ms cue repeats it again, and the words carry inline timings
(`come<00:00:53.600><c> on</c>`). `vtt_text()` skips the header block and the
timing lines, removes tags, unescapes entities, drops a line equal to the one
before it, and wraps what is left at 78 columns. Both automatic files came
out as the same three words in order, none repeated.

End to end, with `DIR` set to a scratch folder:

| Command | Result |
|---|---|
| `ytq transcript https://youtu.be/jNQXAC9IVRw` | `Me_at_the_zoo_jNQXAC9IVRw.txt`, exit 0; no `.vtt` left |
| `ytq transcript https://example.com/x` | "not a YouTube video", exit 1 |
| `ytq add --no-run …jNQXAC9IVRw` then `ytq run --quiet` | `Me_at_the_zoo_jNQXAC9IVRw.mp4` (744 413 bytes, 240p) and `.txt` (290 bytes); entry `done` |
| the same with `SUBS=` in the config | the `.mp4` only |

The `.txt` begins with the title, the URL and `captions: en`, then a blank
line and the text. The log for the queued run read `queued … [240p mp4]` at
08:05:09, then `transcript: …` and `done: Me_at_the_zoo_jNQXAC9IVRw.mp4 +
transcript` at 08:05:15. Those six seconds cover the video and the caption
run together; the caption run was not timed on its own.

### H. The first real download, and what it left

The new `ytq` and `/etc/yt-dlp.conf` were installed at 08:13. The owner then
queued a 1080p video, `mkPc3DCZ-Ec`, from the window.

| Time | Evidence |
|---|---|
| 08:13:56 | log: `added`; 08:13:59 `queued … [1080p mp4]` |
| 08:14:00 | log: `run: yt-dlp --parse-metadata …` (the new filename options). Nothing further was logged for this video |
| 08:14 | `…_mkPc3DCZ-Ec.f299.mp4`, 816 606 929 bytes, and `…_mkPc3DCZ-Ec.f140-19.m4a`, 23 231 557 bytes, finished |
| 08:17:05 | last write to `…_mkPc3DCZ-Ec.temp.mp4`, 840 761 778 bytes |
| 08:17:42 | no `ytq`, `yt-dlp` or `ffmpeg` process; the entry `queued`, `attempts` 0 |

Both parts had arrived within the minute. The three minutes after were
ffmpeg writing the merged file to the 9p share, and the merge was stopped
while the temporary file was already a little larger than the two parts
together. An entry put back as `queued` with its attempt count handed back is
what `stop_current()` does when the window closes, so the window was most
likely closed; the log did not record it, which is the gap Section IV-K
fills. A second abandoned `.temp.mp4`, of 651 951 138 bytes, dated from
2026-09-14 18:07, when several downloads had been logged as `exited -15`.

### I. What `--print` had been hiding

The command `ytq` ran, on `jNQXAC9IVRw` with a pipe for output, printed a
JavaScript-runtime warning and the `FILE` line, and nothing else: no
progress line, no `[download] Destination`, no `[Merger]`. yt-dlp's help
says why: `--progress` "Show progress bar, even if in quiet mode", and
`--print` implies quiet. With `--progress --no-quiet` added, the same run
printed the extraction lines, `[info] jNQXAC9IVRw: Downloading 1 format(s):
133+140`, a `Destination` and progress lines for each part,
`[Merger] Merging formats into "…mp4"` and one `Deleting original file` line
per part, and still the `FILE` line. With this yt-dlp, then, the command as
it stood gave `ytq` no progress line to read, and the list's progress column
could only say `starting`. Earlier yt-dlp versions were not tried.

The new progress template gives, per update, `_percent_str`,
`downloaded_bytes`, `total_bytes`, `total_bytes_estimate`, `_speed_str`,
`_eta_str`, `_elapsed_str`, `fragment_index`, `fragment_count`, and from the
format being fetched `format_id`, `vcodec`, `acodec`, `height`, with the
`status`. Byte counts are raw so parts can be added up. On the real video
the finishing line of each part read, for example,
`100.0%|NA| 422.93KiB|…|133|avc1.4d400c|none|240|finished`: at `finished`,
`downloaded_bytes` can be `NA` and `total_bytes` is what is left.

### J. The status display

Each download's live record is kept in its queue entry, because the process
downloading (a background runner) is often not the one looking (the window,
or `ytq status`). The step comes from yt-dlp's own lines:

| yt-dlp line | Step |
|---|---|
| `[info] ID: Downloading 1 format(s): 299+140` | starting; 2 parts, formats 299 and 140 |
| `[download] Destination: …` | downloading, part N |
| `[download] … has already been downloaded` | already on disk, part N |
| `[Merger] Merging formats into "…"` | merging |
| `[Fixup…]`, `[FFmpeg…]`, `[Embed…]` | post-processing |
| `Deleting original file …` | removing the part files |
| (after exit 0, YouTube, `SUBS` set) | fetching the transcript |

The record is written to the queue once a second, and at once when the step
changes. `ytq status` from another process, mid-part and mid-merge:

```
  downloading  Fake Title   1080p mp4
    now      downloading part 1 of 2: video f299 avc1.64002a 1080p  (for 0:02)
    progress [#########################---------------] 62.5%  4.8 MiB of 7.6 MiB  2.00MiB/s  eta 00:03
    overall  attempt 1, plain yt-dlp, started 0:03 ago, runner pid 13298
    file     Fake_Title_FAKEID0000A.f299.mp4

    now      merging the video and audio into one file (ffmpeg)  (for 0:02)
    progress [########################----------------] ~60%  5.7 MiB written of about 9.5 MiB
    overall  attempt 1, plain yt-dlp, started 0:09 ago, 9.5 MiB fetched in 2 parts, runner pid 13298
    file     Fake_Title_FAKEID0000A.mp4
    yt-dlp   [Merger] Merging formats into "…/Fake_Title_FAKEID0000A.mp4"
```

The window drew the same block above its list, with a `>` title line and a
rule under it, and the list's row read `1/2 62.5% 2.00MiB/s eta 00:03` (the
first capture cut it at `eta 00:0`; the cap was raised from 28 to 40
characters). Merging showed `~70%  6.7 MiB written of about 9.5 MiB` at
11.5 s. For the owner's download in H, at the moment it stopped, that line
would have read `~100%  801.8 MiB written of about 800.9 MiB`, with the
time since the merge began.

Two samples in the first stand-in run showed no progress line at all: each
fell in the second after a `Destination` line, before the next queue write
had any figures. The samples above were taken later in each part.

### K. The log

The real video's run, trimmed of paths:

```
[13929] runner 'run --quiet' took run.lock: ytq …/bin/ytq of 2026-09-15 08:30, yt-dlp 2026.08.19, python 3.14.7; DIR=…/out FORMAT=… SUBS=en,en-orig,en-US,en-G…
[13929] queued Me at the zoo [240p mp4] https://www.youtube.com/watch?v=jNQXAC9IVRw (checked in 2.6 s)
[13929] jNQXAC9IVRw: attempt 1 at Me at the zoo, into …/out
[13929] jNQXAC9IVRw: yt-dlp: [youtube] Extracting URL: https://www.youtube.com/watch?v=jNQXAC9IVRw
[13929] jNQXAC9IVRw: yt-dlp: [youtube] jNQXAC9IVRw: Downloading webpage
[13929] jNQXAC9IVRw: yt-dlp: WARNING: [youtube] No supported JavaScript runtime could be found. …
[13929] jNQXAC9IVRw: yt-dlp: [youtube] jNQXAC9IVRw: Downloading visionos player API JSON
[13929] jNQXAC9IVRw: yt-dlp: [youtube] jNQXAC9IVRw: Downloading m3u8 information
[13929] jNQXAC9IVRw: yt-dlp: [info] jNQXAC9IVRw: Downloading 1 format(s): 133+140
[13929] jNQXAC9IVRw: now starting (the step before took 0:02)
[13929] jNQXAC9IVRw: yt-dlp: [download] Destination: …/out/Me_at_the_zoo_jNQXAC9IVRw.f133.mp4
[13929] jNQXAC9IVRw: now downloading part 1 of 2: f133 (the step before took 0:00)
[13929] jNQXAC9IVRw: part 1 done: video f133 avc1.4d400c 240p, 422.9 KiB in 00:00:00 at 2.98MiB/s
[13929] jNQXAC9IVRw: yt-dlp: [download] Destination: …/out/Me_at_the_zoo_jNQXAC9IVRw.f140.m4a
[13929] jNQXAC9IVRw: now downloading part 2 of 2: f140 (the step before took 0:00)
[13929] jNQXAC9IVRw: part 2 done: audio f140 mp4a.40.2, 302.0 KiB in 00:00:00 at 2.91MiB/s
[13929] jNQXAC9IVRw: yt-dlp: [Merger] Merging formats into "…/out/Me_at_the_zoo_jNQXAC9IVRw.mp4"
[13929] jNQXAC9IVRw: now merging the video and audio into one file (ffmpeg) (the step before took 0:00)
[13929] jNQXAC9IVRw: yt-dlp: Deleting original file …/out/Me_at_the_zoo_jNQXAC9IVRw.f140.m4a (pass -k to keep)
[13929] jNQXAC9IVRw: now removing the part files (the step before took 0:00)
[13929] jNQXAC9IVRw: yt-dlp: Deleting original file …/out/Me_at_the_zoo_jNQXAC9IVRw.f133.mp4 (pass -k to keep)
[13929] jNQXAC9IVRw: file …/out/Me_at_the_zoo_jNQXAC9IVRw.mp4
[13929] jNQXAC9IVRw: yt-dlp exited 0 after 0:02, last step: removing the part files
[13929] jNQXAC9IVRw: …/out/Me_at_the_zoo_jNQXAC9IVRw.mp4 is 727.0 KiB
[13929] jNQXAC9IVRw: fetching the transcript, captions en,en-orig,en-US,en-GB
[13929] jNQXAC9IVRw: transcript run exited 0 after 0:02
[13929] jNQXAC9IVRw: captions written: Me_at_the_zoo_jNQXAC9IVRw.en.vtt
[13929] jNQXAC9IVRw: wrote …/out/Me_at_the_zoo_jNQXAC9IVRw.txt: 39 words from the en captions
[13929] jNQXAC9IVRw: transcript: …/out/Me_at_the_zoo_jNQXAC9IVRw.txt
[13929] done: Me_at_the_zoo_jNQXAC9IVRw.mp4 + transcript
[13929] runner 13929: the queue is empty, leaving
```

Paths are shortened to `…` and the warning, the runner line and the
`FORMAT` value are cut; the two `run:` lines, with each full command, are
left out. The runner line names the ytq file and its date. That line alone
would have settled the morning's question of whether the new `ytq` was
installed.

Stops, from the stand-in runs:

| Stopped by | Log line |
|---|---|
| SIGTERM to `ytq run --quiet` at 9.5 s | `FAKEID0000A: stopping yt-dlp (pid 13517) while merging, 0:08 in, because 'ytq run' was interrupted (Ctrl+C, SIGTERM or SIGHUP). Back in the queue; finished parts and .part files stay, and the next attempt picks them up.` |
| `q` in the window at 11.5 s | `window closed`, then `FAKEID0000A: stopping yt-dlp (pid 13706) while merging, 0:10 in, because the window was closed. …` |

Both left the two part files and the `.temp.mp4`, and the entry `queued`.
A runner that finds an entry still marked `downloading` now logs it, with
the step it was on, before putting it back.

The first version logged every yt-dlp line, and the real run's log held
21 `[MetadataParser]` lines, seven for each time the filename options were
applied. There were three: `ytq`'s own options, `/etc/yt-dlp.conf`, and a
`yt-dlp.conf` in the scratch directory the test ran from. yt-dlp's "Home"
configuration, with no `-P home:`, is `yt-dlp.conf` in the current
directory. Those lines are no longer logged; the name they produce is, as
`file`.

### L. Which captions `en.*` selects

The 08:26 run of the real video with `SUBS=en.*` logged
`ERROR: Unable to download video subtitles for 'en-de': HTTP Error 429: Too
Many Requests`, and wrote `en` and `en-en` (the transcript was still made,
from `en`). The video lists uploader captions `en` and automatic captions
`en`, `en-en` ("English from English") and `en-de` ("English from German").

| `--sub-langs` | Selected |
|---|---|
| `en.*` | `en`, `en-de`, `en-en` |
| `en(-[A-Z]+\|-orig)?` | `en`, `en-de`, `en-en` |
| `en,en-orig` | `en` |
| `en,en-orig,en-US,en-GB` | `en` |

The regular expression that should have excluded lower-case suffixes did
not, so yt-dlp does not match these names as case-sensitive whole-string
patterns. Exact names avoid the question.

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

**Which base64.** The standard alphabet has `+` and `/`, and `/` cannot be
in a filename. The URL-safe alphabet swaps them for `-` and `_`, which is
also exactly the alphabet of a YouTube id, so the id needs no change at all.
The `.` before the extension is the one character outside it.

**Options, not a rename.** Renaming after the download would have to follow
yt-dlp's own bookkeeping: the merge, the `.part` files, "has already been
downloaded", the `FILE` line `ytq` reads. Changing the name yt-dlp chooses
keeps all of that working, and the same options give plain `yt-dlp` and
`yt-brave` the same names through `/etc/yt-dlp.conf`. The new fields are
copies (`safe_title`, `safe_id`) because yt-dlp uses `id` itself, and the
queue shows `title`.

**Why the id stays for every site.** The request was the id for YouTube. It
is kept for other sites too, filtered the same way, because two uploads with
the same title would otherwise have the same name, and yt-dlp would skip the
second as already downloaded.

**What the name loses.** Titles in other scripts leave nothing, so the id is
the name. A line break or tab inside a title is removed, not turned into
`_`, so the words on each side join (`multilinetitle`). Files downloaded
before the change keep their old names; `ytq transcript` names its `.txt`
by the new rule, so it pairs only with new downloads.

**Why the transcript is its own run.** Section F is the reason. YouTube
refuses caption requests (HTTP 429) more readily than video, and a `403` in
the message would even send the entry to a Brave sign-in. As a second run, a
failure costs only the `.txt`: the log says `transcript: none -- <reason>`,
the notification says `(no transcript)`, and `ytq transcript URL` can try
again later. The price is one more extraction request per video. The second
run goes through `yt-brave` when the video needed Brave's cookies.

**Which captions.** `SUBS` defaults to `en.*`, which can match several files
(`en`, `en-orig`, `en-GB`). The shortest name wins. For a language the
uploader captioned, yt-dlp has already chosen those over the automatic ones.
For a video in another language, `en` is presumably YouTube's machine
translation; that case was not tried. `SUBS=ja,en` asks for the original
first. The `.vtt` files are deleted once read, so the timings are not kept.

**Plain yt-dlp gets the names but not the transcript.** Putting
`--write-subs` in `/etc/yt-dlp.conf` would make every hand-run download exit
1 whenever the captions fail (Section F). `ytq transcript URL` is the way to
get one for a file downloaded by hand.

**Quitting the window stops the merge.** That is the rule `ytq` has always
had: the window's downloads belong to the window. For a 1080p video on the
9p share it cost three minutes of merging (IV-H). The window now shows the
merge under way, and the log says it was stopped and why, but it does not ask
before quitting. Leaving the window open, or queuing with Super+Shift+Y and
`~/.config/ytq/auto` so a background runner does the work, avoids it. The
next attempt finds both parts on disk and only merges again.

**The merge figure is an estimate.** ffmpeg writes `NAME.temp.mp4` and
renames it when done; its size against the parts' total is the only measure
available from outside. The merged file is not exactly the parts' sum (in
IV-H it had already passed it), so the figure is capped at 100 % and marked
`~`.

**Why the record lives in the queue file.** The window, `ytq status` and the
runner are separate processes, and the queue file is already the one thing
they share under a lock. A write once a second, and at each new step, keeps
the lock free for `ytq clip`. The record is emptied when the entry leaves
`downloading`.

**Log size.** The 19-second video's queue-and-download wrote 36 lines, 27
of them tagged with its id; a longer transfer adds one line per 30 s. At
that rate the owner's 455-video queue would be about sixteen thousand
lines. At 4 MiB the file becomes `ytq.log.1`, replacing the one before, so
about two files' worth is kept. Two processes rotating at the same moment
could lose a few lines; the pid on each line makes the interleaving of
processes readable.

**The caption default.** `en,en-orig,en-US,en-GB` asks for at most four
exact names; each is fetched only when the video has it. A video captioned
only in, say, `en-CA` gets no transcript unless `SUBS` names it.

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

**Install the filename rule for plain yt-dlp** (root; this overwrites, so
look first at an `/etc/yt-dlp.conf` Copal did not write):

```sh
awk "/cat > \/etc\/yt-dlp.conf <<'CONF'/{f=1;next} /^CONF\$/{f=0} f" copal-prep.sh > /tmp/yt-dlp.conf
doas install -m 0644 -o root -g root /tmp/yt-dlp.conf /etc/yt-dlp.conf
yt-dlp --simulate --print filename 'https://www.youtube.com/watch?v=jNQXAC9IVRw'
```

**Check a name without the network:**

```sh
yt-dlp --ignore-config --config-locations /tmp/yt-dlp.conf \
    --load-info-json some.info.json --simulate --print filename
```

**Transcripts:**

```sh
ytq transcript 'https://youtu.be/ID'          # just the .txt, into DIR
echo 'SUBS=ja,en' >> ~/.config/ytq/config     # original language first
echo 'SUBS=' >> ~/.config/ytq/config          # no transcripts
grep transcript ~/.local/share/ytq/ytq.log    # what happened to each
```

**Follow a download, or find out what happened to one:**

```sh
ytq status                                        # the step, bytes, speed, ETA
grep ' mkPc3DCZ-Ec: ' ~/.local/share/ytq/ytq.log  # one video's whole story
grep "took run.lock" ~/.local/share/ytq/ytq.log | tail -1   # which ytq and yt-dlp
grep 'stopping\|window closed\|exited\|left .downloading.' ~/.local/share/ytq/ytq.log
```

**Clear up after a stopped merge** (once the entry is done or deleted):

```sh
ls ~/Downloads/SharedVM/*.temp.mp4 ~/Downloads/SharedVM/*.f[0-9]*.*
```

**Run yt-dlp away from stray config files.** A `yt-dlp.conf` in the
current directory is read on every run; `--ignore-config` or another
directory avoids it.

## VII. Files touched

| File | Change |
|---|---|
| `copal-prep.sh` | `install_ytq`: `YT_RE`, `youtube_urls()`, `clipboard_urls()` replacing `clipboard_url()`, `import html`, the count summary in `report()`, the `clip` branch of `main()`; `videos_dir()` prefers a mounted `~/Downloads/SharedVM`; the `ytq` header and the stage-10 guide text. Commits `5aca715`, `41aa7b0` |
| `copal-prep.sh` | `install_ytq`: `NAME_OPTS` and `NAME` in the download's `-o` (with `%` in `DIR` escaped), `vtt_text()`, `transcript()`, the transcript step in `download()`, `ytq transcript`, the `SUBS` setting, the help text; `write_ytdlp_conf()` writing `/etc/yt-dlp.conf`, called from `install_ytdlp` and `install_ytq`; a "Filenames" section and transcript lines in the guide. Commit `a538e53` |
| `copal-prep.sh` | `install_ytq`: `--progress --no-quiet` and `PROGRESS_TEMPLATE`; the live record (`stage()`, `stream_of()`, `size_of()`, `describe()`, `compact()`, `live_view()`, `bar()`); `download()` and `stop_current(why)` rewritten to keep and log it; the window's panel and state counts; `ytq status`; `log()` with pid tags and rotation, `log_start()`, `short()`, `fmt_size()`, `fmt_secs()`; timings in `check()` and `transcript()`; `DEFAULT_SUBS`; the header and guide text. Commit `f9635ad` |
| `docs/ytq-clipboard-lab-report.md` | this report |
