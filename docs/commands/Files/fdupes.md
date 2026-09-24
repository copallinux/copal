# command:  fdupes
# purpose:  Find duplicate files -- identical contents, whatever their names -- and optionally delete them.
# why:      The store's duplicate finder: photos copied twice, downloads saved
#           again, backups of backups. It compares sizes, then checksums, then
#           bytes, so a match is exact.
# see:      jdupes, rdfind

## Use
Point it at folders; it prints each set of identical files together.
Look at the list before deleting anything; `-d` then asks, set by set,
which copy to keep.

## Examples
    fdupes -r ~/Pictures                 # sets of duplicates, recursively
    fdupes -rS ~/Downloads               # with each file's size
    fdupes -rm ~/Music                   # just a summary: how many, how much space
    fdupes -rd ~/Pictures                # choose, set by set, which to keep

## Options
-r, --recurse      go into subfolders
-S, --size         show sizes
-m, --summarize    only the totals
-n, --noempty      ignore empty files
-d, --delete       ask which file of each set to keep, delete the rest
-N, --noprompt     with -d: keep the first of each set without asking
-f, --omitfirst    list all but the first file of each set

## Notes
- `-dN` deletes without asking, keeping whichever file happened to be
  listed first: check the list without `-d` first.
- Deleting is permanent; there is no bin. For a gentler clean-up,
  `rdfind -makehardlinks true` keeps every name and frees the space.
