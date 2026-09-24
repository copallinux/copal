# command:  gmnisrv
# purpose:  Serve your own Gemini capsule from a folder.
# why:      The catalogue's Gemini server: publish a capsule from the Pi, with
#           TLS certificates it makes for itself.
# see:      gmni, amfora, darkhttpd

## Use
Put `.gmi` pages in the folder the configuration names, start the
service, and the capsule is at `gemini://HOSTNAME/`. The configuration is
`/etc/gmnisrv.ini`: listen address, certificate store, and one section
per host name.

## Examples
    doas mkdir -p /srv/gemini            # the default root for [localhost]
    echo '# Hello from Copal' | doas tee /srv/gemini/index.gmi
    doas rc-service gmnisrv start        # start it
    gmni gemini://localhost/             # see it
    doas rc-update add gmnisrv           # at every boot

## Options
-C PATH     another configuration file

## Notes
- Out of the box it listens on every address, port 1965, and serves
  only the host name `localhost`. For others to reach it, add a section
  named after the machine's host name, with its own `root=`.
- Certificates are made on first use and kept in
  `/var/lib/gemini/certs`; clients remember them, so keep that folder.
