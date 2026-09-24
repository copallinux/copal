# command:  fftw-wisdom
# purpose:  Pre-compute FFTW's "wisdom": the fastest way to do given Fourier transforms on this machine.
# why:      The catalogue's FFTW tool: programs built on FFTW -- rtl_power_fftw,
#           GNU Radio, Octave -- start their transforms faster, and run them
#           faster, when this machine's best plans are measured once and saved.
# see:      rtl_power_fftw, octave

## Use
Name the transform sizes you use; it measures the options on this CPU
and writes the result, which FFTW-based programs load. Measuring takes a
while; using it is free.

## Examples
    fftw-wisdom -v -c -o wisdom          # common sizes, measured, into ./wisdom
    fftw-wisdom -v -o wisdom cof1024 cof4096   # just these (complex, out-of-place, forward)
    doas fftw-wisdom -c -o /etc/fftw/wisdom    # the system-wide file programs read

## Options
-c           the common sizes
-o FILE      write the wisdom to FILE (default stdout)
-t HOURS     time limit for the measuring
-v           verbose
-x           exhaustive: slowest to make, best plans

## Notes
- Sizes are written as a type and a number: `c` complex or `r` real, `o`
  out-of-place or `i` in-place, `f` forward or `b` backward -- `cof1024`.
- Wisdom is for this CPU: made on a Pi 5, it is wrong for a Pi Zero.
