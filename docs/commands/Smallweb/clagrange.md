# command:  clagrange
# purpose:  Lagrange in the terminal: the well-known Gemini browser, drawn with text.
# why:      The catalogue's terminal build of Lagrange. The same package has
#           `lagrange`, its window; clagrange is the one for a board without a
#           desktop, or for use over SSH.
# see:      amfora, bombadillo, gmnlm

## Use
Open addresses and files in tabs. It keeps Lagrange's features --
bookmarks, feeds, identities (client certificates) -- in a terminal.
`--dump` prints a page as text and leaves, for scripts.

## Examples
    clagrange                            # the browser
    clagrange gemini://geminiprotocol.net/   # open an address
    clagrange a.gmi b.gmi                # several files, one tab each
    clagrange --dump gemini://geminiprotocol.net/   # the page as text

## Options
URL / PATH       open it; several open in tabs
-d, --dump       print the contents of the URLs to stdout and quit
-I, --dump-identity ID   with --dump: use this client certificate

## Notes
- Its settings, bookmarks and identities are Lagrange's, shared with the
  window version.
- The window build, `lagrange`, is in the catalogue as its own row.
