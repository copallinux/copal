# playbook: firefox-esr
# source:   apk
# origin:   catalogue
#
# program:  firefox-esr
# label:    Firefox ESR (full browser)
# shelf:    Internet
# install:  firefox-esr
# mode:     x
# gate:     !v6
# home:
# about:    Mozilla's Firefox on its extended-support branch: security fixes without monthly
#           changes. Copal sets it up with no welcome tab and no telemetry.

# Firefox ESR: no welcome tab, no "make me the default", no telemetry.
# A policies file in the distribution directory; read on every start.
firefox_esr_post() {
    if [ -d /usr/lib/firefox-esr ] && [ ! -f /usr/lib/firefox-esr/distribution/policies.json ]; then
        mkdir -p /usr/lib/firefox-esr/distribution
        cat > /usr/lib/firefox-esr/distribution/policies.json <<'POL'
{ "policies": {
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "DisableTelemetry": true,
    "DontCheckDefaultBrowser": true,
    "NoDefaultBookmarks": true } }
POL
        note "/usr/lib/firefox-esr/distribution/policies.json"
    fi
}
