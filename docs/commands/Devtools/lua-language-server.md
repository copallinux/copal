# command:  lua-language-server
# purpose:  The Lua language server: completion, types, and errors as you type, in any editor.
# why:      Stage 7's server for Lua, which Neovim starts for .lua files -- the
#           language Copal's own Neovim configuration is written in.
# see:      lua5.4, nvim

## Use
The editor runs it; there is nothing to start by hand. From the shell,
`--check` runs its diagnostics over a folder and reports what it finds.

## Examples
    lua-language-server --check=.        # the diagnostics for this folder
    lua-language-server --check=. --check_format=pretty   # readable, to stdout

## Options
--check=DIR           run the diagnostics over DIR
--check_format=FMT    pretty (to stdout) or json (to a file)

## Notes
- In Neovim it warns that `vim` is an undefined global until told the
  code runs inside Neovim: a `.luarc.json` with
  `{"diagnostics.globals": ["vim"]}`.
- A project's settings go in `.luarc.json` at its root.
