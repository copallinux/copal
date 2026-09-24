# command:  hunspell
# purpose:  The spell checker behind LibreOffice and Firefox, from the command line.
# why:      The catalogue's spell checker for files and pipes, with American
#           English installed. Programs that check spelling as you type use
#           the same dictionaries.
# see:      aspell, vim

## Use
Check a file interactively, with suggestions for each unknown word, or
list the misspelled words for a script. `-d` chooses the dictionary.

## Examples
    hunspell letter.txt                  # check it, word by word, with suggestions
    hunspell -l letter.txt               # just the misspelled words
    hunspell -l letter.txt | sort -u     # each once
    echo 'recieve' | hunspell -a         # the pipe protocol: suggestions for a word
    hunspell -D </dev/null               # which dictionaries are installed

## Options
-d DICT      the dictionary: en_US, or another installed one
-l           list misspelled words only
-a           ispell pipe mode, for programs
-H           the input is HTML
-t           the input is TeX
-p FILE      your personal word list

## Notes
- Only `en_US` is installed. Other languages are packages:
  `apk search hunspell-` lists them (`hunspell-en-gb`, `hunspell-de-de`...).
- Words you accept go into `~/.hunspell_en_US` (per dictionary); edit
  it to take one back.
