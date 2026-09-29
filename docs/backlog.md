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

**Standing:** 14 open · 0 in progress · 6 done · 1 dropped. Written 29 September 2026.

---

## Open

### Hardening

| ID | Entry | Rule | Check |
|---|---|---|---|
| T-05 | The path on a `FILE` line is accepted only inside `DIR`; yt-dlp's stderr goes to its own pipe | T6, T8 | unit test: a `FILE` line naming a path outside `DIR` is refused and logged |
| T-06 | `--` before the URL in the four yt-dlp commands, and through `yt-brave` | T5 | the `run:` lines in `ytq.log` show `-- https://…`; `make check` still passes |
| T-08 | `make check` fails if `Command::new("sh")` appears anywhere but the two Workspace lines | T4 | add a third and watch it fail |

### The JavaScript runtime

| ID | Entry | Rule | Check |
|---|---|---|---|
| C-01 | `--js-runtimes node` in the `/etc/yt-dlp.conf` that `copal-prep.sh` writes, and stage 10 installs `nodejs` | — | `yt-dlp -v --simulate URL` reports `JS runtimes: node-…`; a new `ytq.log` has no runtime warning |

### The shell scripts

| ID | Entry | Rule | Check |
|---|---|---|---|
| S-02 | `make lint` runs `sh -n` over every file in `playbooks/` | S12 | lint fails on the radbeeper playbook before S-01 and passes after |
| S-03 | `# shellcheck shell=sh` in the 297 playbooks, written by `tools/copal-playbooks.py fmt` | S1 | no SC2148 |
| S-04 | shellcheck in `make lint`: errors fail it now; warnings are held to a count in the Makefile that may only go down | S1–S10 | `make lint` |
| S-05 | `mktemp` and a `trap` in place of `/tmp/name.$$`: 64 lines, in stages 4, 7 and 17 and `tools/release-walkthrough.sh` | S6 | `grep -rE '/tmp/[A-Za-z0-9._-]+\.\$\$' playbooks tools` finds nothing |
| S-06 | Brave's installer is downloaded to a file, shown, then run — not piped into `sh` | S11 | `grep -E 'curl[^#]*\| *sh' copal-prep.sh` finds only comments |
| S-07 | Read all 41 download lines. Each gets a checksum or a signature where upstream publishes one, and a note where it does not | S11 | a table in the lab report: download, what verifies it |
| S-08 | The three `eval`s on built strings: `tools/copal-app-sweep.sh:26`, `tools/copal-answers.sh:371`, `tools/copal-store-bench.sh:138`. Replace with `"$@"`, or say in a comment why the string cannot hold outside text | S4 | review; shellcheck clean |
| S-09 | The warnings that are real: SC2115 (1), SC2164 (7), SC2089 and SC2090 (1 each), SC1087 (3), SC2015 (10), SC2086 (10), SC2059 (4) | S3, S7–S10 | the count in S-04 goes down by 37 |
| S-10 | `# shellcheck disable=SC1007` on the 24 `CDPATH= cd --` lines in `bin/`, with the reason | — | no SC1007 |
| S-11 | `set -eu` in every script that is run and has none | S2 | `make lint` lists none |

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
| S-01 | `playbooks/Code/radbeeper.sh` was cut short inside a here-document, and the cut was worse in `copal-prep.sh` than in the playbook: the here-document stayed open for 403 lines and took in `staticstream_post`, `install_ytbrave`, `write_media_conf` and `grub_default_lts`, so a fresh install defined none of them. The 196 lines left behind are back in the playbook and gone from where they were stranded. The cut was made by hand when the function was split out in `df8f98e`, not by `tools/copal-playbooks.py`, which reads a body whole. **Check:** `sh -n` passes on all 297 playbooks; a shell that reads the region defines all five functions, where it defined one; `radbeeper_pre` is line for line the function of before the split | 29 September 2026 | `e1300c5` |

## Dropped

| ID | Entry | Why |
|---|---|---|
| — | Clippy's `disallowed_methods` to forbid `Command::new("sh")` | it matches a method, not its argument. T-08 does the job with `grep` |
