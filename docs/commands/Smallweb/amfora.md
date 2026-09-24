# command:  amfora
# purpose:  A terminal browser for Gemini, with tabs, bookmarks and colour.
# why:      The catalogue's fullest Gemini browser for the terminal: tabs,
#           bookmarks, subscriptions to feeds, and pages that look designed.
# see:      bombadillo, clagrange, gmnlm

## Use
Start it on an address, or open one with Space: the bottom bar takes a
URL or a link number. Links are numbered on the page.

## Examples
    amfora                               # its start page
    amfora gemini://geminiprotocol.net/  # a capsule

    Space          (in amfora) the bottom bar: type a URL or a link number
    1 2 3 ...      follow link N
    R              reload
    e              edit the current URL
    /              search the page

## Options
URL           open it
-v, --version the version

## Notes
- Every key is set, and can be changed, in
  `~/.config/amfora/config.toml`, section `[keybindings]`; the defaults
  are listed there.
- Web links open in a web browser as its config says; Gemini, Gopher
  over a proxy, and local files open in Amfora.
