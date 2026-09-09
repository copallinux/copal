#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
"""copal-bus-test -- prove that a node cannot speak for another node.

THIS FILE IS INVARIANT 5.  docs/fleet-plan.md §2 says "A node may only speak
for itself", and docs/fleet-m4-backlog.md §4 W2 says, correctly, that without a
test which watches a server refuse, that sentence is an aspiration rather than
a property.  This is the test.

It does not need the fleet.  It starts its own `nats-server` on the loopback
with a membership rendered by the same `render_users()` the warden uses, and
then tries, as `museum-01`, to do the things `museum-01` must not be able to
do.  A pass means a real NATS server turned each of them down.

    tools/copal-bus-test.py              on any machine with nats-server
    tools/copal-bus-test.py -v           say what each check did

Exit status:  0 every check passed
              1 a check failed -- the fleet's permissions are not what the plan says
             77 skipped: no nats-server here.  NOT a pass, and it says so.

77 is the autotools convention for a skip, and it is used rather than 0 so that
a CI run which never had a server cannot be mistaken for a CI run that proved
something.
"""

import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import copal_nats   # noqa: E402
import copal_nkeys  # noqa: E402

FLEET = "testfleet"
VERBOSE = "-v" in sys.argv or "--verbose" in sys.argv

G = "\033[32m"; R = "\033[31m"; Y = "\033[33m"; Z = "\033[0m"
if not sys.stdout.isatty():
    G = R = Y = Z = ""

FAILURES = []


def check(what, ok, detail=""):
    if ok:
        if VERBOSE:
            print("    %s✓%s %s" % (G, Z, what))
    else:
        FAILURES.append(what)
        print("    %s✗%s %s%s" % (R, Z, what, ("  -- " + detail) if detail else ""))
    return ok


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def wait_for(port, proc, seconds=10):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if proc.poll() is not None:
            return False
        try:
            s = socket.create_connection(("127.0.0.1", port), 0.3)
            s.close()
            return True
        except OSError:
            time.sleep(0.1)
    return False


def refused(client, subject, kind="Publish"):
    """True when the server refused this publish.  Uses flush(), because NATS
    processes one connection's input in order: any -ERR our PUB earned is
    already ahead of the PONG we are waiting for."""
    client.publish(subject, b"x")
    errs = client.flush()
    return any("Permissions Violation" in e for e in errs), errs


def allowed(client, subject):
    client.publish(subject, b"x")
    errs = client.flush()
    return not errs, errs


def main():
    nats = shutil.which("nats-server")
    if not nats:
        print("%sskipped%s: no nats-server on PATH." % (Y, Z))
        print("    This test needs one to be refused by; it does not need the fleet.")
        print("    Alpine:  doas apk add nats-server        (v3.24 community, D2)")
        print("    Then:    tools/copal-bus-test.py")
        return 77

    tmp = tempfile.mkdtemp(prefix="copal-bus-test.")
    port = free_port()
    proc = None
    try:
        seeds = {n: copal_nkeys.new_seed("user")
                 for n in ("museum-01", "museum-02", "console")}
        pubs = {n: copal_nkeys.public_of(s) for n, s in seeds.items()}
        stranger = copal_nkeys.new_seed("user")

        rows = copal_nats.parse_members("\n".join([
            "museum-01 %s node" % pubs["museum-01"],
            "museum-02 %s warden" % pubs["museum-02"],
            "console %s console" % pubs["console"],
        ]))
        users = os.path.join(tmp, "fleet-users.conf")
        with open(users, "w") as fh:
            fh.write(copal_nats.render_users(FLEET, rows))
        conf = os.path.join(tmp, "nats.conf")
        with open(conf, "w") as fh:
            fh.write('host: 127.0.0.1\nport: %d\ninclude "fleet-users.conf"\n' % port)

        # The warden asks nats-server to parse before it installs; so does this.
        parse = subprocess.run([nats, "-t", "-c", conf],
                               capture_output=True, text=True)
        if parse.returncode != 0:
            print("%sfailed%s: nats-server would not parse what the warden renders."
                  % (R, Z))
            print(parse.stderr.strip()[:800])
            return 1
        print("  %s✓%s nats-server parses the rendered membership" % (G, Z))

        proc = subprocess.Popen([nats, "-c", conf],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if not wait_for(port, proc):
            err = proc.stderr.read().decode()[:800] if proc.stderr else ""
            print("%sfailed%s: nats-server did not come up.\n%s" % (R, Z, err))
            return 1
        print("  %s✓%s a real nats-server is listening on 127.0.0.1:%d" % (G, Z, port))

        # ---- the node that must not overreach --------------------------
        print("\n  As museum-01, holding museum-01's seed:")
        one = copal_nats.Nats("127.0.0.1", port, seed=seeds["museum-01"],
                              name="museum-01", timeout=8)
        one.connect()
        check("connects with its own nkey", True)

        ok, errs = allowed(one, "fleet.%s.node.museum-01.state" % FLEET)
        check("may publish its own state", ok, str(errs))
        ok, errs = allowed(one, "fleet.%s.log.museum-01" % FLEET)
        check("may publish its own log", ok, str(errs))
        ok, errs = allowed(one, "fleet.%s.hello" % FLEET)
        check("may say hello", ok, str(errs))

        # THE ONE THAT MATTERS.
        ok, errs = refused(one, "fleet.%s.node.museum-02.state" % FLEET)
        check("MAY NOT publish as museum-02", ok,
              "the server allowed it -- invariant 5 is not enforced")
        ok, errs = refused(one, "fleet.%s.log.museum-02" % FLEET)
        check("MAY NOT write museum-02's log", ok, str(errs))
        ok, errs = refused(one, "fleet.%s.ack.museum-02.abc" % FLEET)
        check("MAY NOT acknowledge for museum-02", ok, str(errs))
        ok, errs = refused(one, "fleet.%s.cmd.all" % FLEET)
        check("MAY NOT issue a command", ok, str(errs))
        ok, errs = refused(one, "fleet.otherfleet.node.x.state")
        check("MAY NOT reach another fleet", ok, str(errs))

        one.subscribe("fleet.%s.cmd.>" % FLEET)
        errs = one.flush()
        check("may subscribe to commands", not errs, str(errs))
        one.subscribe("fleet.%s.>" % FLEET)
        errs = one.flush()
        check("MAY NOT subscribe to the whole fleet",
              any("Permissions Violation" in e for e in errs), str(errs))
        one.subscribe("fleet.%s.log.>" % FLEET)
        errs = one.flush()
        check("MAY NOT read every node's log",
              any("Permissions Violation" in e for e in errs), str(errs))
        one.close()

        # ---- the warden: one extra grant, and it is a subscription -----
        print("\n  As museum-02, which is the warden:")
        war = copal_nats.Nats("127.0.0.1", port, seed=seeds["museum-02"],
                              name="museum-02", timeout=8)
        war.connect()
        check("connects with its own nkey", True)
        war.subscribe("fleet.%s.log.>" % FLEET)
        errs = war.flush()
        check("may collect every node's log", not errs, str(errs))
        ok, errs = refused(war, "fleet.%s.node.museum-01.state" % FLEET)
        check("MAY NOT publish as museum-01 either", ok,
              "being the warden bought a publish grant it should not have")
        ok, errs = refused(war, "fleet.%s.cmd.all" % FLEET)
        check("MAY NOT issue a command", ok, str(errs))
        war.subscribe("fleet.%s.>" % FLEET)
        errs = war.flush()
        check("MAY NOT subscribe to the whole fleet",
              any("Permissions Violation" in e for e in errs), str(errs))
        war.close()

        # ---- the console ----------------------------------------------
        print("\n  As the console:")
        con = copal_nats.Nats("127.0.0.1", port, seed=seeds["console"],
                              name="console", timeout=8)
        con.connect()
        check("connects with the console's nkey", True)
        ok, errs = allowed(con, "fleet.%s.cmd.all" % FLEET)
        check("may issue a command", ok, str(errs))
        con.subscribe("fleet.%s.>" % FLEET)
        errs = con.flush()
        check("may subscribe to the whole fleet", not errs, str(errs))
        ok, errs = refused(con, "fleet.%s.node.museum-01.state" % FLEET)
        check("MAY NOT impersonate a node", ok, str(errs))
        con.close()

        # ---- a machine nobody enrolled ---------------------------------
        print("\n  As a machine that was never enrolled:")
        out = copal_nats.Nats("127.0.0.1", port, seed=stranger,
                              name="stranger", timeout=8)
        try:
            out.connect()
            check("MAY NOT connect at all", False, "it got on the bus")
        except copal_nats.NatsError as exc:
            check("MAY NOT connect at all", "uthorization" in str(exc), str(exc))
        finally:
            out.close()

        # ---- and the lock with no key ----------------------------------
        print("\n  The default membership, before anyone is enrolled:")
        lock_pub = copal_nkeys.public_of(copal_nkeys.new_seed("user"))
        with open(users, "w") as fh:
            fh.write("authorization {\n    users = [\n        { nkey: %s }\n    ]\n}\n"
                     % lock_pub)
        subprocess.run([nats, "--signal", "reload=%d" % proc.pid],
                       capture_output=True)
        time.sleep(0.4)
        shut = copal_nats.Nats("127.0.0.1", port, seed=seeds["museum-01"],
                               name="museum-01", timeout=8)
        try:
            shut.connect()
            check("an unenrolled fleet admits nobody", False, "museum-01 still got in")
        except copal_nats.NatsError as exc:
            check("an unenrolled fleet admits nobody", "uthorization" in str(exc), str(exc))
        finally:
            shut.close()

    finally:
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if FAILURES:
        print("%s%d check(s) failed%s -- the bus does not enforce what the plan says."
              % (R, len(FAILURES), Z))
        for f in FAILURES:
            print("    %s" % f)
        return 1
    print("%severy check passed%s -- a node cannot speak for another node." % (G, Z))
    return 0


if __name__ == "__main__":
    sys.exit(main())
