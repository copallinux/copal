# command:  rigctl
# purpose:  Hamlib's radio control: read and set a transceiver's frequency, mode and more, over its serial port.
# why:      The catalogue's rig control: one command for hundreds of radio
#           models, and the library that logging and digital-mode programs use
#           to steer the radio.
# see:      direwolf

## Use
Name the radio's model number and its port, then give commands: `f` to
read the frequency, `F` to set it, `m` / `M` for the mode. With no
commands it opens a prompt.

## Examples
    rigctl -l | grep -i icom             # find your radio's model number
    rigctl -m 1 f                        # try it with model 1, the dummy radio
    rigctl -m 3073 -r /dev/ttyUSB0 -s 19200 f          # read an IC-7300's frequency
    rigctl -m 3073 -r /dev/ttyUSB0 -s 19200 F 14074000 # set it (20 m FT8)
    rigctld -m 3073 -r /dev/ttyUSB0 &    # share the radio with other programs

## Options
-m ID            the radio model (from -l)
-r DEVICE        its serial port
-s BAUD          the serial speed
-l               list every supported model
-P TYPE          how PTT is keyed (RIG, DTR, RTS...)

## Notes
- The serial port belongs to `dialout`; Copal adds you with the radio
  and Geiger counter setup, as `id` will show.
- Model 1 is Hamlib's dummy radio: every command works on it with no
  hardware, which makes it the place to learn the commands.
