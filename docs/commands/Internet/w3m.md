# command:  w3m
# purpose:  A text web browser and pager: tables laid out, good forms, and it pages files too.
# why:      One of the catalogue's text browsers, kept at every level. It lays
#           out tables and fills forms better than the others, and doubles as a
#           pager: w3m file.html, or HTML piped into it.
# see:      links, elinks, lynx

## Use
Browse with the keyboard, or read HTML from a file or a pipe. It keeps
several pages open as tabs, and its forms handle searches and sign-ins
that the simpler browsers stumble on (as long as they need no
JavaScript).

## Examples
    w3m https://lite.duckduckgo.com      # browse
    w3m README.html                      # a local HTML file
    curl -s URL | w3m -T text/html       # HTML from a pipe
    w3m -dump https://example.com        # the page as text
    w3m -dump -cols 72 URL > page.txt    # at a fixed width

    U              (in the browser) open a URL
    Enter          follow the link;  B  back
    T              a new tab;  { }  between tabs
    /              search;  q  quit (Q without asking)

## Options
-dump          print the rendered page and quit
-cols N        the width for -dump
-T TYPE        the content type of stdin: text/html
-o OPT=VAL     set an option for this run
-M             monochrome

## Notes
- Arrow keys move the cursor, not the page: `Space` and `b` page down
  and up. Links are followed where the cursor is.
- `o` is the options page; changes saved there go to `~/.w3m/config`.
