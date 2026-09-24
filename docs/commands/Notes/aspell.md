# command:  aspell
# purpose:  GNU's spell checker: interactive checking of files, and good suggestions.
# why:      The catalogue's other spell checker. Its suggestions for badly
#           mangled words are often better than hunspell's, and it knows the
#           markup of Markdown, HTML and TeX.
# see:      hunspell, vim

## Use
`aspell check FILE` walks through the file, offering replacements for each
unknown word; `aspell list` prints the unknown words for a script.

## Examples
    aspell check letter.txt              # interactive, with suggestions
    aspell -d en_GB check letter.txt     # British spelling
    aspell --mode=markdown check README.md   # skip code and links
    aspell list < letter.txt | sort -u   # the misspelled words, once each
    aspell dicts                         # the dictionaries installed

## Options
check FILE        check interactively
list              read stdin, print the misspelled words
-d DICT           the dictionary: en, en_US, en_GB, en_CA, en_AU
--mode=MODE       the markup to skip: markdown, html, tex, email
dicts             list the installed dictionaries

## Notes
- `check` rewrites the file in place and leaves a `.bak` beside it.
- English in several spellings is installed (`aspell-en`); other
  languages are `aspell-de`, `aspell-fr` and so on.
- Your added words are in `~/.aspell.en.pws`.
