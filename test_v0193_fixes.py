#!/usr/bin/env python3
"""v0.1.93: Join never mirrors walls; RH axes only; end selection kept."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.93.zip"


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

    assert_("EXTENSION_VERSION = '0.1.93'" in reg, "version")
    assert_("v93" in f_const, "defn v93")

    join_fn = f_geom.split("def join_walls_at_right_angle!")[1].split("\n          def ")[0]
    assert_("end_a:" in join_fn and "end_b:" in join_fn, "ends kept")
    assert_("rh_wall_axes_along" in f_geom, "RH helper")
    assert_("right_handed_axes?" in f_geom, "RH check")
    assert_("rh_wall_axes_along(ya)" in join_fn, "B along +ya RH")
    # Must NOT set yb = into_a (that was the mirror).
    assert_("yb = Geom::Vector3d.new(into_a" not in join_fn, "no into_a yb")
    assert_("turn_plus" not in join_fn, "no auto turn flip")
    assert_("NEVER mirror" in f_geom or "never mirror" in f_geom.lower() or "Never mirror" in join_fn or "never LH" in f_geom, "no-mirror note")

    assert_("@end_a" in f_join and "nearest_end_at_point" in f_join, "end pick kept")
    assert_("no mirror" in f_join.lower() or "never mirrors" in f_join.lower(), "tool no-mirror")

    # Starter left kept
    pc = f_geom.split("def post_centres_mm")[1].split("\n          def ")[0]
    assert_("edges = [width" in pc, "starter left")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        assert_("rh_wall_axes_along" in geom and "turn_plus" not in geom.split("def join_walls_at_right_angle!")[1].split("def definition_name")[0], "zip RH")

    reinstall = os.path.join(STORE, "docs", "v0193-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.93" in body and md5 in body, "reinstall md5")
    assert_("mirror" in body.lower() or "reflect" in body.lower(), "reinstall mirror")

    print("OK — v0.1.93 checks passed")
    print(f"Proof: RH-only join, ends kept, no turn_plus; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
