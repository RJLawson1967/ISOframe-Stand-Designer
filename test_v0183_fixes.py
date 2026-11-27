#!/usr/bin/env python3
"""v0.1.83: Fabric covers Al frame; all geometry Z≥0 (floorspace top)."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.83.zip"


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
    f_edge = read("isoframe_stand_designer/products/fabric/edge_snap_tool.rb")
    f_place = read("isoframe_stand_designer/products/fabric/place_tool.rb")
    html = read("isoframe_stand_designer/ui/dialog.html")

    assert_("EXTENSION_VERSION = '0.1.83'" in reg, "version 0.1.83")
    assert_("GRAPHIC_Z_BOT_MM = 0" in f_const, "fabric from Z=0")
    assert_("v83" in f_const, "defn prefix v83")
    assert_("add_box!" in f_geom, "explicit boxes")
    assert_("pushpull" not in f_geom, "no pushpull (Z flip risk)")
    assert_("z0 = 0 if z0 < 0" in f_geom, "clamp below floor")
    assert_("add_top_rail!" in f_geom, "top rail")
    assert_("module_base_z" in f_place, "place on floorspace top")
    assert_("run_fabric_place" in html and "run_fabric_edge_snap" in html, "place+snap kept")
    assert_("snap_height_key" in f_edge, "edge height snap kept")
    assert_("snap_width_mm" in f_edge, "edge width snap kept")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        assert_("isoframe_stand_designer/products/fabric/geometry.rb" in names, "geom in zip")
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode("utf-8")
        assert_("pushpull" not in geom, "zip geom no pushpull")
        assert_("GRAPHIC_Z_BOT_MM = 0" in zf.read(
            "isoframe_stand_designer/products/fabric/constants.rb"
        ).decode("utf-8"), "zip const Z bot 0")

    reinstall = os.path.join(STORE, "docs", "v0183-reinstall.md")
    assert_(os.path.isfile(reinstall), "v0183-reinstall.md")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.83" in body, "reinstall version")
    assert_(md5 in body, f"reinstall md5 {md5}")
    assert_("covers" in body.lower() or "cover" in body.lower(), "reinstall cover note")

    print("OK — v0.1.83 checks passed")
    print(f"Proof: fabric covers Al, Z≥0 boxes; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
