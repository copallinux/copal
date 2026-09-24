# command:  copal-times
# purpose:  How long each package took to install, which ones pulled in the most, and what could be reordered.
# why:      A Copal install is hours on a small board, and the time goes
#           somewhere measurable. The installer records every package's time
#           and dependencies; this reads that record to show what was slow and,
#           more usefully, which package's position in the order decided what
#           everything after it cost.
# see:      apk, copal-install

## Use
With no argument: the fifteen slowest packages and the total. `groups`
shows the time by stage section; `order` and `shared` are the views for
deciding what to install first.

## Examples
    copal-times                          # the slowest fifteen
    copal-times groups                   # time by section
    copal-times order                    # what pulled the most in, and where it sat
    copal-times shared                   # prerequisites many packages needed
    copal-times deps gcc                 # what gcc brought with it
    copal-times total                    # one line: packages, failures, time
    copal-times csv > times.csv          # for a spreadsheet

## Options
(none), top    the slowest fifteen, and the summary
all            every package, slowest first
groups         time and count by section
order          the packages that pulled in the most, with their position
shared         dependencies wanted by more than one package
deps PKG       what one package brought with it
total          packages, already present, failed, and the install time
csv            the whole record as CSV
--motd         rewrite the login message's summary (needs doas)
--reset        clear the record (needs doas)
-h, --help     the usage

## Notes
- PULLED is how many other packages came with one. A long time with "-"
  is a package that is genuinely expensive; a long time with "+13" is one
  that happened to be asked for first and paid for the dependencies.
- The record is `/var/lib/copal/install-times.tsv`, with dependency sets
  in `install-deps.tsv`; older six-column records still read.
