# command:  elinks
# purpose:  A text web browser with tabs, menus, and Gopher as well as the web.
# why:      One of the catalogue's text browsers, kept at every level: a few
#           hundred kilobytes, it works over SSH with no display, and it opens
#           gopher:// links the smallweb section points at.
# see:      links, lynx, w3m, bombadillo

## Use
Browse in the terminal with the menus and tabs a graphical browser has.
Esc opens the menu bar, so every command can be found without knowing its
key. `-dump` renders a page to plain text for a script.

## Examples
    elinks https://alpinelinux.org       # browse
    elinks gopher://gopher.floodgap.com  # Gopher, in the same browser
    elinks -dump https://example.com     # the page as text, to stdout
    elinks -dump -dump-width 72 URL      # at a fixed width

    g              (in the browser) go to a URL
    t              open a new tab;  < >  move between tabs
    /              search the page
    Esc            the menu bar;  q  quit

## Options
-dump            render the page as text and print it
-dump-width N    the width -dump lays out to
-source          print the HTML as it arrives
-anonymous       restricted: no local files, no downloads
-no-connect      run without connecting to a running ELinks

## Notes
- No JavaScript: a page that builds itself in script is blank. So are
  most modern sign-in pages.
- Settings are in the menu (Setup) and saved to `~/.config/elinks`:
  change them there rather than editing the file by hand.
- A second `elinks` joins the first one's session by default;
  `-no-connect` keeps them apart.
