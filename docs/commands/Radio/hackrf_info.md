# command:  hackrf_info
# purpose:  Identify a HackRF One: its serial number, firmware and board -- and, with its siblings, use it.
# why:      The catalogue's HackRF tools, for the transmit-and-receive SDR that
#           covers 1 MHz to 6 GHz. hackrf_info is the first check that the
#           board is seen and its firmware matches the tools.
# see:      rtl_test, gqrx

## Use
Plug the board in and run it; it prints each board found. The package's
other commands record and play samples (`hackrf_transfer`), sweep the
spectrum (`hackrf_sweep`) and update firmware.

## Examples
    hackrf_info                          # the boards found, their firmware
    hackrf_transfer -r capture.iq -f 433920000 -s 8000000 -n 80000000   # ten seconds of samples
    hackrf_sweep -f 2400:2500 -l 32 -g 20 > wifi.csv   # sweep 2.4 GHz

## Options
(hackrf_info takes none that matter: it reports every board it finds)

## Notes
- "No HackRF boards found": unplugged, or no permission -- the device
  belongs to `plugdev`, which Copal adds you to from 24 Sep 2026.
- The firmware and the tools should match: a mismatch is reported here,
  and `hackrf-firmware` (an optional) carries the matching images.
- Transmitting needs a licence for the band, and never on frequencies
  you are not permitted to use.
