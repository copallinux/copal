# command:  bombadillo
# purpose:  A browser for the small internet: Gopher, Gemini and Finger, with vi keys.
# why:      The catalogue's all-in-one smallweb browser: one program for the
#           three protocols the small internet lives on, in a terminal.
# see:      amfora, clagrange, lynx, elinks

## Use
Open an address; links are numbered, and typing the number follows one.
Commands start with `:`, as in vi. The web itself is not shown: web
links can be handed to a web browser instead.

## Examples
    bombadillo                           # its home page
    bombadillo gemini://geminiprotocol.net/   # a Gemini capsule
    bombadillo gopher://gopher.floodgap.com   # a Gopher hole
    bombadillo finger://user@example.org      # a finger record

    1 2 3 ...      (in bombadillo) follow link N
    j  k           scroll;  g  G  top / bottom
    b  f           back / forward
    B              bookmarks
    q              quit

## Options
-t      set the terminal window's title to Bombadillo
-v      the version
-h      the usage

## Notes
- Settings are changed from inside with `:set`, and kept in
  `~/.config/bombadillo`.
- Gemini uses trust on first use: the first certificate a capsule shows
  is remembered, and a changed one is questioned.
