# command:  lazygit
# purpose:  A terminal interface for git: stage, commit, branch, rebase and push from panels.
# why:      The catalogue's git interface, and the one Copal's Neovim opens with
#           Space g g, in a window over the editor.
# see:      git, gitui, tig, nvim

## Use
Start it in a repository. Panels on the left show status, files,
branches, commits and stashes; the right shows what the selection is.
Keys act on the selection, and the foot of the screen lists them.

## Examples
    lazygit                              # the repository here
    lazygit -p ~/code/copal              # another repository
    lazygit -f README.md                 # the history of one file

    Space          (in lazygit) stage or unstage the file
    c              commit the staged changes
    P  p           push / pull
    Tab / 1-5      move between panels
    ?              every key here;  q  quit

## Options
-p, --path DIR     the repository to open
-f, --filter PATH  only the history that touches PATH
-c, --config       print the default config
-cd, --print-config-dir   where its config lives

## Notes
- Its config is `~/.config/lazygit/config.yml`; `lazygit -c` prints
  every setting with its default, to copy from.
- Whatever it does is ordinary git: `git log` and `git status` in a
  shell show the same repository.
