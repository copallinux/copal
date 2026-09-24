# command:  just
# purpose:  A command runner: a project's recipes -- build, test, deploy -- in a justfile.
# why:      The catalogue's make for tasks rather than files: named recipes,
#           arguments, and no tabs-versus-spaces trap.
# see:      make

## Use
Write recipes in a `justfile`; `just NAME` runs one, `just` runs the
first. Each recipe is a list of shell lines.

## Examples
    just --list                          # the recipes here
    just                                 # the default (first) recipe
    just test                            # one recipe
    just deploy pi                       # with an argument
    just --dry-run build                 # what it would run

## Options
-l, --list        list the recipes
-n, --dry-run     print the commands, run nothing
-f, --justfile F  use another justfile
--choose          pick a recipe from a list
-v                print each command as it runs

## Notes
- A justfile recipe: a name and a colon, then the lines indented under
  it -- spaces or tabs, either works.
- Unlike make, just does not compare file times: a recipe always runs.
