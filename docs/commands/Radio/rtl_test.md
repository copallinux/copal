# command:  rtl_test
# purpose:  Test an RTL-SDR dongle -- and, with its siblings, tune, record and scan with one.
# why:      The catalogue's rtl-sdr tools, for the cheap RTL2832U USB dongle
#           that turns a Pi into a wide-band radio receiver. rtl_test is the
#           first command: is the stick there, and does it keep up?
# see:      rtl_power_fftw, dump1090, direwolf, gqrx

## Use
Plug the dongle in and run `rtl_test`: it names the tuner, then counts
lost samples; none lost means the USB link keeps up. The same package
has `rtl_fm` (listen), `rtl_sdr` (record raw samples), `rtl_power`
(scan) and `rtl_tcp` (serve it to another machine).

## Examples
    rtl_test                             # find the dongle, check for lost samples
    rtl_test -p                          # measure its frequency error, in ppm
    rtl_fm -f 96.3M -M wbfm -s 200k -r 48k - | aplay -r 48000 -f S16_LE   # FM radio
    rtl_sdr -f 433.92M -s 1.024M -n 10240000 capture.bin   # ten seconds of raw samples
    rtl_tcp -a 0.0.0.0                   # serve it to Gqrx or SDR# on another machine

## Options
-d INDEX     which dongle, when there are several
-s RATE      the sample rate (default 2048000)
-p[SECS]     measure the PPM error over SECS seconds
-t           the E4000 tuner benchmark

## Notes
- "usb_claim_interface error -6": the kernel's TV driver took the stick.
  Copal blacklists it from 24 Sep 2026 (`/etc/modprobe.d/copal-rtl-sdr.conf`);
  unplug and plug in again.
- "usb_open error -3": no permission. The device belongs to the group
  `plugdev`, which Copal adds you to from the same date; log in again after.
- A ppm figure from `-p` goes to other tools as `-p N` (rtl_fm) or the
  frequency correction setting (Gqrx).
