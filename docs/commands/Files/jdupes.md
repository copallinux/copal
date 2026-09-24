# command:  jdupes
# purpose:  A faster fdupes: find duplicate files, and delete, hard-link or deduplicate them.
# why:      The store's fast duplicate finder: the same results as fdupes,
#           much quicker on large folders, and able to replace copies with
#           hard links instead of deleting.
# see:      fdupes, rdfind

## Use
The same way as fdupes: point it at folders, read the sets, then decide.
Beyond deleting, `-L` replaces duplicates with hard links, so every name
stays and the space is freed.

## Examples
    jdupes -r ~/Pictures                 # sets of duplicates
    jdupes -rm ~/Music                   # a summary
    jdupes -rL ~/Photos                  # hard-link duplicates together
    jdupes -rd ~/Downloads               # choose which to keep, set by set

## Options
-r, --recurse       go into subfolders
-S, --size          show sizes
-m, --summarize     only the totals
-d, --delete        ask which to keep, delete the rest
-N, --no-prompt     with -d: keep the first without asking
-L, --link-hard     replace duplicates with hard links
-B, --dedupe        copy-on-write deduplication (Btrfs, XFS)
-Q, --quick         skip the final byte-by-byte check (faster, less sure)

## Notes
- Hard links only work within one filesystem, and after linking,
  editing one name edits them all -- fine for photos, wrong for files
  you mean to change separately.
- `-Q` trades certainty for speed; leave it off before deleting.
- It comes from Alpine's testing repository (`jdupes@testing`).
