# Update and Lock Down: PHP, Node and Python on the Bench, and What the Install Base Should Shed

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

*Copal Linux, Alpine 3.24.3 aarch64 guest under UTM on a Mac: the "bench",
host `saskatchewan`. 23 October 2026. The review was done by the author with
an AI coding assistant (Claude) in one terminal on the bench, as an
unprivileged user; the one root-only reading (`sshd -T`) was taken by the
author through `doas`. Nothing on the machine or in the repository was changed
during it. Section VI is the checklist; everything before it is the evidence
for each line.*

---

## Abstract

The question was whether PHP needed its security update, and what PHP, Node
and Python need to be hardened. **PHP is already patched.** Last night's
manual `apk upgrade --available` (22 October, 20:22 UTC) took php83 from
8.3.33 to 8.3.36 and php85 from 8.5.10 to 8.5.12, the releases PHP published
on 21 October. They fix CVE-2026-109618 and CVE-2026-109619 ("PHP2Shell"),
two unauthenticated remote-code-execution flaws rated 9.2 that affect PHP
serving web requests. **Node is not patched.** Node 24.22.1, the security
release of 21 October (ten CVEs across the lines, four High, including a TLS
hostname-check bypass), reached Alpine's index after that upgrade. It is
waiting, along with the `ada-libs` 4.0 it now links against. Python 3.14.9,
an expedited security release, is not yet in Alpine. Its main fix, dropping
the compromised eMudhra/emSign CA, already reached the bench through
`ca-certificates` 20261020. The real gap is the process, not any one
package: a daily job refreshes the index but never upgrades, so a fix waits
until somebody types the command. The machine's exposure is small: **only
sshd listens**, and its configuration is sound. The risk is what is installed
but switched off: sixteen daemons from catalogue sweeps (Samba, MariaDB,
darkhttpd, dnsmasq, Syncthing, rsyncd, OctoPrint and others), each one
`rc-update add` away from a listener with a stock configuration, with no
firewall running behind them. One service, iiod, is enabled at boot and
crashing on a machine with no hardware for it. The report ends with an
eighteen-line checklist and a table of removals.

## I. Objective

1. Establish, from the package index and upstream feeds rather than from
   memory, which security updates are outstanding for PHP, Node and Python.
2. Read each runtime's effective configuration and name what to harden.
3. List every service the bench enables, every port it listens on, and
   every daemon installed but not enabled.
4. Trace each daemon back to the catalogue row that installed it, so the
   suggestions apply to the install base and not only to this machine.
5. Write it as a checklist that can be run top to bottom.

## II. Materials

- **The bench**: Alpine 3.24.3, aarch64, 2,804 packages. Repositories: v3.24
  main and community, edge/testing tagged `@testing`.
- **PHP**: php83 8.3.36 (with phar, openssl, dev, pecl-xdebug), php85 8.5.12
  (with curl, iconv, mbstring, openssl, phar, zip), composer 2.10.3.
- **Node**: nodejs 24.18.1, npm 11.12.1; one global package, Claude Code,
  under the per-user prefix `~/.npm-global`.
- **Python**: python3 3.14.8, 391 `py3-*` packages.
- **OpenSSH** as packaged, with Copal's managed block at the top of
  `/etc/ssh/sshd_config` [1].
- **Feeds**, fetched 23 October 2026: Alpine secdb for v3.24 main and
  community [2], `nodejs.org/dist/index.json` [3], php.net's release JSON for
  8.3 and 8.5 [4], and endoflife.date for PHP, Node and Python [5].
- **copal** at `514465c`: `copal-prep.sh` (37,310 lines), `playbooks/`.

## III. Method

### A. Pending, from the index

`apk version -l '<'` compares what is installed with the index on disk. The
index is only as current as the last `apk update`, so its age was checked
first: `/var/cache/apk/APKINDEX.*` dated 23 October 02:00 local (09:00 UTC).
`/var/log/apk.log` gave the history: who ran what, and when.

### B. Fixed, from upstream

The pending list says that a newer build exists, not whether it fixes a
security problem. So each runtime was checked against its own project:
Node's index flags security releases, php.net names the latest release per
branch, and Alpine's secdb maps each package release to the CVEs it fixes.

### C. Configuration, as the runtime sees it

`php83 -i` and `php85 -i` report the values in force, not what a file says.
`sshd -T` does the same for sshd. It needs the host keys, so the author ran
it under `doas`.

### D. Services: enabled, running, installed

`rc-update show -v` gives the runlevels, `rc-status -a` the state, and
`netstat -tulpn` the listeners. Every script in `/etc/init.d` that is in no
runlevel was resolved to its package with `apk info -W`. Each package was
then traced to its catalogue row in `copal-prep.sh`.

### E. Limits

Without root, two readings were out of reach: the daily Lynis report
(`/var/log/lynis-report.dat`, mode 0640) and root's crontab. Both are steps
in Section VI.

## IV. Results

### A. Updates

| Package | Installed | Available | Security? | Source |
|---|---|---|---|---|
| php83 | 8.3.36 | — | done 22 Oct: CVE-2026-109618, -109619 (unauth. RCE, 9.2) | secdb, php.net, [8] |
| php85 | 8.5.12 | — | done 22 Oct, current upstream | php.net |
| composer | 2.10.3 | — | current; last listed fix 2.9.8 | secdb |
| **nodejs** | **24.18.1** | **24.22.1** | **yes: Node security release, 21 Oct; TLS hostname bypass, DNS, Brotli** | nodejs.org, [9] |
| ada-libs | 3.3.0 | 4.0.0 | needed by nodejs 24.22.1 (`libada.so.4`) | apk |
| cups-libs, cups-dev | 2.4.19-r0 | 2.4.19-r1 | rebuild; unknown | apk |
| dotnet-bash-completion | 9.0.122 | 10.0.303 | no | apk |
| python3 | 3.14.8 | — (upstream 3.14.9) | upstream security release 21 Oct; not yet in Alpine | python.org [10] |
| ca-certificates | 20261020 | — | done 22 Oct: no emSign roots in the bundle | apk, [11] |

How the updates arrive: an `/sbin/apk update` runs every day at 09:00 UTC,
and the only `apk upgrade` in the log is the one typed by hand at 20:22 UTC
on 22 October. Node's fix entered the index nine hours later. Nothing
upgrades the bench on its own, which is a reasonable choice for a machine
the author is working on, as long as the upgrade has a cadence.

Support windows, from [5]: PHP 8.3 has been security-only since 31 December
2025 and reaches end of life on 31 December 2027. PHP 8.5 has active support
to the end of 2027. Node 24 is LTS to April 2028. Node 26 becomes LTS on 28
October 2026, five days from now, and Alpine already ships it as
`nodejs-current` 26.5.1. Python 3.14 runs to October 2030.

### B. PHP

**Two PHP runtimes are installed where one was asked for.** The catalogue
row `Languages|PHP 8.3 + Composer + Xdebug` (`copal-prep.sh:4299`) installs
php83, but Alpine 3.24's `composer` depends on php85. The install therefore
brings in a second interpreter, with its own `php.ini` and `conf.d`, which
appears nowhere in `/etc/apk/world`, and which runs Composer. Xdebug is
loaded only in php83 (`/etc/php83/conf.d/50_xdebug.ini`), so Composer
always runs without the debugger. Alpine 3.24 ships `php85-pecl-xdebug`
3.5.3, so the whole row can move to 8.5.

Effective settings, identical in both:

| Setting | Value | Verdict |
|---|---|---|
| `display_errors` | Off | good |
| `allow_url_include` | Off | good |
| `expose_php` | **On** | turn off: harmless on the CLI, a version banner behind a server |
| `allow_url_fopen` | **On** | keep on the CLI (Composer and scripts fetch with it); off for any served PHP |
| `disable_functions` | none | leave on the CLI; set for any served PHP |
| `open_basedir` | none | as above |

Xdebug itself is configured well: `start_with_request=trigger` and
`client_host=127.0.0.1`, so it connects only when asked, and only to this
machine.

What this means in practice: nothing on the bench serves PHP. There is no
php-fpm and no web server in a runlevel, so PHP's exposure is the code it is
asked to run, chiefly the packages Composer fetches. The useful hardening is
one runtime, kept current, plus `composer audit` on every project that has a
lockfile. Locking down `php.ini` matters the day a web server is installed,
and the checklist puts it in a drop-in file ready for that day.

### C. Node

The 24.22.1 security update is outstanding. Install it, together with
ada-libs 4.0.0, in one `apk upgrade`. Of its fixes, the TLS hostname-check
bypasses and the DNS NUL truncation are in Node's own code and reach the
bench only through this package. The Brotli decoder flaw, CVE-2026-111497,
is in the bundled `deps/brotli`. Alpine builds Node against the shared
`brotli-libs` instead (`ldd /usr/bin/node` shows `libbrotlidec.so.1`), so
for that one the bench depends on `brotli-libs`, at 1.2.1. One analysis
lists upstream Brotli below 1.2.1 as affected, but its severity is
disputed [9]. Upgrading anyway is the answer for every one of them.

What already holds: npm's global prefix is per user (`~/.npm-global`,
written by stage 7, `copal-prep.sh:9804`), so `npm install -g` never runs as
root. The only global package is Claude Code. There is nothing under
`/usr/lib/node_modules` except npm itself.

What is missing: the workshop's project builder runs `npm ci --no-audit
--no-fund` (`copal-prep.sh:9518`). `--no-audit` keeps the build quiet, but it
also means a project's known-vulnerable dependencies are never reported.
Running `npm audit --omit=dev` afterwards, as a report, restores that without
failing the build.

### D. Python

Python 3.14.8 is the build Alpine 3.24 ships. Upstream's 3.14.9 (21 October)
is an expedited security release; its headline change is pip 26.2.2 with
certifi 2026.10.19, after the eMudhra/emSign CA key compromise [10], [11].
On the bench that part is already covered. Alpine's `py3-certifi` returns
the system bundle (`certifi.where()` is `/etc/ssl/certs/ca-certificates.crt`),
and that bundle comes from `ca-certificates` 20261020, installed last night,
which contains no emSign certificate. Venvs are different: a venv that
vendors its own pip and certifi does not use this bundle. Its pip needs
upgrading by hand. The rest of 3.14.9 waits for Alpine's package.

Python is managed: Alpine marks
the system interpreter `EXTERNALLY-MANAGED`, so a plain `pip install` is
refused. Exactly one package in the system `site-packages` is owned by no
apk package: **pyadi-iio 0.0.21**. Stage 14 installs it with
`pip install --break-system-packages --no-deps`
(`copal-prep.sh:16753`). It sits where apk cannot see it, and nothing will
ever update it. The same stage already installs KiKit into its own venv
(`python3 -m venv --system-site-packages ~/.local/kikit`,
`copal-prep.sh:16424`). pyadi-iio should be installed the same way.

### E. sshd

From the author's `sshd -T`:

**What holds.** `permitrootlogin no`, `passwordauthentication no`,
`kbdinteractiveauthentication no`, `permitemptypasswords no`,
`allowusers user`, `allowtcpforwarding no`, `x11forwarding no`,
`permittunnel no`, `gatewayports no`, `strictmodes yes`. The key exchange
leads with the post-quantum `mlkem768x25519-sha256`. Per-source penalties
are on.

**What to tighten.** None of these is a hole, since keys are the only way
in. Each narrows what an authenticated session, or a stolen key, can do:

| Setting | Now | Suggest | Why |
|---|---|---|---|
| `allowagentforwarding` | yes | no | a compromised bench could use the Mac's agent |
| `allowstreamlocalforwarding` | yes | no | Unix-socket forwarding; TCP forwarding is already off |
| `permituserrc` | yes | no | `~/.ssh/rc` runs on every login |
| `maxauthtries` | 6 | 3 | |
| `logingracetime` | 120 | 30 | |
| `macs` | includes `hmac-sha1*`, `umac-64*` | drop those | |
| `subsystem sftp` | `internal-sftp` | decide | `copal-prep.sh:4049` records sftp as removed, yet it is still served |

The changes belong in Copal's managed block (`copal-prep.sh:8210`), which
already runs `sshd -t` before swapping the file in. Because it is first in
the file, its values win.

### F. Services

**Listening:** TCP 22 on IPv4 and IPv6. Nothing else.

**Enabled at boot (default runlevel):** dbus, udev-postmount, bluetooth,
spice-vdagentd, seatd, chronyd, sshd, acpid, alsa, radbeeper, crond, iiod,
local.

Three findings:

1. **iiod is enabled and crashed.** Stage 14 writes `/etc/init.d/iiod`
   (`copal-prep.sh:16655`) and adds it to the default runlevel. iiod serves
   a board's IIO devices to libiio clients on TCP 30431 with no
   authentication, and announces itself over mDNS when avahi runs. That is
   right on a Pluto or an M2K bench board. On a VM with no IIO hardware it
   crashes at every boot, and if it ever stays up, it listens on all
   interfaces. Take it out of the runlevel on any machine that is not an
   instrument host.
2. **bluetooth is enabled on a VM.** It does no harm, but it does nothing
   either.
3. **`/etc/init.d/radbeeper.bak`**, dated 17 September, is a leftover from
   the radbeeper de-embedding and is owned by no package. Delete it.

**No firewall is running.** `ufw` and `iptables` are installed (the catalogue
row `Security|ufw`, `copal-prep.sh:4229`). Neither is in a runlevel. With one
listener this costs nothing today. It is the net under every daemon in IV-G.

### G. Installed, not enabled

These init scripts are in no runlevel. Each one listens on the network if
started:

| Daemon | Listens | Catalogue row |
|---|---|---|
| samba | 139, 445 | `Sharing|Samba`, :4236 |
| mariadb | 3306 | (dependency of a store sweep) |
| darkhttpd | 80/8080 | `Sharing|darkhttpd`, :4235 |
| gmnisrv | 1965 | `Smallweb|gmnisrv`, :4291 |
| dnsmasq | 53, 67 | (dependency) |
| rsyncd | 873 | `Sharing|rsync`, :4238 |
| syncthing | 22000, 8384 | `Sharing|Syncthing`, :4233 |
| octoprint | 5000 | (store) |
| mpd | 6600 | `Media|MPD`, :4139 |
| gpsd | 2947 | (dependency) |
| avahi-daemon | 5353/udp | (dependency) |
| clamd | socket | `Security|ClamAV`, :4224 |
| suricata | — (sniffs) | `Security|Suricata`, :4227 |
| fail2ban | — | `Security|fail2ban`, :4228 |
| lxc, waydroid-container | bridges | `Emulation|Waydroid`, :30646 |
| x11vnc | 5900 (no init script, run by hand) | `Tools|x11vnc`, :4255 |

The full-monty bundle (`playbooks/bundles/full-monty.list`) contains none of
these. They are on the bench because the store sweeps installed every row to
test it (see [6]). An installed, stopped daemon is not an open port. But it
is a binary that `apk upgrade` has to keep patched, and a service one
command away from listening with Alpine's default configuration. Default
configurations are written to work, not to be safe.

## V. Discussion

The worry that started this, PHP's security release, was answered by an
upgrade that had already run. That is luck rather than process: Node's
security release arrived in the same week and missed the upgrade by nine
hours. The bench updates its index daily and its packages only when someone
remembers. The cheapest fix is a habit, not a timer: the daily job already
knows what is pending, so let it say so. Automatic upgrades on the machine
the author develops on would trade one risk for another.

On language runtimes, "harden PHP, Node and Python" means less than it
sounds like on a desktop, because none of them is serving anything. Each one
runs code the author chose to run. The exposure is the dependencies that
code pulls in: Composer packages, npm packages, and the one pip package that
apk cannot see. So the hardening is about the dependency tools: one PHP, not
two; `composer audit` and `npm audit` reports; pip only inside venvs. The
`php.ini` lock-down is worth writing now as a drop-in, so it is in place
before any web server is installed rather than added after.

Most of the risk is in what is installed and switched off. Sixteen daemons
were installed to prove that their catalogue rows work. That proof is done.
For the install base the lesson is about the catalogue, not this machine: a
row that installs a network listener should say so, and the store should
offer the firewall alongside it.

## VI. The checklist

Run on the bench, as the author, in order. Steps marked **repo** are changes
to `copal-prep.sh` that carry the result to every Copal install. Nothing here
has been run.

**Update**

1. `doas apk update && doas apk upgrade --available`: brings Node 24.22.1 (do this first; it is the one open security release)
   and ada-libs 4.0.0. Then `node -v` should print `v24.22.1`.
2. `doas cat /var/log/lynis-report.dat | grep -E '^(hardening_index|warning)'`
   to read today's Lynis warnings, which this review could not.
3. `doas crontab -l` to confirm what the 09:00 UTC job runs.
4. **repo**: have that daily job write a `pending:` line (`apk version -l
   '<'`, with security releases first) somewhere the desktop shows it, so a
   fix like Node's is announced rather than discovered.

**PHP**

5. **repo**: move the Languages row to one runtime: `php85 php85-phar
   php85-openssl php85-pecl-xdebug composer`. Point `dev_write_php_config`
   (`copal-prep.sh:12906`) at `/etc/php85`, and update the `php83` lines in
   the guide text (`:10370`, `:11221`).
6. On the bench: `doas apk del php83 php83-dev php83-doc php83-openssl
   php83-pecl-xdebug php83-phar`, then `doas apk add php85-pecl-xdebug`.
7. `doas tee /etc/php85/conf.d/90_copal.ini` containing `expose_php = Off`.
   Also write, commented out and labelled *for served PHP*, the lines
   `allow_url_fopen = Off`, `disable_functions = exec,passthru,shell_exec,
   system,proc_open,popen`, `open_basedir = /srv/www:/tmp` and
   `session.cookie_httponly = 1`.
8. `composer audit` in every project with a `composer.lock`.

**Node**

9. **repo**: after `npm ci --no-audit` in `build_npm`
   (`copal-prep.sh:9518`), run `npm audit --omit=dev || true` as a report.
10. Before 2027, decide whether to follow Node 26 LTS (`nodejs-current`).
    No action is needed now; 24 is supported to April 2028.

**Python**

11. `doas python3 -m pip uninstall --break-system-packages pyadi-iio`.
    **repo**: install it in a venv the way KiKit is installed
    (`copal-prep.sh:16424`, `:16753`).

**sshd**

12. **repo**: add these lines to the managed block (`copal-prep.sh:8210`):
    `AllowAgentForwarding no`, `AllowStreamLocalForwarding no`,
    `PermitUserRC no`, `MaxAuthTries 3`, `LoginGraceTime 30`,
    `MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com`.
    Then re-run the stage and check `doas sshd -T` against IV-E.
13. Decide on `Subsystem sftp`: drop it, or record in `:4049` that
    `internal-sftp` is intended.

**Services**

14. `doas rc-update del iiod default` on the bench. **repo**: stage 14 should
    enable iiod only when `/sys/bus/iio/devices` is not empty.
15. `doas rc-update del bluetooth default` on the bench (a VM).
16. `doas rm /etc/init.d/radbeeper.bak`.
17. Firewall: `doas ufw default deny incoming && doas ufw allow 22/tcp &&
    doas ufw enable && doas rc-update add ufw default`. **repo**: offer this
    whenever the store installs a row from IV-G.
18. Remove the sweep daemons, per Section VII.

## VII. Suggested removals (bench)

| Remove | Why | Command |
|---|---|---|
| php83 and its five companions | duplicate runtime; Composer uses php85 | step 6 |
| mariadb, mariadb-openrc | database server, nothing uses it | `doas apk del mariadb` |
| samba, samba-server | SMB server; the UTM share already does this job | `doas apk del samba samba-server` |
| darkhttpd, gmnisrv | servers for a capsule/site not hosted here | `doas apk del darkhttpd gmnisrv` |
| dnsmasq | DNS/DHCP server on a guest that gets both from UTM | `doas apk del dnsmasq` (if no dependant objects) |
| octoprint | 3D-printer server, no printer | `doas apk del octoprint` |
| suricata, clamav-daemon, freshclam | heavy, unconfigured, unscheduled; Lynis already audits daily | `doas apk del suricata clamav-daemon freshclam` |
| gpsd | no GPS | `doas apk del gpsd` (if no dependant objects) |
| waydroid, lxc | Android container stack, unused on the bench | `doas apk del waydroid` |
| dotnet-bash-completion | only thing pending a major version, for a runtime not otherwise used | `doas apk del dotnet-bash-completion` |

Keep: sshd, chronyd, crond, spice-vdagentd, seatd, acpid, alsa, radbeeper;
ufw (enable it); fail2ban (harmless stopped, useful if passwords ever
return); syncthing, rsync, mpd (clients the author uses; just not their
daemons at boot).

Where `apk del` refuses because another package depends on the target, the
refusal names that package, and the row is kept. Nothing here has been
removed.

## VIII. Proposed backlog entries

Not yet written to `docs/backlog.md` [7]:

- **SEC-1** Daily job announces pending updates, security first (step 4).
- **SEC-2** Languages row: PHP 8.5 only, Xdebug on 8.5 (step 5).
- **SEC-3** `90_copal.ini` drop-in with the served-PHP lines (step 7).
- **SEC-4** `npm audit` report after `npm ci` (step 9).
- **SEC-5** pyadi-iio into a venv (step 11).
- **SEC-6** sshd managed block, six more lines; decide on sftp (12, 13).
- **SEC-7** iiod only when IIO hardware is present (step 14).
- **SEC-8** Store marks rows that ship a listener and offers ufw (step 17).

## IX. Addendum: checked against the web (23 October 2026)

At the author's request, the findings were checked against published
advisories the same day. The corrections above are folded in. What changed:

- **PHP**: confirmed, and more serious than first stated. 8.3.36 and 8.5.12
  are the 21 October releases for "PHP2Shell", two unauthenticated RCEs
  rated 9.2, with proofs of concept circulating [8]. They affect PHP
  serving web requests, which the bench does not do. It was patched on
  22 October anyway.
- **Node**: confirmed outstanding. The release is dated 21 October, not 20
  (the dist index carries the build date). Researchers reported code
  execution against the official Linux arm64 build of 24.22.0, the bench's
  architecture, although through the bundled Brotli, which Alpine's build
  does not use [9].
- **Python**: corrected. 3.14.9 *is* a security release. Its CA fix is
  already on the bench via the system bundle, as IV-D now says. The rest
  waits for Alpine.
- **Node 26**: LTS on 28 October 2026 confirmed [5].
- **Composer and `allow_url_fopen`**: Composer fails without it [12], which
  supports keeping it on for the CLI (IV-B).
- **iiod**: the port (30431) and the lack of authentication could not be
  confirmed from a published source in this pass. They rest on libiio's
  behaviour as generally described. Read `iiod --help` and libiio's
  documentation before relying on IV-F item 1. The recommendation stands
  either way, because the service crashes on hardware that is not there.

## References

[1] Copal Linux, "Copal ssh policy," `copal-prep.sh`, lines 8130–8251.

[2] Alpine Linux, "Security database," https://secdb.alpinelinux.org/v3.24/,
fetched 23 October 2026.

[3] Node.js, "Distribution index," https://nodejs.org/dist/index.json,
fetched 23 October 2026.

[4] The PHP Group, "Releases," https://www.php.net/releases/, branches 8.3
and 8.5, fetched 23 October 2026.

[5] endoflife.date, "PHP," "Node.js," "Python,"
https://endoflife.date/api/, fetched 23 October 2026.

[6] Copal Linux, "Copal Store," `docs/copal-store.md`, 2026.

[7] Copal Linux, "Backlog," `docs/backlog.md`, 2026.

[8] Snyk, "PHP fixes two critical unauthenticated RCE flaws,"
https://snyk.io/blog/php-patches-critical-unauthenticated-rces/, and Laravel
Forge, "PHP security advisory (CVE-2026-109618, CVE-2026-109619),"
https://laravel.com/forge/docs/knowledge-base/php-security-release-october-2026.

[9] Node.js, "Wednesday, October 21, 2026 Security Releases,"
https://nodejs.org/en/blog/vulnerability/october-2026-security-releases, and
"Node.js 24.22.1 (LTS)," https://nodejs.org/en/blog/release/v24.22.1;
Rescana, "Node2Shell," https://www.rescana.com/post/nodejs-cve-2026-111497-node2shell-brotli-rce-october-2026;
ikow, "brotli2crash," https://github.com/ikow/brotli2crash.

[10] Python Software Foundation, "Python 3.14.9,"
https://www.python.org/downloads/release/python-3149/.

[11] StepSecurity, "eMudhra / emSign CA Compromise: What Python, pip, and
CI/CD Users Need to Update,"
https://www.stepsecurity.io/blog/emudhra-emsign-ca-compromise-python-pip-ci-cd-update.

[12] M. Jacobs, "PHP composer installation fails: allow_url_fopen must be
enabled,"
https://ma.ttias.be/php-composer-installation-fails-file-could-not-be-downloaded-allow_url_fopen-must-be-enabled/.
