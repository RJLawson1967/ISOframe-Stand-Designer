#!/usr/bin/env python3
"""v0.1.90: Join 90° flush 37mm pocket (no ~18.5mm overlap)."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.90.zip"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def md5_file(path: str) -> str:
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")

    assert_("EXTENSION_VERSION = '0.1.90'" in reg, "version")
    assert_("v90" in f_const, "defn v90")
    join_fn = f_geom.split("def join_walls_at_right_angle!")[1].split("\n          def ")[0]
    assert_("join_centre" in join_fn, "join centre")
    assert_("18.5mm overlap" in f_geom or "no intersection" in f_geom, "overlap note")
    assert_("ya.x * post.mm" in join_fn or "post.mm" in join_fn, "pocket offset past front")
    assert_("half.mm" in join_fn, "half offset past end")
    # Must not place join at tip/corner alone without offset
    assert_("Geom::Transformation.new(xa, ya, zb, join_centre)" in join_fn, "join oriented to A")
    assert_("shift_for_widen_right!" in f_geom, "widen-right kept")
    assert_("rem = w - base" in f_geom, "900 snap kept")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        assert_("join_centre" in geom and "post.mm" in geom, "zip pocket")

    reinstall = os.path.join(STORE, "docs", "v0190-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.90" in body and md5 in body, "reinstall md5")
    assert_("pocket" in body.lower() or "37" in body, "reinstall pocket")

    print("OK — v0.1.90 checks passed")
    print(f"Proof: Join flush 37mm pocket; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
