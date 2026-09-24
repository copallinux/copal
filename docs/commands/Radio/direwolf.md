# command:  direwolf
# purpose:  A software packet-radio modem and TNC: decode and send AX.25 and APRS through a sound card.
# why:      The catalogue's packet radio: with a radio and a sound card, or an
#           RTL-SDR, it decodes APRS position reports and packet messages, and
#           serves them to other programs.
# see:      rtl_test, rigctl

## Use
It reads audio -- from a sound card, or piped from rtl_fm -- and prints
each packet it decodes. A configuration file sets the sound device,
the modem speed and your call sign.

## Examples
    cp /usr/share/doc/direwolf/conf/direwolf.conf ~/     # a configuration to edit
    direwolf -c ~/direwolf.conf          # run with it
    rtl_fm -f 144.39M -s 24000 - | direwolf -r 24000 -D 1 -   # APRS (N. America) from a dongle
    rtl_fm -f 144.8M -s 24000 - | direwolf -r 24000 -D 1 -    # APRS in Europe

## Options
-c FILE     the configuration file
-r RATE     the audio sample rate
-n N        audio channels, 1 or 2
-B RATE     the modem speed: 300, 1200, 9600...
-D N        divide the audio sample rate (with rtl_fm)
-l DIR      write logs of received packets to DIR
-           read audio from stdin

## Notes
- Receiving needs no licence. Transmitting -- beaconing, messaging -- needs
  an amateur radio licence and your call sign in the configuration.
- Other programs connect to its KISS and AGW ports (8001 and 8000) for
  maps and messaging.
