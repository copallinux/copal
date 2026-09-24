# command:  unison
# purpose:  Two-way file synchronisation: changes on either side are carried to the other.
# why:      The catalogue's two-way sync, run when you choose -- for a laptop
#           and a Pi that both change the same folder. Where rsync mirrors one
#           way, unison merges both, and asks about conflicts.
# see:      rsync, syncthing, ssh

## Use
Name two roots -- local folders, or one over ssh -- and unison compares
them with what it saw last time, proposes what to copy each way, and
asks about anything changed on both sides.

## Examples
    unison ~/docs ssh://pi//home/you/docs          # sync, asking
    unison -batch ~/docs ssh://pi//home/you/docs   # no questions: skip conflicts
    unison -auto ~/docs /media/usb/docs            # accept non-conflicts, ask the rest
    unison work                                    # the profile ~/.unison/work.prf

## Options
-batch       ask nothing; conflicting files are skipped
-auto        accept the default actions, ask only about conflicts
-ui text     the text interface (the default here)
-path P      sync only P, within the roots
-ignore P    leave P out (as a pattern)
-prefer ROOT on a conflict, take ROOT's version

## Notes
- Both machines need the same unison version -- 2.54 here -- or it
  refuses to talk.
- The double slash in `ssh://pi//home/you/docs` is an absolute path;
  a single one would be relative to your home on `pi`.
- A profile saves the roots and options: `root = ...` lines in
  `~/.unison/NAME.prf`, then `unison NAME`.
