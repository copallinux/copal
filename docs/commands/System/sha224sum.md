# command:  sha224sum
# purpose:  Compute or check SHA-224 checksums; its siblings do MD5 and the other SHA sizes.
# why:      The catalogue's row for GNU coreutils' checksum tools: prove a
#           download or a copied file is exactly what it should be. Copal's own
#           downloads are checked against sha256 sums the same way.
# see:      curl, rsync

## Use
Give it files and it prints a checksum for each. Save those lines to a
file, and `-c` later checks the files against it. `sha256sum` is the one
most downloads publish; `md5sum`, `sha1sum` and `sha512sum` work alike.

## Examples
    sha224sum photo.jpg                  # one checksum
    sha256sum alpine.iso                 # the size most downloads publish
    sha256sum *.iso > SUMS               # save checksums for later
    sha256sum -c SUMS                    # check the files against them
    echo 'HASH  file.iso' | sha256sum -c # check against a published hash

## Options
-c, --check    read checksums from a file and check them
--quiet        with -c: print only failures
--status       with -c: print nothing; the exit code says
-b, --binary   read in binary mode (the same on Linux)

## Notes
- The line format is the hash, two spaces, then the file name; `-c`
  needs exactly that.
- MD5 and SHA-1 catch accidents, not tampering. For checking a
  download's authenticity, use SHA-256 or longer.
