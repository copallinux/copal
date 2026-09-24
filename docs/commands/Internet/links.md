# command:  links
# purpose:  A text web browser: tables and frames laid out, menus on F9.
# why:      Browsing that works over SSH and on a console with no desktop, in a
#           few hundred kilobytes; the catalogue's Internet section carries it
#           beside lynx, w3m and elinks.
# see:      lynx, w3m, elinks, curl

## Use
Read a page in the terminal. Links lays out tables and frames the way a
graphical browser would, which makes it the text browser for pages built
with them; `-dump` turns a page into plain text for a script.

## Examples
    links https://alpinelinux.org        # browse
    links -dump https://example.com      # the page as text, to stdout
    links -dump -width 72 URL > page.txt # at a fixed width, into a file
    links -source URL                    # the HTML, unrendered

## Options
-dump URL      render the page as text and print it
-source URL    print the HTML as it arrives
-width N       the width -dump lays out to
-anonymous     restricted mode: no downloads, no local files
g              (in the browser) go to a URL
/              search the page
d              download the link under the cursor
Esc or F9      the menu; q quits

## Notes
- Alpine builds links without graphics, so `-g` answers "Graphics not
  enabled when compiling": this is the text browser only.
- No JavaScript. A page that builds itself in script is blank here; try
  `w3m` for the same limit with better forms, or a graphical browser.
- No Gopher: for gopher:// use `lynx` or `elinks`.
