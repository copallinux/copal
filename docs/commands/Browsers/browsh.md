# command:  browsh
# purpose:  The modern web in a terminal: a real Firefox renders the page, browsh draws it in text.
# why:      The store's browser for pages the text browsers cannot show --
#           JavaScript, video thumbnails, modern layouts -- over SSH or on a
#           console, with Firefox ESR doing the rendering headless.
# see:      links, w3m, firefox-esr

## Use
Start it with an address; Firefox runs in the background and browsh
draws the page with coloured characters. Ctrl-l goes to a new address;
the mouse clicks links where the terminal passes clicks.

## Examples
    browsh                               # its start page
    browsh --startup-url https://example.com   # open a page
    browsh --monochrome                  # for terminals without colour
    browsh --http-server-mode            # serve pages as plain HTML to other machines

    Ctrl-l         (in browsh) type an address
    Backspace      back
    Ctrl-t / Ctrl-w   a new tab / close it
    Ctrl-q         quit

## Options
--startup-url URL     the page to open
--monochrome          no colour
--http-server-mode    run as an HTTP service instead of a terminal UI
--time-limit SECS     quit after SECS seconds
--firefox.path PATH   which Firefox (Copal's launcher passes firefox-esr)

## Notes
- It is Firefox underneath, so it costs Firefox's memory: a few hundred
  MB, and a slow start on a small Pi.
- Not on ARMv6 (the first Zero): its row is gated off there.
