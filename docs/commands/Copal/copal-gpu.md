# command:  copal-gpu
# purpose:  Say whether the desktop is drawn by the GPU or the CPU, layer by layer, and what to do about it.
# why:      A slow desktop is usually software rendering, and the reason can be
#           at any of four layers: the kernel's device, the host's VirGL offer,
#           the compositor's renderer, or Mesa's. This checks each and reports
#           the first fault only, because one fault makes every layer above it
#           look wrong too.
# see:      glxinfo, dmesg, copal-debug

## Use
Run it inside the desktop. It lists what it found at each layer and ends
with a verdict and, when there is a fault, the fix.

## Examples
    copal-gpu                            # the report
    copal-gpu >/dev/null; echo $?        # just the verdict, for a script

## Options
(none)

## Notes
- The exit status is the verdict: 0 accelerated, 1 working but drawn on
  the CPU, 2 cannot tell yet (X has not run since boot).
- Under Hyprland the answer is the `Renderer:` line in Hyprland's log:
  `llvmpipe` means software. Under X it reads the Xorg log for the driver
  and glamor, then asks `glxinfo -B` (package `mesa-demos`).
- In a UTM virtual machine, 3D is the host's decision: "-virgl" in the
  kernel's messages means the display device offers none, and the fix is
  the VM's display setting (virtio-ramfb-gl), not anything inside.
- On a Raspberry Pi, no DRM device and the framebuffer path are expected.
