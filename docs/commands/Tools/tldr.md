# command:  tldr
# purpose:  Short, practical examples for a command: the man page's answer to "just show me how".
# why:      The store's quick reference (tealdeer): a handful of examples per
#           command, for when a man page is too long -- the Terminal Guide's
#           spirit, for commands it does not cover.
# see:      man, apropos

## Use
Fetch the pages once with `--update`; then `tldr COMMAND` prints its
examples. The cache is local, so it works offline afterwards.

## Examples
    tldr --update                        # fetch the pages (first, and now and then)
    tldr tar                             # examples for tar
    tldr -p linux ip                     # the Linux page when platforms differ
    tldr --list | wc -l                  # how many pages there are

## Options
-u, --update         refresh the local page cache
-l, --list           list every command with a page
-p, --platform P     linux, osx, windows, common
-L, --language L     pages in another language

## Notes
- Right after install there is no cache: every page says it is missing
  until `tldr --update` has run once, with a network.
- The pages are written for GNU/Linux: an option BusyBox lacks will
  fail here. The man page (or this guide) says what the installed
  version takes.
- It comes from Alpine's testing repository (`tealdeer@testing`).
