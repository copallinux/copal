# command:  starship
# purpose:  A fast, configurable shell prompt: the folder, git state, language versions, all at a glance.
# why:      The store's prompt for any shell: one line added to the shell's
#           start-up file, and the prompt shows the branch, what changed, how
#           long the last command took and whether it failed.
# see:      oh-my-posh, git

## Use
Add its init line to your shell's start-up file; the next shell has the
prompt. Change it in `~/.config/starship.toml`, or start from one of its
presets.

## Examples
    echo 'eval "$(starship init bash)"' >> ~/.bashrc   # turn it on for bash
    starship preset --list               # the ready-made looks
    starship preset gruvbox-rainbow -o ~/.config/starship.toml   # use one
    starship explain                     # what each part of the prompt is
    starship toggle git_status           # switch a part off, and on again

## Options
init SHELL        print the line that turns it on (bash, zsh, fish...)
preset NAME       print a preset; -o FILE to write it
explain           describe the prompt you are looking at
config            edit the configuration
print-config      the configuration in force
toggle MODULE     turn one part on or off

## Notes
- Many presets use Nerd Font symbols: without such a font they show as
  boxes. `copal-fonts install coding` brings them.
- For the Linux console, a plain preset (`plain-text-symbols`) avoids
  symbols the console font lacks.
