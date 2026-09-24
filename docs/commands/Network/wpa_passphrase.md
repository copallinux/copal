# command:  wpa_passphrase
# purpose:  Turn a wifi name and password into a network block for wpa_supplicant.
# why:      Alpine's own setup-interfaces uses it to write Copal's wifi
#           configuration, and it is the quick way to add a second network
#           by hand without leaving the password in the file as plain text.
# see:      wpa_cli, iw, setup-alpine

## Use
Give it the network's name; type the password when it asks. It prints a
`network={...}` block with the password hashed into a 64-digit `psk`,
ready to add to `/etc/wpa_supplicant/wpa_supplicant.conf`.

## Examples
    wpa_passphrase "Home WiFi"                        # type the password; prints the block
    wpa_passphrase "Home WiFi" | doas tee -a /etc/wpa_supplicant/wpa_supplicant.conf
    doas rc-service wpa_supplicant restart            # use the new network
    wpa_passphrase "Home WiFi" 'the password'         # password as an argument (see Notes)

## Options
SSID              the network's name; quote it if it has spaces
PASSPHRASE        the password, 8 to 63 characters; omit it to be asked

## Notes
- The block it prints includes the password in clear, as a comment
  (`#psk="..."`). Delete that line from the file -- setup-interfaces
  does the same.
- A password on the command line is saved in the shell's history. Leave
  it off and type it at the prompt instead; piping it in does not work
  ("Not a tty").
- The hash depends on the name: rename the network and the `psk` must
  be made again.
- Open networks and WPA3-only networks need a block written by hand
  (`key_mgmt=NONE`, or `key_mgmt=SAE` with `sae_password`).
