# playbook: staticstream
# source:   clone https://github.com/vonglurt/staticstream.git
# origin:   code
# build:    git rust cargo
#
# program:  ytq
# label:    ytq (download queue)
# shelf:    Code
# install:  staticstream@clone
# mode:     t
# gate:     *
# home:     https://github.com/vonglurt/staticstream
# about:    A download queue that watches the clipboard: Super+Shift+Y queues the copied link, and
#           ytq run fetches it. What it downloads is kept as Static Stream.
#
# program:  sstr-workspace
# label:    sstr-workspace (stream archive)
# shelf:    Code
# install:  staticstream@clone
# mode:     t
# gate:     *
# home:     https://github.com/vonglurt/staticstream
# about:    The terminal Workspace over the archive and the download queue in one browser. Play,
#           verify, export and read a capture on one key each.
#
# program:  sstr
# label:    sstr (record and replay streams)
# shelf:    Code
# install:  staticstream@clone
# mode:     h
# gate:     *
# home:     https://github.com/vonglurt/staticstream
# about:    Records a stream into a .sstr file with its order, pace and damage tolerance intact, and
#           plays it back. sstr export turns a folder of them into ordinary files.
