# command:  rdfind
# purpose:  Find redundant files across folders, ranked by which copy is the original, and act on them.
# why:      The store's duplicate finder for "which copy do I keep?": it ranks
#           files by the order the folders were given, so the first folder's
#           copies win -- right for clearing a backup against the originals.
# see:      fdupes, jdupes

## Use
Name the folders, the one to keep first. By default it only writes a
report, `results.txt`; options replace the later copies with links, or
delete them. Try with `-dryrun true` before changing anything.

## Examples
    rdfind ~/Pictures /media/usb/old-backup            # report only: results.txt
    rdfind -dryrun true -deleteduplicates true ~/Pictures /media/usb/old   # what it would delete
    rdfind -deleteduplicates true ~/Pictures /media/usb/old   # delete the backup's copies
    rdfind -makehardlinks true ~/Music                  # link duplicates, keep every name

## Options
-dryrun true            say what would change, change nothing
-deleteduplicates true  delete all but the highest-ranked copy
-makehardlinks true     replace duplicates with hard links
-makesymlinks true      replace them with symbolic links
-makeresultsfile false  no results.txt
-ignoreempty true       skip empty files (the default)

## Notes
- The order of the folders is the ranking: the first folder's copy is
  the one kept. Put the originals first.
- Options take `true` or `false` after them, unlike most commands.
