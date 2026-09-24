# command:  bluetoothctl
# purpose:  Pair, trust and connect Bluetooth devices, from a prompt or one command at a time.
# why:      Stage 10 installs BlueZ and starts its service where there is a
#           controller. Keyboards, mice, controllers and headphones all pair
#           here; there is no graphical pairing tool on Copal.
# see:      wpctl, rc-service

## Use
Run it for an interactive prompt: power on, scan, pair, trust, connect.
Pair once and trust once; after that the device reconnects by itself.

## Examples
    bluetoothctl                         # the prompt; then:
      power on                           #   the controller on
      agent on                           #   answer pairing requests...
      default-agent                      #   ...from this prompt
      scan on                            #   wait for the device's address
      pair AA:BB:CC:DD:EE:FF             #   pair (accept the PIN if asked)
      trust AA:BB:CC:DD:EE:FF            #   let it reconnect by itself
      connect AA:BB:CC:DD:EE:FF          #   connect now
    bluetoothctl devices                 # one command, no prompt: known devices
    bluetoothctl --timeout 10 scan on    # scan for ten seconds, then stop
    bluetoothctl remove AA:BB:CC:DD:EE:FF    # forget a device

## Options
power on|off         the controller
scan on|off          look for devices
pair / trust / connect ADDR   the three steps
disconnect ADDR      drop the connection
remove ADDR          forget it altogether
devices              the known devices
info ADDR            one device's state: paired, trusted, connected
--timeout SECS       stop a non-interactive command after SECS

## Notes
- "No default controller available": no Bluetooth hardware, or the
  service is not running -- `rc-service bluetooth status`. The first Pi
  Zero and most VMs have none.
- Headphones pair and connect, but PipeWire plays to them only with
  its Bluetooth module: `doas apk add pipewire-spa-bluez`, then log out
  and in. Copal does not install it yet.
- A device that pairs but will not connect again after a reboot was
  not trusted. `trust ADDR`.
