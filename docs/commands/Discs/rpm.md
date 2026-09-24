# command:  rpm
# purpose:  Look inside Red Hat, Fedora and SUSE packages: list, inspect and unpack .rpm files.
# why:      The catalogue's way to open a .rpm on Alpine -- to read what a
#           package holds, or take one file out of it. Not for installing:
#           Alpine's packages are apk's.
# see:      dpkg, bsdtar, apk

## Use
Query a package file with `-qp` and a second letter for what to show.
To unpack it, turn it into a cpio stream with rpm2cpio.

## Examples
    rpm -qpi package.rpm                 # name, version, description
    rpm -qpl package.rpm                 # the files it contains
    rpm -qp --scripts package.rpm        # what it would run on install
    rpm2cpio package.rpm | cpio -idmv    # unpack it into this folder
    bsdtar -xf package.rpm               # the same, in one step

## Options
-q, --query       query mode
-p, --package     query a package file (not an installed package)
-l, --list        list its files
-i                with -q: its information
--scripts         with -q: its install scripts

## Notes
- `rpm -i` would try to install into an rpm database Alpine does not
  use: do not. A program packaged only as .rpm needs rebuilding for
  Alpine, or a Flatpak.
- A .rpm is built for glibc; its binaries will not run on musl as they
  are.
