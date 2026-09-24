# command:  ranger
# purpose:  A terminal file manager in columns, with previews and vi keys.
# why:      The catalogue's file manager with the most on screen: the parent
#           folder, the current one and a preview side by side.
# see:      mc, nnn

## Use
Three columns: the parent folder, the current one, and a preview of what
is selected. h and l move out and in; Enter opens. Commands start with
`:`, as in vim.

## Examples
    ranger                               # the current folder
    ranger ~/Documents                   # a folder
    ranger --copy-config=all             # write its config files, to edit

    h j k l        (in ranger) out / down / up / in
    Space          mark a file
    yy  pp         copy / paste
    zh             show hidden files
    q              quit

## Options
--copy-config=WHICH   copy the default config into ~/.config/ranger
--choosefile=FILE     pick a file, and write its path to FILE
--cmd=CMD             run a ranger command at start

## Notes
- Text previews work out of the box; previews of images and PDFs need
  helper programs.
- `S` opens a shell in the current folder; `exit` returns to ranger.
