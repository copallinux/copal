# copal-zap

A folder, cut into discs and burned straight from the source. There is no
image file and no copy, so the only space a backup needs is the discs'.

```
make && make install            # ~/.local/bin/copal-zap, a link to the build
make gui-build && make gui-install   # the window, copal-zap-gui
XORRISO=/path/to/xorriso make check  # without one, the disc tests say SKIPPED
```

## A disc's life

| step | what happens |
| --- | --- |
| **plan** | The folder is walked and cut into discs in name order, so each disc is a range you can write on its label. A video stays with its transcripts, and a folder two levels down (a git checkout) stays whole. The media is a blank in the drive (its real free space) or one of `cd dvd dvd-dl bd25 bd50 bd100 bd128`. |
| **rehearse** | The whole disc is built into `/dev/null`. Every source byte is read, the file list is proved, and the source's rate is measured; under five seconds is too short to count. |
| **burn** | xorriso streams the disc to the drive and records an MD5 of every file on it. The speed comes from the rehearsal: the fastest whole multiple the source can feed, with a fifth in hand. A source slower than 1x is refused, because the burn would starve. |
| **verify** | The disc is read back against those MD5s. Every planned file must be on it, and every source must still be as planned. |
| **retire** | The files are moved into `FOLDER/_burned/LABEL/`. It is a rename, so nothing is copied. It refuses unless the disc is verified, unchanged, and every source folder is writable. |

Plans are plain text in `~/.local/share/copal-zap/SET/`: a cue per disc
(`bytes  mtime  path`) and a log of the stages it has passed. Each disc
carries its own cue as `/LABEL.cue`.

## Simulate

`copal-zap --simulate …`, or the window's **Simulate** switch, does
everything a burn does with an image file where the disc would be. Every
source byte is read and checksummed, and the image is written, verified and
deleted. Simulated plans live apart, in `copal-zap-sim/`, so they can never
mark a real disc burned. The library refuses to retire them, and refuses to
let them burn to a drive.

## What was learned from xorriso 1.5.8 itself

- Files go in as shell-quoted `-map` lines. `-pathspecs` doubled a
  backslash in a name.
- `-md5 on` must come before `-indev`. Otherwise verify loads no
  checksums, checks nothing, and exits 0.
- xorriso reads 2 KB at a time. Over copal's uncached 9p share that is
  4–8 MB/s, against 22 for `cat`: 1x on a BD-R at best. The fifo dial sits
  at 0% when this is the limit.
