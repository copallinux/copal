# command:  speedtest-cli
# purpose:  Measure the connection's download speed, upload speed and ping, against speedtest.net.
# why:      The store's line test: from a Pi with no browser, is the network
#           slow, or is it something else?
# see:      curl, ip, iw

## Use
Run it; it picks the nearest speedtest.net server, measures latency,
then download and upload, and prints the results.

## Examples
    speedtest-cli                        # the full test, with progress
    speedtest-cli --simple               # three lines: ping, download, upload
    speedtest-cli --list | head          # servers near you, with their IDs
    speedtest-cli --server 12345         # test against one server
    speedtest-cli --json > result.json   # machine-readable, for a log

## Options
--simple        only ping, download and upload
--list          nearby servers and their IDs
--server ID     use this server
--no-upload     skip the upload test
--bytes         show bytes per second instead of bits
--json / --csv  output for scripts
--share         a link to a result image on speedtest.net

## Notes
- Over wifi, the result measures the wifi as much as the line: compare
  with a cable before blaming the provider.
- A test transfers tens of megabytes; on a metered connection, run it
  sparingly.
