#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-menu-audit.py -- is every entry in copal-gui's menu a program that runs?
#
#   tools/copal-menu-audit.py              every entry: its section, and whether its command exists
#   tools/copal-menu-audit.py --missing    only the entries whose command does not
#
# THE SAME LIST THE MENU SHOWS. copal-gui lists what GIO advertises --
# Gio.AppInfo.get_all(), less what should_show() hides (NoDisplay, Hidden,
# OnlyShowIn) -- and files each under the first of its SECTIONS whose
# Categories= words match. This asks GIO the same question, and reads
# SECTIONS out of tools/copal-gui's own source, so the two cannot drift. An
# entry is broken if its Exec= command is not on PATH (or, given as a path,
# not an executable file): the menu would show it and clicking would do
# nothing. It exits non-zero if any is.
#
# Store programs installed under another prefix (the bench's) are included
# by putting that prefix's share/ on XDG_DATA_DIRS and its bin/ on PATH:
#   XDG_DATA_DIRS=~/.cache/copal-store/prefix/share:$XDG_DATA_DIRS \
#       tools/copal-store-bench.sh run x tools/copal-menu-audit.py
import ast, os, shutil, sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio
try:  # GLib 2.86 moved DesktopAppInfo to GioUnix, as copal-gui notes
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ValueError, ImportError):
    DesktopAppInfo = Gio.DesktopAppInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sections():
    tree = ast.parse(open(os.path.join(ROOT, "tools", "copal-gui")).read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "SECTIONS" for t in node.targets):
            return [(name, words) for name, _icons, words in ast.literal_eval(node.value)]
    sys.exit("copal-menu-audit: no SECTIONS in tools/copal-gui")


def main():
    only_missing = "--missing" in sys.argv[1:]
    secs = sections()
    rows = []
    for a in Gio.AppInfo.get_all():
        if not isinstance(a, DesktopAppInfo) or not a.should_show():
            continue
        cats = set(filter(None, (a.get_categories() or "").split(";")))
        sec = next((n for n, words in secs if cats & words), "Other")
        exe = a.get_executable() or ""
        path = exe if os.path.isabs(exe) else shutil.which(exe)
        ok = bool(path) and os.path.isfile(path) and os.access(path, os.X_OK)
        rows.append((sec, a.get_display_name(), a.get_id(), exe, ok))
    rows.sort(key=lambda r: (r[0], r[1].casefold()))
    bad = [r for r in rows if not r[4]]
    for sec, name, _id, exe, ok in (bad if only_missing else rows):
        print("%-8s %-14s %-44s %s" % ("ok" if ok else "MISSING", sec, name[:44], exe))
    by = {}
    for r in rows:
        by[r[0]] = by.get(r[0], 0) + 1
    print("\n%d entries, %d with a working command, %d missing -- %s" % (
        len(rows), len(rows) - len(bad), len(bad), ", ".join("%s %d" % kv for kv in sorted(by.items()))))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
