# command:  retawq
# purpose:  A tiny multi-window text web browser, with a split screen.
# why:      The smallest of the catalogue's text browsers, kept at every level:
#           it keeps several pages open at once and shows two side by side,
#           which the others do not.
# see:      links, lynx, w3m

## Use
Open a page, then more windows with `n`, and split the screen with `2`
to read two at once. Most commands are one key; Escape cancels any of
them.

## Examples
    retawq https://example.com           # browse
    retawq URL1 URL2                     # two documents at once
    retawq --dump=https://example.com    # the page as text, to stdout
    retawq --download=URL > file         # fetch a file, no display

    g              (in the browser) go to a URL
    n  C           a new window / close this one
    2  1           split the screen / un-split it;  Tab  between halves
    b  u           bookmarks / the history of URLs
    Q              quit

## Options
--dump=URL       render the page, write it to stdout, quit
--download=URL   write the content of URL to stdout, quit
--colors=off     no colours
--console        console mode: line by line, no full screen

## Notes
- It is from 2006 and speaks older HTML well and newer HTML less so; a
  modern site may come out as a column of text in the wrong order.
- The full key list is in `/usr/share/doc/retawq/key.html` -- open it
  in retawq itself.
