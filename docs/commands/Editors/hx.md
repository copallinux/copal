# command:  hx
# purpose:  Helix: a modal editor with selections first, and a language server and syntax trees built in.
# why:      The catalogue's modern modal editor: what nvim needs a config for,
#           Helix does out of the box -- completion, go-to-definition, and a
#           menu for every key. Its command is hx.
# see:      nvim, vim, micro

## Use
Modal like vim, but the selection comes first and the action second:
`w` selects a word, then `d` deletes it. Press Space for a menu of
pickers and commands; every menu says what each key does.

## Examples
    hx main.rs                           # edit
    hx --tutor                           # the tutorial, about half an hour
    hx --health                          # which languages have a server and a grammar
    hx --health rust                     # one language in detail
    hx --vsplit a.c b.c                  # two files side by side

    i  Esc          (in hx) insert / back to normal
    w  x  d         select a word / select the line / delete the selection
    Space f         file picker;  Space /  search the project
    g d  g r        go to definition / references
    :w  :q          write / quit

## Options
--tutor              the tutorial
--health [LANG]      check the language servers and grammars
-c, --config FILE    another config file
--vsplit / --hsplit  open the files in splits
-w, --working-dir D  start in directory D
+N                   open the first file at line N

## Notes
- Language servers are programs of their own: `hx --health` shows which
  are found. Stage 7's clangd, rust-analyzer, gopls and pylsp are.
- Config is `~/.config/helix/config.toml`; themes are one line:
  `theme = "onedark"`.
- Vim habits misfire: `dw` is `wd` here, and there is no `:s` --
  select, then `s` to select within, then `c` to change.
