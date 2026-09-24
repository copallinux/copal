# command:  mednafen
# purpose:  One emulator for many consoles: NES, SNES, Game Boy, Mega Drive, PC Engine, PlayStation, Saturn.
# why:      The catalogue's multi-system emulator: one command for most of the
#           classic consoles, accurate enough for the demanding ones, driven
#           entirely from the keyboard.
# see:      copal-store

## Use
Give it a game file (a ROM, or a CD image's .cue) and it picks the
system from the file. It opens a window; F1 shows the keys. Settings are
command-line switches named after the settings in its config file.

## Examples
    mednafen game.nes                    # play
    mednafen game.cue                    # a CD game, from its cue sheet
    mednafen -video.fs 1 game.sfc        # full screen
    mednafen -force_module md game.bin   # say which system when the file does not

    F1          (in the game) the list of keys
    Alt-Shift-1 configure controller 1's buttons
    F5  F7      save state / load state
    Alt-Enter   full screen

## Options
-force_module NAME   the system: nes, snes, gb, gba, md, pce, psx, ss...
-which_medium N      which disc, for a multi-disc game
-soundrecord FILE    record the sound to a WAV
-help                the options it takes on the command line

## Notes
- PlayStation, Saturn and PC Engine CD need the console's BIOS files,
  which cannot be distributed: they go in `~/.mednafen/firmware/`, and
  mednafen names the file it wants when one is missing.
- Every setting in `~/.mednafen/mednafen.cfg` is also a switch:
  `-psx.bios_na FILE`, `-video.driver opengl`.
- Games are yours to bring: only dump cartridges and discs you own.
