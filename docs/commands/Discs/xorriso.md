# command:  xorriso
# purpose:  Make ISO 9660 images and burn them: data discs, bootable images, and updates to both.
# why:      The catalogue's ISO tool, and the one that makes bootable images:
#           its `-as mkisofs` mode takes the options of the classic mkisofs.
# see:      cdw, cdrdao, bsdtar

## Use
Build an image from a folder, burn an image to a disc, or list and
extract what an image holds. `-as mkisofs` and `-as cdrecord` accept the
older tools' options, which is what most recipes online use.

## Examples
    xorriso -as mkisofs -o backup.iso -J -R ~/Documents   # an ISO from a folder
    xorriso -indev image.iso -ls /                        # what is in an image
    xorriso -osirrox on -indev image.iso -extract / out/  # unpack it
    xorriso -as cdrecord -v dev=/dev/sr0 image.iso        # burn it to a disc
    xorriso -devices                                      # the burners it sees

## Options
-as mkisofs      behave like mkisofs (-o OUT, -J, -R, -V LABEL)
-as cdrecord     behave like cdrecord (dev=, -v, blank=)
-indev FILE      read an existing image or disc
-outdev FILE     write to an image or disc
-ls PATH         list a folder inside the image
-extract A B     copy A from the image to B (with -osirrox on)
-devices         list optical drives

## Notes
- `-J -R` add Joliet and Rock Ridge: long names for Windows and Unix.
  Without them names are cut to 8.3 capitals.
- Burning needs the `cdrom` group, which owns `/dev/sr0`.
