# command:  angband
# purpose:  Angband: a hundred-level descent to Morgoth, in the lineage of Moria.
# why:      The catalogue's long-form roguelike: a character built over many
#           hours, a town to return to, and the dungeon from Tolkien's Moria
#           onward.
# see:      zangband, nethack, brogue

## Use
Create a character, buy supplies in the town, and descend. Levels are
made afresh every time you take the stairs, so going back up and down is
normal. `?` is the help, `Enter` a menu of every command.

## Examples
    angband                              # continue, or make a character
    angband -n                           # a new character
    angband -l                           # the savefiles there are
    angband -uGandalf                    # play the savefile named Gandalf

    arrows / hjkl  (in angband) move
    Enter          the menu of every command
    g  i  w        pick up / inventory / wield
    <  >           stairs up / down
    Ctrl-X         save and quit

## Options
-n          a new character (overwrites the default savefile, without -u)
-u NAME     use the savefile NAME
-l          list the savefiles
-c          choose a savefile from a menu
-w          bring a dead character back (marks the save)

## Notes
- Your saves and settings are in `~/.angband`, not in `/usr/share`.
- `-n` without `-u` replaces the default character. Name a new one:
  `angband -n -uSomeone`.
- It comes from Alpine's testing repository (`angband@testing`).
