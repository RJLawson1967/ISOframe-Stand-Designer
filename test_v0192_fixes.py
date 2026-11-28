#!/usr/bin/env python3
"""v0.1.92: Join 90° chooses left/right mating ends; L flips either way."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.92.zip"


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
    f_join = read("isoframe_stand_designer/products/fabric/join_tool.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")

    assert_("EXTENSION_VERSION = '0.1.92'" in reg, "version")
    assert_("v92" in f_const, "defn v92")

    join_fn = f_geom.split("def join_walls_at_right_angle!")[1].split("\n          def ")[0]
    assert_("end_a:" in join_fn and "end_b:" in join_fn, "end kwargs")
    assert_("nearest_end_at_point" in f_geom, "nearest end helper")
    assert_("tip_world_for_end" in f_geom, "tip for end")
    assert_("outward" in join_fn and "into_a" in join_fn, "outward/into")
    assert_("turn_plus" in join_fn, "L flip from B side")
    # Starter left kept
    pc = f_geom.split("def post_centres_mm")[1].split("\n          def ")[0]
    assert_("edges = [width" in pc and "centres.reverse" in pc, "starter left")

    assert_("@end_a" in f_join and "@end_b" in f_join, "tool ends")
    assert_("nearest_end_at_point" in f_join, "tool picks nearest")
    assert_("LEFT or RIGHT" in f_join, "status mentions ends")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        tool = zf.read("isoframe_stand_designer/products/fabric/join_tool.rb").decode()
        assert_("end_a:" in geom and "@end_a" in tool, "zip ends")

    reinstall = os.path.join(STORE, "docs", "v0192-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.92" in body and md5 in body, "reinstall md5")
    assert_("left" in body.lower() and "right" in body.lower(), "reinstall ends")

    print("OK — v0.1.92 checks passed")
    print(f"Proof: join end_a/end_b + nearest tip; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
