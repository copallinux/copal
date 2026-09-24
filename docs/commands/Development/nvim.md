# command:  nvim
# purpose:  Neovim: a modal text editor, set up by Copal as a small IDE.
# why:      Stage 7's editor. Copal's configuration gives it building (F5),
#           the error list, a debugger (F4), language servers and
#           LazyVim-shaped keys -- with no plugin manager and nothing to download.
# see:      make, gdb, git, tmux, clang

## Use
Open a file, edit in insert mode, move and change text in normal mode.
On a Copal machine it also builds and debugs: F5 runs `make`, the errors
land in a list, and the language server answers "where is this defined"
and "who calls this". Space is the leader key: press it and wait for the
menu of what follows.

## Examples
    nvim main.c                          # open a file
    nvim +42 main.c                      # at line 42
    nvim -d old.c new.c                  # side-by-side diff
    copal-guide nvim                     # Copal's tutorial, from nothing to useful

    F5          (in nvim) save and build; ]q / [q walk the errors
    gd  gr  K   go to definition / references / documentation
    Space ci    who calls this function
    F9  F4      breakpoint here / start the debugger
    Ctrl-O      back to where you jumped from
    :Lsp        which language servers this machine has

## Options
+N              open at line N
-d A B          diff mode
-R              read-only
--clean         start with no configuration at all (to test a problem)
:w  :q  :wq     (in nvim) write, quit, both; :q! quits without saving
i  Esc          (in nvim) into insert mode, back to normal mode
u  Ctrl-R       (in nvim) undo, redo

## Notes
- The configuration is layered, and one part is yours:
  `~/.config/nvim/local.lua` is never written by Copal and runs last.
  `init.vim`, `theme.lua`, `keys.lua` and `lsp.lua` are rewritten when
  stage 7 runs again.
- Language servers need the project's build flags for C and C++: a
  `compile_commands.json`, from `bear -- make` or cmake.
- The colours follow the desktop's theme, even in a running editor.
- `:Tutor` inside nvim is the half-hour lesson in the modal part.
