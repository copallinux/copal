# command:  newsboat
# purpose:  An RSS and Atom feed reader for the terminal.
# why:      The catalogue's terminal feed reader: every site and channel you
#           follow, in one list of unread items, readable over SSH.
# see:      newsraft, sfeed, links

## Use
List your feeds' addresses in a file, one per line; newsboat fetches them
and shows what is new. Read an item in place, or open it in a browser
with `o`.

## Examples
    mkdir -p ~/.config/newsboat
    echo 'https://alpinelinux.org/atom.xml' >> ~/.config/newsboat/urls   # a feed
    newsboat                             # read
    newsboat -r                          # refresh every feed at start
    newsboat -i subscriptions.opml       # import another reader's list
    newsboat -e > feeds.opml             # export yours
    newsboat -x reload                   # refresh from a script (cron), no screen

    R  r           (in newsboat) reload all / this feed
    Enter  o       read the item / open it in the browser
    n              the next unread item;  A  mark the feed read
    q              back, or quit

## Options
-r           refresh all feeds at start
-i FILE      import an OPML file
-e           export the feeds as OPML
-x COMMAND   run reload or print-unread, without the interface
-u FILE      another urls file
-C FILE      another config file

## Notes
- The files are `~/.newsboat/urls` and `~/.newsboat/config` -- or, if
  `~/.newsboat` does not exist, the same names in `~/.config/newsboat`.
- A YouTube channel is a feed too:
  `https://www.youtube.com/feeds/videos.xml?channel_id=ID`.
- `o` opens `$BROWSER`; set `browser` in the config to a text browser,
  such as `links %u`, for use over SSH.
