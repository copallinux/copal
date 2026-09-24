# command:  ruby
# purpose:  The Ruby language: scripts, one-liners, and gems.
# why:      The catalogue's Ruby, with irb for trying things and gem for
#           libraries -- for scripting, and for the tools written in it.
# see:      python3, perl, crystal

## Use
Run a script, or `irb` to type Ruby interactively. `-e` runs one line;
with `-n` or `-p` it runs over every line of input, like awk.

## Examples
    irb                                  # interactive Ruby; exit to leave
    ruby script.rb                       # run a script
    ruby -e 'puts 2**100'                # one line
    ruby -ne 'puts $_ if /error/' log.txt    # grep, in Ruby
    gem install --user-install rake      # a gem, in your home

## Options
-e CODE      run CODE
-n / -p      loop over input lines (-p also prints them)
-i[EXT]      edit files in place (with -p)
-I DIR       add DIR to the load path
-w           warnings

## Notes
- `gem install` without `--user-install` wants to write system
  directories: use `--user-install`, or an `apk add ruby-NAME` package.
- User gems' commands land in `~/.local/share/gem/ruby/*/bin`, which is
  not on PATH until you add it.
