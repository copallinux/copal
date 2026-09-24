# command:  pylsp
# purpose:  The Python language server: completion, go-to-definition and lint for Python, in any editor.
# why:      Stage 7's server for Python, which Neovim and Helix start for .py
#           files: definitions, references and hover documentation.
# see:      python3, nvim, hx

## Use
The editor runs it over stdin and stdout; there is nothing to start by
hand. It finds modules as the Python it runs under does, so a project's
virtual environment should be active when the editor starts.

## Examples
    pylsp --help                         # its options
    . .venv/bin/activate && nvim app.py  # the editor sees the venv's packages
    pylsp -v --log-file /tmp/pylsp.log   # a verbose log, to see what it does

## Options
--tcp            serve over TCP instead of stdio
--host / --port  where, with --tcp
--log-file FILE  write its log to FILE
-v               more detail in the log

## Notes
- Its checks come from plugins: pyflakes (errors) and pycodestyle
  (style), which Copal installs with it as optionals from 24 Sep 2026.
- Settings are passed by the editor, not a file of its own.
