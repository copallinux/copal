# command:  gmni
# purpose:  Fetch one Gemini page and print it -- Gemini's curl.
# why:      The catalogue's Gemini tool for scripts: read a capsule into a
#           pipe, save a file, or check what a server answers.
# see:      gmnlm, gemget, curl

## Use
Give it a URL; the page body goes to stdout. `-i` adds the response
header, `-L` follows redirects, `-o` saves to a file.

## Examples
    gmni gemini://geminiprotocol.net/    # print a page
    gmni -L gemini://example.org/old     # follow redirects
    gmni -i gemini://example.org/        # with the status and meta line
    gmni -o page.gmi gemini://example.org/   # save it
    gmni -d 'search words' gemini://example.org/search   # answer an input prompt

## Options
-L          follow redirects
-i          print the status and meta line too
-I          print only the status and meta line
-o PATH     write the response to PATH
-d INPUT    answer the server's input request with INPUT
-j MODE     trust on first use: always, once or fail

## Notes
- Gemini URLs need their scheme: `gemini://`, not just the host.
- It shares `gmnlm`'s trust store, so a capsule trusted in one is
  trusted in the other.
