# command:  unarj
# purpose:  List, test and extract .arj archives -- the DOS-era format.
# why:      The catalogue's key to old archives: software and files from the
#           1990s, BBS downloads and old disk images often arrive as .arj.
# see:      7z, bsdtar, zip

## Use
A command letter, then the archive. It only reads: it cannot make .arj
files.

## Examples
    unarj l old.arj                      # list the contents
    unarj t old.arj                      # test it for damage
    unarj x old.arj                      # extract, keeping folders
    unarj e old.arj                      # extract everything into this folder

## Options
l ARCHIVE    list
t ARCHIVE    test
x ARCHIVE    extract with paths
e ARCHIVE    extract without paths

## Notes
- It is the free demonstration version: it reads ordinary archives but
  not multi-volume or password-protected ones. `7z x old.arj` handles
  more.
- Names from DOS come in capitals and 8.3 form, as they were stored.
