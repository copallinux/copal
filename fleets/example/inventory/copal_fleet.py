#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson
"""Ansible dynamic inventory for the Copal fleet '@FLEET@'.

It is a shim, on purpose. Everything that decides WHICH MACHINES ARE IN THIS
FLEET -- browsing mDNS, dropping strangers and wrong-fleet beacons, and
checking each candidate's host certificate against the fleet CA -- lives in
`copal fleet inventory --json`, and this asks that. Two implementations of
"which machines may we run commands on" is one implementation too many, and
the one that would go stale is the one written in a language the rest of the
fleet is not written in.

The consequence worth knowing: this inventory contains ENROLLED nodes only.
A machine that is announcing but has never been signed does not appear here,
and that is the invariant rather than an oversight -- an inventory is a list of
machines Ansible is about to execute on, and a candidate has proved nothing.
`copal fleet ls` is where you look at candidates; `copal fleet enrol` is what
moves one into this file.

  ./copal_fleet.py --list        every host, with its facts
  ./copal_fleet.py --host NAME   nothing: --list already carries _meta
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def find_copal():
    """The `copal` front door: an override, the checkout this file is in, PATH."""
    override = os.environ.get("COPAL")
    if override:
        return [override]
    # fleets/<name>/inventory/copal_fleet.py -> the repository root is three up.
    root = Path(__file__).resolve().parents[3]
    local = root / "copal"
    if local.is_file():
        return [str(local)]
    return ["copal"]


def main():
    args = sys.argv[1:]
    if "--host" in args:
        # Every fact is already in _meta.hostvars from --list, which is one
        # browse and one certificate check instead of one per host.
        print("{}")
        return 0
    if "--list" not in args:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    cmd = find_copal() + ["fleet", "inventory", "--json"]
    fleet = os.environ.get("COPAL_FLEET")
    if fleet:
        cmd += ["--fleet", fleet]

    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        print("cannot find the `copal` command -- set COPAL=/path/to/copal",
              file=sys.stderr)
        return 1
    except subprocess.TimeoutExpired:
        print("`copal fleet inventory` did not finish in 120s", file=sys.stderr)
        return 1

    if out.returncode != 0:
        # Loudly, and non-zero. An inventory that FAILED and an inventory that
        # is EMPTY are different facts, and a playbook that runs happily on
        # nothing because discovery broke is the failure this prevents.
        sys.stderr.write(out.stderr)
        print("`copal fleet inventory` failed -- refusing to hand Ansible a "
              "guess about which machines exist", file=sys.stderr)
        return out.returncode

    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError as exc:
        print(f"`copal fleet inventory --json` did not return JSON: {exc}",
              file=sys.stderr)
        return 1

    hosts = data.get("_meta", {}).get("hostvars", {})
    if not hosts:
        print("no enrolled node in this fleet -- `copal fleet ls` will say "
              "whether anything is announcing, `copal fleet enrol` signs it",
              file=sys.stderr)
    json.dump(data, sys.stdout, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
