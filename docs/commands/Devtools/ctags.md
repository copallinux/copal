# command:  ctags
# purpose:  Universal Ctags: index a project's definitions, so an editor can jump to them.
# why:      Stage 7 installs it: the tags file lets vim and Neovim jump to a
#           function's definition in any language, even where no language
#           server exists.
# see:      nvim, vim, clangd

## Use
Run it at the top of a project; it writes a `tags` file. In vim or
Neovim, Ctrl-] on a name jumps to where it is defined, Ctrl-T jumps back.

## Examples
    ctags -R .                           # index the whole project into ./tags
    ctags -R --exclude=build .           # leaving out a folder
    ctags --list-languages               # the languages it knows
    ctags -x --kinds-c=f main.c          # the functions in one file, as a table

## Options
-R                   recurse into folders
--exclude=PATTERN    leave matching paths out
-f FILE              write to FILE instead of ./tags
--languages=LIST     index only these languages
--list-languages     list the languages
-x                   print a cross-reference table instead of a file

## Notes
- Re-run it after large changes: the tags file does not update itself.
- Add `tags` to `.gitignore`; it is generated, and large.
