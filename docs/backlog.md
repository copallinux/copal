# Backlog

<!-- SPDX-License-Identifier: MIT -->

Work that is known and not yet done, in the order it should be done. The
reasoning for every entry below is in
[`text-safety-lab-report.md`](text-safety-lab-report.md); the standard the
entries bring the code up to is its section VI.

Milestone 4 of Copal Fleet has a backlog of its own,
[`fleet-m4-backlog.md`](fleet-m4-backlog.md).

## How to use this

1. Take the first entry under **Open**.
2. Make the change in the repository the entry names.
3. Run the entry's **Check**. An entry is done when its check passes, not
   when the change is made.
4. Move the row to **Done**, with the date and the commit.

An entry that is decided against moves to **Dropped** and keeps its reason.

| Prefix | Means | Repository |
|---|---|---|
| T | text from outside | `staticstream` |
| C | configuration | `copal` |
| S | shell scripts | `copal` |

**Standing:** 6 open · 0 in progress · 15 done · 2 dropped. Written 29 September 2026.

---

## Open

### The shell scripts

| ID | Entry | Rule | Check |
|---|---|---|---|
| S-05 | `mktemp` and a `trap` in place of `/tmp/name.$$`: 64 lines, in stages 4, 7 and 17 and `tools/release-walkthrough.sh` | S6 | `grep -rE '/tmp/[A-Za-z0-9._-]+\.\$\$' playbooks tools` finds nothing |
| S-06 | Brave's installer is downloaded to a file, shown, then run — not piped into `sh` | S11 | `grep -E 'curl[^#]*\| *sh' copal-prep.sh` finds only comments |
| S-07 | Read all 41 download lines. Each gets a checksum or a signature where upstream publishes one, and a note where it does not | S11 | a table in the lab report: download, what verifies it |
| S-08 | The three `eval`s on built strings: `tools/copal-app-sweep.sh:26`, `tools/copal-answers.sh:371`, `tools/copal-store-bench.sh:138`. Replace with `"$@"`, or say in a comment why the string cannot hold outside text | S4 | review; shellcheck clean |
| S-11 | `set -eu` in every script that is run and has none | S2 | `make lint` lists none |
| S-12 | The 57 notes shellcheck still has, read one by one: SC2012 (16), SC2015 (12), SC2086 (9), SC2016 (6), SC2059 (4) and eight others. Each is fixed or answered with a directive and its reason, and `NOTES` in `tools/shell-lint.sh` comes down with them | S3, S9, S10 | `make lint` with `NOTES=0` |

---

## In progress

*Nothing.*

## Done

| ID | Entry | Done | Commit |
|---|---|---|---|
| T-07 | `tests/ytq-hostile-check.sh` and `tests/standin/yt-dlp-hostile`, as `make ytq-hostile-check` and last in `make check`: the real ytq against a stand-in yt-dlp whose every field carries an attack. **Check:** 31 checks. Against the ytq of `75cbf7d`, 19 fail; against this one, none. The 12 that passed from the start were each made to fail once by a sabotaged copy | 29 September 2026 | staticstream `425ba64` |
| T-02 | `ffescape` escapes a carriage return and leaves out a NUL, which cannot be escaped. **Check:** with this change alone the MP4 had one chapter where it had three, and its lyrics and description whole: 18 failures became 15 | 29 September 2026 | staticstream `425ba64` |
| T-03 | `printable()` on what `ytq list`, `ytq status` and a runner print, on every line of the log, on a notification line by line, on the `stream`, `source`, `license`, `note` and `key` rows of `sstr verify`, and on the line the Workspace shows before it runs it. **Check:** with T-02 and this, 15 failures became 8 — and `sstr verify` lost its forged rows too, a newline being `^J` | 29 September 2026 | staticstream `425ba64` |
| T-01 | `src/ytq/clean.rs`: `clean`, used on `NOTES`, `META` and the comments as they are parsed, on every line yt-dlp writes, on the check's title, and on a caption's words after its entities are undone. A URL with a control character in it is refused. **Check:** 8 failures became 5, the five forged-row checks | 29 September 2026 | staticstream `425ba64` |
| T-04 | `one_line`: every string of yt-dlp's info is one line, but the description and a comment's text. **Check:** 5 failures became none; `make check` passes, 431 checks and 149 unit tests, the crosschecks against the Python ytq agreeing as before | 29 September 2026 | staticstream `425ba64` |
| T-06 | `--` before the URL in all four yt-dlp commands. `yt-brave` passes it through, as its own comment says it does. **Check:** hostile check, *operand*: 15 of 15 logged commands end ` -- 'https://…'`, where none of 15 did; the crosschecks set the `--` aside, the Python ytq giving none | 29 September 2026 | staticstream `6b626c4` |
| T-05 | `own_path`: a `FILE` or `STEM` line is believed only if the path is in `DIR` itself, in ytq's alphabet and, for a YouTube video, ends in the id the URL gave. **The defect was real, not only possible:** against `425ba64`, a forged last `FILE` line had ytq capture and *remove* a file outside the folder and another video inside it. **Check:** hostile check, *path*, 4 checks, all failing before and passing after; a unit test of 15 cases. The second half of the entry, a pipe of its own for yt-dlp's errors, was not done — see Dropped | 29 September 2026 | staticstream `6b626c4` |
| T-08 | `tests/shell-check.sh`, as `make shell-check` and in `make check`: `Command::new("sh")` and its kin may appear in three files, four times, and nowhere else. **Check:** a fifth, added to a scratch file, failed it and named the line | 29 September 2026 | staticstream `6b626c4` |
| C-01 | `install_js_runtime` and `node_runs` in `copal-prep.sh`: stage 10 offers nodejs (49 MiB) where there is no node, and `/etc/yt-dlp.conf` gains `--js-runtimes node` only where node runs — Node does not run on ARMv6, and is packaged for it all the same. quickjs is named to the person and not chosen for them: yt-dlp confines node and deno and does not confine it. **Check:** the three cases run from the installer's own functions; with the file they write, yt-dlp 2026.08.19 reports `JS runtimes: node-24.18.1` and no warning, and names the file as before. **Not yet on the bench:** `/etc/yt-dlp.conf` is root's, and changes when stage 10 next runs | 29 September 2026 | `99d8df8` |
| S-02 | `tools/copal-playbooks.py check`, which `make lint` runs, now reads every playbook's body: a here-document left open is an error, and so is anything `sh -n` refuses. **Check:** the radbeeper playbook cut as it was fails with both; one with a stray `}` fails with the second; all 297 pass | 29 September 2026 | `dd2e680` |
| S-03 | `# shellcheck shell=sh` is the first line of all 297 playbooks, written by `fmt` and required by `check`. It is not part of the body, so nothing generated from a playbook carries it. **Check:** no SC2148, where there were 296 | 29 September 2026 | `dd2e680` |
| S-09 | Every error and warning, 50 of them, read and answered. Fixed: `${P2MNT}[[:space:]]` for `$P2MNT[[:space:]]` (3), `cd … \|\| exit` and `\|\| return` (7), `"$DEST${_t:?}/bin"` (1), the `gsettings` loop written as four lines (2), an unused `read` name (1), `ls \| grep` as a loop (1). Answered with a directive and its reason, being the installer's own globals: `AUTO_DEFAULT` (4), `copal_theme_dir` (2), `_t` (5). The notes are S-12 | 29 September 2026 | `dd2e680` |
| S-10 | `CDPATH='' cd --` in the 24 shortcuts of `bin/`, which is what shellcheck asked for and says the same thing. No directive was needed, so none was written | 29 September 2026 | `dd2e680` |
| S-04 | `tools/shell-lint.sh`, as `make shell-lint` and in `make lint`: an error or a warning fails; notes are held to `NOTES=57` and may only go down; skipped, and says so, where there is no shellcheck. **Check:** a script with a bare `cd` and an unguarded `rm -rf` failed it, and so did one more note. Its own first run failed it too: a comment that began `# shellcheck exits` was read as a directive | 29 September 2026 | `dd2e680` |
| S-01 | `playbooks/Code/radbeeper.sh` was cut short inside a here-document, and the cut was worse in `copal-prep.sh` than in the playbook: the here-document stayed open for 403 lines and took in `staticstream_post`, `install_ytbrave`, `write_media_conf` and `grub_default_lts`, so a fresh install defined none of them. The 196 lines left behind are back in the playbook and gone from where they were stranded. The cut was made by hand when the function was split out in `df8f98e`, not by `tools/copal-playbooks.py`, which reads a body whole. **Check:** `sh -n` passes on all 297 playbooks; a shell that reads the region defines all five functions, where it defined one; `radbeeper_pre` is line for line the function of before the split | 29 September 2026 | `e1300c5` |

## Dropped

| ID | Entry | Why |
|---|---|---|
| T-05, in part | A pipe of its own for yt-dlp's standard error, so that answers are read from standard output alone | two reasons. The log is compared line for line with the Python ytq's, and two pipes lose the order the lines were written in. And yt-dlp quotes the site on standard output too, so the split would not have closed what it was for. `own_path` checks the line instead of trusting where it came from |
| — | Clippy's `disallowed_methods` to forbid `Command::new("sh")` | it matches a method, not its argument. T-08 does the job with `grep` |
