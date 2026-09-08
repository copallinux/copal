#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
"""copal-degrade-test -- milestone 4, W10.  Every layer removed, on purpose.

Invariant 8 says the console works with every layer above the first taken away.
M4 is where that stops being a claim, and this is the program that stops it.

    tools/copal-degrade-test.py          run it
    tools/copal-degrade-test.py -v       say what each line did

Four lines, from the backlog:

  1. Bus down          the console falls back and SAYS SO -- the operator has
                       to know the wall is polled rather than live
  2. Warden unplugged  the next-highest score takes the role within ~20s and
                       the console follows without a restart
  3. Avahi off         addresses from a written list; everything else the same,
                       because identity never depended on discovery
  4. Console killed    nothing left half-applied that a re-run does not fix

Each line reports PASS, FAIL or NOT PERFORMED, and the last of those is never
counted as a pass.  A line that needs two machines says so rather than being
quietly reworded into one that needs one.

WHAT THIS RUNS IS THE REAL THING.  Line 4 starts an actual `nats-server`, an
actual `copal-grove-agent`, and drives them with the actual client.  The agent
reads its paths from the environment for exactly this reason; the defaults are
the only values a node ever uses.
"""

import argparse
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import copal_nats    # noqa: E402
import copal_nkeys   # noqa: E402

G, R, Y, D, Z = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"
if not sys.stdout.isatty():
    G = R = Y = D = Z = ""

RESULTS = []
VERBOSE = False


def line(n, title):
    print("\n%s%d. %s%s" % (D, n, title, Z))


def ok(what, detail=""):
    RESULTS.append(("PASS", what))
    print("   %s✓%s %s%s" % (G, Z, what, ("  " + D + detail + Z) if detail and VERBOSE else ""))


def bad(what, detail=""):
    RESULTS.append(("FAIL", what))
    print("   %s✗%s %s" % (R, Z, what))
    if detail:
        for ln in str(detail).splitlines()[:6]:
            print("     %s%s%s" % (D, ln, Z))


def skip(what, why):
    RESULTS.append(("SKIP", what))
    print("   %s–%s %s" % (Y, Z, what))
    print("     %s%s%s" % (D, why, Z))


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def node_tool(root):
    """Cut `/usr/bin/copal-grove` out of copal-prep.sh and make it runnable.

    THE NODE TOOL IS NOT A FILE IN THIS REPOSITORY -- it is a heredoc inside
    the installer, which is why W10's first version of this check read it with
    `sed` instead of running it. Extracting it costs four lines and turns a
    checklist item back into a test.
    """
    src = os.path.join(os.path.dirname(HERE), "copal-prep.sh")
    out, keep = [], False
    try:
        with open(src, encoding="utf-8") as fh:
            for ln in fh:
                if ln.rstrip("\n").endswith("<<'COPALGROVE'"):
                    keep = True
                    continue
                if keep and ln.rstrip("\n") == "COPALGROVE":
                    break
                if keep:
                    out.append(ln)
    except OSError:
        return None
    if not out:
        return None
    path = os.path.join(root, "copal-grove")
    with open(path, "w", encoding="utf-8") as fh:
        fh.writelines(out)
    os.chmod(path, 0o755)
    return path


def grove_sh(*args, env=None, timeout=90):
    argv = ["sh", os.path.join(HERE, "copal-grove.sh")] + list(args)
    e = dict(os.environ)
    if env:
        e.update(env)
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=e)
        return out.returncode, out.stdout, out.stderr
    except subprocess.SubprocessError as exc:
        return 1, "", str(exc)


# ---------------------------------------------------------------- fixture ---

def path_without_avahi(root):
    """A bin directory holding a link to every command on PATH but avahi's.

    Deleting PATH would prove nothing; this proves the console does not need
    discovery, which is the actual claim -- identity never depended on it.
    """
    bindir = os.path.join(root, "bin-no-avahi")
    if os.path.isdir(bindir):
        return bindir
    os.makedirs(bindir, exist_ok=True)
    for d in os.environ.get("PATH", "").split(os.pathsep):
        if not d or not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            if name.startswith("avahi"):
                continue
            link = os.path.join(bindir, name)
            if os.path.exists(link):
                continue
            try:
                os.symlink(os.path.join(d, name), link)
            except OSError:
                pass
    return bindir


def write_fixture(root, warden_addr="10.0.0.16"):
    """A grove of eight on paper: beacons, an answers file, a nodes list."""
    beacons = os.path.join(root, "beacons.tsv")
    with open(beacons, "w") as fh:
        for i in (1, 2, 3, 4, 5, 6, 8):
            role = "warden" if i == 6 else "node"
            addr = warden_addr if i == 6 else "10.0.0.%d" % (10 + i)
            fh.write("museum-%02d\t%s\tv=1;g=museum;n=museum-%02d;r=%s;s=%d;"
                     "a=aarch64;m=1024;u=%dm;t=wall;c=show\n"
                     % (i, addr, i, role, 3000 - i, 300 + i))
        fh.write("epson-XY10\t10.0.0.44\tv=1;n=epson-XY10\n")
    answers = os.path.join(root, "answers.txt")
    with open(answers, "w") as fh:
        fh.write('COPAL_GROVE="museum"\nCOPAL_GROVE_SIZE="8"\nCOPAL_USER="user"\n')
    home = os.path.join(root, "copalhome")
    os.makedirs(os.path.join(home, "groves", "museum"), exist_ok=True)
    os.makedirs(os.path.join(home, "ca"), exist_ok=True)
    return beacons, answers, home


# ------------------------------------------------------------------ line 1 ---

def case_bus_down(root, beacons, answers, home):
    line(1, "Bus down -- the console falls back, and says so")
    env = {"COPAL_GROVE_BEACONS": beacons, "COPAL_ANSWERS": answers,
           "COPAL_HOME": home}
    code, out, err = grove_sh("state", "--json", "--grove", "museum", env=env)
    if code != 0:
        return bad("state still answers with no bus", err)
    try:
        doc = json.loads(out)
    except ValueError:
        return bad("state returned JSON with no bus", out[:200])
    ok("state still answers, and it is still JSON")

    if doc["bus"]["reachable"] is False and doc["bus"]["why"]:
        ok("the document says the bus is unreachable, and why",
           doc["bus"]["why"])
    else:
        bad("the document does not admit the bus is down", json.dumps(doc["bus"]))

    if doc["counts"]["announced"] == 7:
        ok("all seven announced nodes are still listed")
    else:
        bad("the node list changed when the bus went away",
            json.dumps(doc["counts"]))

    # NOTHING MAY BE CLAIMED THAT DISCOVERY CANNOT KNOW.
    live = [n["id"] for n in doc["nodes"] if n["status"] == "up"]
    if live:
        bad("nodes were called live with no bus to confirm them", " ".join(live))
    else:
        ok("no node is called live -- they are 'announced', which is all a "
           "beacon can prove")
    silent = [n["id"] for n in doc["nodes"] if n["agent"] == "silent"]
    if silent:
        bad("an agent was called silent with no bus to hear it", " ".join(silent))
    else:
        ok("no agent is called silent -- with no bus that is unknowable")

    code, out, err = grove_sh("console", "--once", "--grove", "museum", env=env)
    if code != 0:
        return bad("the wall would not draw with the bus down", err)
    if "bus off" not in out:
        return bad("the wall does not say the bus is down", out[:200])
    ok("the wall draws, and its header says the bus is off")
    if "polled" in out:
        ok("the wall says the picture is polled rather than live")
    else:
        bad("the wall says the bus is off but not that the picture is now "
            "POLLED rather than live -- the operator has to be told which")


# ------------------------------------------------------------------ line 2 ---

def case_warden_unplugged(root, beacons, answers, home):
    line(2, "Warden unplugged -- the next-highest score takes the role")

    # The console half: does it follow a warden that moved, without a restart?
    moved = os.path.join(root, "beacons-moved.tsv")
    with open(beacons) as fh:
        rows = fh.read().splitlines()
    with open(moved, "w") as fh:
        for r in rows:
            if "museum-06" in r:
                continue                       # the warden is unplugged
            if "museum-01" in r:
                r = r.replace("r=node", "r=warden")   # another has taken it
            fh.write(r + "\n")
    env = {"COPAL_GROVE_BEACONS": moved, "COPAL_ANSWERS": answers,
           "COPAL_HOME": home}
    code, out, _err = grove_sh("state", "--json", "--grove", "museum", env=env)
    if code == 0 and json.loads(out).get("warden") == "10.0.0.11":
        ok("the console follows the warden to a new address, no restart")
    else:
        bad("the console did not follow the warden",
            out[:200] if code == 0 else "state failed")

    # The node half. THIS IS THE ONE W10 EXISTS TO FIND, and until the
    # election was written this was a `sed` over role_now() looking for the
    # word "score" -- which is reading a checklist, not performing one. It now
    # RUNS the election out of copal-prep.sh over a directory of fixtures.
    tool = node_tool(root)
    if not tool:
        bad("the node tool could not be extracted from copal-prep.sh",
            "the `cat > /usr/bin/copal-grove <<COPALGROVE` heredoc moved or "
            "was renamed")
        return

    me = subprocess.run(["hostname"], capture_output=True,
                        text=True).stdout.strip()

    def elect(peers, role="node", pin=None, unreachable=(), lease=None,
              times=1):
        """Run `copal-grove elect` over a made-up grove; the roles it printed.

        `peers` is (id, score) -- this node is never in it, because the
        election reads its own score live rather than out of its own beacon.
        """
        d = os.path.join(root, "electdir")
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
        with open(os.path.join(d, "name"), "w") as fh:
            fh.write("museum\n")
        with open(os.path.join(d, "role"), "w") as fh:
            fh.write(role + "\n")
        if pin:
            with open(os.path.join(d, "role-pin"), "w") as fh:
                fh.write(pin + "\n")
        if lease is not None:
            lp = os.path.join(d, "warden-lease")
            open(lp, "w").close()
            os.utime(lp, (time.time() - lease, time.time() - lease))
        bf = os.path.join(root, "elect-beacons.tsv")
        with open(bf, "w") as fh:
            for nid, sc in peers:
                fh.write("%s\t10.0.0.9\tv=1;g=museum;n=%s;r=node;s=%d;m=1024\n"
                         % (nid, nid, sc))
        uf = os.path.join(root, "elect-unreachable")
        with open(uf, "w") as fh:
            fh.write("".join(i + "\n" for i in unreachable))
        env = dict(os.environ)
        env.update({"COPAL_GROVE_DIR": d, "COPAL_GROVE_BEACONS": bf,
                    "COPAL_GROVE_UNREACHABLE": uf})
        out = []
        for _ in range(times):
            r = subprocess.run([tool, "elect"], capture_output=True,
                               text=True, env=env, timeout=30)
            out.append(r.stdout.strip())
        return out

    # This node's own score decides who wins, so the fixtures are written
    # around it rather than assuming a number.
    mine = int(subprocess.run([tool, "score"], capture_output=True, text=True,
                              env=dict(os.environ, COPAL_GROVE_DIR=root)
                              ).stdout.strip() or 0)
    low = [("museum-01", mine - 100), ("museum-02", mine - 200)]
    high = [("museum-01", mine + 100)]

    got = elect(low, times=3)
    if got == ["node", "node", "warden"]:
        ok("the best score takes the role, after three agreeing checks",
           "slow to take: %s" % " ".join(got))
    else:
        bad("the election did not promote the best score on the third check",
            "got %s, wanted node node warden" % " ".join(got))

    got = elect(high, role="warden", lease=0, times=1)
    if got == ["node"]:
        ok("a better score demotes this node on the FIRST check",
           "quick to yield -- the asymmetry is the hysteresis")
    else:
        bad("a node holding the role did not yield to a better score",
            "got %s, wanted node" % " ".join(got))

    got = elect(high, times=4)
    if got == ["node"] * 4:
        ok("a losing node stays a node, and does not flap")
    else:
        bad("a losing node did not stay a node", " ".join(got))

    got = elect(high, unreachable=["museum-01"], times=3)
    if got == ["node", "node", "warden"]:
        ok("a warden that announces but does not answer is discounted",
           "the agent writes the list; the beacon alone would follow a "
           "machine that is off")
    else:
        bad("an unreachable warden was still counted in the sort",
            "got %s, wanted node node warden" % " ".join(got))

    got = elect(low, pin="node", times=3)
    if got == ["node"] * 3:
        ok("a pinned role overrides the sort")
    else:
        bad("`role-pin` did not override the election", " ".join(got))

    got = elect(low, role="warden", lease=None, times=1)
    if got == ["node"]:
        ok("a card that says warden with no live lease demotes first",
           "a card off a shelf is not a warden that rebooted")
    else:
        bad("a stale warden role was resumed without a lease",
            "got %s, wanted node" % " ".join(got))

    got = elect(low, role="warden", lease=10, times=1)
    if got == ["warden"]:
        ok("a warden that rebooted inside its lease keeps the role at once")
    else:
        bad("a warden inside its lease had to serve the hold again",
            "got %s, wanted warden" % " ".join(got))

    if me:                       # only meaningful if `hostname` answered
        # The grove is this node and a four-minute-old beacon of itself
        # claiming a better score. Counting that beacon would make a node lose
        # an election to its own past, so the only candidate is this node and
        # it takes the role on the usual hold.
        got = elect([(me, mine + 500)], times=3)
        if got == ["node", "node", "warden"]:
            ok("a node does not lose to its own stale beacon",
               "its own row comes from the live score, never from the browse")
        else:
            bad("this node's own stale beacon was counted as a second node",
                "got %s, wanted node node warden" % " ".join(got))

    skip("the 20-second failover, timed on hardware",
         "Needs two machines and a power switch. The election above is a "
         "sort over fixtures; what it cannot show is how fast a real card "
         "stops answering.")


# ------------------------------------------------------------------ line 3 ---

def case_avahi_off(root, beacons, answers, home):
    line(3, "Avahi off -- addresses from a written list")
    nodes_file = os.path.join(home, "groves", "museum", "nodes")
    with open(nodes_file, "w") as fh:
        fh.write("# id            address\n")
        for i in (1, 2, 3, 6):
            fh.write("museum-%02d      10.0.0.%d\n" % (i, 10 + i))
    # A PATH with everything on it EXCEPT avahi. Emptying PATH would only
    # prove that a shell with no `sh` cannot run, which is not the question --
    # the question is whether the console still works when discovery does not.
    env = {"COPAL_ANSWERS": answers, "COPAL_HOME": home,
           "PATH": path_without_avahi(root)}
    # No COPAL_GROVE_BEACONS either: the static path is the only one left.
    code, out, err = grove_sh("browse", "--grove", "museum", env=env)
    if code != 0:
        return bad("browse failed with no avahi and a written list", err)
    if out.count("museum-") >= 4:
        ok("the written list is read when there is nothing to browse with")
    else:
        return bad("the written list was not used", out[:200])

    code, out, err = grove_sh("state", "--json", "--grove", "museum", env=env)
    if code != 0:
        return bad("state failed with no discovery", err)
    doc = json.loads(out)
    if doc["counts"]["announced"] == 4:
        ok("the console works from the list, with identity untouched")
    else:
        bad("the static path changed what the console thinks is there",
            json.dumps(doc["counts"]))
    if doc["counts"]["declared"] == 8 and doc["counts"]["missing"] == 4:
        ok("the four that are not in the list are reported missing, not "
           "forgotten")
    else:
        bad("nodes absent from the list were silently dropped",
            json.dumps(doc["counts"]))
    # AND THE DOCUMENT HAS TO MATCH THE MECHANISM. The backlog said addresses
    # come from `nodes` in grove.toml; they are not there and could not be,
    # because that key is a list of ids for `wait` and carries no addresses. A
    # checklist that names a different file from the one that runs is a
    # checklist somebody follows into a wall at nine in the morning.
    backlog = os.path.join(os.path.dirname(HERE), "docs", "grove-m4-backlog.md")
    try:
        text = open(backlog).read()
    except OSError:
        return skip("the backlog names the file the static path reads",
                    "no docs/grove-m4-backlog.md here")
    if "`nodes` in `grove.toml`" in text:
        bad("the backlog says addresses come from `nodes` in grove.toml. That "
            "key is a list of IDS and carries no addresses.",
            "The static path reads ~/.copal/groves/<grove>/nodes, a different\n"
            "file in a different place. The mechanism works; the document\n"
            "describing it does not.")
    else:
        ok("the backlog names the file the static path actually reads")


# ------------------------------------------------------------------ line 4 ---

def case_redelivery(root, beacons, answers, home, nats):
    line(4, "Console killed mid-command -- a re-run fixes it, a redelivery is safe")
    if not nats:
        return skip("the bus path's idempotence, against a real server",
                    "No nats-server on PATH. apk add nats-server, then re-run.")

    port = free_port()
    node = "museum-03"
    gdir = os.path.join(root, "nodedir")
    os.makedirs(gdir, exist_ok=True)
    for name, value in (("name", "museum"), ("role", "node"), ("tags", "wall"),
                        ("scene", "show")):
        with open(os.path.join(gdir, name), "w") as fh:
            fh.write(value + "\n")
    seed = copal_nkeys.new_seed("user")
    with open(os.path.join(gdir, "nkey.seed"), "w") as fh:
        fh.write(seed + "\n")
    console_seed = copal_nkeys.new_seed("user")

    rows = copal_nats.parse_members("\n".join([
        "%s %s node" % (node, copal_nkeys.public_of(seed)),
        "console %s console" % copal_nkeys.public_of(console_seed)]))
    with open(os.path.join(root, "grove-users.conf"), "w") as fh:
        fh.write(copal_nats.render_users("museum", rows))
    conf = os.path.join(root, "nats.conf")
    with open(conf, "w") as fh:
        fh.write('host: 127.0.0.1\nport: %d\ninclude "grove-users.conf"\n' % port)

    # A stand-in for the node tool and for the forced command. The forced
    # command records every invocation, which is how "exactly once" is counted.
    tool = os.path.join(root, "copal-grove")
    with open(tool, "w") as fh:
        fh.write('#!/bin/sh\ncase "$1" in\n'
                 '  id) echo %s ;;\n'
                 '  state) echo "id=%s role=node score=1 temp=44 up=5m ram=1024 '
                 'arch=aarch64 tags=wall scene=show scene_min=1" ;;\n'
                 '  browse) printf "%s\\t127.0.0.1\\tv=1;g=museum;n=%s;r=warden;s=9\\n" ;;\n'
                 '  *) exit 0 ;;\nesac\n' % (node, node, node, node))
    os.chmod(tool, 0o755)
    ran = os.path.join(root, "ran.log")
    execf = os.path.join(root, "copal-grove-exec")
    with open(execf, "w") as fh:
        fh.write('#!/bin/sh\nprintf "%%s\\n" "$SSH_ORIGINAL_COMMAND" >> %s\n'
                 'echo done\n' % ran)
    os.chmod(execf, 0o755)

    proc = subprocess.Popen([nats, "-c", conf],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    agent = None
    try:
        for _ in range(60):
            try:
                socket.create_connection(("127.0.0.1", port), 0.3).close()
                break
            except OSError:
                time.sleep(0.1)
        env = dict(os.environ)
        env.update({"COPAL_GROVE_DIR": gdir, "COPAL_GROVE_EXEC": execf,
                    "COPAL_GROVE_TOOL": tool, "COPAL_GROVE_PORT": str(port),
                    "COPAL_GROVE_SEEN": os.path.join(root, "seen"),
                    "COPAL_GROVE_NODE_LOG": os.path.join(root, "node.log"),
                    "COPAL_GROVE_COLLECT": os.path.join(root, "collect")})
        agent = subprocess.Popen([sys.executable, os.path.join(HERE, "copal-grove-agent")],
                                 env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
        con = copal_nats.Nats("127.0.0.1", port, seed=console_seed,
                              name="console", timeout=10)
        con.connect()
        # Everything, because the console's credential allows exactly that and
        # this waits on `hello` as well as on acks. Subscribing to ack.> alone
        # and then waiting for a hello is a test that waits out its own clock.
        con.subscribe("grove.museum.>")
        con.flush()

        joined = False
        for _ in range(40):
            if any(m[0] == "grove.museum.hello" for m in con.messages(0.5)):
                joined = True
                break
        if joined:
            ok("the real agent connected to a real bus, and said hello")
        else:
            bad("the agent never appeared on the bus")

        def ran_count():
            try:
                return len(open(ran).read().splitlines())
            except OSError:
                return 0

        def settle(expect, seconds=8.0):
            """Wait until the exec has run `expect` times, or give up.

            Polled rather than slept: a fixed sleep is either slower than it
            needs to be or shorter than the machine, and this suite had both.
            """
            deadline = time.time() + seconds
            while time.time() < deadline:
                if ran_count() >= expect:
                    break
                time.sleep(0.2)
            # A moment past the target, so that a SECOND run would be seen too.
            time.sleep(1.2)
            return ran_count()

        def send(corr, once, verb="state", exp=None):
            env_ = {"v": 1, "corr": corr, "verb": verb, "args": [],
                    "iss": "grove-operator", "once": once}
            if exp is not None:
                env_["exp"] = exp
            con.publish("grove.museum.cmd.node.%s" % node, json.dumps(env_))
            con.flush()

        # THE SAME COMMAND, TWICE, with the same `once` -- which is what a
        # console killed mid-command and re-run looks like from the node.
        send("c1", "2026-09-08T15:00:00Z")
        settle(1)
        send("c1-again", "2026-09-08T15:00:00Z")
        count = settle(2, seconds=3.0)
        if count == 1:
            ok("a redelivered command ran exactly once")
        else:
            bad("a redelivered command ran %d times" % count,
                "`once` is what makes a re-run safe; it did not hold.")

        # AND IT SURVIVES THE AGENT RESTARTING, which is the half that a
        # memory-only seen-list would fail.
        agent.terminate()
        agent.wait(timeout=10)
        agent = subprocess.Popen([sys.executable, os.path.join(HERE, "copal-grove-agent")],
                                 env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
        rejoined = False
        for _ in range(40):
            if any(m[0] == "grove.museum.hello" for m in con.messages(0.5)):
                rejoined = True
                break
        if not rejoined:
            bad("the agent did not come back after a restart")
        send("c1-after-restart", "2026-09-08T15:00:00Z")
        count2 = settle(count + 1, seconds=3.0)
        if count2 == count:
            ok("and still exactly once after the agent restarted")
        else:
            bad("the restart forgot: it ran again",
                "the seen-list has to be on disk, not in memory")

        # An expired command must not fire at four in the afternoon.
        send("c2", "2026-09-08T09:00:00Z", exp=time.time() - 30)
        count3 = settle(count2 + 1, seconds=3.0)
        if count3 == count2:
            ok("a command that expired while the node was off did not fire")
        else:
            bad("an expired command fired")

        # A fresh command still works -- the node is not merely deaf.
        send("c3", "2026-09-08T16:00:00Z")
        count4 = settle(count3 + 1)
        if count4 == count3 + 1:
            ok("a new command still runs -- the node is idempotent, not deaf")
        else:
            bad("a fresh command did not run", "count went %d -> %d" % (count3, count4))

        # And what ran went through the forced command, verb list and all.
        body = open(ran).read() if os.path.exists(ran) else ""
        if body.strip().splitlines() and all(l.strip() == "state" for l in body.strip().splitlines()):
            ok("every command ran through copal-grove-exec, as a verb")
        else:
            bad("something other than the verb reached the exec", body[:200])
        con.close()
    finally:
        for p in (agent, proc):
            if p and p.poll() is None:
                p.send_signal(signal.SIGTERM)
                try:
                    p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    p.kill()


# -------------------------------------------------------------------- main ---

def main():
    global VERBOSE
    ap = argparse.ArgumentParser()
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    VERBOSE = args.verbose

    nats = shutil.which("nats-server")
    print("%sCopal grove -- W10, degradation tested on purpose%s" % (D, Z))
    print("%s%s%s" % (D, time.strftime("%Y-%m-%d %H:%M:%S"), Z))

    root = tempfile.mkdtemp(prefix="copal-degrade.")
    try:
        beacons, answers, home = write_fixture(root)
        case_bus_down(root, beacons, answers, home)
        case_warden_unplugged(root, beacons, answers, home)
        case_avahi_off(root, beacons, answers, home)
        case_redelivery(root, beacons, answers, home, nats)
    finally:
        shutil.rmtree(root, ignore_errors=True)

    p = sum(1 for s, _ in RESULTS if s == "PASS")
    f = sum(1 for s, _ in RESULTS if s == "FAIL")
    s = sum(1 for s, _ in RESULTS if s == "SKIP")
    print("\n%s%d passed, %d failed, %d not performed%s"
          % (R if f else G, p, f, s, Z))
    if f:
        print("\n%sA layer that has become load-bearing is a bug, and this is the"
              " item that finds it.%s" % (D, Z))
        for status, what in RESULTS:
            if status == "FAIL":
                print("  %s✗%s %s" % (R, Z, what))
    return 1 if f else 0


if __name__ == "__main__":
    sys.exit(main())
