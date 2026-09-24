# command:  btop
# purpose:  A resource monitor with graphs: CPU, memory, disks, network and processes, live.
# why:      The store's richer htop: history graphs for every core, the disks
#           and the network in one screen, with the mouse working throughout.
# see:      htop, copal-tm

## Use
Start it; boxes show CPU, memory, disks, network and processes. Click
or use the keys; Esc opens the menu with options and help. Numbers 1 to
4 toggle the boxes.

## Examples
    btop                                 # everything
    btop -p 1                            # start with preset 1
    btop -f firefox                      # processes filtered to firefox
    btop -t                              # plain console mode, 16 colours
    btop -u 500                          # update every half second

    1 2 3 4        (in btop) show or hide cpu, memory, network, processes
    f              filter processes
    k              kill the selected process (asks first)
    Esc  q         the menu / quit

## Options
-p, --preset N     start with preset N (0-9)
-f, --filter TEXT  an initial process filter
-t, --tty          console mode: ANSI graph symbols, 16 colours
-l, --low-color    256 colours, no true colour
-u, --update MS    the update interval
-c, --config FILE  another config file

## Notes
- Its settings are saved from the menu to `~/.config/btop/btop.conf`;
  `btop --default-config` prints the defaults.
- On the Linux console (no desktop) `-t` gives graphs that draw correctly.
