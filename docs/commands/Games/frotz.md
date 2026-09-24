# command:  frotz
# purpose:  A Z-machine interpreter: plays Infocom's text adventures and everything written for it since.
# why:      The catalogue's interactive-fiction player. It ships with no stories;
#           thousands are free on the Interactive Fiction Archive, and Zork I to
#           III are freely distributed.
# see:      adventure

## Use
Give it a story file -- `.z3`, `.z5`, `.z8` -- and play by typing
commands. `save` and `restore` work inside the story, to a file you
name.

## Examples
    frotz zork1.z5                       # play
    frotz -w 80 story.z8                 # at a fixed width
    frotz -d story.z5                    # no colours

    look  inventory    (in the story) the usual commands
    save  restore      to and from a file you name
    undo               take back the last move, in stories that allow it
    quit               leave

## Options
-d          disable colour
-w N        the screen width
-h N        the screen height
-l N        the left margin
-L FILE     load a saved game at start
-e          enable sound

## Notes
- Where to find stories: ifarchive.org (the Interactive Fiction Archive),
  and ifdb.org to choose one. Most are one file; download it and play.
- Glulx stories (`.gblorb`, `.ulx`) need a different interpreter; frotz
  is the Z-machine only.
