#!/usr/bin/env python3
"""v0.1.84: Fabric Frame Size dialog; Edge Snap removed; bottom rear Al rail."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.84.zip"


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

    assert_("EXTENSION_VERSION = '0.1.84'" in reg, "version 0.1.84")
    assert_("products/fabric/frame_size" in main_rb, "main loads frame_size")
    assert_("edge_snap" not in main_rb, "main no edge_snap")
    assert_(not os.path.isfile(os.path.join(ROOT, "isoframe_stand_designer/products/fabric/edge_snap_tool.rb")), "edge_snap file gone")

    assert_("run_fabric_frame_size" in html, "frame size button")
    assert_("run_fabric_edge_snap" not in html, "no edge snap button")
    assert_("run_fabric_place" in html, "place kept")
    assert_("Products::Fabric.run_frame_size!" in dialog, "dialog frame size")
    assert_("run_fabric_edge_snap" not in dialog, "dialog no edge snap")
    assert_("Frame Size…" in menu or "Frame Size" in menu, "menu frame size")
    assert_("Products::Fabric.run_frame_size!" in menu, "menu frame size callback")
    assert_("run_edge_snap!" not in menu, "menu no edge snap callback")
    assert_("run_edge_snap!" not in fabric, "facade no edge snap")
    assert_("run_frame_size!" in fabric, "facade frame size")

    assert_("UI.inputbox" in f_size, "inputbox dialog")
    assert_("Midi 2270" in f_size and "Ultra-Maxi 3470" in f_size, "height choices")
    assert_("snap_width_mm" in f_size, "width snap")
    assert_("add_bottom_rear_rail!" in f_geom, "bottom rear rail")
    assert_("GROUP_RAIL_BOT" in f_const, "bot rail const")
    assert_("v84" in f_const, "defn v84")
    assert_("GRAPHIC_Z_BOT_MM = 0" in f_const, "fabric from Z=0")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        assert_("isoframe_stand_designer/products/fabric/frame_size.rb" in names, "frame_size in zip")
        assert_("isoframe_stand_designer/products/fabric/edge_snap_tool.rb" not in names, "no edge_snap in zip")
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode("utf-8")
        assert_("add_bottom_rear_rail!" in geom, "zip has bottom rail")

    reinstall = os.path.join(STORE, "docs", "v0184-reinstall.md")
    assert_(os.path.isfile(reinstall), "v0184-reinstall.md")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.84" in body, "reinstall version")
    assert_(md5 in body, f"reinstall md5 {md5}")
    assert_("Frame Size" in body, "reinstall frame size")
    assert_("Edge Snap" in body or "edge snap" in body.lower(), "reinstall notes removal")

    print("OK — v0.1.84 checks passed")
    print(f"Proof: Frame Size + bottom rear rail; Edge Snap gone; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
