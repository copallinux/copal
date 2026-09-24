# command:  wpa_cli
# purpose:  Talk to the running wpa_supplicant: scan, add a network, see the state.
# why:      Copal's wifi is wpa_supplicant (stage 10), not NetworkManager, so
#           there is no nmcli. wpa_cli is how to join a new network or see why
#           one will not connect, without editing files and restarting.
# see:      wpa_passphrase, iw, ip

## Use
With a command, run it and return; with none, an interactive prompt
where the same commands work, with tab completion and live events. Add a
network, set its name and password, enable it, and save.

## Examples
    wpa_cli -i wlan0 status              # connected? to what, with which address
    wpa_cli -i wlan0 scan                # start a scan...
    wpa_cli -i wlan0 scan_results        # ...and read it
    wpa_cli -i wlan0 list_networks       # the networks it knows
    wpa_cli -i wlan0 add_network         # a new one: prints its number, say 1
    wpa_cli -i wlan0 set_network 1 ssid '"Home WiFi"'
    wpa_cli -i wlan0 set_network 1 psk '"the password"'
    wpa_cli -i wlan0 enable_network 1    # try it
    wpa_cli -i wlan0 save_config         # keep it across reboots

## Options
-i IF                    the interface, wlan0
-p DIR                   where the control sockets are (/run/wpa_supplicant)
status                   state, SSID, address
scan, scan_results       scan, then list what was found
list_networks            the configured networks and their numbers
add_network              a new empty network; prints its number
set_network N KEY VALUE  ssid, psk, key_mgmt, priority...
enable_network N         allow it; select_network N uses only it
remove_network N         forget it
save_config              write the configuration file
reconfigure              re-read the configuration file

## Notes
- "Failed to connect to non-global ctrl_ifname": wpa_supplicant has no
  control socket. The file `setup-interfaces` writes has no
  `ctrl_interface` line; add
  `ctrl_interface=DIR=/run/wpa_supplicant GROUP=wheel` and
  `update_config=1` at the top of `/etc/wpa_supplicant/wpa_supplicant.conf`,
  then `doas rc-service wpa_supplicant restart`.
- The quotes are both needed: `'"Home WiFi"'`. The outer pair is for
  the shell; the inner pair tells wpa_supplicant it is text, not hex.
- `save_config` fails without `update_config=1` in the file, and the
  network is forgotten at the next restart.
- The password typed into `set_network` lands in the shell's history.
  `wpa_passphrase` avoids that.
