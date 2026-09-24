# playbook: qbittorrent
# source:   apk
# origin:   catalogue
#
# program:  qbittorrent
# label:    qBittorrent (torrents)
# shelf:    Internet
# install:  qbittorrent
# mode:     x
# gate:     *
# home:
# about:    A full-featured BitTorrent client with search, RSS feeds and scheduling. Copal accepts
#           its legal notice for you and keeps it out of the tray, which the i3 bar lacks.

# qBittorrent: the "Legal Notice" box on first start (verified), and no
# vanishing into the tray: on i3 the bar has no tray, so a window closed
# "to the tray" is simply gone until the process is killed.
qbittorrent_post() {
    printf '[LegalNotice]\nAccepted=true\n\n[Preferences]\nGeneral\\CloseToTray=false\nGeneral\\MinimizeToTray=false\nGeneral\\SystrayEnabled=false\n' > "$_t"
    seed_home_if_absent .config/qBittorrent/qBittorrent.conf "$_t"
}
