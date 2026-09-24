# command:  sfeed
# purpose:  Feeds as plain files: fetch with sfeed_update, read with sfeed_curses or plain text.
# why:      The catalogue's feed reader for people who want the feeds as files:
#           one tab-separated line per item, readable with grep, a script or
#           its own small curses reader.
# see:      newsboat, newsraft

## Use
List feeds in `~/.sfeed/sfeedrc`, run `sfeed_update` to fetch them into
`~/.sfeed/feeds/`, and read them with `sfeed_curses`, or turn them into
text, HTML or Atom with the other `sfeed_*` programs. `sfeed` itself is
the parser in the middle: RSS or Atom in, lines out.

## Examples
    mkdir -p ~/.sfeed && cp /usr/share/doc/sfeed/sfeedrc.example ~/.sfeed/sfeedrc  # a starting config
    sfeed_update                         # fetch every feed
    sfeed_curses ~/.sfeed/feeds/*        # read them
    sfeed_plain ~/.sfeed/feeds/* | head  # newest items as plain lines
    curl -s https://alpinelinux.org/atom.xml | sfeed | cut -f2   # the parser alone: titles

## Options
sfeed_update [RC]     fetch the feeds listed in RC (default ~/.sfeed/sfeedrc)
sfeed_curses FILES    the reader
sfeed_plain FILES     items as text
sfeed_html FILES      items as an HTML page
sfeed_opml_import     OPML in, sfeedrc lines out

## Notes
- `sfeedrc` is a shell script: each feed is a line
  `feed 'name' 'https://...'` inside the `feeds()` function.
- The line format is fixed: time, title, link, content, and more,
  separated by tabs -- `cut -f` and `awk -F'\t'` read it directly.
