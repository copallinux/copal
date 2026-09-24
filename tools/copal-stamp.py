#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""copal-stamp -- version the desktop's own files in docs/index.html.

    python3 tools/copal-stamp.py            rewrite the stamps
    python3 tools/copal-stamp.py --check    fail if any stamp is stale (make lint)

GitHub Pages lets a browser keep a file for ten minutes (max-age=600). A
browser that already holds some of the desktop's files and fetches the rest
new can pair a new index.html with an old desk.js, or new scripts with an old
stylesheet, and draw a broken page until the old ones expire. So index.html
asks for each of its own scripts and stylesheets as NAME?v=STAMP, the stamp
taken from the file's content: a changed file is a new address, and nothing
can be paired with a stale copy of it. The Terminal Guide's cards, which
desk.js fetches, are stamped the same way through data-cards on #desk.
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
INDEX = os.path.join(DOCS, "index.html")
ASSET = re.compile(r'((?:src|href)=")([\w.-]+\.(?:js|css))(?:\?v=[0-9a-f]+)?(")')
CARDS = re.compile(r'(<div id="desk")(?: data-cards="[0-9a-f]*")?(>)')


def stamp(name):
    with open(os.path.join(DOCS, name), "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()[:10]


def stamped(text):
    def one(m):
        name = m.group(2)
        if not os.path.isfile(os.path.join(DOCS, name)):
            return m.group(0)
        return "%s%s?v=%s%s" % (m.group(1), name, stamp(name), m.group(3))
    text = ASSET.sub(one, text)
    return CARDS.sub(lambda m: '%s data-cards="%s"%s' % (m.group(1), stamp("guide-cards.json"), m.group(2)), text)


def main(argv):
    text = open(INDEX, encoding="utf-8").read()
    new = stamped(text)
    if "--check" in argv:
        if new != text:
            print("\033[31merror:\033[0m docs/index.html's file stamps are stale -- run: python3 tools/copal-stamp.py")
            return 1
        print("  ok      docs/index.html's file stamps match its files")
        return 0
    if new != text:
        open(INDEX, "w", encoding="utf-8").write(new)
        print("  ok      docs/index.html restamped")
    else:
        print("  ok      docs/index.html's stamps already current")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
