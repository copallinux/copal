#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""copal-menu-sim -- the data behind the site's live menu (docs/menu-sim.js).

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
entries (docs/command-reference.json) are listed too, so a terminal program
can link to its page.

The store's bench prefix (~/.cache/copal-store/prefix, where the store
builds without root) is added to XDG_DATA_DIRS when it exists, so the
programs a full install puts in /usr/local -- darktable, Naev, Konquest --
are in the menu as a full monty has them.

Each entry's picture is its gallery shot (docs/img/gallery), matched by
command, desktop id or the gallery's own label; a larger one from
docs/img/site is used for the window when there is one.
"""

import importlib.machinery
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(DOCS, "img", "menu")
PX = 32          # sprite cell; the page draws them at 24 and 32
COLS = 16


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


def main():
    bench = os.path.expanduser("~/.cache/copal-store/prefix/share")
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
            "terminal": bool(a.get_boolean("Terminal")),
            "icon": icon(a.get_icon(), ()),
            "shot": shot,
            "big": shot if shot in site else None,
        })

    present = {e["section"] for e in entries}
    sections = [{"name": "All Applications", "icon": icon(None, ("view-app-grid-symbolic",))},
                {"name": "Favourites", "icon": icon(None, ("starred", "starred-symbolic"))}]
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

    ref = os.path.join(DOCS, "command-reference.json")
    refs = {e["cmd"]: e["purpose"] for e in json.load(open(ref))} if os.path.exists(ref) else {}

    data = {"px": PX, "cols": COLS, "sections": sections, "session": session,
            "favourites": favs, "apps": entries, "textmenu": textmenu,
            "gallery": sorted(stems), "site": sorted(site), "refs": refs}
    with open(os.path.join(DOCS, "menu-data.js"), "w") as f:
        f.write("// Generated by tools/copal-menu-sim.py from copal-gui on a Copal machine; do not edit.\n")
        f.write("window.COPAL_MENU = ")
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.write(";\n")
    pics = sum(1 for e in entries if e["shot"])
    print("  ok      %d entries (%d with a picture), %d sections, %d icons -> docs/menu-data.js, docs/img/menu/"
          % (len(entries), pics, len(sections), len(icons)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
