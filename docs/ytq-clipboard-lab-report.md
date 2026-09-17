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

Later the same morning (Sections IV-M to IV-O) the name gained the first word
of the uploader's name, and each download began to carry what a citation
needs. The `.txt` now opens with Notes (full title, author, watch URL,
published and downloaded times, the video's filename, the captions'
language and whether the uploader wrote them) and the description. The
`.mp4` holds the same notes in its metadata. Section V sets out why those
fields, and what they still leave to the person citing: automatic captions
are not verbatim, and a video can disappear. It also records which of
`ytq`'s steps leave the recording as it was served and which do not, keeps
that apart from whether a copy may be kept at all, and says what it means
for quoting recordings of public statements.

Section IV-P is the last change: a Shorts link copied without its scheme,
`youtube.com/shorts/SWHZolxKdVU`, was refused by every way into the queue,
because both URL patterns required `https://`. The YouTube pattern now allows
the scheme to be missing, and every single link to a YouTube video is queued
as its plain watch URL. That also closed a duplicate the first version of
the fix created: the same Short queued once by `ytq add` and once by
`ytq clip`.

Section IV-Q adds the license a site states to the notes, in the `.txt` and
in the `.mp4`. On YouTube that picks out the Creative Commons videos, the
ones whose uploader has allowed reuse.

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
10. Put the uploader in the name, so a folder of downloads reads by who made
    them.
11. Record, with every YouTube download, what a checkable reference needs:
    author, full title, published time, URL and retrieval time, with the
    name of the video file the transcript belongs to.
12. Keep those details inside the video file too, so they travel with a copy.
13. Take a YouTube link, Shorts included, however it was copied, with or
    without `https://`, by every way into the queue, and queue each video
    once whatever form its links take.
14. Say in the notes which license, if any, the site states, so a video
    whose uploader allows reuse can be told from one whose uploader does not.

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
| Author input | the real info JSON of `mkPc3DCZ-Ec` (`yt-dlp -j`), with `uploader` and `channel` replaced for each case |
| Tag reader | `ffprobe -v error -show_entries format_tags` (ffmpeg's) |

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

The author rule was tried on the real video with `--simulate --print
filename`, then offline on its info JSON with nine uploader names, each
applied once and again through a config file. The `ytq` list and the
`/etc/yt-dlp.conf` body, both cut from the installer, were compared
argument by argument after `shlex.split`. The notes were first built as a
template on the command line and read back from a 19-second download with
ffprobe. The finished `ytq` then ran end to end under a throwaway `HOME`:
`ytq add` and `ytq run` on `jNQXAC9IVRw`, `ytq transcript` on
`mkPc3DCZ-Ec` (never downloaded), and `ytq transcript` on `jNQXAC9IVRw`
again after deleting its `.txt` with the `.mp4` left in place. Whether the
merge and the tagging re-encode was read from yt-dlp's source,
`yt_dlp/postprocessor/ffmpeg.py` inside the zipapp, and how it chooses
between an uploader's and automatic captions from `process_subtitles()` in
`yt_dlp/YoutubeDL.py`. The caption source was then checked with
`ytq transcript` on `Q2pe-7RNJRM`, whose captions Section IV-G found
automatic, beside the two videos above.

For Shorts, the installed `YT_RE`, `URL_RE` and `youtube_urls()` were first
run, loaded from the extracted script, on eight ways a Shorts link is
copied. The candidate pattern was then tested alone on eleven links it must
match and ten it must not, and `as_url()` on seventeen inputs. End to end,
under a throwaway `HOME` with a stub `wl-paste`, one Short was queued with
`ytq add` in three forms and with `ytq clip` once, and `queue.json` was
counted. After the owner installed the commit, the same run was repeated
with `/usr/local/bin/ytq` itself, and the owner's own download of the Short
was read from the log, its `.txt` and ffprobe.

For the license, yt-dlp's source was searched for `license`, and
`--simulate --print '%(license)j'` was run on three videos. Under a throwaway
`HOME`, `ytq transcript` ran on a Creative Commons lecture, `M4gD1WSo5mA`,
and on `jNQXAC9IVRw`; `META_OPTS`, read out of the extracted script with
`ast`, ran on both with `--simulate --print '%(meta_comment)s'`; and
`ytq add` and `ytq run` downloaded `jNQXAC9IVRw` for ffprobe.

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

### M. The author in the name

Three options go in front of the title's, in `NAME_OPTS` and
`/etc/yt-dlp.conf` alike, and the template gains a prefix:

```
--parse-metadata '%(uploader,channel|)#S:(?s)(?P<safe_author>.+)'
--replace-in-metadata safe_author '^[^A-Za-z0-9]+' ''
--replace-in-metadata safe_author '(?s)[^A-Za-z0-9].*' ''
-o '%(safe_author&{}-|)s%(safe_title&{}_|)s%(safe_id)s.%(ext)s'
```

`|` gives an empty default when neither field exists; `#S` folds accents as
for the title; the regexes trim leading punctuation and keep the first run
of `A-Z a-z 0-9`. `&{}-|` writes the author and a `-` only when one is left.
On `mkPc3DCZ-Ec`, title "They Stopped Trusting The Dollar":

| `uploader` | Name |
|---|---|
| `Minority Mindset` (the real one) | `Minority-They_Stopped_Trusting_The_Dollar_mkPc3DCZ-Ec` |
| `Café Olé` | `Cafe-They_Stopped_…` |
| `@#$ Weird Name` | `Weird-They_Stopped_…` |
| `日本語チャンネル` | `They_Stopped_…` (no author part) |
| `MKBHD` | `MKBHD-They_Stopped_…` |
| `Spider-Man Fan` | `Spider-They_Stopped_…` |
| `  The.Plain.Bagel` | `The-They_Stopped_…` |
| absent, with no `channel` | `They_Stopped_…` |
| empty string | `They_Stopped_…` |

All nine gave the same name applied twice. The two lists, `ytq`'s and the
config's, were equal.

### N. Notes in the transcript

`transcript()` now prints `%(.{title,uploader,channel,webpage_url,timestamp,upload_date,description,subtitles})j`
in place of the title alone, and `notes()` writes the top of the `.txt`.
From `ytq run` on the 19-second video:

```
Me at the zoo

Notes
  Title:      Me at the zoo
  Author:     jawed
  URL:        https://www.youtube.com/watch?v=jNQXAC9IVRw
  Published:  2005-04-23 20:31:52 -0700
  Downloaded: 2026-09-15 09:12:45 -0700
  Video:      jawed-Me_at_the_zoo_jNQXAC9IVRw.mp4
  Captions:   en, written by the uploader

Description
Microplastics are accumulating in human brains at an alarming rate
…

Transcript
All right, so here we are, in front of the elephants the cool thing about
```

| Run | `Video:` |
|---|---|
| `ytq run` (the download passes its file) | `jawed-Me_at_the_zoo_jNQXAC9IVRw.mp4` |
| `ytq transcript` on `mkPc3DCZ-Ec`, never downloaded | `none downloaded` |
| `ytq transcript` on `jNQXAC9IVRw`, `.mp4` already in `DIR` | `jawed-Me_at_the_zoo_jNQXAC9IVRw.mp4` |

`Published` comes from `timestamp` in local time; with no `timestamp` it
would be `upload_date` as a date alone, and otherwise `unknown`. The real
video's description, sponsor links and all, went in whole.

The `Captions` line also says where the captions came from. `subtitles` is
the uploader's captions by language, and yt-dlp's `process_subtitles()`
fills its choices from those first, adding an automatic caption only for a
language not already there. The language chosen is therefore the uploader's
exactly when it is a key of `subtitles`.

| Video | `en` among the uploader's? | `Captions:` |
|---|---|---|
| `jNQXAC9IVRw` | yes | `en, written by the uploader` |
| `mkPc3DCZ-Ec` | no (`subtitles` empty; 157 automatic languages) | `en, automatic: YouTube's speech recognition, not verbatim` |
| `Q2pe-7RNJRM` | no | `en, automatic: YouTube's speech recognition, not verbatim` |

### O. Notes in the video file

`META_OPTS`, added to the download when `ffmpeg` is on `PATH` (`\n` is a
newline inside the argument):

```
--embed-metadata
--parse-metadata 'Title = %(title)s\nAuthor = %(uploader,channel|unknown)s\nURL = %(webpage_url)s\nPublished = %(timestamp>%Y-%m-%d %H.%M.%S UTC,upload_date>%Y-%m-%d|unknown)s\nDownloaded = %(epoch>%Y-%m-%d %H.%M.%S UTC)s:(?s)(?P<meta_comment>.+)'
--replace-in-metadata meta_comment '(?m)^(Title|Author|URL|Published|Downloaded) = ' '\1: '
--replace-in-metadata meta_comment '(\d\d)\.(\d\d)\.(\d\d) UTC' '\1:\2:\3 UTC'
```

The first try wrote `Title: ` and `%H:%M:%S` straight into the template. The
download ran and `[Metadata]` added its tags, but `comment` held only
`https://www.youtube.com/watch?v=jNQXAC9IVRw`, yt-dlp's own value for it.
The same template with `=` labels and `.` in the times, read back with
`--print '%(meta_comment)j'`, parsed in full, so the literal colons were
what stopped it; yt-dlp's source was not read to see where it splits.
`--replace-in-metadata` takes field, pattern and replacement as separate
arguments, so it can put the colons back.

The tags that came out, from ffprobe:

```
title=Me at the zoo
artist=jawed
date=20050424
comment=Title: Me at the zoo
Author: jawed
URL: https://www.youtube.com/watch?v=jNQXAC9IVRw
Published: 2005-04-24 03:31:52 UTC
Downloaded: 2026-09-15 15:58:48 UTC
```

The first try, which listed every tag, also showed `genre`, `description`
and `synopsis` (the description twice) and no `purl`, so the URL in the file
is the one in `comment`. `date=20050424` is the UTC day; the `.txt` gives
the same moment as `2005-04-23 20:31:52 -0700`. The log read
`now post-processing (Metadata)` and `yt-dlp exited 0 after 0:02, last
step: post-processing (Metadata)`; `stage()` now counts `[Metadata]` as
post-processing. In the run of Section N's first version, the file's
`Downloaded` (15:58:48 UTC, yt-dlp's `epoch`) and the `.txt`'s (08:58:50
-0700, when it was written) were two seconds apart.

### P. Shorts links without `https://`

A Shorts link with its scheme had always worked: the log holds
`added https://www.youtube.com/shorts/OORXKq6c7Es` at 07:45:52 and its
download, and `ytq clip` had queued Shorts from the bookmarks as watch
URLs. Without the scheme, nothing took it. From the script as installed
before the fix:

| Text | `URL_RE` | `youtube_urls()` |
|---|---|---|
| `https://www.youtube.com/shorts/SWHZolxKdVU` | match | `watch?v=SWHZolxKdVU` |
| `https://youtube.com/shorts/SWHZolxKdVU?si=AbC123xyz` | match | `watch?v=SWHZolxKdVU` |
| `https://m.youtube.com/shorts/SWHZolxKdVU?feature=share` | match | `watch?v=SWHZolxKdVU` |
| `http://youtube.com/shorts/SWHZolxKdVU/` | match | `watch?v=SWHZolxKdVU` |
| `youtube.com/shorts/SWHZolxKdVU` | no | none |
| `www.youtube.com/shorts/SWHZolxKdVU` | no | none |
| `see youtube.com/shorts/SWHZolxKdVU and https://youtu.be/jNQXAC9IVRw` | no | `jNQXAC9IVRw` only |

So `ytq clip` found no video, and `ytq add`, the window's watcher and its
`a` key, which test the whole text with `URL_RE`, called it "not a URL".
`ytq transcript` would have handed the bare link to yt-dlp.

The pattern's scheme became optional, guarded where it is missing:

```python
YT_RE = re.compile(r"(?:https?://|(?<![\w.@/-]))(?:(?:www|m|music)\.)?"
                   r"(?:youtube\.com/(?:watch\?(?:[^\s\"'<>#]*?&)?v=|shorts/|live/|embed/)|youtu\.be/)"
                   r"([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])")
```

Without a scheme the host may not follow a letter, digit, `.`, `@`, `/` or
`-`. On its own the pattern matched all eleven links it should: bare,
`www.`, `m.` and `youtu.be` forms, `watch?v=` with `v` not first, a link in
a sentence, in parentheses and in `HREF="…"`. It matched none of the ten it
should not: `notyoutube.com`, `foo.youtube.com`, `evil.com/youtube.com/…`,
`youtube.com.evil.com`, `xyoutu.be`, `user@youtube.com`, 12- and
8-character ids, a channel and a playlist.

The single-link checks moved into one function, `as_url()`, which `ytq add`,
the watcher, the `a` key, `ytq clip`'s fallback and `ytq transcript` now
call. Its first version kept a URL as it was and put `https://` back on a
bare YouTube link. End to end, `ytq add youtube.com/shorts/SWHZolxKdVU` then
queued `https://youtube.com/shorts/SWHZolxKdVU`, and `ytq clip` with the
same text queued `https://www.youtube.com/watch?v=SWHZolxKdVU`: two entries,
so two downloads, of one video. The version committed turns a YouTube video
at the start of the text into its watch URL, as `ytq clip` does:

```python
def as_url(text):
    text = text.strip()
    m = YT_RE.match(text)
    if m and not re.search(r"\s", text):
        return "https://www.youtube.com/watch?v=" + m.group(1)
    return text if URL_RE.match(text) else None
```

| `as_url()` input | Result |
|---|---|
| `youtube.com/shorts/…`, `www.…/shorts/…?feature=share`, `youtu.be/…` with spaces and a newline around it, `m.youtube.com/watch?v=…&t=5s` | `https://www.youtube.com/watch?v=SWHZolxKdVU` |
| `https://www.youtube.com/shorts/…`, `https://youtube.com/shorts/…?si=AbC`, `https://www.youtube.com/watch?v=…&list=RDabc&index=2` | the same |
| `https://web.archive.org/web/2024/https://www.youtube.com/watch?v=SWHZolxKdVU` | unchanged |
| `https://vimeo.com/12345`, `https://www.youtube.com/@channel` | unchanged |
| `notyoutube.com/shorts/…`, `foo.youtube.com/shorts/…`, `example.com/shorts/…`, `youtube.com/shorts/… and more words`, `youtube.com/@channel`, `plain words`, empty | `None` |

All seventeen gave the result in the table. End to end:

| Command, in order | Log |
|---|---|
| `ytq add --no-run youtube.com/shorts/SWHZolxKdVU` | `added https://www.youtube.com/watch?v=SWHZolxKdVU` |
| `ytq add --no-run 'https://www.youtube.com/shorts/SWHZolxKdVU?feature=share'` | `already queued: …watch?v=SWHZolxKdVU` |
| `ytq add --no-run youtu.be/SWHZolxKdVU` | `already queued: …` |
| `ytq clip --no-run`, clipboard `youtube.com/shorts/SWHZolxKdVU` | `already queued: …` |
| `ytq add --no-run notyoutube.com/shorts/SWHZolxKdVU` | `not a URL: notyoutube.com/shorts/SWHZolxKdVU` |

`queue.json` held one entry. `ytq transcript youtube.com/shorts/SWHZolxKdVU`
wrote `Trader-The_setup_I_trade_more_than_anything_else_trading_daytrading_SWHZolxKdVU.txt`
in a 12-second caption run, with `Captions: en, automatic: …`. `ytq add`
still exits 0 after "not a URL", as it did before.

The owner installed commit `28d6e5c` at 09:24:39; `/usr/local/bin/ytq` and
the guide were byte-identical to the files cut from it. Run under a
throwaway `HOME`, the installed `ytq add youtube.com/shorts/SWHZolxKdVU`
queued the watch URL, a clipboard of
`www.youtube.com/shorts/SWHZolxKdVU?feature=share` was `already queued`, and
`notyoutube.com/…` was not a URL.

The owner's own download of the Short came a minute earlier, under a `ytq`
installed at 09:23 from the working copy, before the commit at 09:24:00 and
with the same `as_url()`: the runner named its script "of 2026-09-15 09:23".
At 09:23:15 the log reads `added https://www.youtube.com/watch?v=SWHZolxKdVU`
and `started a runner`, since `~/.config/ytq/auto` exists. `ytq add` and
`ytq clip` log those lines alike, and the log keeps neither the command nor
the text as given. Through `ytq add`, the watch URL is `as_url()` at work:
the build of 09:15 refused a bare link and kept an `https://…/shorts/…` link
in that form. Through `ytq clip`, any build gives the watch URL. The command
suggested to the owner was `ytq add youtube.com/shorts/SWHZolxKdVU`, so the
fix was probably exercised, but the log does not show it. The run does show
the rest of the day's work on a Short: yt-dlp
exited 0 after 12 s, the file is 22.5 MiB of 1080 × 1920 H.264 with AAC,
92.07 s long; the `.txt` holds 238 words under Notes naming the `.mp4` in
`Video:` and the captions as automatic; and the file's `comment` gives
`Published: 2026-09-13 13:44:28 UTC`, the `.txt`'s `06:44:28 -0700`.

### Q. The license a site states

`transcript()` now prints `license` with the rest of `META`, `notes()`
writes it as a `License` line after `Downloaded`, and `META_OPTS` adds the
same line to the file's `comment`. Either says `not stated` when the field
is empty. In yt-dlp 2026.08.19 the YouTube extractor sets `license` only
from a row titled "License" in the watch page's metadata
(`yt_dlp/extractor/youtube/_video.py`); its own test for that case is the
lecture used here.

| Video | `--print '%(license)j'` | `.txt` `License:` | `comment` `License:` |
|---|---|---|---|
| `M4gD1WSo5mA`, William Fisher, CopyrightX: Lecture 3.2 | `"Creative Commons Attribution license (reuse allowed)"` | the same | the same |
| `jNQXAC9IVRw`, Me at the zoo | `NA` | `not stated` | `not stated` |
| `SWHZolxKdVU`, the Short of IV-P | `NA` | not run | not run |

The lecture's `comment` was read from `--print` without a download. For
`jNQXAC9IVRw`, `ytq run` wrote a 746 070-byte `.mp4` whose ffprobe
`comment` ends `License: not stated`, logged `yt-dlp exited 0 after 0:01,
last step: post-processing (Metadata)` and `done: … + transcript`. The other
Notes lines, and the other `comment` lines, came out as in IV-N and IV-O.

### R. Stats, and the discussion

Four changes, in `~/code/staticstream` rather than here: ytq is Rust now and
this report follows it. The owner's ask was the replies under an x.com post as
a discussion in the `.txt`, the same for YouTube, and the counts a post carries
"taken on the date".

**What each site gives.** Measured 2026-09-17, yt-dlp 2026.08.19, on one of the
owner's own downloads.

| Field | `x.com/TheBTCTherapist/status/1935298536373170512` | `youtube.com/watch?v=jNQXAC9IVRw` |
|---|---|---|
| `view_count` | 34776 | yes |
| `like_count` | 412 | yes |
| `repost_count` | 68 | *absent — YouTube has no reposts* |
| `comment_count` | 38 | yes |
| `timestamp` | 1750246101 | yes |
| `description` | the tweet's own text | the description |
| `comments` | **`NA`** | a threaded list |

**X reply text cannot be had, and the hole is named rather than left silent.**
Three independent checks agree: `yt_dlp/extractor/twitter.py` defines no
`extract_comments`, no `__post_extractor` and no `comments` key, so
`comment_count` is a number and nothing more; a live run with
`--write-comments --print '%(comments)s'` printed `NA`; and
`cdn.syndication.twimg.com/tweet-result`, the public endpoint, answered HTTP
200 with `conversation_count` and no replies array. Reaching the text means a
signed-in GraphQL call, which is a phase of its own if ever. On an X post the
count is recorded and there is no Discussion section.

**An x.com download used to leave nothing in text at all.** The transcript step
was gated on `first_id(url).is_some()` — YouTube or nothing — because it was
one job doing two: fetching captions, and writing the notes. Splitting them
costs no second yt-dlp run, because the download's own run already prints a
metadata line that the runner already parses. That line asked for five fields
and now asks for twelve.

| After a download of | before | after |
|---|---|---|
| a YouTube video | `.sstr` + `.txt` (Notes, Description, Transcript) | the same, plus Stats and Discussion |
| an x.com post | `.sstr` only | `.sstr` + `.txt` (Notes, Stats, Description) |

**The counts are stamped, and that is the point rather than a detail.** Every
row Notes carried before — title, author, published, licence — is a property of
the recording and reads the same tomorrow. Views and likes are properties of a
moment and are different the second after they are read. So they are written
under their own reading time:

```
Stats  (read 2026-09-17 15:12:03 -0700)
  Views:      34,776
  Likes:      412
  Reposts:    68
  Replies:    38
```

A row appears only where the site gave a number, so YouTube's `.txt` has no
`Reposts:` line rather than a nought. Numbers are written whole: `12k` cannot be
un-rounded later, and the width it saves was never scarce.

**The discussion is a tree, built from `parent`.** yt-dlp's YouTube comments
carry `parent` — `'root'` or the id of the comment being answered — along with
`author`, `author_id`, `timestamp`, `like_count` and `is_pinned`. Both names are
kept where they differ: a display name can be changed afterwards and an id
cannot.

```
Discussion  (200)

  @SanDiegoZoo  (UCC5NfQ6Mf0dq_eEwv4P_hWA)  2020-09-17  * pinned  4,800,000 likes
    We're so honored that the first ever YouTube video was filmed here!
    |  @tacticals.1811  (UCS2FiwDUXi_VJwC7HGJl4sw)  2020-09-17  56,000 likes
    |    How did I randomly go to this video and see this comment 11 hours
    |    after it was posted? That's amazing
```

The header states what was kept against what exists, so what the cap left out is
visible. `COMMENTS` sets the cap, defaults to 200, and `COMMENTS=` asks for none
— `SUBS`'s shape exactly, including empty-disables.

**Comments are fetched on a run of their own**, not on the transcript's. A
comment fetch is the slowest and most rate-limited thing yt-dlp does here, and
sharing a run would mean a 429 on comments cost captions already in hand —
which is the very failure the transcript was split off the *download* run to
avoid in IV-F. Each step that can fail alone fails alone, and only a fetch that
actually broke says `(no discussion)`; a video that simply has none says nothing.

**The capture carries the same fields.** `archive()`'s header gained `published`
and a stamped `stats` object, so the `.sstr` is not the poorer record of the
two. It is the copy most likely to outlive the page the numbers came from, and
therefore the copy that most needs to say when they were true. Both keys are
conditional, so a capture whose site gave neither is byte for byte the header it
always was.

**What checks this.** The frozen Python ytq cannot: it writes neither block, and
`tests/reference/ytq.py` is a specification, not a thing to be edited until a
test passes. So the crosschecks go on holding the parts that did not change —
the runner harness now normalises the two new sections out before comparing, as
it already normalised the `Downloaded:` line — and the new parts are held by
fixtures instead, in the manner phase 4 settled on when version 1 had no Python
either.

One of those comparisons earned its keep immediately. `COMMENTS` was first added
as a default in `settings::load()`; the settings map is compared to the Python's
byte for byte, and five of 32 comparisons failed at once. It is resolved by a
function now, beside `OUTPUT`, `ARCHIVE_DIR` and `SSTR_KEY` — the settings that
decide what a download becomes, which for this exact reason were already kept
out of that map.

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

**What a reference needs.** A citation promises that a reader can find what
was cited and see that it says what was claimed. For an online video the
styles agree on the parts: who published it, the title, when, where, and,
for a source that can change, when it was retrieved. APA 7 cites uploader,
date, title with `[Video]`, site and URL; MLA 9 recommends an access date for
a web source that may change. Each Notes line is one of those parts, taken
at download time, because each can change afterwards: an uploader can
retitle a video, edit its description, rename the channel, or make the video
private or delete it. The notes say what the video was when it was kept.

**The id is the part that stays.** The author and title in the filename are
cut short and folded to ASCII; they help a person scan a folder but cannot be
cited. The id is exact and survives retitling, so it ends every name, and the
URL line is always `webpage_url`, the plain `watch?v=ID` form, whichever link
was queued.

**Two zones, on purpose.** yt-dlp formats times only in UTC, so the file's
`comment` is in UTC; the `.txt` is written by `ytq` in local time with the
offset. Either way the moment is exact. The day alone is not: the `date` tag
of a video published at 20:31 Pacific time on 23 April 2005 reads
`20050424`, and a reference taken from the tag would carry the wrong day.

**Two downloaded times.** The file's is yt-dlp's `epoch`, when it looked the
video up; the `.txt`'s is when the transcript was written, after the video
finished. They were two seconds apart on the short video (IV-O); after a
three-minute merge over the share they would be minutes apart. Either will do
as a retrieval date.

**Archivability.** The copy and its notes outlive the video; a reader's
access does not, and a reference to a deleted video cannot be checked from
its URL. Saving the watch page to the Internet Archive
(`https://web.archive.org/save/URL`) while it is up gives a second, public
address, though the Archive usually keeps the page and its text rather than
the video. The formats stay readable: `DEFAULT_FORMAT` prefers H.264 with
AAC in MP4, the transcript is plain UTF-8, and the notes are inside the
`.mp4` so that a copy moved without its `.txt` still says where it came
from. Citing a video credits it; it does not license a copy, and passing a
copy on is the rights holder's to allow.

**Accessibility.** The transcript serves anyone who cannot use the audio: a
screen reader reads plain text as it is, and a quotation can be copied from
it. WCAG 2.2 treats captions (1.2.2) and a text alternative for prerecorded
media (1.2.3, 1.2.8) as separate criteria; a transcript made from captions is
a start on the second. WCAG sets what a publisher owes and grants no right to
copy. The stronger ground for a reader's own transcript is what it is for:
*Authors Guild v. HathiTrust* (2d Cir. 2014) held copies made for
print-disabled readers' access to be fair use. Automatic captions are speech recognition and not
verbatim, so a quotation should be checked against the audio and cited with
its time in the video. The `Captions` line says which kind a transcript came
from (IV-N). Captions the uploader wrote are the uploader's text, which may
be edited or condensed, so they too are checked against the audio.

**Access a reader does not have.** A video fetched through `yt-brave` needed
a sign-in and may be members-only, age-gated or private. Its notes look like
any other's; the reference should say the video is restricted.

**What is not recorded.** No captions means no `.txt`, so such a video has
its notes only in the `.mp4`. Without `ffmpeg`, `META_OPTS` is left out and
the file has none, though a machine without ffmpeg can only fetch a stream
that is already muxed anyway. Plain `yt-dlp` and `yt-brave` get the author
in the name but not the notes; `--embed-metadata --write-info-json` keeps
the fields by hand. Files downloaded before this change have neither.

**What the copy preserves.** `ytq` changes the form a recording is in: a
stream on a web page becomes an MP4 file, and speech becomes text. In
yt-dlp 2026.08.19, `FFmpegMergerPP` runs
ffmpeg with `-c copy`, and `FFmpegMetadataPP` uses `stream_copy_opts()`, so
neither the merge nor the tagging re-encodes; the file holds the streams
YouTube served. Those are YouTube's encoding of the upload, not the
uploader's original file. The name and the notes are added around the
recording and change nothing in it. The transcript is the lossy step:
`vtt_text()` discards the timings, removes a line equal to the one before
(which would also remove a line a speaker really did say twice in
succession), and rewraps. It is an index into the recording, not a
substitute for it. All of this matters for evidence: a quotation checked
against the file is checked against what was published. It says nothing
about permission. A faithful copy is still a copy, and crediting a source
does not license copying it.

**Whether a copy may be kept.** This report does not settle it. "Format
shifting" means copying a work one already owns into another form, a CD
into MP3s. A streamed video is licensed for watching on the site, so the
term does not carry over, and in the United States format shifting is not
itself a recognised fair use: *Sony* (1984) held *time*-shifting of
broadcast television fair, and the Copyright Office declined to treat
space-shifting as noninfringing in its 2012 and 2015 §1201 rulemakings. The
case for a copy is strongest when it serves a purpose the stream cannot:
quoting, criticising or reporting on a recording, checking a reference after
the video changes or disappears, or reading a transcript instead of
listening. It is weakest when the copy only replaces watching on the site,
as a bookmarks export queued whole (IV-C, a remix among the first ten) mostly
does, and when the video was behind a paid membership. Apart from copyright,
YouTube's terms forbid downloading without its permission, and whether
yt-dlp's handling of YouTube's player circumvents a technical protection
measure has been disputed in court. Uploads of one's own, Creative Commons
videos (the License line, IV-Q) and US federal government works raise none
of this.

**Recordings of public statements.** A recording of a public figure speaking
in public is a primary source for the words and how they were said.
*Public* describes the occasion, not the recording, whose copyright belongs
to whoever made it unless it is a US federal government work (17 USC 105);
*Harper & Row v. Nation* (1985) shows that newsworthiness alone does not
make quoting fair. A
correct citation of one separates two things the notes place side by side.
The speaker, the occasion and its date belong to the statement; `Author` and
`Published` belong to the upload, which may be a news channel posting days
later or a third party re-posting an excerpt. A faithful quotation is exact,
keeps enough context that the meaning is the speaker's, says when it comes
from an excerpt, and gives its time in the recording. The full recording
from the speaker's or the event's own channel is better evidence than a
clip. The transcript helps find the passage; the words, and their time,
should be taken from the video.

**Links without a scheme, and one form per video.** A link copied from an
address bar, typed, or pasted from a message often has no `https://`, and
`youtube.com/shorts/ID` is the form a Short is usually shared in. Accepting
any bare `host/path` as a URL would let a pasted word with a dot in it into
the queue, so the scheme is optional for YouTube hosts only, and the
lookbehind keeps longer hosts and paths under other sites out. A YouTube
link inside another URL's query string, after `=`, still matches in
`ytq clip`, which is the video the text points at. The queue is keyed on the
URL, so a video must have one spelling there. The watch URL is the one
`ytq clip` already used, and yt-dlp takes it for a Short. A `&t=` or
`&list=` is dropped, which a download never needed (`--no-playlist` is
passed anyway). Requiring the match to start the text keeps an archive
address that contains a YouTube URL as the archive address. Entries queued
before this change in another form are not merged with new ones.

**What the License line says, and does not.** It is the license the site
states, as yt-dlp reports it. On YouTube that is either YouTube's one
Creative Commons option, CC BY, which allows copying, sharing and adapting
with credit, or nothing. `not stated` is neither "all rights reserved" nor
"free to reuse": the page offered no license, so the ordinary rules apply.
A Creative Commons license is only as good as the uploader's right to grant
it, and a re-upload of someone else's work marked CC BY does not make that
work reusable. Other extractors fill the field from their own pages; only
YouTube's was read and tried.

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

**Read what a download recorded, for a citation:**

```sh
sed -n '/^Notes$/,/^$/p' ~/Downloads/SharedVM/NAME.txt
ffprobe -v error -show_entries format_tags=title,artist,date,comment -of default=nw=1 ~/Downloads/SharedVM/NAME.mp4
```

**Keep the page where a reader can still find it,** while the video is up:
open `https://web.archive.org/save/https://www.youtube.com/watch?v=ID` in a
browser, and cite the archived address beside the original.

**The same fields from plain yt-dlp or yt-brave:**

```sh
yt-dlp --embed-metadata --write-info-json URL
```

**Queue a Short however it was copied:**

```sh
ytq add youtube.com/shorts/ID          # or youtu.be/ID, with or without https://
ytq list | grep ID                     # one entry, as https://www.youtube.com/watch?v=ID
```

**See whether a video states a license:**

```sh
grep '^  License:' ~/Downloads/SharedVM/NAME.txt
yt-dlp --simulate --print '%(license)s' URL     # NA: none stated
```

## VII. Files touched

| File | Change |
|---|---|
| `copal-prep.sh` | `install_ytq`: `YT_RE`, `youtube_urls()`, `clipboard_urls()` replacing `clipboard_url()`, `import html`, the count summary in `report()`, the `clip` branch of `main()`; `videos_dir()` prefers a mounted `~/Downloads/SharedVM`; the `ytq` header and the stage-10 guide text. Commits `5aca715`, `41aa7b0` |
| `copal-prep.sh` | `install_ytq`: `NAME_OPTS` and `NAME` in the download's `-o` (with `%` in `DIR` escaped), `vtt_text()`, `transcript()`, the transcript step in `download()`, `ytq transcript`, the `SUBS` setting, the help text; `write_ytdlp_conf()` writing `/etc/yt-dlp.conf`, called from `install_ytdlp` and `install_ytq`; a "Filenames" section and transcript lines in the guide. Commit `a538e53` |
| `copal-prep.sh` | `install_ytq`: `--progress --no-quiet` and `PROGRESS_TEMPLATE`; the live record (`stage()`, `stream_of()`, `size_of()`, `describe()`, `compact()`, `live_view()`, `bar()`); `download()` and `stop_current(why)` rewritten to keep and log it; the window's panel and state counts; `ytq status`; `log()` with pid tags and rotation, `log_start()`, `short()`, `fmt_size()`, `fmt_secs()`; timings in `check()` and `transcript()`; `DEFAULT_SUBS`; the header and guide text. Commit `f9635ad` |
| `copal-prep.sh` | `install_ytq`: `safe_author` in `NAME_OPTS` and `NAME`; `META_OPTS`, used by `download()` when `ffmpeg` is present (`import shutil`); `notes()`, with the captions' source; `transcript()` printing `META` and taking `video`; `[Metadata]` in `stage()`; the header's CITATIONS paragraph. `write_ytdlp_conf()`: the author options and comments. The guide: author filenames and "Citing what you keep". The `yt-brave` header and `install_ytdlp` comment on restricted videos, kept downloads and format shifting. The guide and the `ytq` header on quoting recordings of public statements. Commit `923b673` |
| `copal-prep.sh` | `install_ytq`: `YT_RE` with an optional, guarded scheme; `as_url()`, used by `ytq add`, the watcher, the `a` key, `clipboard_urls()` and `ytq transcript`; the header and guide lines on links without `https://`. Commit `28d6e5c` |
| `copal-prep.sh` | `install_ytq`: `license` in `transcript()`'s `META`, a `License` row in `notes()`, a `License` line in `META_OPTS`; the header's Notes list and CITATIONS paragraph. The guide: a "License" paragraph, "What the copy is" in place of "Format shifting", and the archiving, accessibility and quoting paragraphs. The `install_ytdlp` comment and the `yt-brave` header on what a faithful copy does not settle. Commit `95b0be1` |
| `docs/integration-lab-report.md` | a pointer from Section D to this report |
| `docs/ytq-clipboard-lab-report.md` | this report |
