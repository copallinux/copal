# command:  figlet
# purpose:  Print text in large letters made of characters.
# why:      One of the catalogue's toys, and useful: a banner at the top of a
#           script's output, a login message, a heading in a README.
# see:      fortune, cbonsai

## Use
Give it the words; it prints them large. `-f` chooses the font;
`showfigfonts` shows them all.

## Examples
    figlet Copal                         # big text, the standard font
    figlet -f slant Copal                # another font
    figlet -c -w 80 'Hello, world'       # centred on 80 columns
    showfigfonts | less                  # every font, as a sample
    echo Build done | figlet             # from a pipe

## Options
-f FONT      the font: standard, slant, banner, big, small, script...
-c           centre the text
-r           right-justify it
-w N         the output width
-t           use the terminal's width
-k           kerning: letters close, not overlapping

## Notes
- The fonts are in `/usr/share/figlet/fonts`; `figlist` names them.
- A long line wraps at 80 columns unless `-w` or `-t` says otherwise.
