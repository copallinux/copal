# command:  lua5.4
# purpose:  The Lua 5.4 interpreter -- with LuaJIT beside it for speed.
# why:      The catalogue's Lua: the small language Neovim, many games and
#           configuration files are scripted in. The command carries its
#           version; `luajit` is the fast 5.1-compatible one.
# see:      nvim, lua-language-server

## Use
Run a script, or start the prompt and type. `-e` runs a line.

## Examples
    lua5.4                               # the prompt; Ctrl-D leaves
    lua5.4 script.lua                    # run a script
    lua5.4 -e 'print(2^10)'              # one line
    luajit script.lua                    # the same script, often much faster
    lua5.4 -i config.lua                 # run it, then stay at the prompt

## Options
-e CODE     run CODE
-i          stay interactive after running a script
-l NAME     require library NAME first
-v          the version

## Notes
- Plain `lua` may be another version: on a machine where something
  pulled in Lua 5.1, `lua` is 5.1. Say `lua5.4` to be sure; `lua -v`
  tells.
- LuaJIT implements Lua 5.1, not 5.4: integer division `//` and some
  newer features are missing there.
- Libraries come from Alpine as `lua5.4-*` packages.
