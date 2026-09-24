# command:  cdparanoia
# purpose:  Rip audio CDs to WAV files, correcting for scratches and drive errors.
# why:      The catalogue's CD ripper: it reads each sector until it is sure,
#           which is what makes a rip from a worn disc sound like the disc.
# see:      abcde, cdrdao

## Use
With a CD in the drive, rip every track, or chosen ones, to WAV files
in the current folder. The progress line shows how hard it had to work.

## Examples
    cdparanoia -Q                        # the tracks on the disc
    cdparanoia -B                        # every track, as track01.cdda.wav...
    cdparanoia 3 song.wav                # track 3 only
    cdparanoia -B -d /dev/sr1            # from another drive

## Options
-B          batch: every track, each to its own file
-Q          query the disc and print its table of contents
-d DEV      the drive to use
-X          abort on a skip rather than filling it in
-z          never skip: retry an unreadable sector forever

## Notes
- For MP3, FLAC or Ogg with names and tags, `abcde` runs cdparanoia and
  an encoder together.
- The drive needs the `cdrom` group.
