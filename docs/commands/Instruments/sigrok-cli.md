# command:  sigrok-cli
# purpose:  Capture from logic analysers, oscilloscopes and meters, and decode protocols: I2C, SPI, UART...
# why:      The catalogue's instrument front end: a cheap USB logic analyser
#           and sigrok turn a Pi into a bench tool that decodes what flows on
#           a circuit's wires.
# see:      pulseview, rigctl

## Use
`--scan` finds the instruments attached. Choose one with `-d`, capture
a number of samples or a time, and decode with `-P`, or save the capture
to open in PulseView, sigrok's window.

## Examples
    sigrok-cli --scan                    # the instruments connected
    sigrok-cli -d fx2lafw --samples 1M -c samplerate=4M -o cap.sr   # capture to a file
    sigrok-cli -i cap.sr -P uart:baudrate=9600 -A uart   # decode a saved capture as serial
    sigrok-cli -d demo --samples 20 -O ascii              # try it with the demo device
    sigrok-cli -L                        # every driver, format and decoder

## Options
-d DRIVER         the instrument driver (demo, fx2lafw, rigol-ds...)
-c KEY=VALUE      device settings: samplerate, voltage...
--samples N       capture N samples;  --time MS  or for a time
-C CHANNELS       which channels
-i FILE / -o FILE read / write a capture file
-O FORMAT         output format: bits, hex, ascii, csv, vcd...
-P DECODER        a protocol decoder, with its options
--scan            find devices;  -L  list what is supported

## Notes
- The `demo` driver needs no hardware: the place to learn the options.
- A USB instrument needs permission to open; if `--scan` finds nothing
  with it plugged in, try once with doas to see whether that is why.
