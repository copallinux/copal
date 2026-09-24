# command:  lynx
# purpose:  The oldest text web browser still maintained: web and Gopher, keyboard only.
# why:      One of the catalogue's text browsers, kept at every level for use
#           over SSH or on a console. It reads Gopher as well as the web, and its
#           -dump is the classic way to turn a page into text.
# see:      links, elinks, w3m, curl

## Use
Arrows move between links: down and up to the next link, right to follow
it, left to go back. It shows a page as a line of text at a time, with no
columns or tables laid out, which makes it the most readable of the text
browsers with a screen reader.

## Examples
    lynx https://lite.duckduckgo.com     # browse
    lynx gopher://gopher.floodgap.com    # Gopher
    lynx -dump https://example.com       # the page as text, links numbered at the end
    lynx -dump -listonly URL             # only the list of links
    lynx -source URL > page.html         # the HTML

    g              (in the browser) go to a URL
    /              search the page
    o              options;  q  quit

## Options
-dump            print the rendered page and quit
-listonly        with -dump: the links only
-nolist          with -dump: no link list at the end
-source          print the HTML
-width N         the width -dump lays out to
-accept_all_cookies   no questions about each cookie

## Notes
- It asks about every cookie. `-accept_all_cookies`, or set it in `o`
  (options) and save.
- No JavaScript and no CSS: the page is the page's text, in order. For
  a site built for phones, that is often the best way to read it.
