#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-playbooks.py -- playbooks/ into tools/copal-store, and the checks on them.
#
#   tools/copal-playbooks.py sync      write the generated parts of tools/copal-store
#   tools/copal-playbooks.py check     validate every playbook; fail if tools/copal-store has drifted
#   tools/copal-playbooks.py list      one line per playbook: shelf, name, source, programs
#   tools/copal-playbooks.py fmt       rewrite every header in the one layout (values wrapped at 100)
#
# A PLAYBOOK is one project, playbooks/<shelf>/<project>.sh (docs/playbooks-plan.md).
# Its header is data -- the lines up to the first blank line, '# key: value',
# long values continued on '#' lines indented under them:
#
#   playbook, source, origin, build, runs,      the project; origin 'catalogue' for a
#   needs                                       program stage 12 installs in bulk
#   program, label, shelf, install, mode,       one block per program it puts on the
#   gate, home, about                           machine; 'program' is its command
#
# and its body is shell, every name in it prefixed by the project's: NAME_pre,
# NAME_install, NAME_post, NAME_remove, NAME_check, NAME_VER=, patch_* used by it.
# Programs from apk have a header and no body.
#
# What is generated into tools/copal-store, between '# >>> playbooks' markers:
# the store's table (one row per program), the bodies of the source playbooks
# with NAME_bdeps / NAME_rdeps / NAME_needs / NAME_source made from their
# headers, RECIPES, and the bundles (playbooks/bundles/NAME.list). 'make
# sync-store' then carries tools/copal-store into copal-prep.sh as before.
#
# A CATALOGUE playbook (origin: catalogue) is a graphical program from stage
# 12's catalogue. Its row is rewritten in place in copal-prep.sh's catalogue,
# so the catalogue keeps its order and stage 12 installs what it always did;
# a new one goes in after the last row of its section. Its body is at most
# NAME_post (hyphens as underscores), gathered into a marked region of
# copal-prep.sh with catalogue_posts, which seed_app_configs runs; its about
# and home go into tools/copal-store (catalogue_abouts) for Copal Apps. A
# graphical catalogue row with no playbook is an error.
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PB = os.path.join(ROOT, "playbooks")
STORE = os.path.join(ROOT, "tools", "copal-store")
PREP = os.path.join(ROOT, "copal-prep.sh")
PROJECT_KEYS = ("playbook", "source", "origin", "build", "runs", "needs")
PROGRAM_KEYS = ("program", "label", "shelf", "install", "mode", "gate", "home", "about")
GATE = re.compile(r"^(\*|64|!(v6|v7|x32|x64|a64))(,(64|!(v6|v7|x32|x64|a64)))*$")


class Bad(Exception):
    pass


def parse(path):
    text = open(path).read()
    lines = text.split("\n")
    head, i = [], 0
    while i < len(lines) and lines[i].startswith("#"):
        head.append(lines[i]); i += 1
    body = "\n".join(lines[i:]).strip("\n")
    proj, progs, cur, key = {}, [], None, None
    for l in head:
        m = re.match(r"^# ([a-z]+):\s*(.*)$", l)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if key == "program":
                cur = {"program": val}; progs.append(cur)
            elif key in PROGRAM_KEYS:
                if cur is None:
                    raise Bad("%s: '%s' before any 'program'" % (path, key))
                cur[key] = val
            elif key in PROJECT_KEYS:
                if cur is not None:
                    raise Bad("%s: project key '%s' after a program" % (path, key))
                proj[key] = val
            else:
                raise Bad("%s: unknown key '%s'" % (path, key))
            continue
        if l.strip() == "#":
            continue
        m = re.match(r"^#\s{2,}(\S.*)$", l)
        if m and key:
            tgt = cur if key in PROGRAM_KEYS else proj
            # A word broken at its hyphen ("util-linux-" / "misc") is one word.
            sep = "" if re.search(r"\w-$", tgt[key]) else " "
            tgt[key] = (tgt[key] + sep + m.group(1).strip()).strip()
            continue
        raise Bad("%s: header line not understood: %r" % (path, l))
    return {"path": path, "proj": proj, "progs": progs, "body": body}


def load():
    books = []
    for shelf in sorted(os.listdir(PB)):
        d = os.path.join(PB, shelf)
        if shelf == "bundles" or not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".sh") and not f.startswith("._"):
                books.append(parse(os.path.join(d, f)))
    return books


def bundles():
    out = {}
    d = os.path.join(PB, "bundles")
    for f in sorted(os.listdir(d)):
        if f.endswith(".list") and not f.startswith("._"):
            out[f[:-5]] = [l.strip() for l in open(os.path.join(d, f)) if l.strip() and not l.startswith("#")]
    return out


def validate(books):
    errs, ids, names = [], {}, set()
    for b in books:
        p, rel = b["proj"], os.path.relpath(b["path"], ROOT)
        name = p.get("playbook", "")
        if not re.match(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$", name):
            errs.append("%s: playbook name %r" % (rel, name)); continue
        if name in names:
            errs.append("%s: playbook %s twice" % (rel, name))
        names.add(name)
        if os.path.basename(b["path"]) != name + ".sh":
            errs.append("%s: file is not named %s.sh" % (rel, name))
        if not p.get("source"):
            errs.append("%s: no source" % rel)
        if not b["progs"]:
            errs.append("%s: no program" % rel)
        cat = p.get("origin") == "catalogue"
        if p.get("origin") not in (None, "catalogue"):
            errs.append("%s: origin %r" % (rel, p.get("origin")))
        for g in b["progs"]:
            for k in PROGRAM_KEYS:
                if not g.get(k) and not (cat and k == "home"):
                    errs.append("%s: program %s has no %s" % (rel, g.get("program"), k))
            if cat and (g.get("mode") != "x" or "@source" in g.get("install", "")):
                errs.append("%s: a catalogue playbook is a graphical program from a package" % rel)
            if not re.match(r"^[A-Z][a-z]+$", g.get("shelf", "")):
                errs.append("%s: shelf %r" % (rel, g.get("shelf")))
            if g.get("mode") not in ("x", "t", "h", "-"):
                errs.append("%s: mode %r" % (rel, g.get("mode")))
            if not GATE.match(g.get("gate", "")):
                errs.append("%s: gate %r" % (rel, g.get("gate")))
            pid = g["program"] if g.get("program") != "-" else re.sub(r"@.*", "", g.get("install", "").split()[0])
            if pid in ids:
                errs.append("%s: program id %s also in %s" % (rel, pid, ids[pid]))
            ids[pid] = rel
        if b["progs"] and os.path.basename(os.path.dirname(b["path"])) != b["progs"][0].get("shelf"):
            errs.append("%s: lives under %s, its shelf is %s" % (rel, os.path.basename(os.path.dirname(b["path"])), b["progs"][0].get("shelf")))
        is_src = any((name + "@source") in g.get("install", "").split() for g in b["progs"])
        if is_src and not re.search(r"^" + re.escape(name) + r"_install\(\) \{", b["body"], re.M):
            errs.append("%s: builds from source but has no %s_install" % (rel, name))
        if not is_src and not cat and b["body"]:
            errs.append("%s: a store apk playbook with a body (the store runs none)" % rel)
        if cat and b["body"]:
            for n in shell_names(b["body"]):
                if n != fname(name) + "_post":
                    errs.append("%s: a catalogue playbook defines only %s_post, not %s" % (rel, fname(name), n))
        # Every name the body defines is the project's own -- in the shell
        # itself, not in the files its heredocs write.
        for n in shell_names(b["body"]):
            own = (n.startswith(name + "_") or n.startswith(fname(name) + "_")
                   or n.startswith(name.upper().replace("-", "_") + "_") or n.startswith("patch_"))
            if not own:
                errs.append("%s: defines %s, which is not %s's" % (rel, n, name))
    for bundle, members in bundles().items():
        for m in members:
            if m not in ids:
                errs.append("bundles/%s.list: no program %s" % (bundle, m))
    for b in books:
        for n in b["proj"].get("needs", "").split():
            if n not in names:
                errs.append("%s: needs %s, which is not a playbook" % (os.path.relpath(b["path"], ROOT), n))
    return errs


def fname(name):
    """A playbook's name as a shell function prefix: hyphens are not allowed there."""
    return name.replace("-", "_").replace(".", "_").replace("+", "_")


def shell_names(body):
    """Functions and variables defined at column 0, outside heredoc bodies."""
    names, end = [], None
    for l in body.split("\n"):
        if end is not None:
            if l.strip() == end:
                end = None
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)(\(\) \{|=)", l)
        if m:
            names.append(m.group(1))
        h = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", l)
        if h and "<<<" not in l:
            end = h.group(1)
    return names


def q(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")


def generate(books):
    rows = []
    for b in books:
        if b["proj"].get("origin") == "catalogue":
            continue
        for g in b["progs"]:
            rows.append("|".join(g[k] for k in ("shelf", "label", "install", "program", "mode", "gate", "about", "home")))
    rows.sort(key=lambda r: (r.split("|")[0], r.split("|")[1].lower()))
    table = ["store_table() {", "    cat <<'STORETABLE'"] + rows + ["STORETABLE", "}"]

    src = [b for b in books if b["body"] and b["proj"].get("origin") != "catalogue"]
    code = []
    for b in sorted(src, key=lambda b: b["proj"]["playbook"]):
        n, p = b["proj"]["playbook"], b["proj"]
        code += ["", "# ---- " + os.path.relpath(b["path"], ROOT), b["body"],
                 '%s_bdeps() { echo "%s"; }' % (n, q(p.get("build", ""))),
                 '%s_rdeps() { echo "%s"; }' % (n, q(p.get("runs", ""))),
                 '%s_needs() { echo "%s"; }' % (n, q(p.get("needs", ""))),
                 '%s_source() { echo "%s"; }' % (n, q(p.get("source", "")))]
    code += ["", 'RECIPES="%s"' % " ".join(sorted(b["proj"]["playbook"] for b in src)), ""]
    code += ["# The bundles: named lists of program ids (playbooks/bundles/NAME.list).",
             "store_bundle() {", '    case "$1" in']
    for name, members in bundles().items():
        code.append('        %s) echo "%s" ;;' % (name, " ".join(members)))
    code += ['        *) return 1 ;;', "    esac", "}",
             "store_bundles() { echo \"%s\"; }" % " ".join(bundles())]
    cats = [b for b in books if b["proj"].get("origin") == "catalogue"]
    code += ["", "# The catalogue's graphical programs: id|about|home, for Copal Apps (rows()).",
             "catalogue_abouts() {", "    cat <<'CATABOUTS'"]
    for b in sorted(cats, key=lambda b: b["proj"]["playbook"]):
        for g in b["progs"]:
            code.append("%s|%s|%s" % (g["program"], g["about"], g.get("home", "")))
    code += ["CATABOUTS", "}"]
    return table, code


def catalogue_rows(books, prep):
    """The catalogue with every graphical row rewritten from its playbook, in place."""
    cats = {g["program"]: g for b in books if b["proj"].get("origin") == "catalogue" for g in b["progs"]}
    a = prep.index("    cat <<'CATALOGUE'\n") + len("    cat <<'CATALOGUE'\n")
    z = prep.index("\nCATALOGUE\n", a)
    lines = prep[a:z].split("\n")
    out, seen, errs = [], set(), []
    for l in lines:
        f = l.split("|")
        if len(f) == 6 and f[4] == "x":
            g = cats.get(f[3])
            if g is None:
                errs.append("copal-prep.sh catalogue: %s is graphical and has no playbook" % f[3]); out.append(l); continue
            seen.add(f[3])
            l = "|".join(g[k] for k in ("shelf", "label", "install", "program", "mode", "gate"))
        out.append(l)
    for pid, g in cats.items():            # new programs: after their section's last row
        if pid in seen:
            continue
        row = "|".join(g[k] for k in ("shelf", "label", "install", "program", "mode", "gate"))
        at = max([i for i, l in enumerate(out) if l.split("|")[0] == g["shelf"]] or [len(out) - 1])
        out.insert(at + 1, row)
    return prep[:a] + "\n".join(out) + prep[z:], errs


def catalogue_posts(books):
    cats = [b for b in books if b["proj"].get("origin") == "catalogue" and b["body"]]
    code = []
    for b in sorted(cats, key=lambda b: b["proj"]["playbook"]):
        code += ["# ---- " + os.path.relpath(b["path"], ROOT), b["body"], ""]
    code += ["# Each graphical program's postconfiguration, when it is installed.",
             "catalogue_posts() {"]
    for b in sorted(cats, key=lambda b: b["proj"]["playbook"]):
        g = b["progs"][0]
        code.append("    if command -v %s >/dev/null 2>&1; then %s_post; fi" % (g["program"], fname(b["proj"]["playbook"])))
    code += ["    return 0", "}"]
    return code


def wrap(key, value, width=100):
    """'# key:     value', continued under itself; never split inside a word,
    and never at a hyphen, so package names stay whole."""
    import textwrap
    head = "# %-9s " % (key + ":")
    if not value:
        return [head.rstrip()]
    body = textwrap.wrap(value, width - len(head), break_on_hyphens=False, break_long_words=False) or [""]
    return [head + body[0]] + ["#" + " " * (len(head) - 1) + x for x in body[1:]]


def fmt(b):
    out = []
    for k in PROJECT_KEYS:
        if k in b["proj"] or k in ("playbook", "source"):
            out += wrap(k, b["proj"].get(k, ""))
    for g in b["progs"]:
        out.append("#")
        for k in PROGRAM_KEYS:
            out += wrap(k, g.get(k, ""))
    return "\n".join(out) + "\n" + ("\n" + b["body"] + "\n" if b["body"] else "")


BEGIN, END = "# >>> playbooks: %s -- generated from playbooks/ by 'make sync-playbooks'; edit those, not this", "# <<< playbooks: %s"


def splice(text, part, new):
    b, e = BEGIN % part, END % part
    i, j = text.find(b), text.find(e)
    if i < 0 or j < 0:
        raise Bad("tools/copal-store has no '%s' markers" % part)
    return text[:i] + b + "\n" + "\n".join(new) + "\n" + text[j:]


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    try:
        books = load()
    except Bad as e:
        print("error: " + str(e)); return 1
    errs = validate(books)
    if cmd == "fmt":
        n = 0
        for b in books:
            new = fmt(b)
            if new != open(b["path"]).read():
                open(b["path"], "w").write(new); n += 1
        print("  ok      playbooks: %d headers rewritten" % n)
        return 0
    if cmd == "list":
        for b in books:
            print("%-12s %-22s %-40s %s" % (b["progs"][0]["shelf"] if b["progs"] else "?", b["proj"].get("playbook"),
                                            b["proj"].get("source", "")[:40], " ".join(g["program"] for g in b["progs"])))
        return 0
    if errs:
        for e in errs:
            print("error: " + e)
        return 1
    table, code = generate(books)
    text = open(STORE).read()
    new = splice(splice(text, "table", table), "recipes", code)
    prep = open(PREP).read()
    newprep, cerrs = catalogue_rows(books, prep)
    newprep = splice(newprep, "catalogue-post", catalogue_posts(books))
    if cerrs:
        for e in cerrs:
            print("error: " + e)
        return 1
    one = sum(1 for b in books for g in b["progs"] if len(re.findall(r"[.!?](\s|$)", g["about"])) < 2)
    if cmd == "sync":
        if new != text:
            open(STORE, "w").write(new)
        if newprep != prep:
            open(PREP, "w").write(newprep)
        print("  ok      playbooks: %d (%d programs) -> tools/copal-store" % (len(books), sum(len(b["progs"]) for b in books)))
        return 0
    if new != text:
        print("error: tools/copal-store differs from playbooks/ -- run: make sync-playbooks"); return 1
    if newprep != prep:
        print("error: copal-prep.sh's catalogue differs from playbooks/ -- run: make sync-playbooks"); return 1
    print("  ok      playbooks: %d, %d programs, headers and names valid, tools/copal-store in step" % (
        len(books), sum(len(b["progs"]) for b in books)))
    if one:
        print("  note    playbooks: %d descriptions are not yet two sentences" % one)
    return 0


if __name__ == "__main__":
    sys.exit(main())
