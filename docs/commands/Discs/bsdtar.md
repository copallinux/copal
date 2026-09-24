# command:  bsdtar
# purpose:  libarchive's tar: reads almost any archive -- tar, zip, 7z, rar, iso, cpio, deb, rpm, xar.
# why:      The catalogue's universal unpacker. One command extracts whatever
#           format someone sent, detecting it and its compression by itself.
# see:      7z, zip, xorriso, rpm, dpkg

## Use
The tar options, on any format: `-t` lists, `-x` extracts, `-c` creates.
Compression is detected when reading; when creating, `-a` picks it from
the file name.

## Examples
    bsdtar -tf archive.zip               # list any archive
    bsdtar -xf image.iso -C out/         # extract, here an ISO, into out/
    bsdtar -xf package.rpm               # the files inside an .rpm
    bsdtar -caf backup.tar.zst ~/notes   # create, compression from the name
    bsdtar -cf - folder | ssh pi 'bsdtar -xf - -C /tmp'   # copy a tree over ssh

## Options
-t            list the contents
-x            extract
-c            create
-f FILE       the archive (- for stdin or stdout)
-C DIR        change into DIR first
-a            with -c: compression from the suffix (.gz .xz .zst .zip ...)
-v            name each file
-z / -j / -J  gzip / bzip2 / xz, when creating without -a

## Notes
- `tar` on Copal is GNU tar; `bsdtar` is the one that also opens zip,
  7z, ISO and rar.
- It reads rar, but writes only the formats it lists in its manual:
  tar, zip, 7z, iso, cpio and others.
