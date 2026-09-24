# command:  python3
# purpose:  The Python interpreter: scripts, a calculator, and a large standard library.
# why:      Several of Copal's own tools are Python, and so is a good share of
#           what people run on a Pi. Stage 4 installs it; the catalogue's
#           Science section adds the numerical packages.
# see:      pip, gdb, nvim

## Use
Run a script, or start the interactive prompt and type. Third-party
packages come from apk first (`py3-NAME`), and from pip inside a virtual
environment when apk has not got them.

## Examples
    python3                              # the interactive prompt; Ctrl-D leaves
    python3 script.py                    # run a script
    python3 -c 'print(2**64)'            # one line
    python3 -m http.server 8000          # serve this directory on port 8000
    python3 -m venv .venv                # a private environment for a project...
    . .venv/bin/activate                 # ...enter it (deactivate to leave)
    python3 -m json.tool data.json       # pretty-print JSON
    python3 -m pdb script.py             # step through it in the debugger

## Options
-c CMD       run CMD
-m MODULE    run a module as a script: venv, http.server, pdb, json.tool, pip
-i           stay at the prompt after the script ends
-u           unbuffered output (for logs and pipes)
-V           the version

## Notes
- `pip install` outside a virtual environment says
  "externally-managed-environment". That is deliberate: the system's
  Python belongs to apk. `apk add py3-NAME` if it exists, or a venv.
- Packages with C parts often have no ready wheel for musl and build
  from source: `apk add build-base python3-dev` first.
- Python 2 is gone: `python` is Python 3 too, but scripts written for
  Copal say `python3`, which works on every system that has it.
