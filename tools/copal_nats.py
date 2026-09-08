#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
"""copal_nats -- the grove's half of NATS: the permission list, and the wire.

Two things live here because they are two halves of one subject, and keeping
them together means there is ONE place that knows what a grove's subjects are
called:

  render_users()   the warden's authorization block -- invariant 5, rendered
  Nats             a client for the text protocol, standard library only

WHY NOT `nats-py`:  the console's home is the operator's Mac, where `apk` does
not exist and the fallback is `pip install` into whatever environment happens
to be current.  A museum console that needs pip at 08:45 is a console that is
down.  See grove-m4-backlog.md §3 D3.

WHY THE RENDERER IS HERE AND NOT IN THE SHELL:  because the test that proves
invariant 5 has to render exactly what the warden renders.  Two copies of those
allow-lists would mean the test could pass while the fleet was wrong, which is
worse than having no test.

The protocol is newline-delimited text over TCP.  A client that has read the
first INFO knows everything it needs:

    S: INFO {"nonce":"...","auth_required":true}
    C: CONNECT {"nkey":"U...","sig":"...","name":"...","verbose":false}
    C: PING                                 S: PONG
    C: SUB grove.museum.cmd.> 1
    C: PUB grove.museum.hello 0
    S: MSG grove.museum.cmd.all 1 17
    S: -ERR 'Permissions Violation for Publish to "grove.museum.node.x.state"'

A permission violation is an -ERR that does NOT close the connection.  An
authorization failure is an -ERR that does.  The difference is the whole of
what copal-bus-test.py checks.
"""

import json
import socket
import sys
import time

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import copal_nkeys  # noqa: E402  -- same directory, on the node and here

ID_OK = set("abcdefghijklmnopqrstuvwxyz0123456789-")


# ------------------------------------------------------- the permissions ---
#
# INVARIANT 5 OF docs/grove-plan.md, and this function is the only place in the
# system where these strings are built.  Both arguments are checked by the
# caller before they arrive: `grove` against ID_OK by render_users, and `nid`
# the same.  Nothing here interpolates anything a network could choose.

ROLES = ("node", "warden", "console")


def perms_for(grove, nid, role):
    """(publish allow-list, subscribe allow-list) for one member."""
    if role == "console":
        # The console is the one member that may command, and the one member
        # that may listen to everything.  It is not a node and does not get a
        # node's shape.
        return (["grove.%s.cmd.>" % grove],
                ["grove.%s.>" % grove])
    if role not in ("node", "warden"):
        raise ValueError("role is one of %s, not %r" % (", ".join(ROLES), role))

    # A node publishes under its own id and nowhere else.  This is invariant 5.
    publish = ["grove.%s.node.%s.>" % (grove, nid),
               "grove.%s.log.%s" % (grove, nid),
               "grove.%s.ack.%s.>" % (grove, nid),
               "grove.%s.gem.>" % grove,
               "grove.%s.hello" % grove]
    subscribe = ["grove.%s.cmd.>" % grove,
                 "grove.%s.work.>" % grove]

    # THE WARDEN IS A NODE THAT ALSO COLLECTS LOGS, and this is the whole of
    # the difference.  W4 has it subscribe to every node's log subject and
    # write per-node dated files, which a plain node's list does not permit --
    # correctly, since a node has no business reading another node's log.
    #
    # It is a SUBSCRIBE grant and never a publish one: the warden may read what
    # the grove says and still cannot say anything in another node's name. A
    # compromised warden costs the grove its log sink and its queue. It does
    # not let the warden forge telemetry, which is what invariant 5 is for and
    # why §7 can call the warden a convenience rather than an authority.
    if role == "warden":
        subscribe = subscribe + ["grove.%s.log.>" % grove]
    return (publish, subscribe)


def parse_members(text):
    """`<id> <nkey> <node|warden|console>` lines -> [(id, nkey, role)].

    Every refusal below is a refusal the warden makes before it writes
    anything.  A membership list arrives over ssh from a console holding an
    8-hour certificate; that is a good deal of trust, and it is still not a
    reason to skip checking that what arrived is what was meant.
    """
    rows, seen = [], set()
    for n, line in enumerate(text.splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) != 3:
            raise ValueError("line %d: want '<id> <nkey> <node|warden|console>'" % n)
        nid, nkey, role = parts
        if not nid or set(nid) - ID_OK:
            raise ValueError("line %d: %r is not a usable node id" % (n, nid))
        if role not in ROLES:
            raise ValueError("line %d: role is one of %s, not %r"
                             % (n, ", ".join(ROLES), role))
        try:
            kind, _raw = copal_nkeys.decode_public(nkey)
        except ValueError as exc:
            raise ValueError("line %d: %s's nkey is not usable -- %s" % (n, nid, exc))
        if kind != "user":
            raise ValueError("line %d: %s is a %s nkey, not a user one" % (n, nid, kind))
        if nid in seen:
            raise ValueError("line %d: %s appears twice" % (n, nid))
        seen.add(nid)
        rows.append((nid, nkey, role))
    if not rows:
        raise ValueError("an empty membership would open the bus -- refusing")
    return rows


def render_users(grove, rows):
    """The warden's /etc/nats/grove-users.conf, as text."""
    if not grove or set(grove) - ID_OK:
        raise ValueError("refusing to render a grove name that is not [a-z0-9-]: %r" % grove)
    out = [
        "# /etc/nats/grove-users.conf -- rendered by `copal-grove bus-users`.",
        "# Do not edit: the next enrolment overwrites it. %d members." % len(rows),
        "#",
        "# THIS FILE IS INVARIANT 5 of docs/grove-plan.md, in the form the server",
        "# enforces it. A node publishes under its own id and nowhere else. Read",
        "# it against the plan -- that is what it is here for.",
        "authorization {",
        "    users = [",
    ]
    for nid, nkey, role in rows:
        pub, sub = perms_for(grove, nid, role)
        quoted = lambda xs: ", ".join('"%s"' % x for x in xs)  # noqa: E731
        out.append("        # %s (%s)" % (nid, role))
        out.append("        { nkey: %s, permissions: {" % nkey)
        out.append("            publish:   { allow: [%s] }," % quoted(pub))
        out.append("            subscribe: { allow: [%s] }" % quoted(sub))
        out.append("        }},")
    out.append("    ]")
    out.append("}")
    return "\n".join(out) + "\n"


# -------------------------------------------------------------- the wire ---

class NatsError(Exception):
    """A `-ERR` the server sent, or a connection that did not survive."""


class Nats:
    """One connection.  Not thread-safe, and deliberately not a reconnector --
    W3's agent owns the backoff policy, because only it knows that a grove with
    no warden is the ordinary state during a handover rather than a fault."""

    def __init__(self, host, port=4222, seed=None, name="copal", timeout=5.0):
        self.host, self.port = host, int(port)
        self.seed = seed          # an `SU...` nkey seed, or None for open buses
        self.name = name
        self.timeout = float(timeout)
        self.sock = None
        self.peer_closed = False   # set when recv() returns nothing
        self.info = {}
        self.errors = []          # every -ERR seen, in order
        # Messages can arrive during flush() -- a client subscribed to a
        # wildcard hears its own publish -- so this is initialised here rather
        # than lazily in messages(). It was lazy once, and the crash only
        # showed up under a client that could hear itself.
        self._pending = []
        self._buf = b""
        self._sid = 0

    # -- plumbing ---------------------------------------------------------
    def _fill(self, deadline):
        left = deadline - time.monotonic()
        if left <= 0:
            raise NatsError("timed out waiting for the server")
        self.sock.settimeout(left)
        try:
            chunk = self.sock.recv(65536)
        except socket.timeout:
            raise NatsError("timed out waiting for the server")
        if not chunk:
            # Distinguished from an idle timeout on purpose. messages() is
            # allowed to swallow "nothing arrived"; it must never swallow
            # "the warden went away", or an agent would sit in a tight loop
            # believing it was merely quiet.
            self.peer_closed = True
            raise NatsError("the server closed the connection")
        self._buf += chunk

    def _line(self, deadline):
        while b"\r\n" not in self._buf:
            self._fill(deadline)
        line, self._buf = self._buf.split(b"\r\n", 1)
        return line.decode("utf-8", "replace")

    def _exact(self, n, deadline):
        while len(self._buf) < n:
            self._fill(deadline)
        out, self._buf = self._buf[:n], self._buf[n:]
        return out

    def _send(self, text):
        self.sock.sendall(text.encode() if isinstance(text, str) else text)

    # -- the handshake ----------------------------------------------------
    def connect(self):
        deadline = time.monotonic() + self.timeout
        self.sock = socket.create_connection((self.host, self.port), self.timeout)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

        line = self._line(deadline)
        if not line.startswith("INFO "):
            raise NatsError("that is not a NATS server -- it said %r" % line[:40])
        self.info = json.loads(line[5:])

        opts = {"verbose": False, "pedantic": False, "tls_required": False,
                "name": self.name, "lang": "python-copal", "version": "1",
                "protocol": 1, "echo": True}
        nonce = self.info.get("nonce")
        if self.seed:
            # THE ONLY THING THE SEED IS EVER USED FOR. It signs a nonce the
            # server chose, so a recorded CONNECT cannot be replayed against a
            # later one.
            opts["nkey"] = copal_nkeys.public_of(self.seed)
            if nonce:
                opts["sig"] = copal_nkeys.sign_nonce(self.seed, nonce.encode())
        elif nonce:
            raise NatsError("the server wants a credential and this client has none")

        self._send("CONNECT %s\r\nPING\r\n" % json.dumps(opts))

        # An authorization failure arrives as -ERR and then a closed socket; a
        # good handshake arrives as PONG. Read until one or the other.
        while True:
            line = self._line(deadline)
            if line == "PONG":
                return self
            if line.startswith("-ERR"):
                raise NatsError(line[5:].strip().strip("'"))
            if line == "PING":
                self._send("PONG\r\n")
            # INFO can arrive again on cluster changes; ignore it here.

    # -- verbs ------------------------------------------------------------
    def publish(self, subject, payload=b""):
        if isinstance(payload, str):
            payload = payload.encode()
        self._send("PUB %s %d\r\n" % (subject, len(payload)))
        self._send(payload + b"\r\n")

    def subscribe(self, subject, queue=None):
        self._sid += 1
        if queue:
            self._send("SUB %s %s %d\r\n" % (subject, queue, self._sid))
        else:
            self._send("SUB %s %d\r\n" % (subject, self._sid))
        return self._sid

    def unsubscribe(self, sid):
        self._send("UNSUB %d\r\n" % sid)

    def flush(self, timeout=None):
        """PING, then read until PONG.  Returns the -ERRs that arrived first.

        This is how a permission violation becomes visible: NATS processes a
        connection's input in order, so any -ERR our PUB earned is already on
        the wire ahead of the PONG.  Anything that wants to know whether a
        publish was allowed calls this.
        """
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        before = len(self.errors)
        self._send("PING\r\n")
        while True:
            line = self._line(deadline)
            if line == "PONG":
                return self.errors[before:]
            self._absorb(line, deadline)

    def _absorb(self, line, deadline):
        if line.startswith("-ERR"):
            self.errors.append(line[5:].strip().strip("'"))
        elif line == "PING":
            self._send("PONG\r\n")
        elif line.startswith("MSG "):
            parts = line.split()
            n = int(parts[-1])
            payload = self._exact(n + 2, deadline)[:-2]
            self._pending.append((parts[1], int(parts[2]),
                                  parts[3] if len(parts) == 6 else None, payload))

    def messages(self, timeout=1.0):
        """Read whatever has arrived, as (subject, sid, reply, payload)."""
        deadline = time.monotonic() + timeout
        try:
            while time.monotonic() < deadline:
                line = self._line(deadline)
                self._absorb(line, deadline)
        except NatsError:
            if self.peer_closed:
                raise
        out, self._pending = self._pending, []
        return out

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            finally:
                self.sock = None

    def __enter__(self):
        return self.connect()

    def __exit__(self, *_):
        self.close()


# -------------------------------------------------------------------- cli ---

USAGE = """copal_nats -- the grove's permission list, and a client for the bus

  copal_nats.py render GROVE FILE    the warden's authorization block
  copal_nats.py ping HOST[:PORT]     is there a bus there, and does it want a key
  copal_nats.py self-test            the renderer, and the wire against a stub
"""


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help", "help"):
        sys.stdout.write(USAGE)
        return 0
    try:
        if argv[1] == "render":
            grove, path = argv[2], argv[3]
            sys.stdout.write(render_users(grove, parse_members(open(path).read())))
        elif argv[1] == "ping":
            where = argv[2]
            host, _, port = where.partition(":")
            n = Nats(host, port or 4222, seed=None, name="copal-ping")
            try:
                n.connect()
                print("open bus -- no credential was asked for")
            except NatsError as exc:
                print("bus at %s: %s" % (where, exc))
            finally:
                n.close()
        elif argv[1] in ("self-test", "--self-test"):
            print("copal_nats: %d checks passed" % self_test())
        else:
            sys.stderr.write("no such verb: %s\n" % argv[1])
            return 2
    except IndexError:
        sys.stderr.write("missing argument -- see --help\n")
        return 2
    except (ValueError, NatsError, OSError) as exc:
        sys.stderr.write("error: %s\n" % exc)
        return 1
    return 0


# -------------------------------------------------------------- self-test ---
#
# The renderer is checked against its own output.  The CLIENT is checked against
# a stub server in this process -- which is not nats-server and does not pretend
# to be, but it is enough to prove the handshake, the nonce signature, the
# framing and the -ERR path without needing a binary installed.  The test that
# needs a real server is tools/copal-bus-test.py, and it is a separate file
# precisely so that this one can run anywhere.

def _stub_server(sock, seed_pub, verify=True):
    """One connection of a pretend NATS server.  Returns what it observed."""
    import base64
    conn, _ = sock.accept()
    conn.settimeout(5)
    nonce = base64.b64encode(b"a-nonce-worth-signing").decode()
    conn.sendall(('INFO {"server_id":"stub","nonce":"%s","auth_required":true}\r\n'
                  % nonce).encode())
    buf = b""
    seen = {"connect": None, "pub": [], "sub": []}
    while b"\r\n" not in buf:
        buf += conn.recv(4096)
    line, buf = buf.split(b"\r\n", 1)
    assert line.startswith(b"CONNECT "), line
    seen["connect"] = json.loads(line[8:])
    if verify:
        sig = seen["connect"]["sig"]
        raw = base64.urlsafe_b64decode(sig + "=" * (-len(sig) % 4))
        _role, pub = copal_nkeys.decode_public(seen["connect"]["nkey"])
        assert seen["connect"]["nkey"] == seed_pub, "the client sent the wrong nkey"
        assert copal_nkeys.verify(pub, nonce.encode(), raw), "the nonce signature is bad"
    # The client's PING follows in the same write.
    while True:
        while b"\r\n" not in buf:
            chunk = conn.recv(4096)
            if not chunk:
                conn.close()
                return seen
            buf += chunk
        line, buf = buf.split(b"\r\n", 1)
        text = line.decode()
        if text == "PING":
            conn.sendall(b"PONG\r\n")
        elif text.startswith("SUB "):
            seen["sub"].append(text)
        elif text.startswith("PUB "):
            parts = text.split()
            n = int(parts[-1])
            while len(buf) < n + 2:
                buf += conn.recv(4096)
            payload, buf = buf[:n], buf[n + 2:]
            seen["pub"].append((parts[1], payload))
            # Refuse exactly one subject, the way a real server refuses a
            # publish outside an allow-list: an -ERR, connection left open.
            if "forbidden" in parts[1]:
                conn.sendall(('-ERR \'Permissions Violation for Publish to "%s"\'\r\n'
                              % parts[1]).encode())
            # And deliver something back, to exercise MSG framing.
            if parts[1].endswith("echo"):
                conn.sendall(b"MSG %s 1 %d\r\n%s\r\n"
                             % (parts[1].encode(), n, payload))
        elif text == "QUIT":
            conn.close()
            return seen


def self_test():
    import threading
    checks = 0

    # -- the renderer ---------------------------------------------------
    seeds = {n: copal_nkeys.new_seed("user") for n in ("museum-01", "museum-02", "console")}
    pubs = {n: copal_nkeys.public_of(s) for n, s in seeds.items()}
    listing = "\n".join([
        "museum-01 %s node" % pubs["museum-01"],
        "# a comment, and a blank line follow",
        "",
        "museum-02 %s node" % pubs["museum-02"],
        "console %s console" % pubs["console"],
    ])
    rows = parse_members(listing)
    assert [r[0] for r in rows] == ["museum-01", "museum-02", "console"]
    conf = render_users("museum", rows)
    checks += 1

    # A node's own subjects are there; another node's are not, anywhere.
    assert '"grove.museum.node.museum-01.>"' in conf
    assert '"grove.museum.log.museum-01"' in conf
    assert conf.count('"grove.museum.cmd.>"') == 3   # two nodes subscribe, console publishes
    assert '"grove.museum.>"' in conf                # the console, and only the console
    assert conf.count('"grove.museum.>"') == 1
    checks += 5

    # The publish allow-list of a node must not mention any other node's id.
    for nid in ("museum-01", "museum-02"):
        pub, sub = perms_for("museum", nid, "node")
        other = "museum-02" if nid == "museum-01" else "museum-01"
        assert not any(other in s for s in pub + sub), "a node's list names another node"
        assert not any(s == "grove.museum.>" for s in pub + sub), "a node got the console's wildcard"
        checks += 2

    # The warden gets exactly one thing a node does not, and it is a
    # subscription. Anything else would make it an authority.
    npub, nsub = perms_for("museum", "museum-06", "node")
    wpub, wsub = perms_for("museum", "museum-06", "warden")
    assert wpub == npub, "the warden was given a publish grant a node lacks"
    assert set(wsub) - set(nsub) == {"grove.museum.log.>"}, wsub
    assert "grove.museum.log.>" not in nsub, "a plain node may read every log"
    checks += 3

    for bad, why in [
        ("museum-01 %s admin" % pubs["museum-01"], "role"),
        ("museum-01 %s node\nmuseum-01 %s node" % (pubs["museum-01"], pubs["museum-01"]), "twice"),
        ("../etc %s node" % pubs["museum-01"], "usable node id"),
        ("museum-01 %sA node" % pubs["museum-01"][:-1], "not usable"),
        ("museum-01 %s" % pubs["museum-01"], "want"),
        ("", "empty membership"),
    ]:
        try:
            parse_members(bad)
        except ValueError as exc:
            assert why in str(exc), "refused for the wrong reason: %s" % exc
            checks += 1
        else:
            raise AssertionError("accepted a membership it should have refused: %r" % bad)

    for bad in ('museum"; evil', "MUSEUM", "", "../x"):
        try:
            render_users(bad, rows)
        except ValueError:
            checks += 1
        else:
            raise AssertionError("rendered a grove name it should have refused: %r" % bad)

    # -- the wire, against the stub -------------------------------------
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    port = srv.getsockname()[1]
    observed = {}

    def run():
        observed.update(_stub_server(srv, pubs["museum-01"]) or {})

    thread = threading.Thread(target=run, daemon=True)
    thread.start()

    client = Nats("127.0.0.1", port, seed=seeds["museum-01"], name="museum-01")
    client.connect()                                    # handshake + signature
    checks += 1
    sid = client.subscribe("grove.museum.cmd.>")
    assert sid == 1
    client.publish("grove.museum.node.museum-01.state", b"temp=41")
    assert client.flush() == [], "an allowed publish drew an error"
    checks += 2
    client.publish("grove.museum.node.forbidden.state", b"nope")
    errs = client.flush()
    assert len(errs) == 1 and "Permissions Violation" in errs[0], errs
    checks += 1
    client.publish("grove.museum.echo", b"hello")
    got = client.messages(0.5)
    assert got and got[0][3] == b"hello", got
    checks += 1

    # REGRESSION. A client subscribed to a wildcard hears its own publish, so a
    # MSG can arrive inside flush() before messages() has ever been called.
    # This used to raise AttributeError on a lazily-created buffer, and it was
    # found by deliberately breaking a permission to check that the invariant
    # test could fail -- the console heard itself and the client fell over.
    client.publish("grove.museum.echo", b"during-flush")
    assert client.flush() == [], "the echo drew an error"
    heard = client.messages(0.2)
    assert any(m[3] == b"during-flush" for m in heard), heard
    checks += 2
    client._send("QUIT\r\n")
    client.close()
    thread.join(timeout=5)
    srv.close()
    assert observed.get("sub") == ["SUB grove.museum.cmd.> 1"], observed.get("sub")
    checks += 1

    # A client with no seed must refuse to talk to a server that wants one,
    # rather than connecting and failing later in a way that looks like a bug.
    srv2 = socket.socket()
    srv2.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv2.bind(("127.0.0.1", 0))
    srv2.listen(1)
    p2 = srv2.getsockname()[1]
    t2 = threading.Thread(target=lambda: _stub_server(srv2, None, verify=False), daemon=True)
    t2.start()
    try:
        Nats("127.0.0.1", p2, seed=None).connect()
    except NatsError as exc:
        assert "credential" in str(exc), exc
        checks += 1
    else:
        raise AssertionError("connected with no credential to a server that asked")
    srv2.close()

    return checks


if __name__ == "__main__":
    sys.exit(main(sys.argv))
