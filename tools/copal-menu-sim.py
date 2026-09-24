#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""copal-menu-sim -- the data behind the site's desktop and its two menus (docs/desk.js,
docs/menu-gui.js, docs/menu-keys.js).

The home page's first picture is the full monty with copal-gui open. The
simulation that replaces it is fed from the real menu on a real Copal
machine, never typed: this reads the entries through copal-gui's own
load_apps, section_of and read_favourites, so the page shows the sections,
names, descriptions, icons and starter favourites the menu itself would.

Run it on a Copal desktop (it needs GTK and the icon theme), from the
checkout:

    python3 tools/copal-menu-sim.py

and it writes

    docs/menu-data.js            the entries, sections and session buttons
    docs/img/menu/icons.png      every icon at 32 px, one sprite sheet
    docs/img/menu/wallpaper.jpg  the running wallpaper, at 1280x800

and, for the other menu, copal-menu's own list: it is rebuilt with
'copal-menu --rebuild' into a scratch cache (your own ~/.cache/copal is left
alone) and carried whole, so the text menu on the page walks the same rows,
sections and Install branch the keyboard menu does. The command reference's
index (docs/commands-index.json) is carried too, so a terminal program
can link to its page.

The store's bench prefix (~/.cache/copal-store/prefix, where the store
builds without root) is added to XDG_DATA_DIRS when it exists, so the
programs a full install puts in /usr/local -- darktable, Naev, Konquest --
are in the menu as a full monty has them.

Each entry's picture is its gallery shot (docs/img/gallery), matched by
command, desktop id or the gallery's own label; a larger one from
docs/img/site is used for the window when there is one.
"""

import glob
import importlib.machinery
import importlib.util
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "img", "menu")
PX = 32          # sprite cell; the page draws them at 24 and 32
COLS = 16


# The site's own pages, which the desktop's menus open as windows (docs/desk.js
# frames only these): the page's file stem, its title, one line, and the
# theme icons to try, in order.
SITE = [
    ("about", "About Copal", "What Copal is, what you get, and where it runs",
     ("user-home", "help-about")),
    ("desktop", "The Desktop", "Hyprland, the Linux Antiquity theme and the two menus",
     ("user-desktop", "preferences-desktop")),
    ("install", "The Installer", "Eighteen stages, and a playbook for every program",
     ("media-flash", "system-software-install")),
    ("platforms", "Platforms", "Every board and machine it runs on, and what has been tested",
     ("computer",)),
    ("alpine", "Alpine Linux", "Why Copal is built on Alpine, and what that means",
     ("drive-harddisk", "distributor-logo")),
    ("software", "Software", "Copal Apps, the menus, and the programs made for it",
     ("package-x-generic", "system-software-update")),
    ("gallery", "Gallery", "The programs, photographed running on Copal",
     ("image-x-generic",)),
    ("commands", "The Terminal Guide", "Every terminal command, checked against the machine",
     ("text-x-generic", "utilities-terminal")),
    ("terminal-guide-lab-report", "Lab report: the Terminal Guide", "How a command reference was written against a running machine",
     ("x-office-document",)),
]


def load_copal_gui():
    loader = importlib.machinery.SourceFileLoader("copal_gui", os.path.join(ROOT, "tools", "copal-gui"))
    spec = importlib.util.spec_from_loader("copal_gui", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def gallery_index():
    """file stem -> file, and gallery label (sans parenthesis) -> stem."""
    stems = {f[:-4] for f in os.listdir(os.path.join(DOCS, "img", "gallery")) if f.endswith(".jpg")}
    labels = {}
    md = os.path.join(DOCS, "app-gallery.md")
    if os.path.exists(md):
        for label, stem in re.findall(r"!\[([^\]]+)\]\(img/gallery/([^)]+)\.jpg\)", open(md).read()):
            labels.setdefault(label.split(" (")[0].strip().casefold(), stem)
    return stems, labels


SKIP = {"if", "then", "else", "fi", "env", "exec", "sh", "bash", "test", "-c"}


def homes_for(execs):
    """program -> its project's home page, for the menu's documentation link
    where the Terminal Guide has no entry. The store's playbook says it first
    ('# home:'); otherwise Alpine's record for the package that owns it."""
    homes = {}
    for f in glob.glob(os.path.join(ROOT, "playbooks", "*", "*.sh")):
        head = open(f, encoding="utf-8", errors="replace").read(4000)
        home = re.search(r"^# home:\s*(https?://\S+)", head, re.M)
        if not home:
            continue
        # Every program the playbook names, and what it installs (a flatpak's id).
        names = re.findall(r"^# program:\s*(\S+)", head, re.M)
        names += [i.split("@")[0] for i in re.findall(r"^# install:\s*(\S+)", head, re.M)]
        for n in names:
            if n != "-":
                homes.setdefault(n, home.group(1))
    owner = {}
    for e in sorted(set(execs) - set(homes)):
        path = shutil.which(e)
        if not path:
            continue
        out = subprocess.run(["apk", "info", "--who-owns", os.path.realpath(path)],
                             capture_output=True, text=True).stdout
        m = re.search(r" is owned by (\S+)", out)
        if m:
            owner[e] = re.sub(r"-\d[^-]*-r\d+$", "", m.group(1))
    # Not installed (the menu's Install rows): the package of that name, from
    # the index; 'calibre@testing' is the package calibre.
    for e in sorted(set(execs) - set(homes) - set(owner)):
        owner[e] = e.split("@")[0]
    if owner:
        out = subprocess.run(["apk", "info", "-w"] + sorted(set(owner.values())),
                             capture_output=True, text=True).stdout
        pages = {re.sub(r"-\d[^-]*-r\d+$", "", p): u
                 for p, u in re.findall(r"^(\S+) webpage:\n(https?://\S+)", out, re.M)}
        for e, p in owner.items():
            if p in pages:
                homes[e] = pages[p]
    # marathon2 and marathon-infinity are Aleph One's, as marathon is.
    for e in execs:
        base = re.sub(r"(-[a-z]+|\d+)$", "", e)
        if e not in homes and base in homes:
            homes[e] = homes[base]
    return {e: homes[e] for e in execs if e in homes}


def main():
    bench =os.path.expanduser("~/.cache/copal-store/prefix/share")
    if os.path.isdir(bench):
        os.environ["XDG_DATA_DIRS"] = bench + ":" + os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
        # GIO hides an entry whose command is not on PATH; the bench's is not.
        os.environ["PATH"] = os.path.join(os.path.dirname(bench), "bin") + ":" + os.environ.get("PATH", "")
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, GdkPixbuf, Gio

    cg = load_copal_gui()
    apps = cg.load_apps()
    by_id = {a.get_id(): a for a in apps}
    theme = Gtk.IconTheme.get_default()
    stems, labels = gallery_index()
    site = {f[:-4] for f in os.listdir(os.path.join(DOCS, "img", "site")) if f.endswith(".jpg")}

    icons = []   # pixbufs, in sprite order

    def icon(gicon, names):
        """Index of the icon in the sprite: the gicon, else the first name the theme has."""
        pb = None
        if gicon is not None:
            info = theme.lookup_by_gicon(gicon, PX, Gtk.IconLookupFlags.FORCE_SIZE)
            if info is not None:
                try:
                    pb = info.load_icon()
                except Exception:
                    pb = None
        if pb is None:
            info = theme.choose_icon(list(names) + ["application-x-executable"], PX, Gtk.IconLookupFlags.FORCE_SIZE)
            pb = info.load_icon() if info is not None else None
        if pb is None:
            return -1
        if pb.get_width() != PX or pb.get_height() != PX:
            pb = pb.scale_simple(PX, PX, GdkPixbuf.InterpType.BILINEAR)
        icons.append(pb)
        return len(icons) - 1

    def picture(a):
        exe = os.path.basename(a.get_executable() or "")
        stem = a.get_id()[:-len(".desktop")] if a.get_id().endswith(".desktop") else a.get_id()
        for c in (exe, stem, stem.lower(), stem.split(".")[-1].lower()):
            if c in stems:
                return c
        return labels.get(a.get_display_name().casefold())

    def program(a):
        """The program an entry runs, past a wrapper: 'env VAR=1 prog',
        'sh -c "prog ..."', 'flatpak run org.x.Prog'. Its documentation is
        that program's, not coreutils' or the shell's."""
        try:
            w = shlex.split(a.get_commandline() or "")
        except ValueError:
            w = []
        while w:
            h = os.path.basename(w[0])
            if h == "env":
                w = [x for x in w[1:] if "=" not in x and not x.startswith("-")]
            elif h in ("sh", "bash") and "-c" in w:
                w = shlex.split(w[w.index("-c") + 1]) if w.index("-c") + 1 < len(w) else []
                w = [x for x in w if x != "exec"]
            elif h == "flatpak":
                ids = [x for x in w[1:] if x != "run" and not x.startswith("-")]
                return ids[0] if ids else h
            elif re.match(r"^[\w.+-]+$", h) and h not in ("if", "for", "while", "case", "test", "["):
                return h
            else:
                break
        # A script too clever to read: the entry's own name stands in.
        i = a.get_id()
        return i[:-len(".desktop")] if i.endswith(".desktop") else i

    entries = []
    for a in apps:
        shot = picture(a)
        entries.append({
            "id": a.get_id(),
            "name": a.get_display_name(),
            "section": cg.section_of(a),
            "desc": a.get_description() or a.get_generic_name() or "",
            "generic": a.get_generic_name() or "",
            "keywords": " ".join(a.get_keywords() or []),
            "exec": os.path.basename(a.get_executable() or ""),
            "prog": program(a),
            "terminal": bool(a.get_boolean("Terminal")),
            "icon": icon(a.get_icon(), ()),
            "shot": shot,
            "big": shot if shot in site else None,
        })

    present = {e["section"] for e in entries}
    # The site's pages are the Copal section, first after the favourites.
    pages = [{"page": n, "title": t, "desc": d, "icon": icon(None, names)} for n, t, d, names in SITE]
    sections = [{"name": "All Applications", "icon": icon(None, ("view-app-grid-symbolic",))},
                {"name": "Favourites", "icon": icon(None, ("starred", "starred-symbolic"))},
                {"name": "Copal", "icon": icon(None, ("folder", "start-here"))}]
    sections += [{"name": s, "icon": icon(None, cg.section_icon(s))} for s in cg.SHOWN if s in present]

    # The session column, as Hyprland shows it (lock only where hyprlock is).
    session = [{"name": "Lock screen", "icon": icon(None, cg.LOCK)},
               {"name": "Log out", "icon": icon(None, cg.LOGOUT)},
               {"name": "Restart", "icon": icon(None, ("view-refresh-symbolic", "system-reboot"))},
               {"name": "Shut down", "icon": icon(None, ("system-shutdown", "system-shutdown-symbolic"))}]

    # The starter favourites, as a first open with no file would pick them.
    favs = [next(i for i in role if i in by_id) for role in cg.STARTER if any(i in by_id for i in role)]

    os.makedirs(OUT, exist_ok=True)
    rows = (len(icons) + COLS - 1) // COLS
    sheet = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, True, 8, COLS * PX, rows * PX)
    sheet.fill(0x00000000)
    for n, pb in enumerate(icons):
        if not pb.get_has_alpha():
            pb = pb.add_alpha(False, 0, 0, 0)
        pb.copy_area(0, 0, PX, PX, sheet, (n % COLS) * PX, (n // COLS) * PX)
    sheet.savev(os.path.join(OUT, "icons.png"), "png", ["compression"], ["9"])

    wall = os.path.expanduser("~/.config/hypr/wallpapers_bundled/georges_riom_collage.png")
    if os.path.exists(wall):
        subprocess.run(["magick", wall, "-resize", "1280x800^", "-gravity", "center", "-extent", "1280x800",
                        "-quality", "72", "-strip", os.path.join(OUT, "wallpaper.jpg")], check=True)

    # copal-menu's list, built fresh into a scratch cache.
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, XDG_CACHE_HOME=tmp)
        env.setdefault("WAYLAND_DISPLAY", "wayland-1")
        subprocess.run(["copal-menu", "--rebuild"], env=env, check=True)
        textmenu = open(os.path.join(tmp, "copal", "menu-wayland.csv")).read()

    # The Terminal Guide's index (tools/copal-command-ref.py render):
    # command -> purpose, for the "see man" links.
    ref = os.path.join(DOCS, "commands-index.json")
    refs = json.load(open(ref)) if os.path.exists(ref) else {}

    # Home pages, for a click on a program the Terminal Guide does not cover.
    # The text menu's commands are read the way menu-keys.js reads them.
    cmds = [e["prog"] for e in entries]
    for line in textmenu.splitlines():
        act = line.split(",", 1)[1] if "," in line else ""
        m = (re.search(r"copal-install\s+(\S+)", act)
             or re.search(r"-e\s+sh\s+-c\s+'(\S+)\s+--help", act)
             or re.match(r"(?:foot|kitty|alacritty|xterm|urxvt)\s+-e\s+(.*)$", act))
        if act.startswith("^"):
            continue
        if m and " " not in m.group(1):
            cmds.append(os.path.basename(m.group(1)))
            continue
        act = m.group(1) if m else act
        # realCommand() in menu-keys.js: past env, sh -c and shell words.
        for t in act.split():
            t = os.path.basename(t.lstrip("\"'").rstrip("\"';"))
            if t in SKIP or "=" in t or not re.match(r"^[A-Za-z][\w.+-]*$", t):
                continue
            cmds.append(t)
            break
    homes = homes_for(sorted({c for c in cmds if c and c not in refs}))

    data = {"px": PX, "cols": COLS, "sections": sections, "session": session,
            "favourites": favs, "apps": entries, "textmenu": textmenu,
            "gallery": sorted(stems), "site": sorted(site), "refs": refs, "homes": homes, "pages": pages}
    with open(os.path.join(DOCS, "menu-data.js"), "w") as f:
        f.write("// Generated by tools/copal-menu-sim.py from copal-gui on a Copal machine; do not edit.\n")
        f.write("window.COPAL_MENU = ")
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.write(";\n")
    pics = sum(1 for e in entries if e["shot"])
    print("  ok      %d entries (%d with a picture), %d sections, %d icons, %d home pages -> docs/menu-data.js, docs/img/menu/"
          % (len(entries), pics, len(sections), len(icons), len(homes)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
