# command:  rtl_power_fftw
# purpose:  Scan a wide band of spectrum with an RTL-SDR and record the power at each frequency.
# why:      The catalogue's spectrum survey: sweep hundreds of megahertz in
#           steps and see where the signals are -- faster and finer than
#           rtl_power, thanks to FFTW.
# see:      rtl_test, gnuplot, fftw-wisdom

## Use
Give a frequency or a range; it steps the tuner across it and prints the
power in each bin, as text a plotting program reads directly.

## Examples
    rtl_power_fftw -f 88M:108M -b 512 -n 100 > fm.dat    # the FM band, once
    rtl_power_fftw -f 430M:440M -b 1024 -c -e 3600 -q > 70cm.dat   # an hour, continuously
    rtl_power_fftw -f 1090M -b 256 -t 10                 # one frequency, 10 seconds

## Options
-f HZ | HZ:HZ   one frequency or a range to sweep
-b N            bins in each FFT (resolution)
-n N            spectra to average per step
-t SECS         integration time per step
-c              continue: sweep until stopped
-e SECS         stop after SECS seconds
-g GAIN         tuner gain, in tenths of a dB
-q              quiet: data only

## Notes
- It comes from Alpine's testing repository (`rtl-power-fftw@testing`).
- The same dongle rules apply as for rtl_test: the `plugdev` group and
  the TV driver kept off it.
