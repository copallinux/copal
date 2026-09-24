# command:  dpkg
# purpose:  Look inside Debian and Ubuntu packages: list, inspect and unpack .deb files.
# why:      The catalogue's way to open a .deb on Alpine, to see what it holds
#           or take files out of it. Not for installing: Alpine's packages
#           are apk's.
# see:      rpm, bsdtar, apk

## Use
`dpkg-deb` does the looking: `-c` lists the files, `-I` shows the
package's information, `-x` extracts the files into a folder.

## Examples
    dpkg-deb -I package.deb              # name, version, dependencies, description
    dpkg-deb -c package.deb              # the files it contains
    dpkg-deb -x package.deb out/         # extract the files into out/
    dpkg-deb -e package.deb ctl/         # its control files and install scripts
    dpkg -c package.deb                  # the same as dpkg-deb -c

## Options
-c, --contents    list the contents (as dpkg-deb -c)
-I, --info        show the package information
-x DIR            extract the files into DIR (with dpkg-deb)
-e DIR            extract the control files (with dpkg-deb)

## Notes
- `dpkg -i` would install into a Debian database that nothing here reads:
  do not. The program inside is built for glibc and will not run on musl
  as it is.
- `bsdtar -xf package.deb` shows the layers: `control.tar.*` and
  `data.tar.*`, the second holding the files.
