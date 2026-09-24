# command:  waydroid
# purpose:  Run Android apps in a container on the desktop, each in its own window or a full Android screen.
# why:      The store's Android layer: LineageOS in a container, sharing the
#           Linux kernel, drawn through Wayland -- so it needs the Hyprland
#           desktop, not i3.
# see:      scrcpy, qemu-system-x86_64

## Use
Initialise it once (it downloads the Android images, about a gigabyte),
start the container service, then start a session from the desktop and
open the full UI or single apps.

## Examples
    doas waydroid init                   # download and set up the images, once
    doas rc-service waydroid-container start   # the container service
    waydroid session start &             # the Android session, in the desktop
    waydroid show-full-ui                # the Android screen in a window
    waydroid app install app.apk         # install an APK
    waydroid status                      # is it running, and what

## Options
init              set up the images (root)
container         start, stop, restart the container (root)
session start     start the Android session (as you, in the desktop)
show-full-ui      the whole Android screen
app install APK   install an app;  app list  the installed ones
prop              read and set Android properties

## Notes
- It needs the kernel's binder, which Copal's kernel has built in, and a
  Wayland session: from i3 or over SSH it cannot draw.
- To start it at boot: `doas rc-update add waydroid-container`.
- Not on ARMv6: its row is gated off there.
