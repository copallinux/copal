# command:  ttysolitaire
# purpose:  Klondike solitaire drawn with box characters, played with vi keys.
# why:      The catalogue's nicer-looking terminal patience: real card shapes in
#           any terminal, over SSH included.
# see:      klondike

## Use
Standard Klondike: build down in alternating colours on the seven
columns, up by suit from the aces on the foundations. The cursor moves
between piles; a card is picked up and put down with one key.

## Examples
    ttysolitaire                         # play
    ttysolitaire -p 1                    # one pass through the deck: harder
    ttysolitaire --four-color-deck       # a colour per suit

## Options
-p, --passes N          passes through the deck (default 3)
--four-color-deck       a distinct colour for each suit
--no-background-color   no green table

## Notes
- The command is `ttysolitaire`, one word; the package is `tty-solitaire`.
- It installs no documentation; the keys are in the README at
  github.com/mpereira/tty-solitaire.
