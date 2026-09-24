# playbook: kate
# source:   apk
# origin:   catalogue
#
# program:  kate
# label:    Kate (KDE - LSP client built in)
# shelf:    Editors
# install:  kate
# mode:     x
# gate:     !v6
# home:
# about:    KDE's advanced text editor with language servers built in, so completion and errors
#           appear as you type. Copal skips its welcome page.

# Kate: its welcome view in every new window. Only when copal has not
# already written a katerc (stage 7 does, with the LSP client); then the
# line is added there instead.
kate_post() {
    printf '[General]\nShow welcome view for new window=false\n' > "$_t"
    seed_home_if_absent .config/katerc "$_t"
}
