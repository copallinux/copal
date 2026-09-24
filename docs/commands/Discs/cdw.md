# command:  cdw
# purpose:  A terminal front end for burning CDs and DVDs: data discs, ISO images, erasing.
# why:      The catalogue's disc burner for a machine with no desktop, driving
#           the command-line burning tools through menus.
# see:      xorriso, cdrdao, cdparanoia

## Use
Start it with a burner attached; pick files or an ISO image from the
menus, and write them. It calls the underlying tools (xorriso and
others) and shows what they report.

## Examples
    cdw                                  # the menus
    lsblk -o NAME,TYPE,MODEL | grep rom  # is there a drive (sr0)?

    F1  ?          (in cdw) help: the keys of the current window
    Enter          choose
    Q              quit

## Options
(none that matter: everything is chosen in its menus)

## Notes
- Writing needs access to the drive, `/dev/sr0`, which the group
  `cdrom` owns: `doas adduser $USER cdrom`, then log in again.
- Its settings, including which drive and which tools, are in its
  configuration window and `~/.cdw/cdw.conf`.
