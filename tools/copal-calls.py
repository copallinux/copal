#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-calls.py -- a helper the installer calls and never defines.
#
#   tools/copal-calls.py [copal-prep.sh]
#
# copal-init.sh writes some fifty other scripts, each a here-document inside
# it, and most of them define the same small helpers for themselves: have,
# say, note, die. A line written in the installer in the habit of one of
# those scripts calls a helper the installer itself does not have. It parses
# -- a name that does not exist is good syntax -- and shellcheck does not
# ask whether a command exists. It is found when the stage runs: 'have: not
# found', taken for a no.
#
# So: every name that some script written by the installer defines, and the
# installer itself calls, and the installer itself does not define, is an
# error. A program of that name on PATH is not looked for: the card is not
# this machine.
import re, sys

path = sys.argv[1] if len(sys.argv) > 1 else "copal-prep.sh"
src = open(path).read().split("\n")
start = next(i for i, l in enumerate(src) if re.match(r"^cat > .*copal-init\.sh\" <<'COPALINIT'$", l))
end = next(i for i in range(start + 1, len(src)) if src[i] == "COPALINIT")

DEF = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{")
HERE = re.compile(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
# Where a command may begin: the start of a line, or after one of these.
CALL = re.compile(r"(?:^|;|&&|\|\||\||\bthen\b|\bdo\b|\belse\b|\bif\b|\belif\b|\bwhile\b|\buntil\b|!|\{|\$\()\s*([A-Za-z_][A-Za-z0-9_]*)(?=\s|;|$)")
ALONE = re.compile(r"\$\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)")


class Reader:
    """A line with what is said taken out and what is run left in. Quotes
    may run over several lines -- an awk program does -- so it remembers."""

    def __init__(self):
        self.sq = self.dq = False

    def code(self, line):
        out, i, n, depth = [], 0, len(line), 0
        while i < n:
            c = line[i]
            if self.sq:
                if c == "'":
                    self.sq = False
                out.append(" ")
            elif self.dq and depth == 0:
                if c == "\\":
                    i += 1
                elif c == '"':
                    self.dq = False
                elif c == "$" and line[i + 1:i + 2] == "(":
                    depth = 1
                    out.append("$(")
                    i += 2
                    continue
                out.append(" ")
            elif depth:
                # A command inside a string: it is run, so it is kept.
                if c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                out.append(c)
            elif c == "\\":
                out.append("  ")
                i += 1
            elif c == "'":
                self.sq = True
                out.append(" ")
            elif c == '"':
                self.dq = True
                out.append(" ")
            elif c == "#" and (i == 0 or line[i - 1] in " \t"):
                break
            else:
                out.append(c)
            i += 1
        return "".join(out)


own, written, calls, inner = set(), set(), {}, None
reader = Reader()
for i in range(start + 1, end):
    line = src[i]
    if inner is not None:
        if line.strip() == inner:
            inner = None
        else:
            m = DEF.match(line)
            if m:
                written.add(m.group(1))
        continue
    quoted = reader.sq or reader.dq
    code = reader.code(line)
    if not quoted:
        m = DEF.match(line)
        if m:
            own.add(m.group(1))
    for rx in (CALL, ALONE):
        for m in rx.finditer(code):
            calls.setdefault(m.group(1), []).append(i + 1)
    h = HERE.search(line)
    if h and "<<<" not in line and not quoted:
        inner = h.group(1)
        reader = Reader()

missing = sorted(n for n in calls if n in written and n not in own)
if missing:
    for n in missing:
        where = ", ".join(str(x) for x in calls[n][:6])
        print("error: the installer calls '%s' and does not define it: %s line %s" % (n, path, where))
    print("       it is defined in a script the installer writes, which is another program.")
    sys.exit(1)
print("  ok      copal-init.sh defines every helper it calls (%d of its own; %d more are its scripts')"
      % (len(own), len(written - own)))
