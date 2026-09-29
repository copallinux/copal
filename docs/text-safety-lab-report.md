# Text Is Data: A Hostile-Input Review of ytq and Static Stream, and a Standard for Copal's Shell Scripts

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

*Copal Linux, Alpine 3.24 aarch64 guest under UTM on a Mac: the "bench".
29 September 2026. The review was done by the author with an AI coding
assistant (Claude) in one terminal on the bench. Nothing was changed in either
program during it; every defect here is an entry in `docs/backlog.md` [1], and
this report is the reasoning those entries point back to.*

---

## Abstract

ytq downloads a video and writes what the site said about it — title,
description, tags, chapters, captions, comments — into a text file, into the
MP4's own tags, and into a Static Stream capture's header. Every one of those
words is chosen by a stranger. This report asks what a stranger can do with
them. The real `ytq` was run against a stand-in yt-dlp whose every field
carried an attack, in a throwaway home directory. **No field ran a command:**
shell substitutions in a description created no file. But control characters
pass through untouched, and four defects follow: a carriage return in a
chapter title removed the transcript from the MP4's tags; escape sequences
reach the terminal from four commands; a newline in a title forges a
`License:` row in the notes and in `sstr verify`; and the file ytq tags,
captures and removes is named by a line it does not check. The same method —
measure first, with the tool rather than by eye — was then applied to Copal's
346 shell scripts: `shellcheck`, installed on the bench but not part of
`make lint`, reported 405 findings and one playbook that does not parse. The
report ends with a standard of twenty short rules, each tied to the check that
enforces it, and twenty backlog entries.

## I. Objective

1. Find every way text from a site can leave the role of data in ytq and
   Static Stream: run a command, change a file it should not, alter the
   terminal, or forge part of the record.
2. Prove each finding by running it, and prove what is safe the same way.
3. Find out why every ytq log carries yt-dlp's warning about a JavaScript
   runtime, and what removes it on all three of Copal's architectures.
4. Measure Copal's shell scripts against the same standard.
5. Write the standard down as rules short enough to follow, and turn every
   suggestion into a backlog entry that can be marked done.

## II. Materials

- **The bench**: ffmpeg 8.1.2, yt-dlp 2026.08.19 (the zipapp in
  `/usr/local/bin`), Node 24.18.1, shellcheck 0.11.0, shfmt, Python 3.14.
- **staticstream** at `75cbf7d`: `src/ytq/runner.rs` (2,107 lines),
  `textwrap.rs`, `urls.rs`, `log.rs`, `term.rs`, `src/workspace/services.rs`,
  `src/bin/sstr.rs`.
- **copal** at `adb5664`: `copal-prep.sh`, `playbooks/`, `tools/`, `bin/`,
  `utm/` — 346 `.sh` files, 62,658 lines.
- **The stand-in yt-dlp** of `tests/standin/` [2], as the model for a hostile
  one.

## III. Method

### A. Follow the text, not the code

The review did not read files top to bottom. It followed one word from where
it enters to everywhere it lands:

| Enters as | Lands in |
|---|---|
| a URL on the clipboard or typed | yt-dlp's arguments, the browser's, the queue, the log |
| `NOTES`, `META`, `TALK` lines from yt-dlp | the `.txt`, the MP4's tags, the capture's header, the queue |
| a `.vtt` caption file | the `.txt`, the MP4's `lyrics` tag |
| a `FILE` line from yt-dlp | the path ytq tags, captures and may remove |
| any of the above, later | the terminal, a notification, a shell line in the Workspace |

At each landing the question is the same: **what characters mean something
here, and who escapes them?**

### B. A hostile stand-in

A copy of the stand-in yt-dlp was given attacks in place of its sample data:

| Field | Carried |
|---|---|
| title | `ESC ] 0 ; …` (set the window title), `ESC [ 2 J` (clear the screen), a newline and a forged `License:` row |
| uploader | a newline and a forged `URL:` row |
| description | carriage returns followed by `artist=…`, `title=…`; `$(touch PWNED)`, backticks, `; touch` |
| chapter title | a carriage return, then `[CHAPTER]` and its fields |
| captions | an escape sequence, a NUL byte, U+2028 |
| comment | `ESC ] 52 ; …` (write to the clipboard) |

The real `target/release/ytq` was run against it with the harness's own rules
[3]: a throwaway `HOME`, stubs first on `PATH`, the display variables unset.
The outputs were read with `cat -v` and `ffprobe`, never on a live terminal.

### C. The shell scripts, measured

`shellcheck -f json` over all 346 files, counted by code and by file; `sh -n`
over every playbook; and `grep` for five patterns no linter ranks: `eval`,
a download piped into a shell, a fixed name in `/tmp`, a download with no
checksum beside it, and `rm -rf` on a path built from variables.

### D. The JavaScript runtime

yt-dlp was run with `-v` against one real video three ways — as configured,
with `--js-runtimes node`, with `--js-runtimes quickjs` — and its own source
was unpacked from the zipapp to read how it starts each runtime. Alpine's
package indexes for four architectures were read for which runtimes exist
where.

## IV. Results

### A. What held

| Attack | Result | Why |
|---|---|---|
| `$(touch PWNED)`, backticks, `; touch` in the description | no file created | every process is started with an argument list; no shell reads the text |
| a title as a filename | `Up-Honest_title_HOSTILEAAAA.mp4` | `NAME_OPTS` keeps `A-Z a-z 0-9 - _` and nothing else |
| a URL that is really an option (`--exec …`) | refused | `as_url()` accepts only `http://` and `https://` |
| a newline in a title forging a `FILE` line | impossible | site text crosses the pipe as JSON (`%(…)j`), one line |
| a quote or `$HOME` in a name sent to the Workspace's shell | one word | `services::quote`, already tested against a real `sh` |
| deeply nested JSON | refused | the parser has a depth bound |
| an escape sequence in the ytq window | shown as `^[` | the window draws through `term::printable` |

### B. Defects

| # | Severity | Defect | Evidence | Backlog |
|---|---|---|---|---|
| 1 | medium | `ffescape` escapes `= ; # \` and newline, not carriage return or NUL; ffmpeg ends a line at either | a chapter titled `one\r[CHAPTER]…` opened a section inside the `comment` tag: three chapters instead of one, and **no `lyrics` tag in the file**. A NUL in the captions cut `lyrics` at that byte | T-02 |
| 2 | medium | raw control characters reach the terminal | `ytq list` printed `ESC ]0;PWNED-WINDOW-TITLE BEL ESC [2J`; `sstr verify` printed the same from the header; the `.txt` holds them and the Workspace's Text key runs `cat` on it | T-01, T-03 |
| 3 | medium | a newline in a one-line field forges rows | the notes showed `License:    Creative Commons (FORGED ROW)` and `URL:        https://evil.example/forged`; `sstr verify` printed both under `note` | T-04 |
| 4 | low | `FILE` and `NOTES` are read from one pipe carrying stdout and stderr, and the path is not checked to be inside `DIR` before it is tagged, captured and — with `OUTPUT=sstr` — removed | by reading; no working attack was found, because yt-dlp prints its own `FILE` line last | T-05 |
| 5 | low | no `--` before the URL in four yt-dlp commands | safe today by `as_url()` alone | T-06 |

Defect 2 in `sstr verify` is wider than ytq: it applies to any capture
somebody hands over, since whoever made the file wrote its header.

One suggestion made during the review was wrong and is corrected here.
Clippy's `disallowed_methods` was proposed to forbid `Command::new("sh")`; it
matches a method, not its argument, so it would forbid every process or none.
A `grep` in `make check` that allows exactly the two known lines is the tool
that does the job (T-08).

### C. The shell scripts

| Measure | Count |
|---|---|
| `.sh` files, lines | 346, 62,658 |
| files that name their shell | 49 (39 `/bin/sh`, 10 bash) |
| files that do not | 297, all playbooks |
| files with `set -e` or `set -u` near the top | 20 |
| shellcheck findings | 405: 302 errors, 47 warnings, 54 info, 2 style |
| … of which "shell unknown" (SC2148) | 296 |
| playbooks that fail `sh -n` | 1 |

| Finding | Where | Backlog |
|---|---|---|
| **`playbooks/Code/radbeeper.sh` does not parse.** It ends inside a here-document, 31 lines into the 403 that `copal-prep.sh` holds. The cut is at the first `}` in column 0, which belongs to the init script being written, not to the function | `sh -n`: `unexpected end of file (expecting "}")`. `make lint` passes, because it parses `bin/` and `tools/` and only runs the playbooks' own checker over `playbooks/` | S-01, S-02 |
| 297 playbooks name no shell; shellcheck says so of the 296 it can parse | SC2148 | S-03 |
| shellcheck is on the bench and not in `make lint` | `Makefile:1040` | S-04 |
| `/tmp/name.$$` written as root | 64 lines in 4 files; 112 more in the assembled `copal-prep.sh` | S-05 |
| Brave is installed by `curl … \| sh` | `copal-prep.sh:6127` | S-06 |
| 41 download lines, 13 lines that verify anything | by `grep`; each needs reading | S-07 |
| `eval` on a string built from variables | `tools/copal-app-sweep.sh:26`, `tools/copal-answers.sh:371`, `tools/copal-store-bench.sh:138` | S-08 |
| `rm -rf "$DEST$_t/bin"` with nothing to stop both being empty | `playbooks/Tools/ffconverter.sh:29` (SC2115) | S-09 |
| `cd` with no `\|\| exit` | 7 places in 5 files (SC2164) | S-09 |
| a command kept in a string and run unquoted | `playbooks/Stages/17-stage-hyprland.sh:1500` (SC2089, SC2090) | S-09 |
| `A && B \|\| C` used as if/else | 10 places (SC2015) | S-09 |

Two things the numbers overstate. The 24 SC1007 warnings are all
`CDPATH= cd --`, a deliberate idiom; they want a directive, not a change. And
`copal-prep.sh` is assembled from the playbooks, so a defect counted in both
is fixed once, in the playbook, and carried over by `make sync-playbooks`.

### D. The JavaScript runtime

The warning appears 149 times in the current `ytq.log`.

| Run | yt-dlp's own report | Warning |
|---|---|---|
| as configured | `JS runtimes: none` | yes |
| `--js-runtimes node` | `JS runtimes: node-24.18.1` | **no** |
| `--js-runtimes quickjs` | `JS runtimes: none` (not installed) | yes |

The zipapp already carries its script component (`yt_dlp_ejs-0.8.0`); only a
runtime is missing, and only deno is looked for unless another is named.

| Runtime | On the bench | Alpine 3.24 | How yt-dlp starts it |
|---|---|---|---|
| node | yes | x86_64, aarch64, armv7, armhf | with `--permission`: no files, no network unless granted |
| deno | no; 94 MiB | x86_64 and aarch64 only | with no permissions granted |
| quickjs | no | all four | a script in a temporary file |

Node is the one rule that holds on all three of Copal's targets, the Pi 2B
included (C-01).

## V. Discussion

**The boundary is one place.** ytq's text comes in through four doors:
`NOTES`, `META`, `TALK` and the caption file. It goes out through at least
nine. Cleaning at the nine is nine chances to forget one — and `ffescape`,
written with care, forgot two characters. Cleaning at the four means a control
character never exists inside the program at all.

**Escaping is still owed at every exit.** Cleaning removes what is never
wanted. Escaping protects what is wanted but means something: `=` in a tag
file, `'` in a shell line, `"` in JSON. Each format gets one function, and a
test that runs the result through the real reader. `services::quote` was
already built that way, and it is the part of the program that held.

**What held was designed; what failed was assumed.** The argument lists, the
filename alphabet, the JSON on the pipe and `printable` in the window were all
decisions somebody made on purpose. The four defects are all places where a
string was assumed to be one line of printable text because it usually is.

**A linter that is installed is not a linter that runs.** shellcheck has been
on the bench throughout. The radbeeper playbook would have failed the first
time anything parsed it.

**Measure, then rank.** 405 findings is not 405 problems. 296 are one missing
line repeated; 24 are a false alarm; perhaps thirty need a person. The count
is the start of the work, not its size.

## VI. The standard

Each rule is one sentence, and each names what enforces it. A rule with
nothing to enforce it is a wish.

### A. Text from outside (Rust)

| # | Rule | Enforced by |
|---|---|---|
| T1 | Text from a site is cleaned once, where it enters: control characters dropped, except newline and tab | the hostile check |
| T2 | A field that is one line has no newline in it | the hostile check: one `License:` row, one `URL:` row |
| T3 | Every output format has one escaping function, tested against the real reader | unit tests; `ffprobe` in the hostile check |
| T4 | A process is started with an argument list. A shell is used only where a person is meant to read and retype the line | `grep` for `Command::new("sh")` in `make check` |
| T5 | `--` goes before any argument that came from outside | the run lines in `ytq.log` |
| T6 | A path read back from a child is checked before it is written to or removed | unit test |
| T7 | Anything printed to a terminal goes through `printable` | the hostile check: no byte below 0x20 but newline and tab |
| T8 | A child's answer is checked before it is acted on: text is cleaned, and a path is held to the folder and the name it should have | the hostile check, *path*; unit test |

### B. Shell scripts

| # | Rule | Enforced by |
|---|---|---|
| S1 | Every file names its shell: a `#!` line, or `# shellcheck shell=sh` in a file that is sourced | SC2148 |
| S2 | A script that is run starts with `set -eu`. A playbook is sourced and inherits it | `grep` in `make lint` |
| S3 | Every expansion is quoted: `"$var"`, `"$@"` | SC2086 |
| S4 | A command is never kept in a string, and `eval` is never given data | SC2089, SC2090; `grep` |
| S5 | `--` goes before operands that came from outside | review |
| S6 | A temporary file comes from `mktemp` and is removed by a `trap` | `grep` for `/tmp/` |
| S7 | `rm -rf` on a built path uses `"${var:?}"` | SC2115 |
| S8 | `cd` is followed by `\|\| exit` | SC2164 |
| S9 | `printf '%s\n' "$x"`, never a variable as the format | SC2059 |
| S10 | `if … then … else`, not `A && B \|\| C` | SC2015 |
| S11 | A download goes to a temporary name, is checked against a checksum or signature where one is published, and is then renamed. Nothing is piped into a shell | `grep`; review |
| S12 | A here-document that holds code is quoted (`<<'EOF'`), and every file parses | `sh -n` over every file |

### C. Written plainly

The rules above can all be met by a script nobody can read. These three are
for the reader, and only review enforces them:

1. **One function, one job, named for the job.** If the name needs "and", it
   is two functions.
2. **A comment says why.** The code already says what.
3. **The obvious form first.** A loop over a pipeline, an `if` over a chain of
   `&&`, a name over a positional parameter.

The same function, before and after:

```sh
# before
cat > /tmp/conf.$$ <<EOF
dir=$DIR
EOF
cd $DIR && install -m 644 /tmp/conf.$$ app.conf || warn "failed"
rm -rf $DIR/$OLD
```

```sh
# after
write_conf() {
    _tmp=$(mktemp) || return 1
    trap 'rm -f "$_tmp"' EXIT
    printf 'dir=%s\n' "$DIR" > "$_tmp"
    if install -m 644 -- "$_tmp" "$DIR/app.conf"; then
        note "wrote $DIR/app.conf"
    else
        warn "could not write $DIR/app.conf"
    fi
}

remove_old() {
    rm -rf -- "${DIR:?}/${OLD:?}"
}
```

## VII. Procedures

**Run the hostile check by hand**, until T-07 puts it in `make check`:

```sh
cd ~/code/staticstream && make build
W=$(mktemp -d); mkdir -p "$W/stub" "$W/home/.config/ytq" "$W/home/out"
cp tests/standin/yt-dlp "$W/stub/yt-dlp"      # then put the attacks of III.B in it
printf 'DIR=%s/home/out\nOUTPUT=mp4\n' "$W" > "$W/home/.config/ytq/config"
run() { env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u DISPLAY -u WAYLAND_DISPLAY \
        HOME="$W/home" PATH="$W/stub:$PATH" target/release/ytq "$@"; }
run add --no-run 'https://www.youtube.com/watch?v=HOSTILEAAAA'
run run --quiet
run list | cat -v                              # no ^[ may appear
cat -v "$W"/home/out/*.txt
ffprobe -v error -show_entries format_tags:chapter_tags=title -of json "$W"/home/out/*.mp4
```

**Measure the shell scripts:**

```sh
cd ~/code/copal
find . -name '*.sh' -not -path './.git/*' -not -path './vendor/*' \
       -not -path './build/*' -not -name '._*' > /tmp/sh-files
xargs shellcheck -f gcc < /tmp/sh-files | sed 's/.*\[\(SC[0-9]*\)\]$/\1/' | sort | uniq -c | sort -rn
for f in $(find playbooks -name '*.sh' -not -name '._*'); do sh -n "$f" || echo "$f"; done
```

**Ask yt-dlp which runtime it found:**

```sh
yt-dlp -v --simulate --js-runtimes node URL 2>&1 | grep 'JS runtimes'
```

**Work an entry.** Take the first entry under *Open* in `docs/backlog.md`.
Make the change, run the check the entry names, and move the entry to *Done*
with the date and the commit. An entry is not done because the change was
made; it is done because its check passed.

## VIII. Files touched

| File | Change |
|---|---|
| `docs/text-safety-lab-report.md` | this report |
| `docs/backlog.md` | new: twenty entries |
| `README.md` | two rows in the table of files |

No program was changed.

## IX. Addendum: the first two entries (29 September 2026)

**S-01 was worse than section IV says.** The playbook was cut at line 188,
and `make sync-playbooks` had carried the cut into `copal-prep.sh`. There the
here-document did not end at the cut: it ran on for 403 lines until it met
the `RADBEEPERRC` of the function's stranded second half. Everything between
was text in a file, not shell:

| Function | Defined, before | Defined, after |
|---|---|---|
| `radbeeper_pre` | yes | yes |
| `staticstream_post` | **no** | yes |
| `install_ytbrave` | **no** | yes |
| `write_media_conf` | **no** | yes |
| `grub_default_lts` | **no** | yes |

Stage 10 calls `install_ytbrave` and `staticstream_post`. On a machine
installed from `df8f98e` or later it would have found neither, and
`/etc/init.d/radbeeper` would have held four hundred lines of the installer.
`sh -n` passed throughout, because an open here-document that happens to meet
its end word is good syntax. The bench never showed it: its `yt-brave` is of
17 September, from before the split.

The fix moved 196 lines: into the playbook, and out of the place they were
stranded. The function is now, line for line, what it was before the split.
The cut was made by hand during the split; `tools/copal-playbooks.py` reads a
body whole and was not at fault, as the backlog first said it was.

What this adds to section V: **a syntax check proves a file can be read, not
that it says what was meant.** The check that found this asked a shell which
functions it had after reading the file. S-02 should ask the same.

**T-07 is written, and red.** `tests/ytq-hostile-check.sh` makes 30 checks.

| | Checks | Now |
|---|---|---|
| nothing is run; only the stand-in browser opens | 5 | pass |
| no control character in the `.txt`, log, queue, notification | 4 | **fail** |
| none printed by `ytq list`, `ytq status`, `sstr verify` | 3 | **fail** |
| no forged row in the notes or in `sstr verify` | 5 | **fail** |
| the MP4's tags: one chapter, lyrics and description whole, one-line tags | 6 | **fail** |
| guards: a field is not cut short, a real row is not lost, the capture verifies | 7 | pass |

Eighteen fail and twelve pass. The twelve were then run against a copy of
the check that sabotaged its own evidence — a planted file, a deleted row, a
truncated capture — and all thirty failed. A check that cannot fail is not
evidence, and seven of these twelve pass today only because the defect they
guard against has not been made yet.

## X. Addendum: the four defects closed (29 September 2026)

T-02, T-03, T-01 and T-04 were made in that order and the hostile check run
after each, so that each change is seen to do its own work. Cleaning at the
door first would have hidden whether `ffescape` and `printable` were right.

| After | Failing, of 30 | What turned |
|---|---|---|
| nothing | 18 | |
| T-02, `ffescape` | 15 | one chapter; lyrics and description whole |
| T-03, `printable` at the exits | 8 | `ytq list`, `ytq status`, `sstr verify`, the log, a notification |
| T-01, `clean` at the door | 5 | the `.txt`, the queue, the tags |
| T-04, `one_line` | 0 | every forged row |

A thirty-first check was added with T-01: a URL whose path is an escape
sequence is refused. Run against the ytq of `75cbf7d`, the finished check
fails 19 of 31; against the new one, none.

**The whole suite found what the hostile check could not.** With all four
changes in, `ytq-runner-crosscheck` disagreed with the Python ytq on caption
files: a tab in a caption had been made a space before `fill` could expand
it to a tab stop, as Python's `textwrap` does. Captions are now cleaned with
`clean`, which keeps a tab, and not `one_line`. A check written for the
defect would never have caught a fault in the fix; the comparison with the
specification did.

**One defect in T-03 was found by reading, before any check ran.**
`printable` makes a newline `^J`, and `say()` is given messages of several
lines. It is applied line by line.

`make check` in staticstream: 431 checks and 149 unit tests, exit 0.

| Rule | Held by |
|---|---|
| T1 | `clean`, `clean_info`; hostile check, *text* |
| T2 | `one_line`; hostile check, *rows* |
| T3 | `ffescape` and its unit test; hostile check, *tags* |
| T7 | `term::printable`; hostile check, *terminal* |

T4, T5, T6 and T8 waited on T-05, T-06 and T-08: section XI.

## XI. Addendum: hardening, and the runtime (29 September 2026)

**The defect rated low was the worst of the five.** Section IV called the
unchecked `FILE` line hardening, "no working attack found". T-05's check
gave a stand-in yt-dlp one more line to print, last: `FILE` and somebody
else's path. Against the ytq of `425ba64`, with `OUTPUT=sstr`:

| The line named | What ytq did |
|---|---|
| a file outside the folder | rewrote it with this video's tags, captured it as `precious.sstr`, and **removed it** |
| another video in the folder | the same |

How a site would get that line printed is still not known. What follows
once it is, is no longer a guess. `own_path` now holds the path to the
folder, to ytq's alphabet and, on YouTube, to the id the URL gave; both
files are untouched, and the log says what was refused and why.

**Rule T8 was wrong as written, and is changed.** "Read from stdout alone"
could not be built without losing the order of the log, which is compared
line for line with the Python ytq's — and would not have helped, since
yt-dlp quotes the site on standard output as well. The rule that can be
held is the one T-05 implements: an answer is checked, not believed.

**A severity is a guess until somebody tries.** The five defects were rated
by reading. Four were rated medium and did what was expected. The one rated
low deleted files. The rating followed how likely the way in seemed, and
said nothing of what lay behind it.

| Entry | Check | Before | After |
|---|---|---|---|
| T-05 | hostile check, *path* | 0 of 4 | 4 of 4 |
| T-06 | hostile check, *operand* | 0 of 15 commands | 15 of 15 |
| T-08 | `make shell-check`, given a fifth shell | — | fails, and names the line |
| C-01 | yt-dlp's own report, with the written file | `JS runtimes: none`, a warning | `node-24.18.1`, none |

`make check` in staticstream: 436 checks, 150 unit tests and the shell
check, exit 0.

**C-01 chose less than the backlog asked.** The entry said node; section
IV-D had shown quickjs runs on every architecture, the Pi Zero included,
where node does not. It was not chosen. yt-dlp runs deno with no
permissions and node with `--permission`, and hands quickjs the site's
script with no limits at all. A warning and fewer formats is the better
default on the one board that has no confined runtime, and the installer
says how to choose otherwise.

All eight T rules are now held by a check. Of the S rules, S12 is held for
one file, by hand; the rest wait on S-02 to S-11.

## XII. Addendum: the linter runs (29 September 2026)

| | Before | After |
|---|---|---|
| playbooks that name their shell | 0 of 297 | 297 |
| playbooks a shell cannot read | 1, unnoticed | 0, and `make lint` fails on one |
| shellcheck errors | 302 | 0 |
| shellcheck warnings | 47 | 0 |
| shellcheck notes | 56 | 57, and may only go down |
| shellcheck in `make lint` | no | yes |

**Of 349 errors and warnings, 15 were changes to code.** 296 were one
missing line, 24 were one idiom spelled the way shellcheck prefers, 11
were the installer's own globals, which a playbook read by itself cannot
see, and 3 were the radbeeper playbook of section IX. That leaves
fifteen, among them a `cd` that could fail unnoticed in seven
places, an `rm -rf` that two empty variables would have pointed at `/bin`,
and a loop that split a string to get two arguments where four plain lines
say the same. None was a defect that had bitten. All were the kind that
does.

**A directive carries its reason or it is not written.** Eleven were added,
each with a few words after it: `# read by ask(), in the installer`. Where
the code could be written so that no directive was needed — `CDPATH=''` —
it was.

**The notes are not done, and the lint says so.** Fifty-seven remain, in
the disk tool, the fleet console and the VM wrapper among others. They are
not warnings because shellcheck is not sure, and neither is a reader who
has not run the code. They are entry S-12, and until it is worked the
number in `tools/shell-lint.sh` holds them where they are.

Rules S1, S7, S8 and S12 are now held by `make lint`. S3, S9 and S10 are
held as far as warnings go, and wait on S-12 for the rest. S2, S4, S5, S6
and S11 wait on S-05 to S-08 and S-11.

## XIII. Addendum: the notes, the evals and the downloads (29 September 2026)

### A. The notes

| | |
|---|---|
| notes, before | 57 |
| rewritten | 19 |
| answered, by 31 directives, each with its reason | 38 |
| notes, after | 0 — and `NOTES=0`, so the next one fails `make lint` |

**A note was the one that ran the installer.** shellcheck's SC2006 is a
matter of style: write `$(…)`, not backticks. It was raised once, in stage
3, on a line of a message:

```
takes effect. (`copal` on its own also works -- a copy was installed
```

The message is a here-document that expands, because it names `$PI_USER`.
So the backticks were not quotation marks. Printing the message ran `copal`
and put what it printed in the sentence. On the card, before the first
reboot, there is no `copal` to run and the sentence lost a word. On an
installed machine `copal` is the installer.

| | The line as printed | Ran |
|---|---|---|
| before | `(RAN-THE-INSTALLER on its own also works` | the stand-in `copal` |
| after | `('copal' on its own also works` | nothing |

This is the defect of section IV over again, in the project's own text: a
character that means something where it lands. Rule S12 asked that a
here-document holding code be quoted. One holding prose needs the same
care, and the linter is what gave it.

**A directive is for what is meant.** Thirty-eight notes were about lines that split a list into words,
or list files whose names the project chose, or print a `$` for i3 to read.
Each says so after the directive. Three of them were one fact said three
times, and became one function, `verb_list`, that says it once.

### B. The evals

There were four, not three. One was a defect: `copal-app-sweep.sh` built
the line it evaluated with the checkout's path already in it.

| Checkout in | Before | After |
|---|---|---|
| `re po $(touch X)/` | `X` was made; the probe was not found | nothing was made; the probe ran, the path one word |

Only the row's own command line is code, as it has to be: it is written
as a person would type it, and a shell is what reads that.

### C. The downloads

| What | From | Checked against | |
|---|---|---|---|
| Alpine's payload | Alpine's mirror | the `.sha256` beside it | checked |
| the UEFI bootloader ISO | Alpine's mirror | the `.sha256` beside it | checked |
| store recipes, 94 calls in 39 playbooks | GitHub and others | **a sha256 pinned in the playbook** | checked |
| streamripper | SourceForge | a sha256 pinned in the installer | checked |
| wxMaxima, the latest | GitHub | the `.sha256` beside it, if there is one | checked, or says it is not |
| Notepad++, for Wine | GitHub | the release's checksums file | checked |
| 7-Zip, for Wine | 7-zip.org | nothing: none is published | **not**, and says so |
| the installer itself, fetched to update a machine | this repository, at a branch | its size, its first line, and that it parses; no sum and no signature | **not** — S-16 |
| yt-dlp, the latest | GitHub | nothing | **not** — S-13 |
| PianoBooster, at a pinned commit | GitHub | nothing | **not** — S-14 |
| Mini vMac, VICE | gryphel.com, SourceForge | nothing | **not** — S-14 |
| five IIO sources, at pinned tags | GitHub | nothing | **not** — S-14 |
| kicad-templates, the latest of a series | GitLab | nothing | **not** — S-14 |
| the desktop theme | GitHub, `refs/heads/main` | nothing, and the branch moves | **not** — S-15 |
| Brave's installer | dl.brave.com | nothing; piped into `sh` as root | **not** — S-06 |
| wallpapers | GitHub, `main` | nothing | **not**; pictures, resized and kept |

**Two kinds of sum, and only one proves where a file came from.** A
`.sha256` fetched from beside the file proves the transfer: whoever can
change the file can change the sum. A sum written in this repository
proves the file is the one somebody here read. The store's recipes are the
second kind, all of them. The installer's own downloads are the first kind
or none, and they are the ones that run as root.

**The table was nearly wrong about the one that matters most.** A search
for `sha256sum` near each download marked the installer's own update as
checked. It is not: a function called `sha` stands a few lines below it,
for something else. Reading the function found that. Sixteen kinds of
download are in the table; five are checked before use, one is checked
when it can be, and ten are not.

**Left as they are, on purpose.** 7-Zip publishes no sum, and the installer
says so when it fetches it. The wallpapers are pictures from a branch that
moves; they are not run, and pinning them would mean nobody gets a new one.

Rules S4 and S3, S9, S10 are now held by `make lint` at zero notes. S11
waits on S-06 and S-13 to S-16; S2, S5 and S6 on S-11 and S-05.

## XIV. Addendum: the downloads are held to a sum (29 September 2026)

| Entry | What is fetched | Held to | A byte changed |
|---|---|---|---|
| S-13 | yt-dlp, the latest | the release's own `SHA2-256SUMS` | refused; the old yt-dlp stays |
| S-14 | nine sources built as root | a sum in `pinned_sum`, by address | refused |
| S-15 | the theme | a sum, at the commit it was forked at | refused; nothing unpacked |
| S-06 | Brave's installer | nothing: none is published | — |

Of the ten kinds of download section XIII found unchecked, six are now
checked, Brave's is run whole or not at all, and two are left as they
were, on purpose. One remains: the installer fetching itself, S-16.

**A sum taken today proves tomorrow, not yesterday.** The nine sums of S-14
are what nine addresses gave on one day, fetched twice. No project among
them publishes a sum for these files, and Alpine packages none of them at
these versions, so there was nothing to set them beside. They say a file
has not changed since somebody here first fetched it. They do not say it
was right then. The table in the installer says so where the sums are.

**The pipe, measured.** Brave's instruction is `curl … | sh`. With a server
that sends the first line of a script and half of the second, and then
drops the connection:

| | Ran |
|---|---|
| piped into `sh` | the first line, and then `ech: not found` |
| fetched to a file, then run | nothing: `it could not be fetched` |

A script that is cut short at `rm -rf /tmp/brave` and one cut at
`rm -rf /` differ by where the connection dropped.

**A mistake in the testing, recorded because it is the subject.** The test
for S-06 put a stand-in `curl` first on `PATH`. The line that wrote the
stand-in came after another in a chain of `&&`, that one failed, and the
stand-in was never written. The test then ran `curl … | sh` with the real
`curl`: Brave's real installer, once, on the bench, as the user and not as
root. Its first act is to ask for glibc's version; Alpine has none, and it
stopped there. Nothing was changed. But the test of an unguarded download
made one, because a guard was assumed and not checked. The stand-in is now
written first, tested to be there, and called by its whole path.

## XV. Addendum: the folder, the setting and the signature (29 September 2026)

### A. A folder of its own

| | Before | After |
|---|---|---|
| files written by root under a name in `/tmp` that can be guessed | 121 uses | 0 |
| `make lint` on a new one | passes | fails |

One folder, made by `mktemp -d` when the installer starts and removed by
the trap that already unmounts what it mounted. The names inside it are
the names they were. What changed is that nobody else can put a file
there first.

**The failure that was designed out.** `"$COPAL_TMP/vimrc"` with the
variable unset is `/vimrc`, and root can write that. Every use is
`"${COPAL_TMP:?}/vimrc"`, which stops:

```
sh: COPAL_TMP: parameter not set or null
```

**One name could not move.** `/tmp/makewhatis.lock` is a lock, found by
its name by two programs. It wants a folder that is root's, not a name
nobody can guess. It is S-17.

### B. The signature

`copal -U` fetched the whole installer from a branch and checked that it
was large, began with `#!` and parsed. Its own comment said so: *"There is
no signature check … say so plainly rather than implying more."* It is now
checked, where a machine has been told whom to trust:

| The machine has | The file has | `copal -U` |
|---|---|---|
| no signers | anything | installs, and says it did not check |
| signers | a good signature | installs |
| signers | no signature | **refuses** |
| signers | no signature, and `--unsigned` was given | installs, and says it is not signed |
| signers | a signature, and one line more than was signed | **refuses** |
| signers | a signature by a key it does not know | **refuses** |
| signers | a signature by the right key, made for another purpose | **refuses** |

Run with two throwaway keys and a stand-in for the server. **Nothing was
signed with the author's key, and no key is in the repository.** That is
the author's to do, and to decide: `make signers KEY=…` once, and
`make sign KEY=…` when a release is tagged. Until then every machine is in
the first row, which is where it was.

**The order was changed with it.** The update used to take the installer
out of the file, parse it, and then compare. It now asks who made the file
before it reads anything in it.

**The signers come from the card and from nowhere else.** An update
cannot be allowed to say who may sign the next one.

### C. Where the standard stands

| Rule | Held by |
|---|---|
| T1–T8 | `make check` in staticstream: the hostile check, 36; the shell check; unit tests |
| S1, S3, S4, S7–S10 | `make lint`: shellcheck, no error, no warning, no note |
| S2 | `make lint`: a script that is run has `set -u` |
| S6 | `make lint`: no `/tmp/name.$$`; S-17 for the lock |
| S11 | `sha256_is`, `source_is`, the signature; by test, not by lint |
| S12 | `make lint`: every playbook read by `sh -n`, no here-document left open |
| S5 | review only |

## XVI. Addendum: a lock that is somebody else's (29 September 2026)

S-17 said to move `/tmp/makewhatis.lock` to `/run`. Reading why the lock
is taken showed that it cannot move:

```
nohup nice sh -c "( flock 9 && /usr/sbin/makewhatis -T utf8 ) 9>/tmp/makewhatis.lock" …
```

That is Alpine's own trigger for `mandoc-apropos`, run by `apk` after
every install. The installer takes the same lock to wait for it. A lock
two programs find by name is no lock if one of them looks elsewhere.

So the name stays, and the harm goes:

| A link named `makewhatis.lock`, to a file of 25 bytes | The file, after | `makewhatis` |
|---|---|---|
| `9>`, as it was | **0 bytes** | ran |
| `9>>`, and a link refused | 25 bytes | did not run, and said why |

On the bench the kernel would have refused the old line first:
`fs.protected_symlinks` is 1, and root may not follow another's link in
`/tmp`. That is a setting, and the installer does not depend on it now.

Alpine's trigger has the same `9>`. That is Alpine's to change, and worth
telling them.

**The backlog was wrong three times, and each time by not reading far
enough.** It blamed a tool for a cut made by hand (S-01). It asked for a
pipe that would have lost the log's order (T-05). It asked for a lock to
be moved away from the program it was shared with (S-17). Each entry was
written from what a line looked like. Each was corrected by reading what
the line was for. An entry is a guess until the work begins, and the
Dropped list is where the guesses that were wrong are kept.

### Where it ends

| | |
|---|---|
| entries | 26 |
| done | 25 |
| in progress | 1: S-16, which waits on a signature only the author can make |
| open | 0 |
| dropped, with the reason | 3: two were halves of entries that were done another way, and one was never an entry |

| What was found | Count |
|---|---|
| defects in ytq and Static Stream, from hostile input | 5, one of which removed files |
| defects in the installer, found by a linter that was installed and not run | a playbook cut in half, and four functions never defined |
| defects found by reading what the linter only noted | a message that ran the installer; an `eval` that ran a path |
| downloads used by root with nothing to check them | 10: 6 are now checked, 1 will be once a release is signed, 1 is run whole or not at all, and 2 are left as they are |

**Not yet done, and not in the backlog because it is not a change:** none
of the installer's changes has run on a freshly built machine. Stages 2,
3, 4, 7, 9, 10, 11, 12, 17 and 18 are changed. `make check` in copal, on the Mac, is
the test of all of it.

## References

[1] Copal Linux, "Backlog," `docs/backlog.md`, 2026.

[2] P. Richeson, "staticstream: the stand-in yt-dlp," `tests/standin/yt-dlp`,
staticstream `75cbf7d`, 2026.

[3] Copal Linux, "ytq and the Clipboard," `docs/ytq-clipboard-lab-report.md`,
2026.

[4] FFmpeg, "Metadata," `ffmpeg-formats(1)`, section *ffmetadata*, version
8.1.2.

[5] yt-dlp, "EJS," https://github.com/yt-dlp/yt-dlp/wiki/EJS, and
`yt_dlp/extractor/youtube/jsc/_builtin/`, version 2026.08.19.

[6] ShellCheck, "Checks," https://www.shellcheck.net/wiki/, version 0.11.0.

[7] The Open Group, "Shell Command Language," IEEE Std 1003.1-2024.

[8] OWASP, "OS Command Injection Defense Cheat Sheet" and "Injection
Prevention Cheat Sheet," OWASP Cheat Sheet Series.

[9] MITRE, "CWE-78: OS Command Injection," "CWE-150: Improper Neutralization
of Escape, Meta, or Control Sequences," "CWE-93: CRLF Injection," "CWE-377:
Insecure Temporary File."
