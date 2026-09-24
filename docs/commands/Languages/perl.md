# command:  perl
# purpose:  Perl: text processing, one-liners, and a great deal of Unix glue.
# why:      On every Copal machine: much of the system's own tooling is Perl,
#           and its one-liners edit files and reports faster than anything.
# see:      awk, sed, python3, ruby

## Use
Run a script, or a one-liner with `-e`. With `-n` or `-p` it loops over
every input line; with `-i` it edits files in place.

## Examples
    perl -e 'print 2**40, "\n"'          # one line
    perl -ne 'print if /error/i' log.txt     # grep, case-insensitive
    perl -pi -e 's/colour/color/g' *.md  # edit files in place
    perl -pi.bak -e 's/foo/bar/' conf    # the same, keeping conf.bak
    perldoc -f sprintf                   # the manual for one function

## Options
-e CODE     run CODE
-n / -p     loop over input lines (-p also prints each)
-i[EXT]     edit in place, keeping a backup with EXT
-l          chomp input lines and add newlines to print
-w          warnings
-M MODULE   use MODULE first

## Notes
- Libraries come from Alpine as `perl-*` packages: `apk search
  perl-json`. cpan is not installed.
- `-i` without an extension edits with no backup; give one while
  learning.
