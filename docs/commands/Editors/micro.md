# command:  micro
# purpose:  A terminal text editor with the keys of a desktop editor: Ctrl-S, Ctrl-C, Ctrl-V, the mouse.
# why:      The catalogue's editor for anyone who does not want modes. Copy and
#           paste reach the desktop clipboard, and the mouse selects text.
# see:      nano, nvim, hx

## Use
Open a file and type. Ctrl-S saves, Ctrl-Q quits, Ctrl-Z undoes, and
Ctrl-E opens a command prompt for anything else. Syntax colours, multiple
cursors and splits come built in.

## Examples
    micro notes.txt                      # edit
    micro +42 main.c                     # at line 42
    micro -clean                         # with default settings, to rule out the config
    micro -plugin install editorconfig   # add a plugin

    Ctrl-S  Ctrl-Q     (in micro) save / quit
    Ctrl-F  Ctrl-N     find / next match
    Ctrl-Z  Ctrl-Y     undo / redo
    Ctrl-E             command prompt: help, set, vsplit, replace...
    Alt-G              show the key bindings at the foot

## Options
+N                 open at line N
-clean             ignore the configuration
-config-dir DIR    use another configuration directory
-plugin install P  install a plugin; remove to take it out
-options           list every setting and its default

## Notes
- Settings are in `~/.config/micro/settings.json`, keys in
  `bindings.json`; `Ctrl-E` then `set tabsize 4` changes and saves one.
- Copy and paste reach the desktop's clipboard through `wl-copy` and
  `wl-paste` (its `clipboard` setting is `external`).
- `Ctrl-E help` opens the manual inside the editor.
