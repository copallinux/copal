# command:  radbeeper
# purpose:  A GQ GMC Geiger counter on the desk: find it, watch it, log it, and pull its history.
# why:      Stage 10 sets up the Geiger counter; radbeeper, built by copal-build
#           from its checkout, is the command the counter's instrument panel
#           (radbeeper-gui) is built on.
# see:      copal-build, dmesg

## Use
Plug the counter in by USB, `radbeeper probe` to find it, `radbeeper
watch` to see its rate over five time spans at once while it logs. It
also downloads what the counter recorded on its own, and turns the timing
of decays into random numbers.

## Examples
    radbeeper probe                      # find the counter, say what it is
    radbeeper watch                      # the monitor, logging while it is open
    radbeeper cpm                        # its counts per minute, once
    radbeeper clock                      # its clock against this machine's
    radbeeper clock --set                # correct it
    radbeeper log pull                   # download the history in its flash
    radbeeper backfill                   # fill the log's gaps from that history
    radbeeper random                     # 256 bits of hex, from decay timing

## Options
probe                 find and identify the counter
watch                 the live monitor
cpm                   one reading
clock [--set]         compare, or set, the counter's clock
log info|pull         what history it holds / download it
backfill              fill gaps in the log from the counter's memory
random                random bits from decay timing; --check F to verify a log
-d, --device PATH     the serial port; repeat for a second counter
-b, --baud RATE       the baud (default: 115200, then 57600)
--duration SECONDS    stop after this long
--logs DIR            where logs are written and read

## Notes
- Nothing found? `probe` says what went wrong, because each cause has
  its own fix. "Permission denied" means the account is not in `dialout`,
  which owns the serial port: `doas adduser $USER dialout`, then log in
  again.
- Set the clock first (`clock --set`): the history in the counter's
  flash carries the counter's own timestamps.
- The default tube factor is 151.5 CPM per µSv/h, the GMC-320's;
  `--cpm-per-usvh` for another tube.
- `doas dmesg | tail` after plugging it in shows the serial port it got.
