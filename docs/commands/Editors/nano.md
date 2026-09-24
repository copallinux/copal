# command:  nano
# purpose:  The simplest terminal editor: type, and the keys are listed at the bottom.
# why:      The catalogue's editor for anyone new to the terminal, and the one
#           to reach for to change a config file quickly -- nothing to learn
#           before the first edit.
# see:      micro, vim, nvim

## Use
Open a file and type. The two lines at the foot list the commands: `^`
means Ctrl, `M-` means Alt. Ctrl-O saves ("write Out"), Ctrl-X leaves.

## Examples
    nano notes.txt                       # edit
    doas nano /etc/hostname              # edit a system file
    nano -l script.sh                    # with line numbers
    nano +42 main.c                      # at line 42
    nano -/ notes.txt                    # modern keys: Ctrl-S save, Ctrl-Q quit, Ctrl-C copy

    Ctrl-O  Ctrl-X     (in nano) save / quit
    Ctrl-W  Ctrl-\     find / find and replace
    Ctrl-K  Ctrl-U     cut the line / paste
    Alt-U              undo;  Ctrl-G  help

## Options
-l, --linenumbers      show line numbers
-m, --mouse            use the mouse
-i, --autoindent       keep the indentation of the line above
-E, --tabstospaces     type spaces for Tab
-T N, --tabsize=N      tab width
-B, --backup           keep a backup (file~)
-v, --view             read-only
-/, --modernbindings   Ctrl-S, Ctrl-Q, Ctrl-C, Ctrl-V as elsewhere

## Notes
- Settings go in `~/.config/nano/nanorc`, one `set` per line:
  `set linenumbers`, `set modernbindings`.
- `doas nano FILE` edits as root. Keep root's edits to system files --
  your own files edited as root end up owned by root.
