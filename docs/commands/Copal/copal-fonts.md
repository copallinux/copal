# command:  copal-fonts
# purpose:  Install Copal's font sets -- coding, console, IBM PC, web documents -- and set the text console's font.
# why:      Fonts in groups rather than one by one: the coding faces (with Nerd
#           Font symbols for prompts), the console fonts, the classic IBM PC
#           faces, and the metric-compatible set that makes a .docx look right.
#           Stage 12 installs coding, console and ibmpc by default.
# see:      starship, oh-my-posh

## Use
With no arguments it shows what is installed, group by group. `install`
adds a group; `console` sets the font of the text console (the one before
the desktop, and after Ctrl-Alt-F2).

## Examples
    copal-fonts                          # what is installed, by group
    copal-fonts list coding              # what a group contains
    doas copal-fonts install web         # the document fonts (about 120 MB)
    doas copal-fonts install coding-extra   # Iosevka and the large Nerd cuts (~1.9 GB)
    doas copal-fonts console             # the console fonts available
    doas copal-fonts console ter-v24n    # set one

## Options
install GROUP...   coding, console, ibmpc, web, coding-extra, or all
list [GROUP]       a group's contents, and what is on disk
console [NAME]     list, or set, the text console's font
licences           where the fonts' licence files are

## Notes
- `web` is not installed by default: it matters only when a document
  from elsewhere looks wrong, and it is large. Install it when that
  happens.
- Installing a group again only fetches what is missing.
