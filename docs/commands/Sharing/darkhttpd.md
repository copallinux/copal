# command:  darkhttpd
# purpose:  Serve a folder over HTTP, with one command and no configuration.
# why:      The catalogue's smallest web server: share a folder of files on the
#           LAN for a minute, or preview a static site from its output folder.
# see:      hugo, zola, croc, python3

## Use
Give it a folder; it serves it on port 8080 until Ctrl-C, with a listing
of the files where there is no index.html.

## Examples
    darkhttpd ~/Public                   # http://this-machine:8080/
    darkhttpd public --port 8000         # a built site, on port 8000
    darkhttpd . --addr 127.0.0.1         # this machine only
    darkhttpd ~/Public --no-listing      # no folder listings

## Options
--port N         the port (default 8080)
--addr IP        listen on one address only (default: all)
--no-listing     do not list folders without an index.html
--index FILE     the index file (default index.html)
--log FILE       write an access log

## Notes
- By default it listens on every address, so anyone on the network can
  read the folder. `--addr 127.0.0.1` keeps it to this machine.
- It serves files as they are: no PHP, no uploads, no passwords.
- A service is installed too (`/etc/init.d/darkhttpd`) for serving a
  folder permanently; `/etc/conf.d/darkhttpd` says which.
