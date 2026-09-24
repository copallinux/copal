# command:  copal
# purpose:  The installer, on the machine itself: re-run any stage, update Copal, and see what is installed.
# why:      Stage 3 leaves this copy on every Copal machine, so the whole
#           install -- eighteen stages -- can be re-run, one stage or all of
#           them, and updated from the repository without the Mac.
# see:      copal-store, copal-config, copal-code

## Use
With no arguments it shows the stage menu. `--stage N` re-runs chosen
stages; `-U` updates Copal's scripts from the repository (or from a local
checkout); `--check` says whether an update exists. Updating changes what
the stages will do; it does not run them.

## Examples
    copal                                # the stage menu
    copal --check                        # is there a newer Copal?
    doas copal -U                        # update from the repository
    doas copal --stage 17                # re-run one stage (the desktop)
    doas copal --stage 12,18 --auto      # re-run two, answering for you
    doas copal -U --from ~/code/copal && doas copal --stage 17 --auto   # test a local change
    copal --version                      # what is installed, and from where

## Options
--stage N,...    run only these stages (add --auto to answer their questions)
--auto           every stage, unattended, resuming across reboots
-U [REF]         update from the repository; REF a branch, tag or commit
-U --from PATH   update from a checkout on this machine
--check [REF]    whether an update is available; changes nothing
--version        the installed version and its source

## Notes
- Every stage is written to be run again: a re-run repairs or updates
  what it set up and leaves the rest alone.
- An update keeps the previous copy as `copal-init.sh.bak`.
- `-U REF` pins a version: a tag or commit goes back to an older Copal.
