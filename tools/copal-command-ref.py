#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""copal-command-ref -- the Terminal Guide's generated layer.

Every terminal command a Copal machine carries on purpose, and the facts
about each that can be read rather than written: where it comes from, its
package, version, description and dependencies, and its man page's NAME
and SYNOPSIS. docs/terminal-guide-plan.md is the design; the written layer
(docs/commands/<section>/<cmd>.md) sits on top of this one.

    copal-command-ref.py inventory   the commands, from the repository alone
    copal-command-ref.py collect     on a Copal machine: the facts, into
                                     docs/commands/facts.json
    copal-command-ref.py man-html    on a Copal machine: each command's man
                                     page as HTML, into docs/man/

THE INVENTORY is read from the files that install the commands, never
typed: man_core_commands in copal-prep.sh (the Alpine and toolchain core);
every 'cat > /usr/local/bin/copal-*' in the installer (Copal's own); the
catalogue's rows of mode t and h (stage 12); and the store's table rows of
mode t and h. A command in two of them is one entry with both origins.

THE FACTS need the machine: apk for packages (a command that is not
installed is looked up by its row's package name), and mandoc for the man
pages, which install_manuals put there. The store's bench prefix is on
PATH when it exists, so its builds count as installed.
"""

import datetime
import gzip
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREP = os.path.join(ROOT, "copal-prep.sh")
STORE = os.path.join(ROOT, "tools", "copal-store")
STAGES = os.path.join(ROOT, "playbooks", "Stages")
FACTS = os.path.join(ROOT, "docs", "commands", "facts.json")
MANDIR = os.path.join(ROOT, "docs", "man")
BENCH = os.path.expanduser("~/.cache/copal-store/prefix")

ORDER = ("core", "copal", "catalogue", "store")   # the first origin names the entry


def run(argv, **kw):
    try:
        return subprocess.run(argv, capture_output=True, text=True, errors="replace",
                              timeout=kw.pop("timeout", 30), **kw).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


# --------------------------------------------------------------------------
# The inventory
STAGE_FN = {}      # stage_gui -> 4, from the stage playbooks' headers
FUNCS = []         # (name, first line, last line) of every top-level function
PREP_LINES = []    # copal-init.sh's lines, blank outside its heredoc


def call_graph(prep):
    for f in sorted(os.listdir(STAGES)):
        if f.endswith(".sh"):
            t = open(os.path.join(STAGES, f)).read()
            m, k = re.search(r"^# stage:\s*(\d+)", t, re.M), re.search(r"^# playbook:\s*(\S+)", t, re.M)
            if m and k:
                STAGE_FN[k.group(1).replace("-", "_")] = int(m.group(1))
    lines = prep.split("\n")
    # The stages live in copal-init.sh, which copal-prep.sh carries whole as
    # one heredoc (COPALINIT): that body is the program scanned here.
    a = next(i for i, l in enumerate(lines) if re.search(r"<<'COPALINIT'$", l))
    b = next(i for i in range(a + 1, len(lines)) if lines[i] == "COPALINIT")
    lines = [""] * (a + 1) + lines[a + 1:b] + [""] * (len(lines) - b)
    # Heredoc-aware: an embedded script's own functions (copal-store's, in
    # stage 18) are text inside the installer, not functions of it.
    hd, cur = None, None
    for i, l in enumerate(lines):
        if hd is not None:
            if (l.lstrip("\t") if hd[1] else l) == hd[0]:
                hd = None
            continue
        m = re.match(r"^([a-z_][a-z0-9_]*)\(\) \{", l)
        if m and cur is None:
            if l.rstrip().endswith("}"):          # one line: name() { ...; }
                FUNCS.append((m.group(1), i, i))
                continue
            cur = (m.group(1), i)
        elif l == "}" and cur is not None:
            FUNCS.append((cur[0], cur[1], i))
            cur = None
        for h in re.finditer(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2", l):
            if "<<<" not in l[max(0, h.start() - 1):h.start() + 3]:
                hd = (h.group(3), h.group(1) == "-")
    return lines


def stage_of(prep_lines, marker):
    """The stage that writes a file: the function around the line that writes
    it, then its callers, up to the first stage function (depth 5)."""
    at = next((i for i, l in enumerate(prep_lines) if marker in l), None)
    if at is None:
        return None
    fn = next((f for f, a, b in FUNCS if a <= at <= b), None)
    seen, frontier = set(), [fn]
    for _ in range(5):
        nxt = []
        for f in frontier:
            if f in STAGE_FN:
                return STAGE_FN[f]
            if not f or f in seen:
                continue
            seen.add(f)
            call = re.compile(r"(^|[\s;&|(])%s($|[\s;&|)])" % re.escape(f))
            # Called from the script's top level: it runs on every start (0).
            if any(call.search(l) for i, l in enumerate(prep_lines)
                   if l and not l.lstrip().startswith("#") and not any(a <= i <= b for _g, a, b in FUNCS)):
                return 0
            nxt += [g for g, a, b in FUNCS if g != f and any(call.search(l) for l in prep_lines[a + 1:b + 1])]
        frontier = nxt
    return None


def inventory():
    prep = open(PREP).read()
    global PREP_LINES
    prep_lines = PREP_LINES = call_graph(prep)
    found = {}

    def add(cmd, origin, **kw):
        e = found.setdefault(cmd, {"cmd": cmd, "origins": []})
        if origin not in e["origins"]:
            e["origins"].append(origin)
        for k, v in kw.items():
            e.setdefault(k, v)

    # Core: the list install_manuals uses.
    m = re.search(r'^man_core_commands\(\) \{\n\s*echo "(.*?)"\n\}', prep, re.M | re.S)
    for c in m.group(1).split():
        add(c, "core")

    # Copal's own: every copal* the installer writes onto PATH -- by heredoc,
    # by 'install' from the checkout, or (copal itself) by copying the script.
    own = re.compile(r"(?:cat >|install -m \d+ \S+|cp \S+) (?:/mnt)?(/usr/(?:local/)?bin/(copal[\w-]*))\b")
    for m in sorted(own.finditer(prep), key=lambda m: m.group(2)):
        # The line that writes it, not the first line that mentions it.
        add(m.group(2), "copal", stage=stage_of(prep_lines, m.group(0)), mode="h")

    # The catalogue (the first one: winebox carries a catalogue() of its own).
    a = prep.index("    cat <<'CATALOGUE'\n") + len("    cat <<'CATALOGUE'\n")
    for line in prep[a:prep.index("\nCATALOGUE\n", a)].split("\n"):
        f = line.split("|")
        if len(f) >= 6 and f[4] in ("t", "h"):
            add(f[3], "catalogue", section=f[0], label=f[1], packages=f[2], mode=f[4], gate=f[5], stage=12)

    # The store's table.
    store = open(STORE).read()
    a = store.index("# >>> playbooks: table")
    for line in store[a:store.index("# <<< playbooks: table", a)].split("\n"):
        f = line.split("|")
        if len(f) >= 6 and re.match(r"^[A-Za-z]+$", f[0]) and f[4] in ("t", "h"):
            add(f[3], "store", section=f[0], label=f[1], packages=f[2], mode=f[4], gate=f[5], stage=18)

    out = sorted(found.values(), key=lambda e: e["cmd"].casefold())
    for e in out:
        e["origin"] = next(o for o in ORDER if o in e["origins"])
    return out


# --------------------------------------------------------------------------
# The facts
def env():
    e = dict(os.environ)
    if os.path.isdir(os.path.join(BENCH, "bin")):
        e["PATH"] = os.path.join(BENCH, "bin") + ":" + e.get("PATH", "")
    return e


def which(cmd, e):
    for d in e.get("PATH", "").split(":"):
        p = os.path.join(d, cmd)
        if d and os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None


VER = re.compile(r"^(.+?)-(\d[^-]*-r\d+)$")


def owners(paths):
    """path -> package, for many paths in one apk call."""
    out = run(["apk", "info", "-W"] + paths, timeout=120)
    got = {}
    for m in re.finditer(r"^(\S+) is owned by (\S+)$", out, re.M):
        v = VER.match(m.group(2))
        got[m.group(1)] = v.group(1) if v else m.group(2)
    return got


def query(names, fields, match=None):
    """apk query, JSON, for many names in one call."""
    if not names:
        return []
    argv = ["apk", "query", "--format", "json", "--fields", fields]
    if match:
        argv += ["--match", match]
    try:
        return json.loads(run(argv + sorted(set(names)), timeout=300) or "[]")
    except ValueError:
        return []


# Libraries nobody needs told about.
QUIET = {"musl", "libgcc", "libstdc++", "busybox", "ncurses-terminfo-base"}


BS = re.compile(".\b")


def man_sections(path):
    """NAME's one line and SYNOPSIS, from mandoc's text rendering."""
    text = BS.sub("", run(["mandoc", "-T", "utf8", "-O", "width=100", path]))
    secs, cur = {}, None
    for line in text.split("\n"):
        if re.match(r"^[A-Z][A-Z0-9 ]+$", line):
            cur = line.strip()
            secs[cur] = []
        elif cur:
            secs[cur].append(line)

    def block(name):
        lines = secs.get(name, [])
        while lines and not lines[-1].strip():
            lines.pop()
        while lines and not lines[0].strip():
            lines.pop(0)
        ind = min((len(l) - len(l.lstrip()) for l in lines if l.strip()), default=0)
        return "\n".join(l[ind:] for l in lines)
    name = re.sub(r"\s+", " ", block("NAME"))
    syn = block("SYNOPSIS").split("\n")
    return name, "\n".join(syn[:14]) + ("\n..." if len(syn) > 14 else "")


def help_usage(path):
    """No man page: the usage lines of --help, from a command that exits."""
    out = run([path, "--help"], stdin=subprocess.DEVNULL, timeout=4)
    lines = [l.rstrip() for l in out.split("\n")]
    for i, l in enumerate(lines):
        if re.match(r"^\s*usage:", l, re.I):
            return "\n".join(x for x in lines[i:i + 4] if x.strip())
    return ""


MANSECS = ("1", "8", "6", "7", "5")


def man_page(cmd):
    """The page named exactly after the command, by section, before
    man -w's first guess (which answers 'apk' with apk-package(5))."""
    for sec in MANSECS:
        d = "/usr/share/man/man" + sec
        for suf in ("", "p", "x"):
            for ext in (".gz", ""):
                f = os.path.join(d, "%s.%s%s%s" % (cmd, sec, suf, ext))
                if os.path.exists(f):
                    return f
    mp = run(["man", "-w", cmd]).strip().split("\n")[0]
    return mp if mp and os.path.exists(mp) else None


def install_stage(pkg):
    """The stage whose install line names the package."""
    pat = re.compile(r"(add_optional|try_add|apk add)\b[^#]*[\s'\"]%s(@\w+)?($|[\s'\"\\])" % re.escape(pkg))
    for i, l in enumerate(PREP_LINES):
        if pat.search(l):
            st = stage_of(PREP_LINES, l)
            if st is not None:
                return st
    return None


def collect():
    inv = inventory()
    e = env()
    alpine = open("/etc/alpine-release").read().strip() if os.path.exists("/etc/alpine-release") else None
    # Where each command is, and whose file it is: one apk call for all.
    for c in inv:
        c["path"] = which(c["cmd"], e)
        c["installed"] = bool(c["path"])
    own = owners([os.path.realpath(c["path"]) for c in inv if c["path"] and not c["path"].startswith(BENCH)])
    for c in inv:
        pkg = own.get(os.path.realpath(c["path"])) if c["path"] else None
        if pkg is None and c.get("packages"):
            pkg = next((p.split("@")[0] for p in c["packages"].split()
                        if not re.search(r"@(source|clone|flathub)$", p)), None)
        if c["path"] and c["path"].startswith(BENCH):
            c["built"] = "copal-store recipe, built from source"
        c["package"] = "copal" if c["origin"] == "copal" else pkg
    # Every package's metadata: one query.
    meta = {}
    for q in query([c["package"] for c in inv if c.get("package") and c["package"] != "copal"],
                   "name,version,description,url,depends,origin"):
        meta.setdefault(q["name"], q)
    # Every library they link, to the package that provides it: one query.
    sos = {d.split("=")[0] for q in meta.values() for d in q.get("depends", []) if d.startswith("so:")}
    prov = {}
    for q in query(sos, "name,provides", match="provides"):
        for pv in q.get("provides", []):
            prov.setdefault(pv.split("=")[0], q["name"])
    for n, c in enumerate(inv, 1):
        cmd, pkg = c["cmd"], c.get("package")
        q = meta.get(pkg)
        if q:
            c.update(version=q.get("version"), description=q.get("description", ""),
                     webpage=q.get("url", ""), source_package=q.get("origin", pkg))
            deps = []
            for d in q.get("depends", []):
                d = d.split("=")[0]
                if d.startswith(("cmd:", "pc:", "/")):
                    continue
                d = prov.get(d, re.sub(r"^so:|\.so.*$", "", d)) if d.startswith("so:") else re.split(r"[<>=~]", d)[0]
                if d and d not in QUIET and d != pkg and d not in deps:
                    deps.append(d)
            c["deps"] = deps
        if c.get("stage") is None and pkg and pkg != "copal":
            c["stage"] = install_stage(pkg) if install_stage(pkg) is not None else install_stage(c.get("source_package", pkg))
        mp = man_page(cmd)
        if not mp and pkg == "busybox":
            mp = man_page("busybox")
            c["applet"] = True
        if mp:
            c["man"] = os.path.relpath(mp, "/usr/share/man")
            c["man_name"], c["synopsis"] = man_sections(mp)
        elif c["path"] and c.get("mode") == "h" and c["origin"] != "copal":
            c["synopsis"] = help_usage(c["path"])
        c["gallery"] = os.path.exists(os.path.join(ROOT, "docs", "img", "gallery", cmd + ".jpg"))
        c.pop("path", None)
        sys.stderr.write("\r  %3d/%d %-30s" % (n, len(inv), cmd))
    sys.stderr.write("\r" + " " * 50 + "\r")
    os.makedirs(os.path.dirname(FACTS), exist_ok=True)
    with open(FACTS, "w") as f:
        json.dump({"generated": datetime.date.today().isoformat(), "alpine": alpine,
                   "arch": os.uname().machine, "commands": inv}, f, indent=1, ensure_ascii=False)
        f.write("\n")
    have = sum(1 for c in inv if c.get("man"))
    pk = sum(1 for c in inv if c.get("package"))
    print("  ok      %d commands (%d installed here), %d with a package, %d with a man page -> %s"
          % (len(inv), sum(c["installed"] for c in inv), pk, have, os.path.relpath(FACTS, ROOT)))
    return 0


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s · Copal Linux</title>
<meta name="description" content="%(desc)s">
<link rel="stylesheet" href="../site.css">
<link rel="stylesheet" href="man.css">
</head>
<body>
<nav class="site-nav" aria-label="Site">
  <a class="mark" href="../">Copal</a>
  <a class="key" href="../commands.html">Commands</a>
  <a class="key" href="../commands.html#c-%(anchor)s">%(cmd)s in the guide</a>
</nav>
<main class="man">
<p class="man-src">%(src)s</p>
%(body)s
</main>
</body>
</html>
"""


def html_escape(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def man_html():
    """Each command's man page as a site page: docs/man/<cmd>.html."""
    facts = json.load(open(FACTS))
    cmds = [c for c in facts["commands"] if c.get("man")]
    built = {c["cmd"] for c in cmds}
    os.makedirs(MANDIR, exist_ok=True)
    total = 0
    for c in cmds:
        src = os.path.join("/usr/share/man", c["man"])
        body = run(["mandoc", "-T", "html", "-O", "fragment,man=%N.html", src], timeout=60)
        if not body.strip():
            continue
        # A cross-reference to a page that is not built here is plain text.
        body = re.sub(r'<a class="Xr" href="([^"#]+)\.html">(.*?)</a>',
                      lambda m: m.group(0) if m.group(1) in built else '<span class="Xr">%s</span>' % m.group(2),
                      body)
        page = PAGE % {"title": html_escape("%s(%s)" % (c["cmd"], c["man"].split("/")[0][3:])),
                       "desc": html_escape(c.get("man_name", "")), "anchor": c["cmd"], "cmd": html_escape(c["cmd"]),
                       "src": html_escape("%s %s — %s, Alpine %s" % (c.get("source_package") or c.get("package", ""),
                                          c.get("version", "") or "", c["man"], facts.get("alpine", ""))),
                       "body": body}
        with open(os.path.join(MANDIR, c["cmd"] + ".html"), "w") as f:
            f.write(page)
        total += len(page.encode())
    gz = sum(len(gzip.compress(open(os.path.join(MANDIR, f), "rb").read()))
             for f in os.listdir(MANDIR) if f.endswith(".html"))
    print("  ok      %d man pages -> docs/man/  (%.1f MB, %.1f MB compressed as served)"
          % (len(cmds), total / 1e6, gz / 1e6))
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip().split("\n\n")[0] + "\n\n  " +
              "\n  ".join(l.strip() for l in __doc__.split("\n") if l.startswith("    copal-command-ref")))
        return 0
    if argv[1] == "inventory":
        inv = inventory()
        for c in inv:
            print("%-26s %-9s %s" % (c["cmd"], ",".join(c["origins"]), c.get("section", "")))
        by = {}
        for c in inv:
            by[c["origin"]] = by.get(c["origin"], 0) + 1
        print("  ok      %d commands: %s" % (len(inv), ", ".join("%s %d" % (o, by.get(o, 0)) for o in ORDER)),
              file=sys.stderr)
        return 0
    if argv[1] == "collect":
        return collect()
    if argv[1] == "man-html":
        return man_html()
    print("usage: copal-command-ref.py inventory|collect|man-html", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
