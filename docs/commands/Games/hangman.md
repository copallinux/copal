# command:  hangman
# purpose:  Hangman, against the system dictionary.
# why:      Part of the catalogue's BSD games. It draws its words from
#           /usr/share/dict/words, which Copal links to the English word list.
# see:      fortune, robots

## Use
Guess the hidden word a letter at a time; seven wrong guesses and the
figure is complete.

## Examples
    hangman                              # play, words from the system dictionary
    hangman -m 8                         # only words of 8 letters or more
    hangman -d words.txt                 # words from your own list

## Options
-d FILE    the word list (default /usr/share/dict/words)
-m N       the shortest word length

## Notes
- "unable to open dictionary file /usr/share/dict/words" means the
  word list is missing: stage 18 links it to `american-english` from
  `words-en`.
