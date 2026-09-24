# command:  cdrdao
# purpose:  Write CDs in disc-at-once mode: audio CDs, gapless, from a TOC or CUE file.
# why:      The catalogue's audio CD writer: disc-at-once keeps the gaps between
#           tracks exactly as described, which track-at-once cannot.
# see:      cdparanoia, abcde, xorriso

## Use
Describe the disc in a table of contents (a `.toc` or `.cue` file) that
lists the WAV files, then write it. It can also copy a whole CD.

## Examples
    cdrdao scanbus                       # the drives it can see
    cdrdao write --device /dev/sr0 disc.toc      # burn from a TOC
    cdrdao write --device /dev/sr0 --speed 8 disc.cue   # slower, from a CUE
    cdrdao read-cd --device /dev/sr0 copy.toc    # read a whole CD to image + TOC
    cdrdao show-toc disc.toc             # check a TOC before burning

## Options
write TOC          burn the disc described in TOC
read-cd TOC        read a CD into an image and a TOC
show-toc TOC       print what a TOC describes
scanbus            list drives
--device DEV       the drive (/dev/sr0)
--speed N          the writing speed
--eject            eject when done

## Notes
- A TOC file is plain text: one `TRACK AUDIO` block per track, each
  with `FILE "track01.wav" 0`.
- Access to the drive is the `cdrom` group's.
