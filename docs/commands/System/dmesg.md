# command:  dmesg
# purpose:  Read the kernel's message buffer: hardware, drivers, and what went wrong.
# why:      The first place to look when a device does nothing -- a USB radio
#           that never appears, a card reader, a wifi chip without firmware.
#           Copal's syslog does not collect kernel messages; they are only here.
# see:      logread, lsblk, rc-status

## Use
Print what the kernel has said since boot, oldest first. Plug a device
in, then look at the last lines: they say what it was recognised as, which
driver took it, or why none did.

## Examples
    doas dmesg | tail -20                # the latest, after plugging something in
    doas dmesg -T                        # with wall-clock times
    doas dmesg -w                        # follow: print new lines as they come
    doas dmesg -l err,warn               # errors and warnings only
    doas dmesg | grep -i usb             # everything about USB

## Options
-T, --ctime       human-readable timestamps (off after a suspend)
-H, --human       readable and paged, with colour
-w, --follow      wait for new messages
-W, --follow-new  print only new ones
-l, --level LIST  only these levels: emerg, alert, crit, err, warn, notice, info, debug
-k, --kernel      only kernel messages
--since TIME      only lines after TIME
-C, --clear       empty the buffer

## Notes
- It needs root on Copal: `kernel.dmesg_restrict` is 1, so without `doas`
  it says "read kernel buffer failed: Operation not permitted".
- The buffer is fixed-size: on a long-running machine the boot messages
  have been overwritten. Look soon after the event.
- Silence is an answer too. A device that adds no line at all is not
  being seen -- a cable, power, or (in a VM) a device not passed through.
