# command:  httrack
# purpose:  Copy a website to disk, links rewritten, so it can be read offline.
# why:      The store's website copier: save a manual, a reference site or your
#           own old site as a folder of files a browser opens from disk.
# see:      curl, lftp

## Use
Give it the address and a folder with `-O`; it follows links within the
site, saves the pages and their images, and rewrites the links to point
at the local copies. Limit the depth, or it may try to copy far more
than you meant.

## Examples
    httrack https://example.org/docs/ -O ~/mirror/docs          # copy a site's section
    httrack https://example.org/ -O ~/mirror/site --depth=3     # three links deep at most
    httrack https://example.org/ -O ~/mirror/site --max-rate=100000   # at most 100 kB/s
    httrack --update -O ~/mirror/docs                           # refresh an earlier copy

## Options
-O, --path DIR        where the copy goes
--depth=N             how many links deep to follow
--ext-depth=N         how far into other sites (default 0: none)
--max-rate=N          bytes per second, at most
--sockets=N           parallel connections (default 4)
--update              update a copy made before
-v, --verbose         log on screen

## Notes
- Be kind to the site: a limited depth and a modest `--max-rate`; copy
  only what you are allowed to.
- It does not run JavaScript: a site built by script copies as empty
  pages.
- It comes from Alpine's testing repository (`httrack@testing`).
