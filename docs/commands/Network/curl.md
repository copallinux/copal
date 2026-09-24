# command:  curl
# purpose:  Fetch or send one URL -- HTTP, HTTPS, FTP and more -- from the command line.
# why:      Every download in Copal's install is curl: Mini vMac's sources,
#           the Hyprland configs, the store's release files, each checked
#           against its sha256. It is also how to test a web server or an API.
# see:      links, rsync, ssh

## Use
Given a URL, print what is there. Save it with `-o` or `-O`, follow
redirects with `-L`, and add `-f` so a server error is an error, not an
HTML page saved under your filename.

## Examples
    curl https://example.com             # the page, to the terminal
    curl -fLO https://host/file.tar.gz   # download, under the name in the URL
    curl -fL -o out.iso -C - URL         # resume a download that stopped
    curl -I https://example.com          # the response headers only
    curl -fsSL URL | sh                  # a remote install script (read it first)
    curl -d 'name=copal' https://host/form      # POST form data
    curl --json '{"a":1}' https://host/api      # POST JSON, with its headers
    curl -s -o /dev/null -w '%{http_code}\n' URL  # just the status code

## Options
-o FILE           save to FILE
-O                save under the URL's own filename
-L                follow redirects
-f, --fail        exit non-zero on an HTTP error, save nothing
-s -S             silent, but still show errors (-sS)
-C -              continue a partial download where it stopped
-I, --head        headers only
-d DATA           POST DATA
--json DATA       POST JSON, with the Content-Type set
-H 'Name: value'  add a header
-u USER:PASS      log in
-w FORMAT         print details after: %{http_code}, %{size_download}
--retry N         try again on a transient failure

## Notes
- Without `-L`, a download that redirects -- GitHub release files all
  do -- saves a tiny redirect page. Without `-f`, a 404 saves the error
  page. `-fL` is the habit.
- Without `-o` or `-O`, a binary goes to the terminal; curl refuses and
  says so.
- BusyBox has `wget` too, with far fewer options; curl is the one the
  answers online assume.
