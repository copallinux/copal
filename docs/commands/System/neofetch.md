# command:  neofetch
# purpose:  The original system-summary-with-a-logo script.
# why:      The store keeps it for the recipes and screenshots that name it;
#           fastfetch is its faster successor and the one to use day to day.
# see:      fastfetch

## Use
Run it; it prints the system's details beside an ASCII logo. It is a
bash script, so it is slower than fastfetch, and no longer developed.

## Examples
    neofetch                             # the summary
    neofetch --off                       # no logo
    neofetch --ascii_distro arch         # another distribution's logo
    neofetch --config none               # ignore any config file

## Options
--off                 no ASCII art
--ascii_distro NAME   use that distribution's logo
--config FILE         another config file; none for the defaults
--backend NAME        how to show an image (ascii, off...)

## Notes
- Upstream stopped in 2020: details of newer hardware and desktops may
  be missing or wrong. fastfetch reports them correctly.
- It comes from Alpine's testing repository (`neofetch@testing`).
