#!/usr/bin/env python3
"""v0.1.91: outer-corner join per plan + starter packs viewer-left."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.91.zip"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def md5_file(path: str) -> str:
    return hashlib.md5(open(path, "rb").read()).hexdigest()


def simulate_post_centres(width: float, segs: list[float], half: float = 18.5) -> list[float]:
    """Mirror of Geometry.post_centres_mm packing (starter at left)."""
    edges = [float(width)]
    for s in segs:
        edges.append(edges[-1] - float(s))
    centres = []
    for i, e in enumerate(edges):
        if i == 0:
            centres.append(width - half)
        elif i == len(edges) - 1:
            centres.append(half)
        else:
            centres.append(e)
    return list(reversed(centres))


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")

    assert_("EXTENSION_VERSION = '0.1.91'" in reg, "version")
    assert_("v91" in f_const, "defn v91")

    # Starter packs from viewer-left (local width), not from local 0.
    pc = f_geom.split("def post_centres_mm")[1].split("\n          def ")[0]
    assert_("width - half" in pc or "(width - half)" in pc, "left end post")
    assert_("edges = [width" in pc, "edges from left")
    assert_("centres.reverse" in pc, "ascending centres")

    # First extension post 900 mm from left edge.
    c1150 = simulate_post_centres(1150.0, [900.0, 250.0])
    assert_(abs(c1150[0] - 18.5) < 1e-6, f"right post {c1150}")
    assert_(abs(c1150[1] - 250.0) < 1e-6, f"ext post {c1150}")
    left_edge = 1150.0
    assert_(abs(left_edge - c1150[1] - 900.0) < 1e-6, "900 from left edge")
    c900 = simulate_post_centres(900.0, [900.0])
    assert_(abs(c900[0] - 18.5) < 1e-6 and abs(c900[1] - 881.5) < 1e-6, f"starter {c900}")

    # Join: outer corner (offset -xa only), not past +ya by a full post.
    join_fn = f_geom.split("def join_walls_at_right_angle!")[1].split("\n          def ")[0]
    assert_("OUTER corner" in f_geom or "outer corner" in f_geom.lower() or "Outer-corner" in join_fn, "outer note")
    assert_("join_centre" in join_fn, "join centre")
    # Must NOT offset join by +ya * post (v0.1.90 front pocket).
    assert_("ya.x * post.mm" not in join_fn and "ya.y * post.mm" not in join_fn, "no front-pocket offset")
    assert_("xa.x * half.mm" in join_fn, "past-end offset")
    # Graphic of B faces +xa (inside).
    assert_("yb = Geom::Vector3d.new(xa.x, xa.y, 0)" in join_fn, "B graphic inside")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        assert_("edges = [width" in geom, "zip left pack")
        assert_("ya.x * post.mm" not in geom.split("def join_walls_at_right_angle!")[1].split("def definition_name")[0], "zip no front pocket")

    reinstall = os.path.join(STORE, "docs", "v0191-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.91" in body and md5 in body, "reinstall md5")
    assert_("outer" in body.lower() and "900" in body, "reinstall content")
    assert_(os.path.isfile(os.path.join(STORE, "media/fabric/join-90-plan.png")), "plan png")

    print("OK — v0.1.91 checks passed")
    print(f"Proof: starter-left centres {c1150}; join outer pocket; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
