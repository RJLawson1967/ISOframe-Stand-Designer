#!/usr/bin/env python3
"""v0.1.89: widen grows right; Fabric Join 90° + join post."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.89.zip"


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
    main_rb = read("isoframe_stand_designer/main.rb")
    html = read("isoframe_stand_designer/ui/dialog.html")
    dialog = read("isoframe_stand_designer/ui/dialog.rb")
    menu = read("isoframe_stand_designer/ui/menu.rb")
    fabric = read("isoframe_stand_designer/products/fabric.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")
    f_size = read("isoframe_stand_designer/products/fabric/frame_size.rb")
    constants = read("isoframe_stand_designer/constants.rb")

    assert_("EXTENSION_VERSION = '0.1.89'" in reg, "version")
    assert_("products/fabric/join_tool" in main_rb, "main loads join")
    assert_("run_fabric_join" in html, "join button")
    assert_("Products::Fabric.run_join!" in dialog, "dialog join")
    assert_("Join 90°" in menu, "menu join")
    assert_("run_join!" in fabric, "facade join")
    assert_("shift_for_widen_right!" in f_geom, "widen right helper")
    assert_("shift_for_widen_right!" in f_size, "frame size shifts")
    assert_("join_walls_at_right_angle!" in f_geom, "join helper")
    assert_("TYPE_FABRIC_JOIN" in constants, "join type")
    assert_("v89" in f_const, "defn v89")
    assert_("rem = w - base" in f_geom, "900 snap locked")
    assert_("'super_maxi' => [950.0, 1600.0, 2200.0]" in f_const, "super braces")
    assert_("'ultra_maxi' => [950.0, 1600.0, 2200.0, 3000.0]" in f_const, "ultra braces")
    assert_(os.path.isfile(os.path.join(ROOT, "isoframe_stand_designer/products/fabric/join_tool.rb")), "join_tool file")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        assert_("isoframe_stand_designer/products/fabric/join_tool.rb" in names, "join in zip")
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        assert_("shift_for_widen_right!" in geom and "join_walls_at_right_angle!" in geom, "zip geom")

    reinstall = os.path.join(STORE, "docs", "v0189-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.89" in body and md5 in body, "reinstall md5")
    assert_("RIGHT" in body or "right" in body, "reinstall right")
    assert_("90" in body, "reinstall join")

    print("OK — v0.1.89 checks passed")
    print(f"Proof: widen-right + Join 90°; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
