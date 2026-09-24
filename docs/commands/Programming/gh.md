# command:  gh
# purpose:  GitHub from the command line: pull requests, issues, releases, repositories and CI runs.
# why:      The store's GitHub client: everything around the code -- review,
#           issues, Actions -- without a browser, next to git in the same
#           terminal.
# see:      git, ssh-keygen

## Use
Sign in once with `gh auth login`; then run commands inside a checkout
and gh knows which repository you mean.

## Examples
    gh auth login                        # sign in (a browser code, or a token)
    gh repo clone owner/project          # clone
    gh pr list                           # open pull requests here
    gh pr create --fill                  # a pull request from this branch
    gh pr checkout 42                    # check out someone's pull request
    gh issue list --label bug            # issues with a label
    gh run watch                         # follow the current Actions run

## Options
auth login        sign in to GitHub
repo clone R      clone a repository
pr list/create/checkout/merge   pull requests
issue list/create/view          issues
release create TAG              a release, with files
run list/watch                  GitHub Actions runs
gist create FILE                a gist

## Notes
- `gh auth login` can make git use gh for HTTPS as well, so pushes over
  HTTPS work without a separate token; SSH keys keep working as before.
- On a machine without a desktop browser, choose the device-code way to
  sign in: it prints a code to enter on any other device.
