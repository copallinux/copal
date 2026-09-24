# command:  vim
# purpose:  The Vim editor: modal editing, everywhere, with spell checking.
# why:      Stage 7 writes ~/.vimrc -- the half of Copal's editor setup vim and
#           Neovim share: building with F5, the error list, the debugger. The
#           catalogue row adds it with spelling for writing prose.
# see:      nvim, hunspell, aspell

## Use
Edit text with Vim's modes: normal mode to move and change, insert mode
to type. On Copal, `nvim` is the full IDE; `vim` is the same editing
with fewer parts, and the spell checker is where it earns its row.

## Examples
    vim notes.md                         # edit
    vim -c 'set spell spelllang=en_us' letter.txt   # with spelling on
    doas apk add vim-tutor && vimtutor   # the half-hour lesson (a separate package)

    :set spell       (in vim) spell checking on (spelllang=en_gb for British)
    ]s  [s           next / previous misspelling
    z=               suggestions for the word under the cursor
    zg               add the word to your own list
    :w  :q  :wq      write / quit / both

## Options
-c CMD       run an Ex command after opening the file
+N           open at line N
-d A B       diff two files
-R           read-only
-u NONE      start with no configuration (to test a problem)

## Notes
- Vim uses its own spell files, not Hunspell's dictionaries. English
  ships with it; for another language, `:set spelllang=de` offers to
  download that file.
- `~/.vimrc` is rewritten when stage 7 runs; your own settings go in
  `~/.vimrc.local`, which it reads last.
- Words added with `zg` are kept in `~/.vim/spell/`.
