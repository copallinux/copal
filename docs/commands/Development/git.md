# command:  git
# purpose:  Version control: keep a project's history, branch it, and share it.
# why:      Stage 7 clones your repositories into ~/code with it, and sets its
#           identity from the answers given on the Mac. copal-code pulls and
#           rebuilds every checkout through it; Copal itself is a git checkout.
# see:      ssh-keygen, ssh, make, copal-code, copal-build

## Use
Record changes as commits, move between versions, and exchange them with
a remote such as GitHub. The daily loop is short: `status`, `add`,
`commit`, `pull`, `push`.

## Examples
    git status                           # what changed, what is staged
    git add -p                           # stage changes a piece at a time
    git commit -m 'Fix the menu order'   # record them
    git pull --rebase                    # bring in others' work, yours on top
    git push                             # send your commits
    git log --oneline --graph -20        # recent history as a tree
    git diff HEAD~1                      # what the last commit changed
    git switch -c try-this               # a new branch, and onto it
    git restore file.c                   # throw away uncommitted edits to a file

## Options
status                 the working tree against the last commit
add -p                 stage hunk by hunk, asking for each
commit -m MSG          commit with a message; --amend to redo the last one
pull --rebase          fetch, then replay your commits on top
log --oneline          one line per commit; --graph draws the branches
diff / diff --staged   unstaged / staged changes
switch -c NAME         create a branch and switch to it
restore FILE           discard working-tree changes; --staged to unstage
stash / stash pop      set changes aside, and bring them back
remote -v              where fetch and push go

## Notes
- Stage 7 clones over SSH when it can and over HTTPS when it cannot.
  HTTPS checkouts pull but cannot push without a token: make a key
  (`ssh-keygen -t ed25519`), add its `.pub` to GitHub, then
  `git remote set-url origin git@github.com:you/thing.git`.
- The identity comes from stage 1's answers: `git config --global
  user.email` shows it, and sets it.
- `git restore` and `git reset --hard` discard work with no undo. When
  unsure, `git stash` first: it keeps the changes where you can get them back.
- With `delta` installed (the catalogue's System section),
  `git config --global core.pager delta` makes diffs coloured and clearer.
