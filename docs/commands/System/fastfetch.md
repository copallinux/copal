# command:  fastfetch
# purpose:  The system at a glance, beside a logo: OS, kernel, CPU, memory, desktop, uptime.
# why:      The store's system summary: what this machine is, in one screen --
#           useful for a bug report, and the screenshot every desktop gets.
# see:      neofetch, btop, uname

## Use
Run it; it prints the details beside Alpine's logo. A config file chooses
which modules appear and in what order.

## Examples
    fastfetch                            # the summary
    fastfetch -l none                    # without the logo (for a bug report)
    fastfetch -c all                     # every module it has
    fastfetch --gen-config               # write a config to edit
    fastfetch --list-modules             # what it can show

## Options
-l, --logo NAME       another logo, or none
-c, --config FILE     a config file or preset (all, neofetch...)
--gen-config [PATH]   write a starting config
--list-modules        list the modules
-s, --structure LIST  which modules, in order: OS:Kernel:Memory

## Notes
- Its config is `~/.config/fastfetch/config.jsonc` once generated.
- It is neofetch's fast successor: the same idea, in C, in a fraction
  of the time.
