# command:  mksquashfs
# purpose:  Pack a folder into a SquashFS image -- compressed, read-only, mountable -- and unsquashfs to unpack one.
# why:      The catalogue's SquashFS tools: the format of live systems and of
#           Alpine's own boot images, and a way to keep a large folder
#           compressed yet browsable.
# see:      bsdtar, xorriso

## Use
`mksquashfs FOLDER IMAGE` writes a compressed image of the folder.
Mount it read-only to use the files in place, or `unsquashfs` to get
them back.

## Examples
    mksquashfs ~/photos photos.sqfs -comp zstd      # an image, zstd-compressed
    unsquashfs -l photos.sqfs                       # list what is inside
    unsquashfs -d restored photos.sqfs              # unpack into restored/
    doas mount -o loop,ro photos.sqfs /mnt          # browse it in place

## Options
-comp ALG      compression: gzip, xz, lz4, zstd, lzo
-b SIZE        block size (larger compresses better)
-e NAMES       exclude these files
-noappend      overwrite the image rather than add to it
-processors N  threads to use

## Notes
- Without `-noappend`, a second run adds to an existing image rather
  than replacing it.
- The image is read-only by design; to change it, unpack, edit, and
  pack again.
