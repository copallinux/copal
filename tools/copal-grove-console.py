#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
"""copal-grove-console -- the wall.  Milestone 4, W7.

THE ACCEPTANCE TEST FOR THE WHOLE MILESTONE IS AN ARCHITECTURAL ONE, and it is
this: the TUI calls `copal grove`, never the network.  §12 of the plan says the
console is three faces on one read model and that anything the wall can do,
`copal grove` can do, because the wall calls it.  So this program opens no
socket, holds no credential and knows no subject names.  It runs

    copal grove state --json

for its picture, and `copal grove scene|run|power|logs|notify` for its verbs.
Every screen here is a rendering of a command a person could have typed, and if
that ever stops being true the console has become the thing the grove depends
on -- which is the failure this milestone was most likely to produce.

RENDERING IS A PURE FUNCTION.  `frame()` turns a state document into a list of
styled lines; curses paints them and `--once` prints them with ANSI.  That is
what lets the wall be tested and screenshotted without a terminal, and it is
why the layout code has no curses calls in it.

Thumbnails are W5 and are not here.  Per D4 the default tier is half-block
Unicode with 256 colour, so where a thumbnail will go each tile draws the one
continuous quantity the grove already publishes -- temperature -- as a bar.
That is a real reading rather than a placeholder pretending to be a picture.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

# Style tokens.  The renderer emits these; curses and ANSI each map them.
FG, DIM, UP, WARN, DOWN, ALARM, HEAD, SEL, KEY = (
    "fg", "dim", "up", "warn", "down", "alarm", "head", "sel", "key")

ANSI = {FG: "\033[0m", DIM: "\033[2m", UP: "\033[32m", WARN: "\033[33m",
        DOWN: "\033[2m", ALARM: "\033[31m", HEAD: "\033[1m",
        SEL: "\033[7m", KEY: "\033[36m"}

GLYPH = {"up": ("●", UP), "announced": ("◐", WARN), "missing": ("○", DOWN)}

TILE_W, TILE_H = 25, 7

# The verbs, and the honest truth about each. A menu that lies about what it
# can do is worse than one that is honest and short.
VERBS = [
    ("S", "Scene",   "live"),
    ("r", "Run",     "live"),
    ("p", "Power",   "live"),
    ("k", "Snapshot", "live"),
    ("n", "Notify",  "live"),
    ("L", "Log",     "live"),
    ("c", "Control", "L6"),
    ("o", "Observe", "L6"),
    ("e", "Exchange", "L6"),
    ("s", "Send",    "L6"),
    ("m", "Message", "L6"),
]
LIVE = {k for k, _n, s in VERBS if s == "live"}
L6 = {k: n for k, n, s in VERBS if s == "L6"}

TOAST_S = 5.0          # W9: how long "nothing to do" stays in the corner
SEAT_PANEL_W = 32      # W8: the facts panel, right of where a screen would go


# ------------------------------------------------------- W9, notifications ---
#
# THREE SEVERITIES, AND WHAT SEPARATES THEM IS WHAT THE OPERATOR MUST DO --
# not how bad it sounds, and not the exit code.
#
#   toast  something changed and there is nothing to do. The corner for five
#          seconds, then it falls into the event log.
#   chip   a node needs attention. Its tile turns amber and STAYS: a colour
#          that clears itself is a colour nobody learns to trust.
#   alarm  the room is not in the state the scene says it is. A bar across the
#          top that does not leave until it is acknowledged.
#
# THE SEVERITY IS DECIDED FROM THE STATE DOCUMENT, not by reading a verb's
# prose for the word "failed". A node that never announced cannot have taken a
# scene, and that is a fact the console already holds; parsing English would be
# a second read model, which is the thing §12 forbids.

class Notice:
    def __init__(self, sev, text, node=None, at=None):
        self.sev, self.text, self.node = sev, text, node
        self.at = time.time() if at is None else at
        self.acked = False

    def fresh(self, now=None):
        return (time.time() if now is None else now) - self.at < TOAST_S

    def __repr__(self):                                   # for a failed assert
        return "Notice(%s, %r, %s)" % (self.sev, self.text, self.node)


def notices_for(verb, targets, code, text, nodes, at=None):
    """What a verb's result means, as notices.

    W9's acceptance test is here: applying a scene while a node is unreachable
    is an ALARM and not a toast, and it NAMES THE NODE -- because "something is
    wrong" is not an instruction and an operator cannot act on it.
    """
    by = {n["id"]: n for n in nodes}
    gone = [t for t in targets if by.get(t, {}).get("status") == "missing"]
    silent = [t for t in targets
              if by.get(t, {}).get("status") != "missing"
              and by.get(t, {}).get("agent") == "silent"]
    out = []
    if gone:
        out.append(Notice("alarm", "%s: %s did not take it -- not announced"
                          % (verb, ", ".join(gone)), gone[0], at))
    for nid in silent:
        out.append(Notice("chip", "%s: %s is announced but not on the bus"
                          % (verb, nid), nid, at))
    if not out:
        if code == 0:
            out.append(Notice("toast", "%s: done on %d node(s)"
                              % (verb, len(targets)), None, at))
        else:
            # No node to pin it to and it did not work: the room may not be in
            # the state the scene claims, which is the definition of an alarm.
            out.append(Notice("alarm", "%s: failed -- %s"
                              % (verb, (text or "no output").splitlines()[0][:60]),
                              None, at))
    return out


# ------------------------------------------------------------ the picture ---

def read_state(grove_cmd, grove, timeout=45):
    """`copal grove state --json`, and nothing else.  Never the network."""
    argv = list(grove_cmd) + ["state", "--json"]
    if grove:
        argv += ["--grove", grove]
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as exc:
        return None, str(exc)
    if out.returncode != 0:
        return None, (out.stderr or out.stdout).strip().splitlines()[:1] or ["failed"]
    try:
        return json.loads(out.stdout), None
    except ValueError:
        return None, "state did not return JSON"


def run_verb(grove_cmd, grove, args, timeout=180):
    argv = list(grove_cmd) + list(args)
    if grove:
        argv += ["--grove", grove]
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as exc:
        return 1, str(exc)
    return out.returncode, (out.stdout + out.stderr).strip()


def parse_facts(text):
    """`copal grove run facts` -- key, tab, value, one reading per line.

    A key this console does not know is kept and ignored, which is the same
    contract the beacon has: a node that learned a field must not break a
    console written before it, and a console must not invent one the node did
    not send.
    """
    out = {}
    for ln in (text or "").splitlines():
        if "\t" not in ln:
            continue
        k, v = ln.split("\t", 1)
        k, v = k.strip(), v.strip()
        if k:
            out[k] = v
    return out


# --------------------------------------------------------------- the tile ---

def bar(value, lo, hi, width, on=WARN):
    """Half-block bar -- D4's default tier, and the only drawing this does."""
    if value is None:
        # THE SAME WIDTH AS A DRAWN BAR. A placeholder that is shorter than the
        # thing it stands in for shifts every tile to its right, which is how
        # this was found -- one node with no temperature bent the whole row.
        return [(" no reading".ljust(width + 2)[:width + 2], DIM)]
    span = max(hi - lo, 1)
    filled = int(round(max(0.0, min(1.0, (value - lo) / span)) * width))
    colour = UP if value < lo + span * 0.55 else (WARN if value < lo + span * 0.8 else ALARM)
    return [("▐" + "█" * filled, colour), ("░" * (width - filled) + "▌", DIM)]


def tile(node, selected, cursor, width=TILE_W, chip=False):
    """One node, as TILE_H rows of [(text, style)].

    `chip` is W9's middle severity: the tile turns amber and stays that way.
    It recolours cells that are already there and adds no character, because a
    marker that widened a tile would shift every tile to its right -- which is
    exactly the bug the TILE_W assertions exist to catch.
    """
    glyph, gstyle = GLYPH.get(node["status"], ("○", DOWN))
    if chip:
        gstyle = ALARM
    inner = width - 2
    mark = "▸" if cursor else " "
    name = node["id"][:inner - 4]
    rows = [
        [(mark, KEY if cursor else DIM), (" ", FG), (glyph, gstyle), (" ", FG),
         (name.ljust(inner - 4),
          SEL if selected else (WARN if chip else HEAD)),
         ("W" if node["role"] == "warden" else " ", KEY if node["role"] == "warden" else DIM)],
        [("  ┌" + "─" * (inner - 2) + "┐", DIM)],
    ]
    if node["status"] == "missing":
        body = [[("  │ ", DIM), ("not announced".ljust(inner - 3), DOWN), ("│", DIM)],
                [("  │ ", DIM), ("".ljust(inner - 3), FG), ("│", DIM)]]
    else:
        scene = (node.get("scene") or "-")[:inner - 4]
        body = [[("  │ ", DIM), (scene.ljust(inner - 3), FG), ("│", DIM)],
                [("  │ ", DIM)] + bar(node.get("temp_c"), 30, 75, inner - 6)
                + [(" ", FG), ("│", DIM)]]
    rows += body
    rows.append([("  └" + "─" * (inner - 2) + "┘", DIM)])

    temp = "%d°C" % node["temp_c"] if node.get("temp_c") is not None else "  -"
    if node.get("agent") == "up":
        agent, astyle = "agent %ds" % (node.get("heard_s") or 0), UP
    elif node.get("agent") == "silent":
        agent, astyle = "agent silent", WARN
    elif node.get("agent") == "absent":
        agent, astyle = "", DIM
    else:
        agent, astyle = "no bus", DIM
    rows.append([("  ", FG), (temp.ljust(6), FG), (agent.ljust(inner - 8), astyle)])
    return rows


def join_row(tiles, width):
    """Lay tiles side by side into TILE_H lines."""
    out = []
    for r in range(TILE_H):
        line = []
        for t in tiles:
            line.extend(t[r] if r < len(t) else [("", FG)])
            used = sum(len(x) for x, _ in (t[r] if r < len(t) else []))
            if used < TILE_W:
                line.append((" " * (TILE_W - used), FG))
        out.append(line)
    return out


# -------------------------------------------------------------- the frame ---

def frame(doc, sel, cursor, width, height, overlay=None, err=None,
          seat=None, notices=(), now=None):
    """The whole screen, as [[(text, style)]].  No curses, no I/O."""
    # W8: the seat is a screen and not a modal -- it replaces the wall rather
    # than floating over it, because it is a place you go rather than a thing
    # that interrupts you. Esc is still the only way back, and it always is.
    if seat:
        return seat_frame(seat, width, height)

    lines = []
    nodes = doc["nodes"] if doc else []
    counts = doc["counts"] if doc else {}
    grove = doc["grove"] if doc else "?"

    up = counts.get("announced", 0)
    declared = max(counts.get("declared", 0), up)
    bus = doc["bus"] if doc else {"reachable": False, "why": "no state"}

    # W9, ALARM: a bar across the top that does not go away until it is
    # acknowledged. It is drawn first so that it is the thing read first.
    alarms = [n for n in notices if n.sev == "alarm" and not n.acked]
    if alarms:
        lines.append([("  ⚠ ", ALARM), (alarms[0].text[:max(10, width - 30)], ALARM),
                      ("   ", FG), ("[!]", KEY), (" acknowledge", DIM)])
        if len(alarms) > 1:
            lines.append([("    and %d more -- " % (len(alarms) - 1), ALARM),
                          ("E", KEY), (" for the event log", DIM)])

    header = [
        ("  COPAL GROVE · ", HEAD), (grove, KEY),
        ("   %d of %d up" % (up, declared), HEAD),
        ("   ", FG),
        # See the note in copal-grove-view: "bus off" does not tell an operator
        # that the tiles are beacons now rather than agents. This does.
        ("bus on" if bus.get("reachable")
         else "bus off -- polled, not live (%s)" % (bus.get("why") or "?"),
         UP if bus.get("reachable") else WARN),
        ("   ⌂ wall", DIM),
    ]
    # W9, TOAST: something changed and there is nothing to do. The corner for
    # five seconds, and then it is only in the event log.
    toasts = [n for n in notices if n.sev == "toast" and n.fresh(now)]
    if toasts:
        header.append(("   " + toasts[-1].text, KEY))
    lines.append(header)

    # THE SCENE, PER NODE AND NEVER AS A GLOBAL BOOLEAN. Six machines got the
    # memo is the normal case and the header has to be able to say so.
    scenes = (doc or {}).get("scenes") or {}
    if scenes:
        parts = [("  scene  ", DIM)]
        for name, ids in sorted(scenes.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            parts += [(name, HEAD), (" %d" % len(ids), FG), ("   ", FG)]
        mins = [n.get("scene_min") for n in nodes if n.get("scene_min") is not None]
        if mins:
            parts.append(("since %dm" % max(mins), DIM))
        warden = (doc or {}).get("warden")
        if warden:
            parts.append(("     warden %s" % warden, DIM))
        lines.append(parts)
    lines.append([("", FG)])

    # W9, CHIP: the tile turns amber and stays. Derived from the notices rather
    # than from the state, because a chip records that SOMETHING HAPPENED to
    # this node -- it is not the same fact as the node being unhealthy now.
    chipped = {n.node for n in notices
               if n.node and not n.acked and n.sev in ("chip", "alarm")}

    per_row = max(1, (width - 2) // TILE_W)
    for i in range(0, len(nodes), per_row):
        chunk = nodes[i:i + per_row]
        tiles = [tile(n, n["id"] in sel, (i + j) == cursor,
                      chip=n["id"] in chipped)
                 for j, n in enumerate(chunk)]
        lines.extend(join_row(tiles, width))

    strangers = (doc or {}).get("strangers") or []
    if strangers:
        names = "  ".join("%s (%s)" % (x["address"], x["id"]) for x in strangers[:3])
        lines.append([("  ! ", ALARM), ("%d stranger(s) on this network: %s"
                                        % (len(strangers), names), FG)])
        lines.append([("    seen, never contacted", DIM)])

    silent = [n["id"] for n in nodes if n.get("agent") == "silent"]
    if silent:
        lines.append([("  ! ", WARN), ("announced but not on the bus: %s"
                                       % " ".join(silent), FG)])

    if err:
        lines.append([("  ! ", ALARM), (str(err)[:width - 6], ALARM)])

    # THE VERB BAR IS TWO LINES, and the split is the honest one rather than a
    # way of fitting: what works, then what does not. Eleven verbs on one line
    # overflowed 80 columns, and a wall that wraps is a wall that scrolls --
    # which is the one thing a wall is for not doing.
    lines.append([("", FG)])
    lines.append([("  ", FG),
                  ("%d selected" % len(sel) if sel else "none selected",
                   HEAD if sel else DIM)])
    live_line = [("  ", FG)]
    for key, name, state in VERBS:
        if state != "live":
            continue
        live_line += [("[", DIM), (key, KEY), ("]", DIM), (name + " ", FG)]
    lines.append(live_line)
    l6_line = [("  ", FG)]
    for key, name, state in VERBS:
        if state == "live":
            continue
        l6_line += [("[", DIM), (key, DIM), ("]", DIM), (name + " ", DIM)]
    l6_line.append(("-- L6, not built", DIM))
    lines.append(l6_line)
    lines.append([("  ", FG), ("space", KEY), (" select  ", DIM), ("a", KEY),
                  (" all  ", DIM), ("A", KEY), (" none  ", DIM),
                  ("Enter", KEY), (" seat  ", DIM), ("E", KEY), (" events  ", DIM),
                  ("?", KEY), (" help  ", DIM), ("q", KEY), (" quit  ", DIM),
                  ("Esc", KEY), (" back to the wall", DIM)])

    if overlay:
        lines = overlay_over(lines, overlay, width, height)
    return [clip(ln, width) for ln in lines[:height]]


def clip(line, width):
    """No line may exceed the width it was given.  Enforced here rather than
    trusted to every caller, because the one that overflowed was a verb bar
    somebody would go on adding verbs to."""
    out, used = [], 0
    for text, style in line:
        if used >= width:
            break
        out.append((text[:width - used], style))
        used += len(text)
    return out


def overlay_over(lines, overlay, width, height):
    """A modal, drawn under the wall it interrupts.  Esc closes it, always."""
    out = list(lines[:2])
    out.append([("", FG)])
    title, body = overlay["title"], overlay["body"]
    out.append([("  ┌─ ", DIM), (title, HEAD),
                (" " + "─" * max(0, min(width, 78) - len(title) - 7), DIM), ("┐", DIM)])
    for row in body:
        out.append([("  │ ", DIM)] + row)
    out.append([("  └" + "─" * max(0, min(width, 78) - 4) + "┘", DIM)])
    out.append([("", FG)])
    out.append([("  ", FG), ("Esc", KEY), (" back to the wall -- it never asks", DIM)])
    return out


# ------------------------------------------------------------- the overlays --

def help_overlay():
    body = [[("The wall is the home. Esc returns to it from anywhere, and", FG)],
            [("never asks: the operator cannot get stuck inside a machine.", FG)],
            [("", FG)]]
    for key, name, state in VERBS:
        note = "" if state == "live" else "  -- L6, not built"
        body.append([("  ", FG), (key, KEY), ("  %-9s" % name, FG),
                     (note, DIM)])
    body += [[("", FG)],
             [("Every screen here is a rendering of a command you could", DIM)],
             [("have typed. The wall calls `copal grove`, never the network.", DIM)]]
    return {"title": "keys", "body": body}


def refusal_overlay(name, count):
    """Control on a multi-selection is refused, and the refusal is IMPLEMENTED
    rather than merely documented."""
    return {"title": "%s on %d nodes -- refused" % (name, count), "body": [
        [("Broadcasting keystrokes to %d machines is a way to reach %d" % (count, count), FG)],
        [("different broken states with one gesture. It is refused here on", FG)],
        [("purpose, and it is not a missing feature.", FG)],
        [("", FG)],
        [("What you want is ", FG), ("Scene", KEY), (" -- declarative, and it reports", FG)],
        [("per node -- or ", FG), ("Run", KEY), (", which gives you a result column.", FG)],
        [("", FG)],
        [("Select one node and %s works." % name, DIM)],
    ]}


def l6_overlay(name):
    return {"title": name, "body": [
        [(name + " is layer 6, and it is not built.", FG)],
        [("", FG)],
        [("VNC, screen sharing and input forwarding are a milestone of", FG)],
        [("their own. This menu says so rather than pretending: a menu", FG)],
        [("that lies about what it can do is worse than a short one.", FG)],
        [("", FG)],
        [("What M4 delivers instead is the wall you are looking at,", DIM)],
        [("which is one-way and low-rate by design.", DIM)],
    ]}


def human_uptime(minutes):
    if minutes is None:
        return "not reported"
    d, rem = divmod(int(minutes), 1440)
    h, m = divmod(rem, 60)
    return ("%dd %02dh" % (d, h)) if d else ("%dh %02dm" % (h, m) if h else "%dm" % m)


def seat_rows(node, facts):
    """The panel from the lab report §IV-B, as (label, value, style).

    THREE KINDS OF ABSENCE, KEPT APART. `not reported` means this console asked
    and the node said nothing -- an old node, or a failed call. `n/a` means the
    node answered that its board has no such interface. `not collected` means
    nothing in Copal produces the reading yet. Collapsing them into a blank row
    would tell an operator that a value is zero when it is unknown, and W10's
    rule is that a fallback must never be silent.
    """
    def g(key, fallback=None):
        v = facts.get(key)
        if v not in (None, ""):
            return v
        if fallback not in (None, ""):
            return str(fallback)
        return "not reported"

    def style_for(v):
        low = v.lower()
        if low.startswith("not collected"):
            return DIM          # nothing in Copal produces it yet
        if low.startswith("not reported") or low.startswith("unknown"):
            return WARN         # we asked and got nothing: that is a fault
        return FG

    up = human_uptime(node.get("uptime_min"))
    warden = "yes" if node.get("role") == "warden" else "no"
    glyph, gstyle = GLYPH.get(node.get("status"), ("○", DOWN))
    rows = [("", "%s %s · warden %s" % (glyph, up, warden), gstyle)]

    temp = g("temp_c", node.get("temp_c"))
    if temp not in ("not reported", "?"):
        temp = "%s°C" % temp
    elif temp == "?":
        temp = "no sensor"

    for label, value in (
            ("build",  g("build", node.get("build"))),
            ("alpine", "%s %s" % (g("alpine"), g("arch", node.get("arch")))),
            ("ram",    "%s MB · zram %s" % (g("ram_mb", node.get("ram_mb")),
                                            g("zram_pct"))),
            ("temp",   "%s · throttle %s" % (temp, g("throttled"))),
            ("card",   "%s%% used" % g("card_pct")
                       if g("card_pct").isdigit() else g("card_pct")),
            ("cert",   "%s days" % g("cert_days")
                       if g("cert_days").lstrip("-").isdigit() else g("cert_days")),
            ("mounts", g("mounts")),
            ("scene",  "%s · %sm" % (g("scene", node.get("scene")),
                                     g("scene_min", node.get("scene_min")))),
            ("job",    g("job")),
            ("apk",    "%s pending" % g("apk_pending")
                       if g("apk_pending").isdigit() else g("apk_pending")),
    ):
        rows.append((label, value, style_for(value)))
    return rows


def seat_frame(seat, width, height):
    """W8. One node, full size: the facts panel, and the log beside it.

    NO LIVE SCREEN. Observe and Control are layer 6 and are not built, and the
    space where a screen would go says exactly that rather than being left
    blank or filled with something that looks like one.

    THE LOG COMES FROM THE WARDEN'S COLLECTOR, which is what makes W8's real
    requirement work: A DEAD NODE STILL HAS A SEAT. The node is unreachable and
    its last hours are still readable, because they were never on it.
    """
    node = seat["node"]
    inner = max(40, min(width, 110)) - 4
    lines = []

    title = "%s ── the seat" % node["id"]
    if node.get("status") == "missing":
        title += " ── not announced"
    lines.append([("  ┌─ ", DIM), (title, HEAD),
                  (" " + "─" * max(0, inner - len(title) - 3), DIM), ("┐", DIM)])

    if seat.get("view") == "log":
        filt = seat.get("filter") or ""
        head = "log · from the warden's collector"
        if filt:
            head += " · filter %r" % filt
        lines.append([("  │ ", DIM), (head.ljust(inner - 1)[:inner - 1], KEY), ("│", DIM)])
        if node.get("status") == "missing":
            lines.append([("  │ ", DIM),
                          ("this node is gone and still has a seat -- these "
                           "lines are on the warden".ljust(inner - 1)[:inner - 1], DIM),
                          ("│", DIM)])
        body = seat.get("logs")
        if body is None:
            rows = ["(not read yet)"]
        elif seat.get("logs_err"):
            rows = ["could not read the collector:", seat["logs_err"]]
        else:
            rows = [ln for ln in body.splitlines() if not filt or filt in ln]
            if not rows:
                rows = ["no line matches %r" % filt] if filt else ["(the collector returned nothing)"]
        for ln in rows[-(max(4, height - 12)):]:
            lines.append([("  │ ", DIM), (ln.ljust(inner - 1)[:inner - 1], FG), ("│", DIM)])
    else:
        panel = seat_rows(node, seat.get("facts") or {})
        left_w = max(18, inner - SEAT_PANEL_W - 1)
        # WHERE THE SCREEN WILL GO, W7'S RULE APPLIED AGAIN: the tile put a
        # real temperature reading in the thumbnail's place rather than a
        # placeholder pretending to be a picture, and this puts the node's own
        # log in the screen's place for the same reason. Sixty columns of empty
        # box would imply a screen is coming in a way a reading does not.
        left = ["no live screen -- Observe and Control are layer 6,",
                "not built. The log until then:", ""]
        if seat.get("logs_err"):
            left.append("the collector: " + seat["logs_err"])
        elif seat.get("logs") is None:
            left.append("(the log has not been read yet -- press L)")
        else:
            tail = [ln for ln in seat["logs"].splitlines() if ln.strip()]
            left += tail[-(max(3, len(panel) - 4)):] or ["(the collector had nothing for this node)"]
        if seat.get("facts_err"):
            left += ["", "facts: " + seat["facts_err"]]
        left = [ln[:left_w - 2] for ln in left]
        for i in range(max(len(left), len(panel))):
            l = left[i] if i < len(left) else ""
            cell = [("  │ ", DIM), (l.ljust(left_w - 2)[:left_w - 2], DIM),
                    (" │ ", DIM)]
            if i < len(panel):
                label, value, style = panel[i]
                txt = ("%-7s %s" % (label, value)) if label else value
                cell.append((txt.ljust(SEAT_PANEL_W - 2)[:SEAT_PANEL_W - 2], style))
            else:
                cell.append((" " * (SEAT_PANEL_W - 2), FG))
            cell.append(("│", DIM))
            lines.append(cell)

    lines.append([("  └" + "─" * max(0, inner - 1) + "┘", DIM)])
    lines.append([("", FG)])
    if seat.get("typing"):
        lines.append([("  filter: ", KEY), (seat.get("filter") or "", HEAD),
                      ("▏", KEY), ("   Enter to apply", DIM)])
    else:
        lines.append([("  ", FG), ("L", KEY), (" log/facts  ", DIM),
                      ("/", KEY), (" filter  ", DIM), ("E", KEY), (" events  ", DIM),
                      ("Esc", KEY), (" back to the wall -- it never asks", DIM)])
    return [clip(ln, width) for ln in lines[:height]]


def events_overlay(notices):
    """W9's event log: the toasts that have fallen out of the corner, and every
    chip and alarm, newest first."""
    if not notices:
        return {"title": "events", "body": [[("nothing has happened yet.", DIM)]]}
    style = {"alarm": ALARM, "chip": WARN, "toast": DIM}
    body = []
    for n in sorted(notices, key=lambda x: -x.at)[:14]:
        stamp = time.strftime("%H:%M:%S", time.localtime(n.at))
        body.append([(stamp + "  ", DIM),
                     ("%-5s " % n.sev, style.get(n.sev, FG)),
                     (n.text[:60], FG),
                     ("  (acknowledged)" if n.acked else "", DIM)])
    return {"title": "events", "body": body}


def result_overlay(title, text, limit=16):
    rows = [[(ln[:76], FG)] for ln in (text or "(no output)").splitlines()[:limit]]
    return {"title": title, "body": rows or [[("(no output)", DIM)]]}


# ------------------------------------------------------------- the driver ---

class Wall:
    """State, and the one place a key becomes an action."""

    def __init__(self, grove_cmd, grove, every=4.0):
        self.grove_cmd, self.grove, self.every = grove_cmd, grove, every
        self.doc, self.err = None, None
        self.sel, self.cursor = set(), 0
        self.overlay = None
        self.seat = None            # W8
        self.notices = []           # W9
        self.last = 0.0
        self.quit = False

    # -- W8, the seat ----------------------------------------------------
    def open_seat(self, nid=None):
        node = None
        for n in self.nodes:
            if n["id"] == (nid or (self.current() or {}).get("id")):
                node = n
        if node is None:
            return
        self.seat = {"node": node, "view": "facts", "filter": "", "typing": False,
                     "facts": None, "facts_err": None,
                     "logs": None, "logs_err": None}
        self.load_facts()
        self.load_logs()

    def load_facts(self):
        nid = self.seat["node"]["id"]
        code, text = run_verb(self.grove_cmd, self.grove,
                              ["run", "facts", "--node", nid], timeout=60)
        if code == 0 and "\t" in (text or ""):
            self.seat["facts"], self.seat["facts_err"] = parse_facts(text), None
        else:
            # A node that cannot be asked still has a seat; the panel says why
            # rather than showing a column of blanks.
            self.seat["facts"] = {}
            self.seat["facts_err"] = (text or "no answer").splitlines()[0][:60]

    def load_logs(self):
        nid = self.seat["node"]["id"]
        code, text = run_verb(self.grove_cmd, self.grove, ["logs", nid], timeout=90)
        self.seat["logs"] = text if code == 0 else ""
        self.seat["logs_err"] = None if code == 0 else (
            (text or "the collector did not answer").splitlines()[0][:60])

    # -- W9 ---------------------------------------------------------------
    def note(self, verb, targets, code, text):
        self.notices.extend(
            notices_for(verb, targets, code, text, self.nodes))
        del self.notices[:-50]

    def ack(self):
        for n in self.notices:
            n.acked = True

    def refresh(self, force=False):
        if not force and time.time() - self.last < self.every:
            return
        doc, err = read_state(self.grove_cmd, self.grove)
        self.last = time.time()
        if doc:
            self.doc, self.err = doc, None
            ids = [n["id"] for n in doc["nodes"]]
            self.sel &= set(ids)
            self.cursor = max(0, min(self.cursor, len(ids) - 1))
        else:
            self.err = err

    @property
    def nodes(self):
        return (self.doc or {}).get("nodes", [])

    def current(self):
        return self.nodes[self.cursor] if 0 <= self.cursor < len(self.nodes) else None

    def targets(self):
        """The selection, or the node under the cursor when nothing is selected."""
        if self.sel:
            return sorted(self.sel)
        node = self.current()
        return [node["id"]] if node else []

    # -- one key ---------------------------------------------------------
    def key(self, ch, per_row=4):
        # ESC IS THE ONE RULE. From anywhere, back to the wall, no question --
        # and "anywhere" now includes the seat and the filter box. It clears
        # every mode at once rather than unwinding them one at a time: an
        # operator pressing Esc wants the wall, not the previous screen.
        if ch in ("\x1b", "ESC"):
            self.overlay = None
            self.seat = None
            return
        if self.overlay:
            # Any key dismisses a result; only Esc is promised, but a modal you
            # cannot leave by pressing something is a modal people fear.
            self.overlay = None
            return

        # -- W8: inside the seat, the keys mean seat things -----------------
        if self.seat:
            if self.seat.get("typing"):
                if ch in ("\n", "\r", "ENTER", "KEY_ENTER"):
                    self.seat["typing"] = False
                elif ch in ("KEY_BACKSPACE", "\x7f", "\b"):
                    self.seat["filter"] = self.seat["filter"][:-1]
                elif len(ch) == 1 and ch.isprintable():
                    self.seat["filter"] += ch
                return
            if ch == "L":
                self.seat["view"] = "facts" if self.seat["view"] == "log" else "log"
                if self.seat["view"] == "log" and self.seat["logs"] is None:
                    self.load_logs()
            elif ch == "/":
                self.seat["typing"] = True
                self.seat["view"] = "log"
                if self.seat["logs"] is None:
                    self.load_logs()
            elif ch == "E":
                self.overlay = events_overlay(self.notices)
            elif ch == "!":
                self.ack()
            elif ch == "q":
                self.quit = True
            return

        n = len(self.nodes)
        if ch == "q":
            self.quit = True
        elif ch in ("\n", "\r", "ENTER", "KEY_ENTER") and n:
            self.open_seat()
        elif ch == "E":
            self.overlay = events_overlay(self.notices)
        elif ch == "!":
            self.ack()
        elif ch in ("h", "LEFT") and n:
            self.cursor = (self.cursor - 1) % n
        elif ch in ("l", "RIGHT") and n:
            self.cursor = (self.cursor + 1) % n
        elif ch in ("k", "UP") and n:
            self.cursor = (self.cursor - per_row) % n
        elif ch in ("j", "DOWN") and n:
            self.cursor = (self.cursor + per_row) % n
        elif ch == " " and n:
            nid = self.nodes[self.cursor]["id"]
            self.sel.symmetric_difference_update({nid})
        elif ch == "a":
            self.sel = {x["id"] for x in self.nodes}
        elif ch == "A":
            self.sel = set()
        elif ch == "?":
            self.overlay = help_overlay()
        elif ch in L6:
            # Control on a multi-selection is refused BEFORE the not-built
            # notice, because the refusal is a property of the design and the
            # not-built notice is a property of today.
            if ch == "c" and len(self.targets()) > 1:
                self.overlay = refusal_overlay("Control", len(self.targets()))
            else:
                self.overlay = l6_overlay(L6[ch])
        elif ch in LIVE:
            self.act(ch)

    def act(self, ch):
        who = self.targets()
        if not who and ch != "n":
            self.overlay = result_overlay("nothing selected",
                                          "Select a node with space, or a for all.")
            return
        if ch == "S":
            code, text = run_verb(self.grove_cmd, self.grove, ["scene"])
            self.overlay = result_overlay("scenes -- press S again on a name", text)
            self.note("scene", who, code, text)
        elif ch == "r":
            code, text = run_verb(self.grove_cmd, self.grove,
                                  ["run", "state"] + sum([["--node", w] for w in who], []))
            self.overlay = result_overlay("run state on %d node(s)" % len(who), text)
            self.note("run state", who, code, text)
        elif ch == "p":
            self.overlay = result_overlay(
                "Power on %d node(s)" % len(who),
                "This would run:\n  copal grove run power off\n\n"
                "Confirmation is deliberately not a keystroke away in M4.\n"
                "Type it, and the room turns off with a result per node.")
        elif ch == "k":
            self.overlay = result_overlay(
                "Snapshot restore on %d node(s)" % len(who),
                "This would run:\n  copal grove run snapshot restore\n\n"
                "Seconds rather than the minutes a reimage costs.")
        elif ch == "n":
            code, text = run_verb(self.grove_cmd, self.grove,
                                  ["notify", "--all-up", "--timeout", "20"])
            self.overlay = result_overlay("notify --all-up", text or
                                          ("all up" if code == 0 else "timed out"))
        elif ch == "L":
            code, text = run_verb(self.grove_cmd, self.grove, ["logs", who[0]])
            self.overlay = result_overlay("logs %s" % who[0], text)
            self.note("logs", who[:1], code, text)


def per_row_for(width):
    return max(1, (width - 2) // TILE_W)


# ------------------------------------------------------------------ output ---

def to_ansi(lines):
    out = []
    for line in lines:
        buf = ""
        for text, style in line:
            buf += ANSI.get(style, "") + text + "\033[0m"
        out.append(buf)
    return "\n".join(out)


def curses_main(stdscr, wall):
    import curses
    curses.curs_set(0)
    stdscr.nodelay(True)
    pairs = {}
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        for i, (name, colour) in enumerate([
                (UP, curses.COLOR_GREEN), (WARN, curses.COLOR_YELLOW),
                (ALARM, curses.COLOR_RED), (KEY, curses.COLOR_CYAN)], start=1):
            curses.init_pair(i, colour, -1)
            pairs[name] = curses.color_pair(i)
    attr = {HEAD: curses.A_BOLD, DIM: curses.A_DIM, DOWN: curses.A_DIM,
            SEL: curses.A_REVERSE, FG: 0}
    attr.update(pairs)

    while not wall.quit:
        wall.refresh()
        h, w = stdscr.getmaxyx()
        stdscr.erase()
        for y, line in enumerate(frame(wall.doc, wall.sel, wall.cursor, w, h - 1,
                                       wall.overlay, wall.err,
                                       wall.seat, wall.notices)):
            x = 0
            for text, style in line:
                if x >= w - 1:
                    break
                clipped = text[:max(0, w - 1 - x)]
                try:
                    stdscr.addstr(y, x, clipped, attr.get(style, 0))
                except curses.error:
                    pass
                x += len(clipped)
        stdscr.refresh()
        time.sleep(0.05)
        try:
            ch = stdscr.getkey()
        except Exception:
            continue
        name = {"KEY_LEFT": "LEFT", "KEY_RIGHT": "RIGHT",
                "KEY_UP": "UP", "KEY_DOWN": "DOWN",
                "\n": "ENTER", "\r": "ENTER"}.get(ch, ch)
        wall.key(name, per_row_for(w))
        if name in LIVE or name in L6 or name == "?":
            wall.last = 0.0     # a verb changed something; look again


def main(argv=None):
    ap = argparse.ArgumentParser(description="the Copal grove wall")
    ap.add_argument("--grove", default="")
    ap.add_argument("--grove-cmd", default="copal grove")
    ap.add_argument("--every", type=float, default=4.0)
    ap.add_argument("--once", action="store_true",
                    help="render one frame to stdout and exit")
    ap.add_argument("--keys", default="",
                    help="with --once: keys to apply first, e.g. 'a' or ' j?'")
    ap.add_argument("--width", type=int, default=0)
    ap.add_argument("--height", type=int, default=0)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)

    if args.self_test:
        print("copal-grove-console: %d checks passed" % self_test())
        return 0

    cmd = args.grove_cmd.split()
    wall = Wall(cmd, args.grove, args.every)

    if args.once:
        size = shutil.get_terminal_size((100, 34))
        w = args.width or size.columns
        h = args.height or size.lines
        wall.refresh(force=True)
        for ch in args.keys:
            wall.key(ch, per_row_for(w))
        print(to_ansi(frame(wall.doc, wall.sel, wall.cursor, w, h,
                            wall.overlay, wall.err, wall.seat, wall.notices)))
        return 0

    import curses
    try:
        curses.wrapper(curses_main, wall)
    except KeyboardInterrupt:
        pass
    return 0


# --------------------------------------------------------------- self-test ---

def fake_doc():
    def node(i, status="up", scene="show", temp=47, agent="up", role="node"):
        return {"id": "museum-%02d" % i, "address": "10.0.0.%d" % (10 + i),
                "role": role, "status": status, "scene": scene, "scene_min": 14,
                "build": "2026-09-04.3",
                "temp_c": temp, "agent": agent, "heard_s": 0, "uptime_min": 300,
                "announced": status != "missing", "on_bus": agent == "up",
                "declared": True, "tags": [], "arch": "aarch64"}
    nodes = [node(i) for i in range(1, 6)]
    nodes.append(node(6, scene="wake", temp=39, role="warden"))
    nodes.append(node(7, status="missing", scene="", temp=None, agent="absent"))
    nodes.append(node(8, scene="rest", temp=48, agent="silent"))
    return {"grove": "museum", "at": "2026-09-08T15:00:00", "warden": "museum-06",
            "bus": {"reachable": True, "why": None},
            "counts": {"declared": 8, "announced": 7, "on_bus": 6, "missing": 1},
            "scenes": {"show": ["museum-01"], "wake": ["museum-06"], "rest": ["museum-08"]},
            "strangers": [{"id": "epson-XY10", "address": "10.0.0.44", "grove": None}],
            "nodes": nodes}


def text_of(lines):
    return "\n".join("".join(t for t, _ in ln) for ln in lines)


def self_test():
    checks = 0
    doc = fake_doc()

    # -- the frame ------------------------------------------------------
    lines = frame(doc, set(), 0, 104, 40)
    txt = text_of(lines)
    assert "COPAL GROVE · museum" in txt
    assert "7 of 8 up" in txt
    assert "bus on" in txt
    for i in range(1, 9):
        assert "museum-%02d" % i in txt, i
    assert "not announced" in txt, "a missing node must say so"
    assert "stranger" in txt and "epson-XY10" in txt
    assert "seen, never contacted" in txt
    assert "announced but not on the bus: museum-08" in txt
    checks += 6

    # THE SCENE IS PER NODE AND NEVER A GLOBAL BOOLEAN.
    assert "show" in txt and "wake" in txt and "rest" in txt
    assert "scene  " in txt
    checks += 2

    # No line may exceed the width it was given -- a wall that wraps is a wall
    # that scrolls, and the whole point is that it does not.
    for w in (80, 100, 132):
        for ln in frame(doc, set(), 0, w, 40):
            assert sum(len(t) for t, _ in ln) <= w, (w, text_of([ln]))
    checks += 3

    # The warden is marked, and only the warden.
    assert sum(1 for ln in lines
               for t, st in ln if t == "W" and st == KEY) == 1
    checks += 1

    # The verb bar says which half is real, in the frame and not only in help.
    assert "L6, not built" in txt, "the wall must admit what is not built"
    for w in (72, 80, 100, 132):
        f = text_of(frame(doc, set(), 0, w, 40))
        assert "[S]Scene" in f and "[c]Control" in f, w
    checks += 5

    # -- selection and the cursor ---------------------------------------
    wall = Wall(["true"], "museum")
    wall.doc = doc
    wall.key(" "); assert wall.sel == {"museum-01"}
    wall.key(" "); assert wall.sel == set(), "space must toggle, not only add"
    wall.key("l"); assert wall.cursor == 1
    wall.key("h"); assert wall.cursor == 0
    wall.key("h"); assert wall.cursor == 7, "the cursor wraps"
    wall.key("j", 4); assert wall.cursor == 3
    wall.key("a"); assert len(wall.sel) == 8
    wall.key("A"); assert wall.sel == set()
    checks += 8

    # targets(): the selection, or the node under the cursor.
    wall.cursor = 2
    assert wall.targets() == ["museum-03"]
    wall.sel = {"museum-01", "museum-05"}
    assert wall.targets() == ["museum-01", "museum-05"]
    checks += 2

    # -- CONTROL ON A MULTI-SELECTION IS REFUSED, AND IT IS IMPLEMENTED ---
    wall.sel = {"museum-01", "museum-02"}
    wall.key("c")
    assert wall.overlay is not None, "Control on many did nothing at all"
    body = text_of(wall.overlay["body"]) + wall.overlay["title"]
    assert "refused" in wall.overlay["title"], wall.overlay["title"]
    assert "Scene" in body, "the refusal must name what to do instead"
    assert "not a missing feature" in body
    checks += 4

    # One node, and Control is not refused -- it is honestly not built.
    wall.overlay = None
    wall.sel = {"museum-01"}
    wall.key("c")
    assert wall.overlay and "refused" not in wall.overlay["title"], wall.overlay["title"]
    assert "not built" in text_of(wall.overlay["body"])
    checks += 2

    # -- ESC RETURNS TO THE WALL FROM ANYWHERE, AND NEVER ASKS -----------
    for opener in ("?", "c", "o", "e", "s", "m"):
        wall.overlay = None
        wall.sel = {"museum-01"}
        wall.key(opener)
        assert wall.overlay is not None, opener
        wall.key("\x1b")
        assert wall.overlay is None, "Esc did not return to the wall from %s" % opener
        assert wall.quit is False, "Esc must never quit"
        checks += 1

    # Esc on the bare wall is harmless, and still never quits.
    wall.key("\x1b")
    assert wall.overlay is None and wall.quit is False
    checks += 1

    # -- the menu tells the truth ---------------------------------------
    ov = help_overlay()
    help_text = text_of(ov["body"])
    for _k, name, state in VERBS:
        assert name in help_text, name
        if state == "L6":
            assert "L6, not built" in help_text
    checks += 2

    # -- overlays are drawn, and say how to leave -----------------------
    over = frame(doc, set(), 0, 104, 40, overlay=help_overlay())
    otxt = text_of(over)
    assert "Esc" in otxt and "back to the wall" in otxt
    assert "COPAL GROVE" in otxt, "the header stays; you can see where you are"
    checks += 2

    # EVERY TILE ROW IS EXACTLY TILE_W WIDE, whatever the node is missing.
    # A short row shifts every tile to its right, and the one that did it was a
    # node with no temperature reading.
    for probe in (doc["nodes"][0], doc["nodes"][6], doc["nodes"][7],
                  dict(doc["nodes"][0], temp_c=None),
                  dict(doc["nodes"][0], id="a-very-long-node-name-indeed"),
                  dict(doc["nodes"][0], scene="a-scene-with-a-very-long-name")):
        for row in tile(probe, False, False):
            got = sum(len(t) for t, _ in row)
            assert got <= TILE_W, (probe["id"], got, text_of([row]))
    checks += 6

    # And the rows of a joined row all match, which is what keeps the grid a
    # grid rather than a staircase.
    joined = join_row([tile(doc["nodes"][i], False, False) for i in (0, 4, 6)], 104)
    widths = {sum(len(t) for t, _ in row) for row in joined}
    assert len(widths) == 1, widths
    checks += 1

    # -- the bar is a reading, not a decoration -------------------------
    cold = text_of([bar(31, 30, 75, 10)])
    hot = text_of([bar(74, 30, 75, 10)])
    assert cold.count("█") < hot.count("█"), "the bar does not track the value"
    assert bar(None, 30, 75, 10)[0][0].strip() == "no reading"
    assert text_of([bar(31, 30, 75, 10)]).count("█") + \
        text_of([bar(31, 30, 75, 10)]).count("░") == 10
    checks += 3

    # -- degraded: no bus, and it says so rather than inventing ---------
    dark = json.loads(json.dumps(doc))
    dark["bus"] = {"reachable": False, "why": "timed out"}
    for n in dark["nodes"]:
        n["status"] = "announced" if n["status"] == "up" else n["status"]
        n["temp_c"] = None
        n["agent"] = "unknown"
    dtxt = text_of(frame(dark, set(), 0, 104, 40))
    assert "bus off -- polled, not live" in dtxt, dtxt.splitlines()[0]
    assert "timed out" in dtxt
    assert "no reading" in dtxt, "a missing temperature must read as missing"
    assert "silent" not in dtxt, "with no bus, nothing can be called silent"
    checks += 4

    # ================================================================== W8
    # THE SEAT. One node, full size, and the two things it must do: show the
    # facts the grove already knows, and read a log that is not on the node.

    seat_node = dict(doc["nodes"][2])
    full = {"id": "museum-03", "alpine": "3.24.1", "arch": "aarch64",
            "build": "2026-09-04.3", "ram_mb": "1024", "zram_pct": "42",
            "temp_c": "51", "throttled": "no", "card_pct": "12",
            "cert_days": "87", "scene": "show", "scene_min": "14",
            "apk_pending": "3",
            "mounts": "not collected -- §11 attachments are not wired",
            "job": "not collected -- §10 gem work is not wired"}
    seat = {"node": seat_node, "view": "facts", "filter": "", "typing": False,
            "facts": full, "facts_err": None, "logs": None, "logs_err": None}
    stxt = text_of(seat_frame(seat, 104, 40))
    for want in ("museum-03", "the seat", "build", "2026-09-04.3", "3.24.1",
                 "1024 MB", "zram 42", "51°C", "throttle no", "12% used",
                 "87 days", "show", "3 pending"):
        assert want in stxt, (want, stxt)
    checks += 4

    # NO LIVE SCREEN, and the seat says which milestone it is waiting for
    # rather than leaving the space blank or drawing something screen-shaped.
    assert "no live screen" in stxt
    assert "layer 6" in stxt and "not built" in stxt
    checks += 2

    # THREE KINDS OF ABSENCE, AND THE PANEL KEEPS THEM APART.
    thin = dict(full)
    del thin["alpine"]           # asked, and the node said nothing
    thin["throttled"] = "n/a"    # the node says its board has no such reading
    rows = {lbl: (val, st) for lbl, val, st in seat_rows(seat_node, thin)}
    assert "not reported" in rows["alpine"][0], rows["alpine"]
    assert rows["alpine"][1] == WARN, "a fact we failed to get is a fault"
    assert "n/a" in rows["temp"][0], rows["temp"]
    assert rows["mounts"][0].startswith("not collected"), rows["mounts"]
    assert rows["mounts"][1] == DIM, "not collected is not a fault, it is a gap"
    checks += 5

    # The build comes off the beacon when the node cannot be asked for facts.
    # It was parsed by W6 and dropped by assemble() until W8 went looking, so
    # the fallback is the thing worth asserting rather than the happy path.
    fb = {lbl: val for lbl, val, _st in seat_rows(seat_node, {})}
    assert fb["build"] == "2026-09-04.3", fb["build"]
    assert fb["alpine"].startswith("not reported"), fb["alpine"]
    checks += 2

    # A NODE THAT CANNOT BE ASKED STILL HAS A PANEL, and it says why.
    broken = dict(seat, facts={}, facts_err="museum-03 did not answer")
    btxt = text_of(seat_frame(broken, 104, 40))
    assert "did not answer" in btxt
    assert "not reported" in btxt, "blank rows would read as zero"
    checks += 2

    # A DEAD NODE STILL HAS A SEAT -- the log is on the warden, not on it.
    gone = dict(seat, node=dict(doc["nodes"][6]), view="log",
                logs="09:01 museum-07 scene rest\n09:02 museum-07 went away\n")
    gtxt = text_of(seat_frame(gone, 104, 40))
    assert "not announced" in gtxt, "the seat must say the node is gone"
    assert "still has a seat" in gtxt
    assert "went away" in gtxt, "the collector's lines are readable regardless"
    assert "warden's collector" in gtxt
    checks += 4

    # The filter narrows the log, and says what it filtered by.
    filt = dict(gone, filter="scene")
    ftxt = text_of(seat_frame(filt, 104, 40))
    assert "scene rest" in ftxt and "went away" not in ftxt
    assert "filter" in ftxt
    empty_filter = text_of(seat_frame(dict(gone, filter="zzz"), 104, 40))
    assert "no line matches" in empty_filter, "an empty filter must say so"
    checks += 3

    # The seat obeys the width, in every view.
    for w in (80, 100, 132):
        for view in ("facts", "log"):
            for ln in seat_frame(dict(seat, view=view, logs="x" * 300), w, 40):
                assert sum(len(t) for t, _ in ln) <= w, (w, view, text_of([ln]))
    checks += 3

    # -- ESC STILL RETURNS TO THE WALL, FROM THE SEAT AND FROM THE FILTER ---
    wall = Wall(["true"], "museum")
    wall.doc = doc
    wall.seat = dict(seat)
    wall.key("\x1b")
    assert wall.seat is None, "Esc did not leave the seat"
    assert wall.quit is False, "Esc must never quit"

    wall.seat = dict(seat, typing=True, filter="bu")
    wall.key("\x1b")
    assert wall.seat is None, "Esc in the filter box must still reach the wall"
    assert wall.quit is False
    checks += 2

    # Typing in the filter box types, and does not trigger verbs.
    wall.seat = dict(seat, typing=True, filter="")
    for ch in "bus":
        wall.key(ch)
    assert wall.seat["filter"] == "bus", wall.seat["filter"]
    assert wall.overlay is None, "a keystroke in a text box is not a verb"
    wall.key("KEY_BACKSPACE")
    assert wall.seat["filter"] == "bu"
    wall.key("\n")
    assert wall.seat["typing"] is False, "Enter applies the filter"
    checks += 4

    # ================================================================== W9
    # NOTIFICATIONS. Three severities, told apart by what the operator must do.

    # THE ACCEPTANCE TEST: applying a scene while a node is unreachable is an
    # ALARM and not a toast, and it names the node.
    got = notices_for("scene rest", ["museum-01", "museum-07"], 0, "", doc["nodes"])
    alarm = [n for n in got if n.sev == "alarm"]
    assert alarm, "an unreachable node during a scene must alarm: %r" % got
    assert "museum-07" in alarm[0].text, alarm[0].text
    assert not [n for n in got if n.sev == "toast"], "that is not a toast"
    checks += 3

    # Everything reachable and it worked: a toast, and nothing to do.
    got = notices_for("scene rest", ["museum-01"], 0, "", doc["nodes"])
    assert [n.sev for n in got] == ["toast"], [n.sev for n in got]
    checks += 1

    # Announced but not on the bus is a chip: that node, amber, and it stays.
    got = notices_for("run state", ["museum-08"], 0, "", doc["nodes"])
    assert [n.sev for n in got] == ["chip"], [n.sev for n in got]
    assert got[0].node == "museum-08"
    checks += 2

    # The alarm is a bar across the top, it names the node, and it says how to
    # acknowledge -- an alarm with no way out is a thing people learn to ignore.
    al = Notice("alarm", "scene rest: museum-07 did not take it", "museum-07")
    atxt = text_of(frame(doc, set(), 0, 104, 40, notices=[al]))
    assert "museum-07" in atxt.splitlines()[0], atxt.splitlines()[0]
    assert "acknowledge" in atxt
    al.acked = True
    cleared = text_of(frame(doc, set(), 0, 104, 40, notices=[al]))
    assert "acknowledge" not in cleared, "an acknowledged alarm must leave"
    assert "did not take it" not in cleared.splitlines()[0], \
        "the bar is gone but its text is still at the top"
    checks += 3

    # The chip colours the tile and DOES NOT WIDEN IT.
    chip_rows = tile(doc["nodes"][7], False, False, chip=True)
    plain_rows = tile(doc["nodes"][7], False, False, chip=False)
    assert [sum(len(t) for t, _ in r) for r in chip_rows] == \
           [sum(len(t) for t, _ in r) for r in plain_rows], "a chip changed a width"
    assert any(st == WARN for r in chip_rows for _t, st in r), "the chip is not amber"
    for row in chip_rows:
        assert sum(len(t) for t, _ in row) <= TILE_W
    checks += 3

    # A toast is in the corner for five seconds and then only in the event log.
    fresh = Notice("toast", "scene rest: done on 1 node(s)", None, at=1000.0)
    assert "done on 1" in text_of(frame(doc, set(), 0, 104, 40,
                                        notices=[fresh], now=1002.0))
    assert "done on 1" not in text_of(frame(doc, set(), 0, 104, 40,
                                            notices=[fresh], now=1099.0)), \
        "a toast must not stay in the corner"
    assert "done on 1" in text_of(events_overlay([fresh])["body"]), \
        "but it must still be in the event log"
    checks += 3

    # The event log is newest first, and says nothing has happened when it has not.
    old_n = Notice("toast", "older", None, at=1000.0)
    new_n = Notice("alarm", "newer", None, at=2000.0)
    ev = text_of(events_overlay([old_n, new_n])["body"])
    assert ev.index("newer") < ev.index("older"), ev
    assert "nothing has happened yet" in text_of(events_overlay([])["body"])
    checks += 2

    # E opens the event log from the wall AND from the seat; ! acknowledges.
    wall.seat = None
    wall.notices = [Notice("alarm", "scene rest: museum-07 did not take it",
                           "museum-07")]
    wall.key("E")
    assert wall.overlay and wall.overlay["title"] == "events"
    wall.key("\x1b")
    wall.key("!")
    assert all(n.acked for n in wall.notices), "! did not acknowledge"
    checks += 2

    # Enter opens the seat on the node under the cursor.
    wall.overlay, wall.seat, wall.cursor = None, None, 1
    wall.open_seat()
    assert wall.seat and wall.seat["node"]["id"] == "museum-02", wall.seat
    checks += 1

    # -- and with no state at all, it still draws ------------------------
    empty = text_of(frame(None, set(), 0, 104, 40, err="state did not return JSON"))
    assert "COPAL GROVE" in empty and "state did not return JSON" in empty
    checks += 1

    return checks


if __name__ == "__main__":
    sys.exit(main())
