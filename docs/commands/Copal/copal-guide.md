# command:  copal-guide
# purpose:  Read Copal's plain-text guides, on the machine, with no network: tmux, nvim, languages, radio and more.
# why:      The tutorials that come with Copal -- how the editor is set up,
#           which languages this board has, software radio, the small web --
#           kept in /usr/local/share/copal/guides and opened by name.
#           Super+/ (or Super+F1) opens the desktop's key guide.
# see:      man, tldr

## Use
Without a name it lists the guides and asks which; with a name it opens
that guide in the pager.

## Examples
    copal-guide                          # the list, then a choice
    copal-guide nvim                     # the editor, from nothing to useful
    copal-guide languages                # what this board has, and why
    copal-guide radio                    # software-defined radio
    copal-guide small-web                # Gemini and Gopher

## Options
NAME     open that guide (the file's name without .txt)

## Notes
- The guides are plain text files in `/usr/local/share/copal/guides`;
  `less` or `grep` reads them as well.
- The stage that installs a feature writes its guide, so the list grows
  with what the machine has.
