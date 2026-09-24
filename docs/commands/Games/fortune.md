# command:  fortune
# purpose:  Print a random saying: quotations, jokes, limericks, Star Trek.
# why:      One of the catalogue's toys, and a tradition: the saying a new
#           terminal greets you with.
# see:      cbonsai, figlet

## Use
Run it and a saying is printed. Name a collection to choose from it
alone; `-s` keeps it to a line or two.

## Examples
    fortune                              # a saying
    fortune -s                           # a short one
    fortune startrek                     # from one collection
    fortune -m 'computer'                # every saying that matches
    fortune -f                           # the collections, and their sizes

## Options
-s          short sayings only
-l          long ones only
-m PATTERN  print every saying matching PATTERN
-i          ignore case, with -m
-f          list the files it would choose from
-o          only the potentially offensive ones
-a          all of them, offensive included

## Notes
- The collections are in `/usr/share/fortune`: fortunes, fortunes2,
  limerick, recipes, startrek, zippy.
- To greet every new terminal, add `fortune -s` to the end of
  `~/.profile.local`.
