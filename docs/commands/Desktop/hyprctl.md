# command:  hyprctl
# purpose:  Ask the running Hyprland about its windows, monitors and settings, and change them.
# why:      Stage 17's desktop is Hyprland. hyprctl is how to find a monitor's
#           name, a window's class for a rule, or why a line in the config
#           was not accepted -- and to try a setting before writing it down.
# see:      copal-desk, copal-theme, copal-shot

## Use
Query (`monitors`, `clients`, `activewindow`), or act (`dispatch`,
`keyword`, `reload`). A `keyword` change lasts until the next reload;
to keep it, put the same line in `~/.config/hypr/local.conf`.

## Examples
    hyprctl monitors all                 # every output, its name and modes
    hyprctl clients                      # every window: class, title, workspace
    hyprctl activewindow                 # the focused one (click it first)
    hyprctl configerrors                 # what the config got wrong
    hyprctl reload                       # re-read the config
    hyprctl dispatch workspace 3         # do what a key would do
    hyprctl keyword general:gaps_out 0   # change a setting until the next reload
    hyprctl -j clients                   # the same as JSON, for a script

## Options
monitors [all]         outputs; all includes the disabled ones
clients                windows
activewindow           the focused window
workspaces             workspaces and what is on them
binds                  every key binding
configerrors           config lines that failed
reload                 reload the configuration
dispatch NAME ARGS     run a dispatcher: workspace, exec, killactive...
keyword NAME VALUE     set a config value for now
-j                     JSON output
--batch 'A; B'         several commands in one call

## Notes
- `~/.config/hypr/hyprland.conf` is rewritten each time stage 17 runs.
  Your changes go in `local.conf`, which it sources last, so they win;
  Hyprland reloads on save.
- Hyprland 0.54 reads only the `.conf` dialect. The `hyprland.lua`
  beside it is upstream's original, for 0.55 and later.
- A window rule needs the window's class: open it, then
  `hyprctl clients` and read `class:`.
