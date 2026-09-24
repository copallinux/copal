# playbook: zim
# source:   apk
# origin:   catalogue
#
# program:  zim
# label:    Zim (wiki-style notebook)
# shelf:    Notes
# install:  zim
# mode:     x
# gate:     *
# home:
# about:    A desktop wiki: notes as linked pages, saved as plain text files. Copal creates a first
#           notebook so it opens straight onto a page.

# Zim: without a notebook the first window is "Add Notebook". One in
# ~/Notebooks/Notes, registered as the default, and it opens on a page.
zim_post() {
    printf '[NotebookList]\nDefault=~/Notebooks/Notes\n\n[Notebook 1]\nuri=~/Notebooks/Notes\nname=Notes\n' > "$_t"
    seed_home_if_absent .config/zim/notebooks.list "$_t"
    printf '[Notebook]\nversion=0.4\nname=Notes\nhome=Home\n' > "$_t"
    seed_home_if_absent Notebooks/Notes/notebook.zim "$_t"
}
