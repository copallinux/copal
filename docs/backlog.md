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

**Standing:** 7 open · 0 in progress · 18 done · 2 dropped. Written 29 September 2026.

---

## Open

### The shell scripts

| ID | Entry | Rule | Check |
|---|---|---|---|
| S-05 | `mktemp` and a `trap` in place of `/tmp/name.$$`: 64 lines, in stages 4, 7 and 17 and `tools/release-walkthrough.sh` | S6 | `grep -rE '/tmp/[A-Za-z0-9._-]+\.\$\$' playbooks tools` finds nothing |
| S-06 | Brave's installer is downloaded to a file, shown, then run — not piped into `sh` | S11 | `grep -E 'curl[^#]*\| *sh' copal-prep.sh` finds only comments |
| S-11 | `set -eu` in every script that is run and has none | S2 | `make lint` lists none |
| S-13 | yt-dlp's zipapp is checked against the `SHA2-256SUMS` of the release it came from, before it replaces the one in `/usr/local/bin`. It is the latest, so no sum can be pinned here; the release's own is what there is | S11 | a zipapp with one byte changed is refused, and the old one stays |
| S-14 | A pinned sha256 for each source that is fetched by version and built as root: PianoBooster, Mini vMac, VICE, the five IIO sources, kicad-templates. A version given on the command line has no pinned sum, and the installer says it is building unverified, as wxMaxima's does | S11 | each refuses an archive with one byte changed |
| S-15 | The desktop theme is fetched from `refs/heads/main`, a branch that moves, and unpacked as root. Pin it to a commit and a sha256, as `PIANOBOOSTER_REF` is pinned | S11 | the URL names a commit; a changed archive is refused |
| S-16 | The installer fetches itself, to update a machine, from a branch of this repository, and checks its size, its first line and that it parses. Nothing says it is the file that was published. Sign a release with the key captures are signed with, and have the machine check the signature against a key it was installed with | S11 | a `copal-prep.sh` with one byte changed is refused |

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
| S-08 | Four `eval`s, not three. `copal-app-sweep.sh` put the checkout's path into the line it evaluated: from a folder named `re po $(touch X)`, it ran `touch`. Only the row's command line is code now; the path is expanded inside the `eval`, in quotes. `copal-answers.sh` parses the two functions it cuts from `copal-prep.sh` before it evaluates them. `copal-store-bench.sh env` prints its values in single quotes. `copal-app-probe.sh` holds what it evaluates to a hexadecimal address and four numbers. **Check:** the sweep from that folder runs nothing and passes the path as one word; a value with quotes, a `$` and backticks in it reads back the same | 29 September 2026 | `c7953b3` |
| S-12 | The 57 notes, read one by one: 19 rewritten, 38 answered by 31 directives, each with its reason. `NOTES=0`, so the next note fails `make lint`. **One was a defect:** stage 3's closing message had `` `copal` `` in a here-document that expands, so printing it *ran* `copal` — on an installed machine, the installer itself. **Check:** with a stand-in `copal` on `PATH` the old message ran it and the new one does not; `copal-disk.sh self-test` passes its 59 checks with the same output; the four `printf` lines of `copal-fleet.sh` print the same bytes | 29 September 2026 | `c7953b3` |
| S-07 | Every download read, and tabled in the lab report, section XIII: sixteen kinds, of which five are checked against a sum before use, one is checked when upstream gives a sum, and ten are not. What is to be done about the ten is S-06 and S-13 to S-16; two are left as they are, with the reason | 29 September 2026 | `c7953b3` |
| S-01 | `playbooks/Code/radbeeper.sh` was cut short inside a here-document, and the cut was worse in `copal-prep.sh` than in the playbook: the here-document stayed open for 403 lines and took in `staticstream_post`, `install_ytbrave`, `write_media_conf` and `grub_default_lts`, so a fresh install defined none of them. The 196 lines left behind are back in the playbook and gone from where they were stranded. The cut was made by hand when the function was split out in `df8f98e`, not by `tools/copal-playbooks.py`, which reads a body whole. **Check:** `sh -n` passes on all 297 playbooks; a shell that reads the region defines all five functions, where it defined one; `radbeeper_pre` is line for line the function of before the split | 29 September 2026 | `e1300c5` |

## Dropped

| ID | Entry | Why |
|---|---|---|
| T-05, in part | A pipe of its own for yt-dlp's standard error, so that answers are read from standard output alone | two reasons. The log is compared line for line with the Python ytq's, and two pipes lose the order the lines were written in. And yt-dlp quotes the site on standard output too, so the split would not have closed what it was for. `own_path` checks the line instead of trusting where it came from |
| — | Clippy's `disallowed_methods` to forbid `Command::new("sh")` | it matches a method, not its argument. T-08 does the job with `grep` |
