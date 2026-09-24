# command:  delta
# purpose:  A pager for git diffs: syntax colour, word-level changes, line numbers, side by side.
# why:      The catalogue's diff viewer. Set as git's pager, it makes every
#           git diff, show and log -p easier to read, in any terminal.
# see:      git, tig, lazygit

## Use
Set it once as git's pager, and git uses it for everything it pages.
It also reads any diff from a pipe, or compares two files itself.

## Examples
    git config --global core.pager delta                 # git's pager, from now on
    git config --global interactive.diffFilter 'delta --color-only'   # and in git add -p
    git diff                             # now through delta
    delta -s old.txt new.txt             # two files, side by side
    diff -u a b | delta                  # any unified diff

## Options
-s, --side-by-side     the two versions in columns
-n, --line-numbers     line numbers down the side
--navigate             n and N jump between files in the pager
--dark / --light       for the terminal's background
--syntax-theme NAME    the colours; --list-syntax-themes lists them

## Notes
- Put settings in `~/.gitconfig` under `[delta]`: `side-by-side = true`,
  `line-numbers = true`.
- On Copal's light terminal theme, `--light` (or `light = true` in the
  config) keeps the colours readable.
