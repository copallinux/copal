# command:  flatpak
# purpose:  Install and run desktop applications from Flathub, in their own runtime.
# why:      For the few programs Alpine does not package -- a browser like
#           Brave. Copal Apps installs a row marked @flathub through it, and
#           says the cost first: a Flatpak brings its own glibc runtime, about
#           500 MB, beside the musl system.
# see:      apk

## Use
Search Flathub, install an application by its ID, run it. Copal's
installation is system-wide (`/var/lib/flatpak`), so installing and
updating need `doas`; running does not.

## Examples
    flatpak search brave                 # find an app's ID
    doas flatpak install flathub com.brave.Browser   # install it
    flatpak run com.brave.Browser        # run it (the menus do this for you)
    flatpak list --app                   # installed applications
    doas flatpak update                  # update apps and runtimes
    doas flatpak uninstall --unused      # remove runtimes nothing uses
    flatpak override --user --filesystem=~/Music com.example.App  # let it see a folder

## Options
install REMOTE ID    install an application (and its runtime)
uninstall ID         remove it; --unused for orphaned runtimes, --delete-data for its files
update               update everything installed
list --app           applications only; --runtime for runtimes
run ID               start an application
remotes              the configured repositories (Copal adds flathub)
override             change an app's permissions; --show to see them
-y, --assumeyes      answer yes to every question

## Notes
- Space is the cost. The first app brings a runtime of about 500 MB;
  apps that share it cost only themselves. `flatpak list --runtime`
  shows what is installed, `uninstall --unused` clears what is left over.
- Flathub builds for 64-bit ARM and x86 only: on a 32-bit Pi there is
  nothing to install.
- An app sees only what its permissions allow. A file dialog that cannot
  find your folder is the sandbox: `flatpak override` widens it.
- Prefer the apk when there is one. It is smaller, updates with the
  system, and is built for musl.
