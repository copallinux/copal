# command:  oh-my-posh
# purpose:  A shell prompt engine with a hundred ready-made themes.
# why:      The store's other prompt: built by Copal Apps from source, with its
#           whole theme collection, for anyone who wants to pick a look rather
#           than design one.
# see:      starship

## Use
Initialise it in your shell's start-up file with a theme; the next shell
has that prompt. The themes are JSON files: try one, keep the one you
like, or copy it and change it.

## Examples
    ls /usr/local/share/oh-my-posh/themes          # the themes
    echo 'eval "$(oh-my-posh init bash --config /usr/local/share/oh-my-posh/themes/jandedobbeleer.omp.json)"' >> ~/.bashrc
    oh-my-posh print primary --config THEME.omp.json   # preview a theme's prompt
    oh-my-posh debug                     # timing of each segment, to find a slow one

## Options
init SHELL          print the line that turns it on; --config THEME
print primary       print the prompt, to preview
config              read or export the configuration
debug               show what each segment costs
font                install a Nerd Font for the icons
version             the version

## Notes
- Most themes need a Nerd Font; without one the icons show as boxes.
  `copal-fonts install coding` brings them.
- A theme that runs `git` in every prompt can feel slow on a Pi in a big
  repository; `oh-my-posh debug` shows which segment it is.
