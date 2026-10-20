#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""feature-guide -- the pictures in docs/FEATURE_GUIDE.md.

    python3 tools/feature-guide.py              every picture
    python3 tools/feature-guide.py 01 03 12     only those numbers

Three kinds of picture, and the guide says which is which:

  live terminal  a command run in a pseudo-terminal (script(1)), its colours
                 turned into HTML, numbered rings drawn on the lines the guide
                 talks about, and photographed by headless Chromium. The
                 front door runs anywhere. copal --help, copal-store and
                 copal-guide exist only on a Copal machine and are skipped
                 elsewhere.
  live site      a section of this repository's own site (docs/*.html),
                 served from a local port and photographed the same way.
  from the repo  a picture already in docs/, copied (or a frame cut out of a
                 recording) because the thing it shows needs a VM boot or a
                 desktop this script cannot give it.

Needs python3, chromium and ImageMagick 7 (magick). Writes docs/features/
and nothing else. Port 8101 by default (FG_PORT to change it).
"""
import html
import http.server
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "features")
PORT = int(os.environ.get("FG_PORT", "8101"))
HOME = os.path.expanduser("~")
CHROME = shutil.which("chromium") or shutil.which("chromium-browser") or "chromium"

TERM_BG, TERM_FG = "#16181d", "#d8dee9"
PALETTE = {30: "#4c566a", 31: "#e06c75", 32: "#98c379", 33: "#e5c07b",
           34: "#61afef", 35: "#c678dd", 36: "#56b6c2", 37: "#d8dee9"}

# ------------------------------------------------------------ the shots ---
# kind "term": cmd, keys (typed one per second), start/end (regexes that cut
# the transcript; end is inclusive), rings [(regex, label)], copal (True when
# it only exists on a Copal machine).
# kind "site": page, h2 (the section's heading text), rings (CSS selectors
# shaded amber; the guide's numbered captions name them in order).
# kind "repo": src, frame (for a GIF), crop (magick geometry) and width.
SHOTS = [
    dict(n="01", name="four-acts", kind="site", page="install.html", h2="Four acts"),
    dict(n="02", name="front-door", kind="term", cmd=["./copal", "--flow"],
         rings=[(r"1 Choose a target", 1), (r"3 Prepare the medium", 2),
                (r"boot the target", 3), (r"8 Stage 3", 4)]),
    dict(n="03", name="targets", kind="term", cmd=["./copal"], keys=["\n", "q\n"],
         start=r"CHOOSE A TARGET", end=r"Choose \[1-9",
         rings=[(r"Raspberry Pi -- SD card", 1), (r"PC -- UEFI only", 2),
                (r"Virtual machine -- UTM", 3), (r"r\) What can this Mac", 4)]),
    dict(n="04", name="briefing", kind="term", cmd=["./copal"],
         keys=["\n", "8\n", "n\n", "q\n"],
         start=r"UTM ON APPLE SILICON", end=r"Begin\? \[y/N\]",
         rings=[(r"Equipment you need", 1), (r"Minimum requirements", 2),
                (r"This hands over to", 3), (r"Begin\?", 4)]),
    dict(n="05", name="first-boot", kind="repo", src="media/guided-levels.gif", frame=15,
         width=1000),
    dict(n="06", name="full-automatic", kind="repo", src="media/guided-levels.gif", frame=16,
         width=1000),
    dict(n="07", name="auto-plan", kind="repo", src="media/guided-levels.gif", frame=17,
         width=1000),
    dict(n="08", name="eighteen-stages", kind="site", page="install.html", h2="Eighteen stages",
         rings=["tbody tr:nth-child(3) td", "tbody tr:nth-child(4) td",
                "tbody tr:nth-child(13) td", "tbody tr:nth-child(17) td"]),
    dict(n="09", name="desktop", kind="repo", src="img/site/desktop-menu.jpg", width=1100,
         colors=256),
    dict(n="10", name="copal-apps", kind="repo", src="img/site/copal-apps.jpg", width=1280),
    dict(n="11", name="copal-apps-progress", kind="repo", src="img/site/copal-apps-progress.jpg",
         width=1280),
    dict(n="12", name="store-sections", kind="term", cmd=["copal-store", "sections"], copal=True,
         rings=[(r"^Games ", 1), (r"^Instruments", 2), (r"^Terminals", 3)]),
    dict(n="13", name="guides", kind="term", cmd=["copal-guide"], keys=["\n"], copal=True,
         end=r"Number, or Enter",
         rings=[(r"\b3\) code", 1), (r"\b6\) ide", 2), (r"\b12\) nvim", 3)]),
    dict(n="14", name="update-loop", kind="term", cmd=["copal", "--help"], copal=True,
         end=r"that checkout is the same",
         rings=[(r"^  copal --auto", 1), (r"^  copal --stage", 2),
                (r"^  copal -U --from PATH", 3), (r"copal -U --from ~/code/copal &&", 4)]),
    dict(n="15", name="fleet", kind="term", cmd=["./copal", "fleet"],
         end=r"copal fleet wait",
         rings=[(r"discovery announces, it never", 1), (r"copal fleet enrol ", 2),
                (r"copal fleet run VERB", 3), (r"copal fleet scene NAME", 4)]),
]


def run(argv, **kw):
    return subprocess.run(argv, check=True, **kw)


# ------------------------------------------------------- terminal shots ---
def transcript(cmd, keys):
    """Run cmd in a pty and return what it printed, keys typed a second apart."""
    line = " ".join("'%s'" % a.replace("'", "'\\''") for a in cmd)
    env = dict(os.environ, TERM="xterm-256color", COLUMNS="110", LINES="60",
               COPAL_TUI="0")
    p = subprocess.Popen(["script", "-qfc", line, "/dev/null"], cwd=ROOT, env=env,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    for k in keys or []:
        time.sleep(1)
        p.stdin.write(k.encode())
        p.stdin.flush()
    try:
        out, _ = p.communicate(timeout=30)
    except subprocess.TimeoutExpired:
        p.kill()
        out, _ = p.communicate()
    text = out.decode("utf-8", "replace").replace("\r\n", "\n").replace("\r", "")
    return text.replace(HOME, "~")


SGR = re.compile(r"\x1b\[([0-9;]*)m")
OTHER = re.compile(r"\x1b(\[[0-9;?]*[A-Za-ln-z]|\[[0-9;?]*[?][0-9;]*m|\][^\x07]*\x07|[()][A-Z0-9])")


def plain(s):
    return OTHER.sub("", SGR.sub("", s))


def to_html(line):
    """One line of SGR-coloured text as HTML spans."""
    line = OTHER.sub("", line)
    out, pos, style = [], 0, {}
    for m in SGR.finditer(line):
        out.append(span(line[pos:m.start()], style))
        pos = m.end()
        for c in [int(x) if x else 0 for x in m.group(1).split(";")]:
            if c == 0:
                style = {}
            elif c == 1:
                style["b"] = 1
            elif c == 2:
                style["d"] = 1
            elif 30 <= c <= 37:
                style["fg"] = PALETTE[c]
            elif 90 <= c <= 97:
                style["fg"] = PALETTE[c - 60]
            elif c == 39:
                style.pop("fg", None)
            elif c == 22:
                style.pop("b", None)
                style.pop("d", None)
    out.append(span(line[pos:], style))
    return "".join(out)


def span(text, style):
    if not text:
        return ""
    css = []
    if "fg" in style:
        css.append("color:" + style["fg"])
    if "b" in style:
        css.append("font-weight:bold")
    if "d" in style:
        css.append("opacity:.6")
    t = html.escape(text)
    return '<span style="%s">%s</span>' % (";".join(css), t) if css else t


RING_CSS = """
.ring{outline:2px solid #f0a020;outline-offset:3px;border-radius:3px;position:relative}
.badge{display:inline-block;margin-left:14px;width:22px;height:22px;line-height:22px;
 border-radius:50%;background:#f0a020;color:#111;font:bold 13px/22px sans-serif;
 text-align:center;vertical-align:middle}
"""


def term_page(lines, rings):
    body = []
    for raw in lines:
        lead = re.match(r" *", raw).group(0)
        h = to_html(raw)
        p = plain(raw)
        for rx, label in rings:
            if re.search(rx, p):
                h = '%s<span class="ring">%s</span><span class="badge">%s</span>' % (
                    lead, to_html(raw[len(lead):]), label)
                break
        body.append(h)
    return ("<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:%s}"
            "pre{margin:0;padding:28px 32px;color:%s;font:15px/1.45 'DejaVu Sans Mono',monospace;"
            "white-space:pre}%s</style><pre>%s</pre>"
            % (TERM_BG, TERM_FG, RING_CSS, "\n".join(body)))


def cut(text, start, end):
    lines = text.split("\n")
    i = 0
    if start:
        i = next(k for k, l in enumerate(lines) if re.search(start, plain(l)))
    j = len(lines)
    if end:
        j = next(k for k, l in enumerate(lines) if k >= i and re.search(end, plain(l))) + 1
    lines = lines[i:j]
    while lines and not plain(lines[0]).strip():
        lines.pop(0)
    while lines and not plain(lines[-1]).strip():
        lines.pop()
    return lines


def shoot(url, path, width, height, bg):
    run([CHROME, "--headless=new", "--no-sandbox", "--hide-scrollbars",
         "--window-size=%d,%d" % (width, height), "--virtual-time-budget=4000",
         "--screenshot=" + path, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run(["magick", path, "-fuzz", "1%", "-trim", "+repage", "-bordercolor", bg,
         "-border", "20", path])


def term_shot(s, tmp):
    if s.get("copal") and not shutil.which(s["cmd"][0]):
        print("skip    %s-%s: %s exists only on a Copal machine" % (s["n"], s["name"], s["cmd"][0]))
        return
    lines = cut(transcript(s["cmd"], s.get("keys")), s.get("start"), s.get("end"))
    page = os.path.join(tmp, s["name"] + ".html")
    with open(page, "w") as f:
        f.write(term_page(lines, s.get("rings", [])))
    out = os.path.join(OUT, "%s-%s.png" % (s["n"], s["name"]))
    cols = max(len(plain(l)) for l in lines)
    shoot("file://" + page, out, min(1600, int(cols * 9.3) + 160), len(lines) * 22 + 160, TERM_BG)
    print("live    " + os.path.relpath(out, ROOT))


# ----------------------------------------------------------- site shots ---
class Handler(http.server.SimpleHTTPRequestHandler):
    """docs/ as it is, plus /__fg/PAGE?h2=..&r=.. -- the page cut to one section."""
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=DOCS, **kw)

    def log_message(self, *a):
        pass

    def do_GET(self):
        if not self.path.startswith("/__fg/"):
            return super().do_GET()
        from urllib.parse import urlsplit, parse_qs
        u = urlsplit(self.path)
        q = parse_qs(u.query)
        with open(os.path.join(DOCS, os.path.basename(u.path)), encoding="utf-8") as f:
            page = f.read()
        rings = q.get("r", [])
        css = ("<style>*{animation:none!important;transition:none!important}"
               ".site-nav,footer,.onward,.page-head{display:none!important}"
               + "".join("%s{background:rgba(240,160,32,.38)!important}" % r for r in rings)
               + "</style>")
        js = ("<script>addEventListener('DOMContentLoaded',function(){var m=document.querySelector('main');"
              "var keep=false,want=%s;Array.prototype.slice.call(m.children).forEach(function(e){"
              "if(e.tagName==='H2'){keep=e.textContent.indexOf(want)>=0;}"
              "if(!keep)e.style.display='none';});});</script>" % repr(q["h2"][0]))
        page = page.replace("<head>", '<head><base href="/">', 1).replace("</head>", css + js + "</head>", 1)
        data = page.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def site_shot(s):
    from urllib.parse import urlencode
    q = urlencode([("h2", s["h2"])] + [("r", r) for r in s.get("rings", [])])
    out = os.path.join(OUT, "%s-%s.png" % (s["n"], s["name"]))
    shoot("http://127.0.0.1:%d/__fg/%s?%s" % (PORT, s["page"], q), out, 1200, 1600, "#f1e3c0")
    print("live    " + os.path.relpath(out, ROOT) + "  (the site, docs/" + s["page"] + ")")


# ----------------------------------------------------------- repo shots ---
def repo_shot(s, tmp):
    src = os.path.join(DOCS, s["src"])
    out = os.path.join(OUT, "%s-%s.png" % (s["n"], s["name"]))
    if "frame" in s:
        frames = os.path.join(tmp, "frames-" + os.path.basename(src))
        if not os.path.isdir(frames):
            os.mkdir(frames)
            run(["magick", src, "-coalesce", os.path.join(frames, "f-%02d.png")])
        src = os.path.join(frames, "f-%02d.png" % s["frame"])
    run(["magick", src, "-resize", "%dx>" % s["width"]]
        + (["-colors", str(s["colors"])] if "colors" in s else []) + ["-strip", out])
    print("repo    %s  (from docs/%s)" % (os.path.relpath(out, ROOT), s["src"]))


def main():
    only = set(sys.argv[1:])
    os.makedirs(OUT, exist_ok=True)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    tmp = tempfile.mkdtemp(prefix="copal-fg-")
    try:
        for s in SHOTS:
            if only and s["n"] not in only:
                continue
            {"term": lambda: term_shot(s, tmp), "site": lambda: site_shot(s),
             "repo": lambda: repo_shot(s, tmp)}[s["kind"]]()
    finally:
        srv.shutdown()
        shutil.rmtree(tmp, ignore_errors=True)
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png") and os.path.getsize(os.path.join(OUT, f)) > 600 * 1024:
            print("large   docs/features/%s is over 600 KB" % f)


if __name__ == "__main__":
    main()
