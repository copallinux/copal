# command:  cmus
# purpose:  A music player for the terminal: a library, playlists, a queue, and vi-like keys.
# why:      The catalogue's terminal music player: a whole collection, sorted
#           and searchable, playing in a tmux pane or over SSH on a Pi wired to
#           speakers.
# see:      ncmpcpp, alsamixer, wpctl

## Use
Add your music folder once, then browse the library by artist and album
and play. The number keys switch views; the command line (`:`) does the
rest. It keeps playing when you switch to another view.

## Examples
    cmus                                 # start

    :add ~/Music       (in cmus) add a folder to the library
    1  2  3            library / sorted list / playlist views
    5                  the file browser: Enter plays, a adds
    x  c  v            play / pause / stop
    b  z               next / previous track
    +  -               volume;  / search;  q quit

## Options
--listen ADDR    the address cmus-remote controls it at
--plugins        list the input and output plugins
--show-cursor    keep the cursor visible
--help           the short usage

## Notes
- `cmus-remote` controls a running cmus from another shell or a key
  binding: `cmus-remote -u` pauses, `-n` skips.
- No sound? `:set output_plugin=pulse` sends it through PipeWire's pulse
  layer; `alsa` goes through PipeWire's ALSA plugin. Both reach the same
  place.
- The library and settings are in `~/.config/cmus`.
