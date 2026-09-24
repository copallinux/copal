# command:  newsraft
# purpose:  A small, fast feed reader for the terminal, with feeds grouped in sections.
# why:      The catalogue's lighter feed reader: newsboat's job in less memory,
#           with sections to update and read feeds in groups.
# see:      newsboat, sfeed

## Use
Write a feeds file -- a URL a line, with `@ Section` lines to group them
-- and start it. Four menus: sections, feeds, items, and the pager for
reading one.

## Examples
    mkdir -p ~/.config/newsraft
    printf '@ Linux\nhttps://alpinelinux.org/atom.xml\n' >> ~/.config/newsraft/feeds
    newsraft                             # read
    newsraft -e reload-all               # refresh everything, no screen (for cron)
    newsraft -e convert-opml-to-feeds < subs.opml >> ~/.config/newsraft/feeds

    R  r           (in newsraft) update all / this feed
    Enter          open;  o  open the link in a browser
    q              back, or quit

## Options
-f FILE      another feeds file
-c FILE      another config file
-e ACTION    run ACTION and exit: reload-all, convert-opml-to-feeds, convert-feeds-to-opml
-l FILE      write a log to FILE (to see why a feed fails)

## Notes
- The feeds file is `~/.config/newsraft/feeds`; nothing starts until it
  exists.
- A feed that will not update: `newsraft -l log.txt`, then look in the
  log for the HTTP answer.
