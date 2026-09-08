#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
"""copal_nkeys -- the grove's bus key format, and nothing else.

An NKEY is how NATS names a principal: an ed25519 keypair in a base32 encoding
with a one-byte role prefix and a CRC.  A node proves itself to the bus by
signing the server's nonce with its seed; the server checks that signature
against the public nkey it was configured with.  That is the whole of the
mechanism, and this module is the whole of our implementation of it.

WHY THIS EXISTS AT ALL, rather than `pip install nkeys`:

  The console's home is the operator's Mac.  `apk` cannot help there and
  `pip install` at 08:45 is a console that is down -- see grove-m4-backlog.md
  §3 D3.  So: standard library only, on both halves of the grove.

WHAT IT DELIBERATELY DOES NOT DO:

  No JWTs.  Permissions live in the warden's nats.conf, in plain text a person
  can read against invariant 5.  See grove-plan.md §6 "How the bus is
  authenticated" and grove-m4-backlog.md §3 D1.

  No X.509.  The SSH CA remains the only thing that decides membership; an
  nkey is a capability issued as a consequence of membership, never a second
  authority.

The ed25519 below is RFC 8032, in extended twisted-Edwards coordinates so that
one signature costs milliseconds rather than the second the textbook affine
version costs on a Pi Zero.  It is checked against RFC 8032's own test vectors
by `--self-test`, which `make lint` runs.
"""

import hashlib
import hmac
import os
import sys

# --------------------------------------------------------------- ed25519 ---
#
# RFC 8032 §5.1.  The curve is  -x^2 + y^2 = 1 + d x^2 y^2  over GF(2^255-19),
# so a = -1 and the fast addition formulas apply.

P = 2**255 - 19
L = 2**252 + 27742317777372353535851937790883648493
D = (-121665 * pow(121666, P - 2, P)) % P


def _recover_x(y, sign):
    """The x that goes with this y, or None if the point is not on the curve."""
    if y >= P:
        return None
    xx = (y * y - 1) * pow(D * y * y + 1, P - 2, P) % P
    x = pow(xx, (P + 3) // 8, P)
    if (x * x - xx) % P != 0:
        x = x * pow(2, (P - 1) // 4, P) % P
    if (x * x - xx) % P != 0:
        return None
    if (x & 1) != sign:
        x = P - x
    return x


_BY = 4 * pow(5, P - 2, P) % P
_BX = _recover_x(_BY, 0)
# The base point, in extended coordinates (X, Y, Z, T) with T = XY/Z.
B = (_BX, _BY, 1, _BX * _BY % P)


def _add(p, q):
    """add-2008-hwcd-3, the a = -1 addition.  Ten multiplications."""
    x1, y1, z1, t1 = p
    x2, y2, z2, t2 = q
    a = (y1 - x1) * (y2 - x2) % P
    b = (y1 + x1) * (y2 + x2) % P
    c = 2 * t1 * t2 * D % P
    dd = 2 * z1 * z2 % P
    e, f, g, h = b - a, dd - c, dd + c, b + a
    return (e * f % P, g * h % P, f * g % P, e * h % P)


def _mul(s, p):
    """Scalar multiplication, double-and-add over the bits of s."""
    q = (0, 1, 1, 0)  # the neutral element
    while s > 0:
        if s & 1:
            q = _add(q, p)
        p = _add(p, p)
        s >>= 1
    return q


def _encode_point(p):
    x, y, z, _ = p
    zi = pow(z, P - 2, P)
    x, y = x * zi % P, y * zi % P
    return int.to_bytes(y | ((x & 1) << 255), 32, "little")


def _clamp(h):
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8          # clear the low three bits, and the top one
    a |= 1 << 254                # set bit 254
    return a


def public_from_seed(seed):
    """The 32-byte ed25519 public key for a 32-byte seed."""
    if len(seed) != 32:
        raise ValueError("an ed25519 seed is 32 bytes")
    h = hashlib.sha512(seed).digest()
    return _encode_point(_mul(_clamp(h), B))


def sign(seed, message):
    """A 64-byte ed25519 signature over `message`."""
    if len(seed) != 32:
        raise ValueError("an ed25519 seed is 32 bytes")
    h = hashlib.sha512(seed).digest()
    a = _clamp(h)
    pub = _encode_point(_mul(a, B))
    r = int.from_bytes(hashlib.sha512(h[32:] + message).digest(), "little") % L
    rr = _encode_point(_mul(r, B))
    k = int.from_bytes(hashlib.sha512(rr + pub + message).digest(), "little") % L
    return rr + int.to_bytes((r + k * a) % L, 32, "little")


def verify(pub, message, signature):
    """True when `signature` is pub's signature over message.

    Only the console needs this -- the server does the verifying that matters.
    It is here so that the self-test can check signing against RFC 8032's
    vectors in both directions rather than only reproducing bytes.
    """
    if len(signature) != 64 or len(pub) != 32:
        return False
    y = int.from_bytes(pub, "little")
    sign_bit = (y >> 255) & 1
    x = _recover_x(y & ((1 << 255) - 1), sign_bit)
    if x is None:
        return False
    a = (P - x, y & ((1 << 255) - 1), 1, (P - x) * (y & ((1 << 255) - 1)) % P)
    s = int.from_bytes(signature[32:], "little")
    if s >= L:
        return False
    k = int.from_bytes(
        hashlib.sha512(signature[:32] + pub + message).digest(), "little") % L
    return _encode_point(_add(_mul(s, B), _mul(k, a))) == signature[:32]


# ------------------------------------------------------------------ nkeys ---
#
# NATS role prefixes are 5-bit values in the top of a byte, chosen so that the
# base32 encoding of the whole blob starts with a recognisable letter.

PREFIX = {
    "operator": 14 << 3,   # O
    "server":   13 << 3,   # N
    "cluster":   2 << 3,   # C
    "account":   0 << 3,   # A
    "user":     20 << 3,   # U
}
_SEED = 18 << 3            # S


def _crc16(data):
    """CCITT, poly 0x1021, init 0 -- what NATS appends, little-endian."""
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def _b32(raw):
    import base64
    return base64.b32encode(raw).decode("ascii").rstrip("=")


def _unb32(text):
    import base64
    pad = "=" * (-len(text) % 8)
    return base64.b32decode(text + pad)


def _wrap(prefix_bytes, key):
    body = prefix_bytes + key
    return _b32(body + int.to_bytes(_crc16(body), 2, "little"))


def _unwrap(text, n_prefix):
    raw = _unb32(text)
    body, crc = raw[:-2], int.from_bytes(raw[-2:], "little")
    if _crc16(body) != crc:
        raise ValueError("nkey checksum does not match -- it was mistyped or truncated")
    return body[:n_prefix], body[n_prefix:]


def encode_public(role, pub):
    """`U...` for a user, `A...` for an account, from a 32-byte public key."""
    if role not in PREFIX:
        raise ValueError("no such nkey role: %s" % role)
    return _wrap(bytes([PREFIX[role]]), pub)


def encode_seed(role, seed):
    """`SU...` for a user seed.  Two prefix bytes, because 5 bits do not divide 8."""
    if role not in PREFIX:
        raise ValueError("no such nkey role: %s" % role)
    role_byte = PREFIX[role]
    return _wrap(bytes([_SEED | (role_byte >> 5), (role_byte & 31) << 3]), seed)


def decode_seed(text):
    """(role, 32-byte seed) from an `S...` nkey.  Raises on anything else."""
    prefix, seed = _unwrap(text.strip(), 2)
    if prefix[0] & 0xF8 != _SEED:
        raise ValueError("that is not a seed -- a seed starts with S")
    role_byte = ((prefix[0] & 7) << 5) | ((prefix[1] >> 3) & 31)
    for name, value in PREFIX.items():
        if value == role_byte:
            if len(seed) != 32:
                raise ValueError("a seed carries 32 bytes, not %d" % len(seed))
            return name, seed
    raise ValueError("unknown nkey role in seed")


def decode_public(text):
    """(role, 32-byte public key) from a `U...`/`A...` nkey."""
    prefix, pub = _unwrap(text.strip(), 1)
    for name, value in PREFIX.items():
        if value == prefix[0]:
            if len(pub) != 32:
                raise ValueError("a public nkey carries 32 bytes, not %d" % len(pub))
            return name, pub
    raise ValueError("unknown nkey role: not a public nkey")


def new_seed(role="user"):
    """A fresh seed, from the system CSPRNG.  This is the only place one is made."""
    return encode_seed(role, os.urandom(32))


def public_of(seed_text):
    role, seed = decode_seed(seed_text)
    return encode_public(role, public_from_seed(seed))


def sign_nonce(seed_text, nonce):
    """What a client sends as `sig` in its CONNECT: base64url, unpadded."""
    import base64
    _role, seed = decode_seed(seed_text)
    return base64.urlsafe_b64encode(sign(seed, nonce)).decode("ascii").rstrip("=")


# -------------------------------------------------------------- self-test ---

_RFC8032 = [
    # (seed, public, message, signature) -- RFC 8032 §7.1, tests 1 and 2.
    ("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
     "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
     "",
     "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821"
     "590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"),
    ("4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb",
     "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
     "72",
     "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e"
     "43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"),
]


def self_test():
    """Every claim this module makes, checked.  Returns the number of checks."""
    checks = 0

    for seed_hex, pub_hex, msg_hex, sig_hex in _RFC8032:
        seed, pub = bytes.fromhex(seed_hex), bytes.fromhex(pub_hex)
        msg, sig = bytes.fromhex(msg_hex), bytes.fromhex(sig_hex)
        assert public_from_seed(seed) == pub, "RFC 8032 public key mismatch"
        assert sign(seed, msg) == sig, "RFC 8032 signature mismatch"
        assert verify(pub, msg, sig), "RFC 8032 signature did not verify"
        assert not verify(pub, msg + b"!", sig), "a bad message verified"
        checks += 4

    # The nkey encoding round-trips, and says which role it carries.
    for role in ("user", "account", "operator", "server", "cluster"):
        text = new_seed(role)
        back_role, seed = decode_seed(text)
        assert back_role == role, "seed role did not round-trip"
        assert len(seed) == 32
        pub_text = encode_public(role, public_from_seed(seed))
        assert decode_public(pub_text) == (role, public_from_seed(seed))
        assert public_of(text) == pub_text, "public_of disagreed with the long way"
        checks += 4

    # The human-visible shapes, because the console prints these and the
    # warden's config is read by people.
    user_seed = new_seed("user")
    assert user_seed.startswith("SU"), "a user seed starts with SU"
    assert public_of(user_seed).startswith("U"), "a user nkey starts with U"
    assert len(public_of(user_seed)) == 56, "a public nkey is 56 characters"
    assert new_seed("account").startswith("SA")
    checks += 4

    # A corrupted nkey is refused rather than silently accepted -- the CRC is
    # the reason the encoding has one.
    good = public_of(new_seed("user"))
    bad = good[:-1] + ("A" if good[-1] != "A" else "B")
    try:
        decode_public(bad)
    except ValueError:
        checks += 1
    else:
        raise AssertionError("a corrupted nkey was accepted")

    # Signing is deterministic, which is what makes ed25519 safe to use with
    # no entropy at signing time -- a Pi that just booted has very little.
    s = new_seed("user")
    assert sign_nonce(s, b"nonce") == sign_nonce(s, b"nonce")
    assert sign_nonce(s, b"nonce") != sign_nonce(s, b"other")
    checks += 2

    return checks


# -------------------------------------------------------------------- cli ---

USAGE = """copal_nkeys -- the grove's bus key format

  copal_nkeys.py new-seed [ROLE]     a fresh seed (default: user)
  copal_nkeys.py public SEED         the public nkey for a seed
  copal_nkeys.py sign SEED NONCE     sign a nonce, base64url as NATS wants it
  copal_nkeys.py self-test           RFC 8032 vectors and the encoding

A seed is a private key.  Print one only into a file you have already made
mode 0600, and never onto a network.
"""


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help", "help"):
        sys.stdout.write(USAGE)
        return 0
    verb = argv[1]
    try:
        if verb == "new-seed":
            role = argv[2] if len(argv) > 2 else "user"
            print(new_seed(role))
        elif verb == "public":
            print(public_of(argv[2]))
        elif verb == "sign":
            print(sign_nonce(argv[2], argv[3].encode()))
        elif verb in ("self-test", "--self-test"):
            n = self_test()
            print("copal_nkeys: %d checks passed" % n)
        else:
            sys.stderr.write("no such verb: %s\n" % verb)
            return 2
    except IndexError:
        sys.stderr.write("missing argument -- see --help\n")
        return 2
    except (ValueError, AssertionError) as exc:
        sys.stderr.write("error: %s\n" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
