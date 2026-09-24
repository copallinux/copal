# command:  iw
# purpose:  Look at and control wireless interfaces: scan, link, signal, country.
# why:      Stage 10 installs it with wpa_supplicant for the Pi's wifi. It
#           answers what the radio sees and how well it is connected; joining
#           a protected network is wpa_supplicant's job, not iw's.
# see:      wpa_cli, wpa_passphrase, ip

## Use
Name a wireless interface (`wlan0`) and ask it something: which networks
it can hear, what it is connected to and at what signal, which channels
the country allows.

## Examples
    iw dev                               # the wireless interfaces
    doas iw dev wlan0 scan | grep SSID   # the networks in range
    iw dev wlan0 link                    # connected to what, signal, speed
    iw dev wlan0 station dump            # the access point's statistics
    iw reg get                           # the regulatory country in force
    doas iw reg set GB                   # set it (use your own country)
    iw list | less                       # everything the chip can do

## Options
dev                   list wireless interfaces
dev IF scan           scan for networks (root)
dev IF link           the current connection
dev IF station dump   per-station statistics
reg get / reg set CC  read or set the regulatory country
list                  the hardware's capabilities
phy                   the radios, as distinct from interfaces

## Notes
- A scan needs root: without it, "Operation not permitted (-1)". "Device
  or resource busy (-16)" means the interface is down --
  `doas ip link set wlan0 up` -- or blocked: `rfkill list`, then
  `doas rfkill unblock wifi`.
- 5 GHz networks missing from a scan often means no country is set:
  the radio then allows only what is legal everywhere.
- `iw dev wlan0 connect` joins open networks only. For WPA, which is
  nearly every network, use `wpa_supplicant` -- `setup-interfaces` or
  `wpa_cli`.
- The Pi Zero (the first one) has no wifi at all; the Zero W and Zero 2 W do.
