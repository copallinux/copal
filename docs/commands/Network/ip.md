# command:  ip
# purpose:  Show and change network interfaces, addresses and routes.
# why:      The quickest answer to "what is my address" and "is the wifi up".
#           On Copal it is BusyBox's applet: the common part of iproute2's ip,
#           not all of it.
# see:      iw, wpa_cli, ssh, busybox

## Use
`ip addr` shows each interface and its addresses, `ip route` where
traffic goes, `ip link` whether an interface is up. Changes made with it
last until the next restart; the lasting configuration is
`/etc/network/interfaces`.

## Examples
    ip addr                              # every interface and its addresses
    ip -4 -o addr                        # IPv4 only, one line each
    ip addr show wlan0                   # one interface
    ip route                             # the default gateway is the 'default via' line
    doas ip link set wlan0 up            # bring an interface up
    ip neigh                             # machines seen on the local network
    doas rc-service networking restart   # re-apply /etc/network/interfaces

## Options
addr [show DEV]   addresses (a, address)
route             the routing table (r)
link              interfaces, up or down, and their MAC addresses
neigh             the neighbour (ARP) table
-f inet           one address family: inet, inet6 (-4 and -6 work too)
-o                one line per entry, for grep
link set DEV up   bring DEV up; down to take it down

## Notes
- BusyBox's `ip` lacks the newer options: `ip -br a`, `-c` and `-j`
  print its usage instead. Use `ip -o addr` for the short form.
- No IPv4 address on wlan0 means it is not associated, or DHCP has not
  answered: check `iw dev wlan0 link` before blaming DHCP.
- `ifconfig` is here too (BusyBox), for the habit; `ip` is what Alpine's
  own scripts use.
- `/etc/network/interfaces` is read by `ifup` and `ifdown` (ifupdown-ng):
  `auto wlan0` and `iface wlan0 inet dhcp` make it come up at boot.
