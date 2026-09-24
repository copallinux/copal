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
    copal-command-ref.py render      anywhere: facts.json and the written
                                     notes into docs/commands.html
    copal-command-ref.py check       the notes against the inventory and,
                                     on a Copal machine, their options
                                     against the man page or --help

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
from html import unescape as html_unescape
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
CODE = os.path.expanduser("~/code")
# Each command's --help, as the installed version printed it: with the site's
# man pages, what check reads on a machine that is not a Copal install.
HELPDIR = os.path.join(ROOT, "docs", "commands", "help")
# Programs that do something other than print on --help: serve, boot, animate.
NO_HELP = {"ollama", "waydroid", "asciiquarium", "sl", "cmatrix"}
# Colours, cursor codes, and OSC 8 links -- coreutils 9.11 wraps each option
# in one, ended by BEL or by ESC \.
ANSI = re.compile(r"\x1b(\[[0-9;?]*[a-zA-Z]|[()][A-Z0-9]|\][^\x07\x1b]*(\x07|\x1b\\)|[=>])")

ORDER = ("core", "copal", "catalogue", "store")   # the first origin names the entry


def run(argv, **kw):
    try:
        if "stderr" not in kw:
            kw["stderr"] = subprocess.PIPE
        return subprocess.run(argv, stdout=subprocess.PIPE, text=True, errors="replace",
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
    if isinstance(marker, int):
        at = marker
    else:
        at = next((i for i, l in enumerate(prep_lines) if l == marker), None)
        if at is None:
            at = next((i for i, l in enumerate(prep_lines) if marker in l), None)
    if at is None:
        return None
    fn = next((f for f, a, b in FUNCS if a <= at <= b), None)
    seen, frontier, hit = set(), [fn], set()
    for _ in range(5):
        # Every stage that reaches it; the one that runs first wins -- a
        # helper stage 1 and stage 4 both call is stage 1's.
        hit |= {STAGE_FN[f] for f in frontier if f in STAGE_FN}
        nxt = []
        for f in frontier:
            # A stage is where the climb ends: the stages themselves are
            # called from the dispatcher at the top level.
            if not f or f in seen or f in STAGE_FN:
                continue
            seen.add(f)
            call = re.compile(r"(^|[\s;&|(])%s($|[\s;&|)])" % re.escape(f))
            # Called from the script's top level: it runs on every start (0).
            if any(call.search(l) for i, l in enumerate(prep_lines)
                   if l and not l.lstrip().startswith("#") and not any(a <= i <= b for _g, a, b in FUNCS)):
                return 0
            nxt += [g for g, a, b in FUNCS if g != f and any(call.search(l) for l in prep_lines[a + 1:b + 1])]
        frontier = [f for f in nxt if f not in STAGE_FN or STAGE_FN[f] not in hit]
    return first_run(hit)


RUN_ORDER = []


def first_run(stages):
    """Of several stages, the one a full install runs first (order.list);
    0 (every run) before all; stages no level runs, by number, last."""
    if not stages:
        return None
    if 0 in stages:
        return 0
    if not RUN_ORDER:
        RUN_ORDER.extend(int(l.split()[0]) for l in open(os.path.join(STAGES, "order.list"))
                         if l.strip() and not l.startswith("#"))
    return min(stages, key=lambda n: (RUN_ORDER.index(n) if n in RUN_ORDER else 99, n))


def own_purpose(name, prep, at):
    """A Copal tool's first line about itself: '# NAME -- text' (or a
    docstring's 'NAME -- text'), in the heredoc that writes it or in tools/."""
    text = prep[at:at + 6000]
    src = os.path.join(ROOT, "tools", name)
    if not re.search(r"<<'?\w+'?\s*$", prep[at:prep.find("\n", at)]) and os.path.exists(src):
        text = open(src).read()[:6000]
    # 'NAME -- text', 'NAME [ARGS]  -- text'; the front door's header shouts.
    m = re.search(r'^(?:#\s*|"""|\s*)%s\b[^\n]{0,40}?\s--?\s+(.+(?:\n(?:#\s+|\s+)(?!\S+\s+--)\S.*)*)'
                  % re.escape(name), text, re.M | re.I)
    if not m:
        return None
    t = " ".join(re.sub(r"^#\s*", "", l).strip() for l in m.group(1).split("\n"))
    t = re.split(r"(?<=[.:;])\s", t)[0].rstrip(".:;")
    return t[0].upper() + t[1:] if t else None


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
        # The line that writes it, not the first line that mentions it; and
        # what it says it is, from its own header ('# NAME -- what it is').
        add(m.group(2), "copal", stage=stage_of(prep_lines, m.group(0)),
            purpose=own_purpose(m.group(2), prep, m.start()))

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
    # What a Copal machine has, not what this account added: ~/.cargo/bin's
    # rustup shadows Alpine's cargo on the bench. ~/.local/bin stays -- the
    # checkouts' programs are linked there.
    home = os.path.expanduser("~")
    keep = os.path.join(home, ".local", "bin")
    e["PATH"] = ":".join(d for d in e.get("PATH", "").split(":")
                         if d == keep or not (d + "/").startswith(home + "/"))
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


def so_target(f):
    """A page that is only '.so man1/pdftex.1' is the page it names: mandoc
    does not find that one when it is compressed (pdflatex's is)."""
    try:
        with (gzip.open(f) if f.endswith(".gz") else open(f, "rb")) as h:
            head = h.read(400).decode("latin-1")
    except OSError:
        return f
    m = re.match(r"(?:\.\\\".*\n|\s*\n)*\.so\s+(\S+)", head)
    if m:
        for ext in (".gz", ""):
            t = os.path.join("/usr/share/man", m.group(1) + ext)
            if os.path.exists(t):
                return t
    return f


def man_page(cmd):
    """The page named exactly after the command, by section, before
    man -w's first guess (which answers 'apk' with apk-package(5))."""
    for sec in MANSECS:
        d = "/usr/share/man/man" + sec
        for suf in ("", "p", "x"):
            for ext in (".gz", ""):
                f = os.path.join(d, "%s.%s%s%s" % (cmd, sec, suf, ext))
                if os.path.exists(f):
                    return so_target(f)
    mp = run(["man", "-w", cmd]).strip().split("\n")[0]
    return mp if mp and os.path.exists(mp) else None


# The programs in ~/code have READMEs, not man pages: copal-build makes one
# from the README (tools/copal-readme-man), and so does the site, from the
# same record of what each checkout made.
PROJECTS = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
                        "copal", "projects")
README_MAN = os.path.join(ROOT, "tools", "copal-readme-man")
README_CACHE = os.path.expanduser("~/.cache/copal-command-ref/man1")


def checkout_of(cmd):
    """(checkout, its programs) for a program copal-build made, or None."""
    rows = [l.rstrip("\n").split("|") for l in open(PROJECTS)] if os.path.exists(PROJECTS) else []
    n = next((r[0] for r in rows if len(r) > 2 and r[2] == cmd), None)
    if not n or not os.path.exists(os.path.join(CODE, n, "README.md")):
        return None
    return n, sorted(r[2] for r in rows if r[0] == n and len(r) > 2)


def readme_page(cmd, checkout):
    """The man page copal-build would write for cmd, as a file: roff."""
    n, progs = checkout
    os.makedirs(README_CACHE, exist_ok=True)
    out = os.path.join(README_CACHE, cmd + ".1")
    roff = run([README_MAN, os.path.join(CODE, n, "README.md"), ",".join(progs)], timeout=60)
    if not roff.strip():
        return None
    with open(out, "w") as f:
        f.write(roff)
    return out


def man_source(c):
    """Where a command's man page is: the system's, or one made from a README."""
    if c.get("readme"):
        return readme_page(c["cmd"], checkout_of(c["cmd"]) or (c["readme"], [c["cmd"]]))
    return os.path.join("/usr/share/man", c["man"])


def install_stage(pkg):
    """The stage whose install line names the package."""
    pat = re.compile(r"(add_optional|try_add|apk add)\b[^#]*[\s'\"]%s(@\w+)?($|[\s'\"\\;|&)])" % re.escape(pkg))
    # Every line that installs it; the stage of them that runs first.
    def code(l):
        # An install, not a sentence about one: note "apk add tmux && ..."
        # is advice to the reader. The keyword must not sit inside quotes.
        m = pat.search(l)
        return m and not (l[:m.start()].count('"') % 2 or l[:m.start()].count("'") % 2)
    # By position: the same text can sit earlier inside a guide's heredoc.
    return first_run({g for g in (stage_of(PREP_LINES, i) for i, l in enumerate(PREP_LINES) if code(l))
                      if g is not None})


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
    # Alpine's base system, as Alpine itself lists it (alpine-base's
    # dependencies), and what setup-alpine installs from the answers file
    # stage 1 applies (SSHDOPTS="-c openssh").
    base = {l.strip() for l in run(["apk", "info", "-R", "alpine-base"]).split("\n")[1:] if l.strip()}
    answers = set(re.findall(r'^\w+OPTS="-c (\S+)"', open(PREP).read(), re.M))
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
        if c["origin"] == "core" and ({pkg, c.get("source_package")} & base):
            c["base"] = True
            c["stage"] = None
        elif c.get("stage") is None and {pkg, c.get("source_package")} & answers:
            c["stage"] = 1
        # A catalogue row says stage 12, but an earlier stage may install the
        # same program (gdb: stage 7); the one that runs first is its stage.
        if not c.get("base") and pkg and pkg != "copal":
            # The package by name, its origin, or -- for the core, whose
            # compilers arrive inside build-base -- a package that needs it.
            cands = [pkg, c.get("source_package", pkg)]
            if c["origin"] == "core":
                cands += [re.sub(r"-\d[^-]*-r\d+$", "", r) for r in
                          run(["apk", "info", "-r", pkg]).split("\n")[1:] if r.strip()]
            got = {g for g in map(install_stage, dict.fromkeys(cands)) if g is not None}
            if c.get("stage") is not None:
                got.add(c["stage"])
            c["stage"] = first_run(got)
        mp = man_page(cmd)
        # A link to another program has that program's page: ninja is samu.
        real = os.path.basename(os.path.realpath(c["path"])) if c["path"] else cmd
        if not mp and real not in (cmd, "busybox", "coreutils"):
            mp = man_page(real)
        # An applet's namesake in section 7 or 5 is another thing: ip(7) is
        # the socket API, not BusyBox's ip.
        if pkg == "busybox" and not (mp and re.search(r"/man[18]/", mp)):
            mp = man_page("busybox")
            c["applet"] = True
        co = None if mp else checkout_of(cmd)
        if co and os.access(README_MAN, os.X_OK) and which("lowdown", e):
            c["readme"] = co[0]
            mp = readme_page(cmd, co)
            if mp:
                c["man"] = "man1/%s.1" % cmd
                c["man_name"], c["synopsis"] = man_sections(mp)
        elif mp:
            c["man"] = os.path.relpath(mp, "/usr/share/man")
            c["man_name"], c["synopsis"] = man_sections(mp)
        if not c.get("man") and c["path"] and c.get("mode") == "h" and c["origin"] != "copal":
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
    d = datetime.date.today()
    today = "%s %d, %d" % (d.strftime("%B"), d.day, d.year)
    for c in cmds:
        src = man_source(c)
        if not src:
            continue
        body = run(["mandoc", "-T", "html", "-I", "os=Alpine %s" % facts.get("alpine", ""),
                    "-O", "fragment,man=%N.html", src], timeout=60)
        # A page with no date of its own gets today's from mandoc, which
        # would change every page on every build: leave it undated.
        body = body.replace('<td class="foot-date">%s</td>' % today, '<td class="foot-date"></td>')
        if not body.strip():
            continue
        # A cross-reference to a page that is not built here is plain text.
        body = re.sub(r'<a class="Xr" href="([^"#]+)\.html">(.*?)</a>',
                      lambda m: m.group(0) if m.group(1) in built else '<span class="Xr">%s</span>' % m.group(2),
                      body)
        page = PAGE % {"title": html_escape("%s(%s)" % (c["cmd"], c["man"].split("/")[0][3:])),
                       "desc": html_escape(c.get("man_name", "")), "anchor": c["cmd"], "cmd": html_escape(c["cmd"]),
                       "src": html_escape("%s's README, made a man page by copal-readme-man" % c["readme"]
                                          if c.get("readme") else
                                          "%s %s — %s, Alpine %s" % (c.get("source_package") or c.get("package", ""),
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


# --------------------------------------------------------------------------
# The written layer, and the page
NOTES = os.path.join(ROOT, "docs", "commands")
GUIDE = os.path.join(ROOT, "docs", "commands.html")
INDEX = os.path.join(ROOT, "docs", "commands-index.json")

# The core list has no catalogue section; these are its sections.
CORE_SECTION = {
    "Packages": "apk flatpak",
    "System": "doas busybox lbu setup-alpine mkinitfs dmesg logread",
    "Services": "openrc rc-service rc-update rc-status",
    "Disks": "sfdisk resize2fs zramctl lsblk",
    "Network": "ssh ssh-keygen curl ip iw wpa_cli wpa_passphrase bluetoothctl rsync",
    "Development": "git gcc clang make cmake ninja gdb valgrind nvim cargo go python3 pip tmux",
    "Desktop": "hyprctl",
    "Audio": "wpctl pactl",
}
CORE_OF = {c: sec for sec, cs in CORE_SECTION.items() for c in cs.split()}
MODE = {"t": "terminal program", "h": "command-line tool", "x": "graphical"}


def section_of(c):
    if c.get("section"):
        return c["section"]
    if c["origin"] == "copal":
        return "Copal"
    return CORE_OF.get(c["cmd"], "System")


def parse_note(path):
    """One written entry: '# key: value' header lines (continued by '#' and
    spaces), then '## Use', '## Examples', '## Options', '## Notes'."""
    head, secs, cur, key = {}, {}, None, None
    for line in open(path).read().split("\n"):
        m = re.match(r"^# (\w+):\s*(.*)$", line)
        if cur is None and m:
            key = m.group(1)
            head[key] = m.group(2).strip()
            continue
        if cur is None and key and re.match(r"^#\s{2,}\S", line):
            head[key] += " " + line.lstrip("#").strip()
            continue
        m = re.match(r"^## (\w+)\s*$", line)
        if m:
            cur = m.group(1).lower()
            secs[cur] = []
            continue
        if cur:
            secs[cur].append(line)
    for k in secs:
        while secs[k] and not secs[k][-1].strip():
            secs[k].pop()
        while secs[k] and not secs[k][0].strip():
            secs[k].pop(0)
    return head, secs


def notes():
    out = {}
    for d in sorted(os.listdir(NOTES)) if os.path.isdir(NOTES) else []:
        dd = os.path.join(NOTES, d)
        if not os.path.isdir(dd):
            continue
        for f in sorted(os.listdir(dd)):
            if f.endswith(".md"):
                head, secs = parse_note(os.path.join(dd, f))
                out[head.get("command", f[:-3])] = {"head": head, "secs": secs,
                                                    "path": os.path.relpath(os.path.join(dd, f), ROOT)}
    return out


def esc(t):
    return (t or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(t, known):
    """`code` becomes code, and a link when it names a command in the guide."""
    out, parts = [], re.split(r"(`[^`]+`)", esc(t))
    for p in parts:
        if p.startswith("`") and p.endswith("`"):
            w = p[1:-1]
            first = w.split()[0] if w.split() else w
            if first in known and w == first:
                out.append('<a href="#c-%s"><code>%s</code></a>' % (first, w))
            else:
                out.append("<code>%s</code>" % w)
        else:
            out.append(p)
    return "".join(out)


def paragraphs(lines, known):
    text = "\n".join(lines).strip()
    return "".join("<p>%s</p>" % inline(" ".join(p.split()), known) for p in re.split(r"\n\s*\n", text) if p.strip())


def stage_names():
    names = {}
    for f in os.listdir(STAGES):
        if f.endswith(".sh"):
            t = open(os.path.join(STAGES, f)).read()
            m, k = re.search(r"^# stage:\s*(\d+)", t, re.M), re.search(r"^# step:\s*(.*)$", t, re.M)
            if m and k:
                names[int(m.group(1))] = k.group(1).strip()
    return names


def entry_html(c, note, known, stages):
    cmd = c["cmd"]
    head, secs = (note["head"], note["secs"]) if note else ({}, {})
    purpose = head.get("purpose") or c.get("purpose") or (c.get("man_name", "").split(" - ", 1)[-1].split(" – ", 1)[-1].split(" — ", 1)[-1]
                                      if c.get("man_name") else c.get("description", ""))
    h = ['<article class="cmd%s" id="c-%s" data-s="%s">' % ("" if note else " facts-only", cmd,
         esc(" ".join([cmd, purpose, section_of(c), c.get("package") or ""])).lower())]
    h.append('<h3><a class="self" href="#c-%s"><code>%s</code></a> <span class="purpose">%s</span></h3>'
             % (cmd, esc(cmd), inline(purpose, known)))
    # The facts line.
    f = [esc(section_of(c))]
    if c.get("mode"):
        f.append(MODE.get(c["mode"], ""))
    if c["origin"] == "copal":
        f.append("Copal's own")
    elif c.get("built"):
        f.append("built from source by Copal Apps")
    elif c.get("package"):
        f.append("<b>%s</b> %s" % (esc(c["package"]), esc((c.get("version") or "").split("-r")[0])))
    st = c.get("stage")
    if st == 0:
        f.append("written on every run of the installer")
    elif st:
        f.append("stage %d · %s" % (st, esc(stages.get(st, ""))))
    elif c.get("base"):
        f.append("Alpine's base system")
    if c.get("origin") == "store":
        f.append("on the Copal Apps shelf")
    if c.get("man"):
        sec = c["man"].split("/")[0][3:]
        f.append('<a href="man/%s.html">man %s(%s)</a>%s' % (cmd, "busybox" if c.get("applet") else esc(cmd), sec,
                                                          ", from its README" if c.get("readme") else ""))
    if c.get("webpage"):
        f.append('<a href="%s">home</a>' % esc(c["webpage"]))
    h.append('<p class="facts">%s</p>' % " · ".join(x for x in f if x))
    if c.get("deps"):
        h.append('<p class="deps">needs %s</p>' % ", ".join(esc(d) for d in c["deps"][:8]))
    if c.get("applet"):
        h.append('<p class="deps">a BusyBox applet: <code>busybox %s --help</code>, and BusyBox\'s page</p>' % esc(cmd))
    if head.get("why"):
        h.append('<p class="why"><b>On Copal:</b> %s</p>' % inline(head["why"], known))
    elif c.get("description") and head.get("purpose"):
        h.append('<p class="why">%s</p>' % esc(c["description"]))
    if c.get("synopsis"):
        h.append('<pre class="syn">%s</pre>' % esc(c["synopsis"]))
    if secs.get("use"):
        h.append("<h4>Use</h4>" + paragraphs(secs["use"], known))
    if secs.get("examples"):
        rows = []
        for l in secs["examples"]:
            if not l.strip():
                continue
            m = re.match(r"^\s*(.*?)\s{2,}#\s?(.*)$", l)
            code, what = (m.group(1), m.group(2)) if m else (l.strip(), "")
            rows.append('<div class="ex"><code>%s</code>%s</div>' % (esc(code), '<span>%s</span>' % inline(what, known) if what else ""))
        h.append("<h4>Examples</h4>" + "".join(rows))
    if secs.get("options"):
        rows = []
        for l in secs["options"]:
            m = re.match(r"^(\S.*?)\s{2,}(.*)$", l)
            if m:
                rows.append("<dt><code>%s</code></dt><dd>%s</dd>" % (esc(m.group(1)), inline(m.group(2), known)))
            elif l.strip() and rows:
                rows[-1] = rows[-1][:-5] + " " + inline(l.strip(), known) + "</dd>"
        h.append('<h4>Options</h4><dl class="opts">%s</dl>' % "".join(rows))
    if secs.get("notes"):
        items, cur = [], None
        for l in secs["notes"]:
            if l.startswith("- "):
                cur = [l[2:]]
                items.append(cur)
            elif cur is not None and l.strip():
                cur.append(l.strip())
        h.append("<h4>Notes</h4><ul>%s</ul>" % "".join("<li>%s</li>" % inline(" ".join(i), known) for i in items))
    see = [x.strip() for x in head.get("see", "").split(",") if x.strip()]
    if see:
        h.append('<p class="see">See also %s</p>' % ", ".join(
            ('<a href="#c-%s"><code>%s</code></a>' % (x, esc(x))) if x in known else "<code>%s</code>" % esc(x) for x in see))
    if not note:
        h.append('<p class="pending">No notes yet: the facts above are read from apk and the man page.</p>')
    h.append("</article>")
    return "\n".join(h)


GUIDE_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>The Terminal Guide · Copal Linux</title>
<meta name="description" content="Every terminal command on a Copal machine: what it is for, why it is here, where it comes from, how to use it, and the parts people get wrong.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,600;1,300;1,400&family=JetBrains+Mono:wght@400;500;700&display=swap">
<link rel="stylesheet" href="site.css">
<link rel="stylesheet" href="commands.css">
</head>
<body>
<nav class="site-nav" aria-label="Site">
  <a class="mark" href="./">Copal</a>
  <a class="key" href="./">Home</a>
  <a class="key" href="about.html">About</a>
  <a class="key" href="desktop.html">Desktop</a>
  <a class="key" href="install.html">Install</a>
  <a class="key" href="software.html">Software</a>
  <a class="key" href="commands.html" aria-current="page">Commands</a>
</nav>
<main class="guide">
<header class="page-head">
  <h1>The Terminal Guide</h1>
  <p class="lede">Every terminal command a Copal machine carries on purpose: %(n)d of them. What each is
  for, why it is here, the package it came in, how to use it, and the parts people get wrong.</p>
  <p class="gen">Facts read from Alpine %(alpine)s (%(arch)s) on %(date)s; %(written)d commands have written notes so
  far, the rest their facts and man page. Every page in <code>man</code> on a Copal machine is here too.
  How it is written, checked against a running machine: <a href="terminal-guide-lab-report.html">the lab report</a>.</p>
</header>
<div class="finder">
  <input id="find" type="search" placeholder="Find a command: name, purpose, package" autocomplete="off" aria-label="Find a command">
  <span id="found"></span>
</div>
<nav class="toc" aria-label="Sections">%(toc)s</nav>
%(body)s
</main>
<script>
(function () {
  var q = document.getElementById("find"), n = document.getElementById("found");
  var all = [].slice.call(document.querySelectorAll("article.cmd"));
  var secs = [].slice.call(document.querySelectorAll("section.sec"));
  q.addEventListener("input", function () {
    var t = q.value.trim().toLowerCase(), shown = 0;
    all.forEach(function (a) { var on = !t || a.dataset.s.indexOf(t) >= 0; a.hidden = !on; shown += on; });
    secs.forEach(function (s) { s.hidden = !s.querySelector("article.cmd:not([hidden])"); });
    n.textContent = t ? shown + " of " + all.length : "";
  });
})();
</script>
</body>
</html>
"""


def render():
    facts = json.load(open(FACTS))
    cmds = facts["commands"]
    ns = notes()
    known = {c["cmd"] for c in cmds}
    stages = stage_names()
    by = {}
    for c in cmds:
        by.setdefault(section_of(c), []).append(c)
    order = sorted(by, key=lambda s: (s != "Copal", s))
    body, toc = [], []
    for sec in order:
        sid = "s-" + re.sub(r"\W+", "-", sec.lower())
        toc.append('<a href="#%s">%s <span>%d</span></a>' % (sid, esc(sec), len(by[sec])))
        body.append('<section class="sec" id="%s"><h2>%s</h2>' % (sid, esc(sec)))
        for c in sorted(by[sec], key=lambda c: c["cmd"].casefold()):
            body.append(entry_html(c, ns.get(c["cmd"]), known, stages))
        body.append("</section>")
    page = GUIDE_PAGE % {"n": len(cmds), "alpine": esc(facts.get("alpine") or ""), "arch": esc(facts.get("arch", "")),
                         "date": esc(facts.get("generated", "")), "written": sum(1 for c in cmds if c["cmd"] in ns),
                         "toc": "".join(toc), "body": "\n".join(body)}
    open(GUIDE, "w").write(page)
    index = {}
    for c in cmds:
        note = ns.get(c["cmd"])
        index[c["cmd"]] = (note and note["head"].get("purpose")) or c.get("purpose") or \
            (c.get("man_name", "").split(" - ", 1)[-1] if c.get("man_name") else c.get("description", ""))
    with open(INDEX, "w") as f:
        json.dump(index, f, ensure_ascii=False, indent=0, sort_keys=True)
        f.write("\n")
    print("  ok      %d commands, %d with notes -> docs/commands.html (%.0f kB), docs/commands-index.json"
          % (len(cmds), sum(1 for c in cmds if c["cmd"] in ns), len(page.encode()) / 1024))
    return 0


def help_text(path):
    """What --help prints, both streams; --help-extra too where it points."""
    kw = dict(stdin=subprocess.DEVNULL, timeout=4, stderr=subprocess.STDOUT, cwd="/tmp")
    t = run([path, "--help"], **kw)
    if "--help-extra" in t:
        t += run([path, "--help-extra"], **kw)
    # GHC lists its flags only under --show-options, and says so in --help.
    if "--show-options" in t:
        t += run([path, "--show-options"], **kw)
    # Nim keeps most of its options for --fullhelp.
    if "--fullhelp" in t:
        t += run([path, "--fullhelp"], **kw)
    return ANSI.sub("", t)


def help_snapshot():
    """docs/commands/help/<cmd>.txt: every command's --help, on a Copal machine."""
    facts = json.load(open(FACTS))["commands"]
    e = env()
    os.makedirs(HELPDIR, exist_ok=True)
    keep = set()
    for c in facts:
        path = which(c["cmd"], e)
        if not path or c["cmd"] in NO_HELP or c.get("origin") == "copal":
            continue
        t = help_text(path)
        if t.strip() and len(t) < 200000:
            with open(os.path.join(HELPDIR, c["cmd"] + ".txt"), "w") as f:
                f.write(t)
            keep.add(c["cmd"] + ".txt")
    for f in os.listdir(HELPDIR):
        if f not in keep:
            os.remove(os.path.join(HELPDIR, f))
    print("  ok      %d help texts -> docs/commands/help/" % len(keep))
    return 0


def source_text(cmd):
    """Copal's own commands are never run to read their help: copal-shot
    starts a screenshot, copal-halt shuts down, and most take no --help.
    Their text is their source -- the heredoc copal-prep.sh writes them
    from, else their file in tools/."""
    lines = open(os.path.join(ROOT, "copal-prep.sh"), encoding="utf-8", errors="replace").read().split("\n")
    # Every heredoc written to the file, 'cat >' and 'cat >>' alike: some are
    # built in parts, an unquoted head for the values and a quoted body.
    # '.new': the front door, copal, is written beside itself and renamed.
    pat = re.compile(r'cat >>? "?/usr(?:/local)?/bin/%s(?:\.new)?"? <<\s*\'?"?([A-Z_]+)' % re.escape(cmd))
    body = []
    for i, l in enumerate(lines):
        m = pat.search(l)
        if m:
            tag = m.group(1)
            for l2 in lines[i + 1:]:
                if l2.strip() == tag:
                    break
                body.append(l2)
    if body:
        return "\n".join(body)
    # Not written by the installer: its file in tools/. The heredoc wins where
    # both exist, because it is what a machine has -- copal-fleet in tools/ is
    # the console ('copal fleet'); /usr/bin/copal-fleet is stage 16's node half.
    for f in (os.path.join(ROOT, "tools", cmd), os.path.join(ROOT, "tools", cmd + ".sh")):
        if os.path.isfile(f):
            return open(f, encoding="utf-8", errors="replace").read()
    return ""


def saved_text(cmd):
    """Off a Copal machine: the site's man page, as text, and the saved --help."""
    t = ""
    page = os.path.join(MANDIR, cmd + ".html")
    if os.path.exists(page):
        t += html_unescape(re.sub(r"<[^>]+>", " ", open(page).read()))
    h = os.path.join(HELPDIR, cmd + ".txt")
    if os.path.exists(h):
        t += open(h).read()
    return t


def check():
    """Every note names a command in the inventory, has the header and the
    sections; on a Copal machine, every option it lists is in the man page
    or the --help of the installed version."""
    facts = {c["cmd"]: c for c in json.load(open(FACTS))["commands"]}
    errs, warns = [], []
    on_machine = os.path.exists("/etc/alpine-release")
    e = env()
    for cmd, n in notes().items():
        where = n["path"]
        if cmd not in facts:
            errs.append("%s: '%s' is not in the inventory" % (where, cmd))
            continue
        for k in ("purpose", "why"):
            if not n["head"].get(k):
                errs.append("%s: no '# %s:' line" % (where, k))
        for k in ("use", "examples"):
            if not n["secs"].get(k):
                errs.append("%s: no '## %s' section" % (where, k.capitalize()))
        c = facts[cmd]
        text = ""
        path = None
        if c.get("origin") == "copal":
            text = source_text(cmd)
        elif not on_machine:
            # What the last Copal machine saved: its man pages and --help.
            text = saved_text(cmd)
        else:
            if c.get("man"):
                # The page, and its subcommands' pages (apk-add(8) for apk add).
                page = man_source(c) or ""
                d = os.path.dirname(page)
                subs = [] if c.get("readme") or not page else \
                    sorted(os.path.join(d, f) for f in os.listdir(d) if f.startswith(cmd + "-"))
                for f in ([page] if page else []) + subs:
                    text += BS.sub("", run(["mandoc", "-T", "utf8", f]))
            path = which(cmd, e)
            # A terminal program that opens its screen instead of answering
            # --help has no terminal here (stdin closed, output captured) and is
            # stopped after four seconds; the rest print their options, on
            # either stream (ssh, resize2fs and orrery use stderr).
            if path:
                text += help_text(path)
        if not text:
            warns.append("%s: nothing to check its options against here" % where)
            continue
        tried_h = False
        for l in n["secs"].get("options", []):
            m = re.match(r"^(\S+)", l)
            if not m or not m.group(1).startswith("-"):
                continue
            for flag in re.findall(r"--?[\w][\w-]*", m.group(1).split("=")[0]):
                # A one-letter flag may be printed glued to its value: dot's -ooutfile.
                # A quote before it too: Copal's sources test "--self-test".
                found = lambda f: re.search(r"(^|[\s\[,(|\"'])%s(?![\w-])" % re.escape(f), text) or \
                    (len(f) == 2 and re.search(r"(^|[\s\[,(|])%s(<|[a-z]+\b)" % re.escape(f), text))
                # apk 3 and others: every --X also as --no-X, stated once.
                if flag.startswith("--no-") and "--no-option" in text and found("--" + flag[5:]):
                    continue
                # clang: every -Wname, stated once as -W<warning>.
                if re.match(r"-W[a-z]", flag) and "-W<warning>" in text:
                    continue
                # --[no-]shuffle (openmpt123) and -[no-]shell-escape (TeX) state both.
                bare = flag.lstrip("-")
                if ("--[no-]" + bare) in text or ("-[no-]" + bare) in text:
                    continue
                # Some answer only -h (zangband starts the game on --help).
                if not found(flag) and path and not tried_h:
                    tried_h = True
                    text += run([path, "-h"], stdin=subprocess.DEVNULL, timeout=4, stderr=subprocess.STDOUT)
                if not found(flag):
                    errs.append("%s: %s is not in %s's man page or --help" % (where, flag, cmd))
    for w in warns:
        print("  warn    " + w)
    for x in errs:
        print("\033[31merror:\033[0m " + x)
    if not errs:
        print("  ok      %d notes: in the inventory, complete, options checked%s"
              % (len(notes()), "" if on_machine else " (against the saved pages and --help)"))
    return 1 if errs else 0


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
    if argv[1] == "help-snapshot":
        return help_snapshot()
    if argv[1] == "render":
        return render()
    if argv[1] == "check":
        return check()
    print("usage: copal-command-ref.py inventory|collect|man-html", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
