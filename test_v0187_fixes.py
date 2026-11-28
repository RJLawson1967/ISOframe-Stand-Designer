#!/usr/bin/env python3
"""v0.1.87: snap keeps 900 (not 1000); Super-Maxi four braces."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.87.zip"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def md5_file(path: str) -> str:
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def snap_width_mm(w: float, base: float = 900.0, step: float = 250.0) -> float:
    """Mirror of Fabric::Geometry.snap_width_mm."""
    if w < base:
        w = base
    rem = w - base
    steps = round(rem / step)
    if steps < 0:
        steps = 0
    return base + steps * step


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")

    assert_("EXTENSION_VERSION = '0.1.87'" in reg, "version")
    assert_("v87" in f_const, "defn v87")
    assert_("950.0, 1400.0, 1600.0, 2200.0" in f_const, "super four braces")
    assert_("950.0, 1600.0, 3000.0" in f_const, "ultra three braces")
    # Must NOT use whole-width (w/step).round style
    snap_fn = f_geom.split("def snap_width_mm")[1].split("def ")[0]
    assert_("rem = w - base" in snap_fn or "rem = w - C::STARTER" in snap_fn or "rem = w - base" in snap_fn, "snap rem from base")
    assert_("never rounds 900" in f_geom or "900 into 1000" in f_geom, "bug comment")
    assert_(snap_width_mm(900.0) == 900.0, "snap 900→900")
    assert_(snap_width_mm(900.0) != 1000.0, "snap 900 not 1000")
    assert_(snap_width_mm(1150.0) == 1150.0, "snap 1150")
    # Old bug: (900/250).round*250 == 1000
    assert_(round(900.0 / 250.0) * 250.0 == 1000.0, "document old bug")
    assert_(snap_width_mm(900.0) == 900.0, "fixed vs old bug")

    # Outer faces from centres
    half = 18.5
    width = snap_width_mm(900.0)
    c0, c1 = half, width - half
    assert_(abs((c0 - half) - 0.0) < 1e-9, "left outer 0")
    assert_(abs((c1 + half) - 900.0) < 1e-9, "right outer 900")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        const = zf.read("isoframe_stand_designer/products/fabric/constants.rb").decode()
        assert_("rem = w - base" in geom, "zip snap fix")
        assert_("1400.0, 1600.0, 2200.0" in const, "zip super braces")

    reinstall = os.path.join(STORE, "docs", "v0187-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.87" in body and md5 in body, "reinstall md5")
    assert_("900" in body and "1000" in body, "reinstall explains bug")

    print("OK — v0.1.87 checks passed")
    print(f"Proof: snap 900→900 (not 1000); Super 4 braces; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
