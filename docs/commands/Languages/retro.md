# command:  retro
# purpose:  RetroForth: a small, modern language in the Forth family.
# why:      The catalogue's Forth. Alpine packages no gforth on any
#           architecture; RetroForth is packaged everywhere and actively kept.
#           It is not ANS Forth: the words differ.
# see:      guile, lua5.4

## Use
Type at the prompt, or run a file. Values go on a stack; words take them
off and put results back. A prefix says what a token is: `#` a number,
`'` a string, `:` a new definition.

## Examples
    retro                                # the interactive prompt
    retro program.retro                  # run a file
    echo "#2 #3 + n:put" | retro         # prints 5

    #2 #3 + n:put                (at the prompt) add, print the number
    'hello s:put                 print a string
    :square dup * ;              define a word
    #7 square n:put              use it: 49

## Options
-i            interactive mode
-f FILE       run the code blocks in FILE
-h            the usage

## Notes
- Code in a `.retro` file runs only inside fenced blocks (~~~ lines):
  the rest is prose, literate-programming style.
- `copal-guide languages` says more about why it is Retro, not gforth.
