#!/usr/bin/env python3
"""v0.1.85: Fabric outer-to-outer width; bottom rail coplanar with posts."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.85.zip"


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
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")
    html = read("isoframe_stand_designer/ui/dialog.html")

    assert_("EXTENSION_VERSION = '0.1.85'" in reg, "version 0.1.85")
    assert_("v85" in f_const, "defn v85")
    assert_("post_centres_mm" in f_geom, "outer-to-outer centres")
    assert_("width - half" in f_geom or "(width - half)" in f_geom, "end post inset")
    assert_("add_bottom_rail!" in f_geom, "coplanar bottom rail")
    assert_("add_bottom_rear_rail!" not in f_geom, "no offset rear rail")
    # Bottom rail uses same Y as posts (−half … +half), not behind.
    assert_("def add_bottom_rail!" in f_geom, "bottom rail def")
    bot = f_geom.split("def add_bottom_rail!")[1].split("def ")[0]
    assert_("y1 - rail" not in bot and "y0 = y1 - rail" not in bot, "bottom not offset in Y")
    assert_("Geom::Point3d.new(x_c0 - half, -half, 0)" in bot, "bottom Y matches posts")
    assert_("run_fabric_frame_size" in html and "run_fabric_place" in html, "frame size kept")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode("utf-8")
        assert_("post_centres_mm" in geom, "zip centres")
        assert_("add_bottom_rear_rail!" not in geom, "zip no offset rail")

    reinstall = os.path.join(STORE, "docs", "v0185-reinstall.md")
    assert_(os.path.isfile(reinstall), "v0185-reinstall.md")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.85" in body and md5 in body, "reinstall md5/version")
    assert_("900" in body and "outer" in body.lower(), "reinstall outer width")

    print("OK — v0.1.85 checks passed")
    print(f"Proof: outer-to-outer 900 + coplanar bottom rail; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
