# command:  pip
# purpose:  Install Python packages from PyPI -- inside a virtual environment.
# why:      Stage 7 installs it for the packages Alpine does not carry. On
#           Alpine it refuses to touch the system's Python, and that refusal
#           is the most-asked question about it.
# see:      python3, apk

## Use
Make a virtual environment for the project, enter it, and pip installs
there -- not into the system. For a command-line tool you want
everywhere, `pipx` does the same for one program at a time.

## Examples
    apk search -e py3-requests           # first: does apk have it?
    python3 -m venv .venv && . .venv/bin/activate   # a venv, entered
    pip install requests                 # into the venv
    pip install -r requirements.txt      # a project's list
    pip freeze > requirements.txt        # write that list
    pip list --outdated                  # what could be upgraded
    doas apk add pipx && pipx install yt-dlp   # a tool, in its own venv, on PATH

## Options
install PKG         install; -U to upgrade; ==VER for a version
install -r FILE     install every line of FILE
uninstall PKG       remove
list                what is installed; --outdated
show PKG            version, location, dependencies
freeze              installed packages as a requirements file

## Notes
- "error: externally-managed-environment" outside a venv is Alpine
  protecting apk's Python. `--break-system-packages` overrides it and
  means what it says: a later `apk upgrade` can break both.
- A package with C inside may have no musl wheel and compile instead,
  which needs `build-base python3-dev` and, on a Pi, patience.
- `pip install --user` is refused too. `pipx` is the tool for
  per-user programs; it puts them in `~/.local/bin`, which Copal puts on PATH.
