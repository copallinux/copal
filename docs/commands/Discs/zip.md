# command:  zip
# purpose:  Make .zip archives -- and, with unzip, list and extract them.
# why:      The catalogue's zip pair: the archive format every other system
#           opens without asking, for sending folders to Windows and Mac users.
# see:      unzip, 7z, bsdtar

## Use
`zip ARCHIVE FILES` adds files to an archive, creating it if needed; `-r`
takes whole folders. `unzip` extracts, `unzip -l` lists.

## Examples
    zip -r photos.zip ~/Pictures/trip    # a folder, recursively
    zip notes.zip *.txt                  # some files
    zip -e secret.zip plan.txt           # with a password
    unzip -l photos.zip                  # what is inside
    unzip photos.zip -d ~/restore        # extract into a folder

## Options
-r          include folders, recursively
-e          encrypt, asking for a password
-9          best compression (-1 fastest)
-u          update: add only changed files
-x PATTERN  leave matching files out
-q          quiet

## Notes
- zip's own password encryption is weak. For real secrecy use
  `7z a -p -mhe=on`, which is AES-256 and hides the file names too.
- `zip -r` stores paths as given: `zip -r a.zip /home/you/x` stores the
  full path, so change into the folder first for short ones.
