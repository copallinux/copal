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

**Standing:** 1 open · 1 in progress · 24 done · 2 dropped. Written 29 September 2026.

---

## Open

### The shell scripts

| ID | Entry | Rule | Check |
|---|---|---|---|
| S-17 | `/tmp/makewhatis.lock` is a lock two programs find by its name, so it cannot be one `mktemp` made. It is opened for writing by root, in a folder anybody can write to. It belongs in `/run`, which is root's; both programs that take it change together | S6 | `grep -rn '/tmp/makewhatis.lock'` finds nothing; two installs at once still wait for each other |

---

## In progress

| ID | Entry | Rule | Where it stands |
|---|---|---|---|
| S-16 | The installer fetching itself is checked against a signature. **The checking side is built, and does nothing until a machine has signers.** `copal -U` fetches `copal-prep.sh.sig` from beside the file and checks it with `ssh-keygen -Y verify` against `/etc/copal/allowed_signers`, which the card brings. With signers and no good signature it refuses, unless `--unsigned` is given. With no signers it installs as it always did and says it did not check. `tools/copal-sign.sh` and `make signers`, `make sign`, `make signed` are the other side. **Checked** with throwaway keys and a stand-in server, eight cases: no signers; a good signature; none published; none, with `--unsigned`; signed and then changed; signed by a key the machine does not know; signed by the right key for another purpose; nothing at that ref. **What is left is the author's:** `make signers KEY=…` once, `make sign KEY=…` when a release is tagged, and the decision to do either. Nothing was signed, and no key of anybody's is in the repository | S11 | `ecebfc1` |

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
| S-05 | Every file the installer writes in `/tmp` before putting it in place is in a folder of its own, `COPAL_TMP`, made by `mktemp -d` when it starts and removed by its cleanup trap: 121 uses, in stages 4, 7 and 17 and in the installer's own part. Each is `"${COPAL_TMP:?}/name"`, so a stage run where the folder was never made stops, and does not write to `/name`. Three more outside the installer use `mktemp` themselves. `make lint` now fails on `/tmp/name.$$`. **Check:** none is left; none was inside a here-document, where the name would have been text for another program; an unset `COPAL_TMP` stops the line and writes nothing; the rule read into `mdev.conf` arrives as before. S-17 is what this left | 29 September 2026 | `ecebfc1` |
| S-11 | `set -eu` in the 21 shortcuts of `bin/` that had none. `copal-app-sweep.sh` has `set -u` and says why not `-e`: a probe that fails is a verdict, and the sweep goes on. `lib-profile.sh` is read into the launchers and never run, so its first line names its shell and is not a `#!`. `make lint` fails on a script that is run and has no `set -u`. **Check:** a script with neither failed it | 29 September 2026 | `ecebfc1` |
| S-13 | yt-dlp's zipapp is held to the sum its own release gives, by `sha256_is`, before it replaces the one in `/usr/local/bin`. **Check:** the real release installs; one with a byte changed is refused, and the yt-dlp that was there is as it was | 29 September 2026 | `43a7f32` |
| S-15 | The theme is fetched at `c0e3eac`, the commit it was forked at, and held to a sum. Its `configs/` are the card's, byte for byte. **Check:** the real archive unpacks; one with a byte changed is refused and nothing is unpacked | 29 September 2026 | `43a7f32` |
| S-14 | `pinned_sum`, one table of nine sums by the address each file is fetched from, and `source_is`, which holds a download to it. A version the table does not know is built, and said to be unverified. A copy from the card is not asked: the card is where the installer came from too. **Check:** all nine real files pass, and all nine addresses are found in the table; one with a byte changed is refused; an unknown version is built with the warning. **The sums are first-use:** what each address gave on 29 September 2026, the same twice. None could be set beside a sum its project publishes | 29 September 2026 | `43a7f32` |
| S-06 | Brave's installer is fetched to a file, its size and sha256 written to the log, and then run. **Check:** with a connection that drops after the first line, the pipe ran that line as root would have; the file ran nothing | 29 September 2026 | `43a7f32` |
| S-01 | `playbooks/Code/radbeeper.sh` was cut short inside a here-document, and the cut was worse in `copal-prep.sh` than in the playbook: the here-document stayed open for 403 lines and took in `staticstream_post`, `install_ytbrave`, `write_media_conf` and `grub_default_lts`, so a fresh install defined none of them. The 196 lines left behind are back in the playbook and gone from where they were stranded. The cut was made by hand when the function was split out in `df8f98e`, not by `tools/copal-playbooks.py`, which reads a body whole. **Check:** `sh -n` passes on all 297 playbooks; a shell that reads the region defines all five functions, where it defined one; `radbeeper_pre` is line for line the function of before the split | 29 September 2026 | `e1300c5` |

## Dropped

| ID | Entry | Why |
|---|---|---|
| T-05, in part | A pipe of its own for yt-dlp's standard error, so that answers are read from standard output alone | two reasons. The log is compared line for line with the Python ytq's, and two pipes lose the order the lines were written in. And yt-dlp quotes the site on standard output too, so the split would not have closed what it was for. `own_path` checks the line instead of trusting where it came from |
| — | Clippy's `disallowed_methods` to forbid `Command::new("sh")` | it matches a method, not its argument. T-08 does the job with `grep` |
