# command:  ncmpcpp
# purpose:  A terminal client for MPD, the music player that runs in the background.
# why:      The catalogue's player-as-a-service: MPD plays, ncmpcpp (or mpc, or a
#           phone app) is only the remote -- quit it and the music goes on.
#           The row installs mpd, mpc and ncmpcpp together.
# see:      cmus, wpctl, mpc

## Use
Run MPD as yourself with a small config, tell it where the music is,
then use ncmpcpp to browse and queue. MPD must be running first: ncmpcpp
connects to it on localhost port 6600.

## Examples
    mkdir -p ~/.config/mpd ~/.local/state/mpd
    printf 'music_directory "~/Music"\ndb_file "~/.local/state/mpd/database"\nstate_file "~/.local/state/mpd/state"\naudio_output {\n  type "pipewire"\n  name "PipeWire"\n}\n' > ~/.config/mpd/mpd.conf
    mpd                                  # start MPD, as you
    mpc update                           # scan ~/Music
    ncmpcpp                              # browse and play

    1  2  3        (in ncmpcpp) playlist / file browser / search
    Enter  Space   play / add to the playlist
    p  >  <        pause / next / previous
    q              quit ncmpcpp (MPD keeps playing)

## Options
-h HOST        the MPD to connect to (default localhost)
-p PORT        its port (default 6600)
-c FILE        another config
-s SCREEN      start on a screen: playlist, browser, search_engine...

## Notes
- "Connection refused" is MPD not running. The system service
  (`/etc/mpd.conf`, user `mpd`) cannot reach your session's PipeWire;
  run `mpd` as yourself, as above, from the session.
- To start it with the desktop, add `exec-once = mpd` to
  `~/.config/hypr/local.conf`.
- `mpc` is the one-line remote for scripts and keys: `mpc toggle`,
  `mpc next`, `mpc volume +5`.
