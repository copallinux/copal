# command:  shellcheck
# purpose:  Find bugs in shell scripts: quoting, portability, and the traps sh is full of.
# why:      The catalogue's shell linter, and the one Copal's own scripts are
#           written against: most of Copal is POSIX sh, and shellcheck knows
#           which sh a script says it is.
# see:      shfmt, busybox

## Use
Run it on a script; each finding has a code (SC2086 and so on), a line,
and an explanation. The script's first line decides the dialect it
checks: `#!/bin/sh` is held to POSIX, `#!/bin/bash` allows bash.

## Examples
    shellcheck script.sh                 # check one script
    shellcheck -s sh script.sh           # as POSIX sh, whatever its first line
    shellcheck -x script.sh              # follow the files it sources
    shellcheck -f diff script.sh | patch -p1   # apply the fixes it can make

## Options
-s SHELL       check as sh, bash, dash or ksh
-x             follow `source`d files
-e CODES       exclude these codes
-S LEVEL       minimum severity: error, warning, info, style
-f FORMAT      output format: tty, gcc, json, diff

## Notes
- A finding can be silenced for one line with a comment above it:
  `# shellcheck disable=SC2086`, with the reason beside it.
- Every code has a page explaining it: search "shellcheck SC2086".
