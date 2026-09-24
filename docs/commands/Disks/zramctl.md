# command:  zramctl
# purpose:  Show and set up zram devices: compressed swap in RAM.
# why:      Stage 5 gives every Copal machine a zram swap half the size of RAM,
#           compressed with lz4 -- on a 512 MB board the largest single win,
#           and it spares the card the writes of disk swap.
# see:      lsblk, dmesg

## Use
With no arguments, show each zram device: its size, how much is stored in
it and how small that compressed to. Copal sets zram up at boot from
`/etc/local.d/zram.start`; zramctl is for looking, or for changing it.

## Examples
    zramctl                              # size, data stored, compressed size
    free -m                              # swap in use, zram included
    cat /proc/swaps                      # zram0 at priority 100, before any disk swap
    doas swapoff /dev/zram0              # stop using it (to resize)...
    doas zramctl -r /dev/zram0           # ...reset it...
    doas zramctl -a lz4 -s 1G /dev/zram0 # ...set it up again at 1 GiB
    doas mkswap /dev/zram0 && doas swapon -p 100 /dev/zram0  # ...and swap on it

## Options
-s, --size SIZE        the device size: 512M, 1G
-a, --algorithm ALG    lzo, lz4, lz4hc, deflate, 842 or zstd
-r, --reset DEVICE     empty and release a device
-f, --find             the first free device
-o, --output LIST      choose the columns
-b, --bytes            sizes in bytes

## Notes
- DISKSIZE is the most it will take, not memory spent: RAM is used only
  for what is stored, compressed. DATA against COMPR is the ratio --
  usually 2 to 3 times.
- A change made with zramctl is gone at the next boot. To change the size
  for good, edit the `disksize` line in `/etc/local.d/zram.start`.
- zram is swap, not more memory: a machine that swaps constantly is
  slow either way. Its gain is that a burst -- a big build, a browser --
  no longer ends in the out-of-memory killer.
