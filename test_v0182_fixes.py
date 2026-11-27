#!/usr/bin/env python3
"""v0.1.82: Fabric place-and-snap + shared floorspace above tabs."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.82.zip"
MD5_EXPECTED = "3f83abeb94f7f10cedd89db99125480a"


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
    constants = read("isoframe_stand_designer/constants.rb")
    constraints = read("isoframe_stand_designer/constraints.rb")
    f_const = read("isoframe_stand_designer/products/fabric/constants.rb")
    f_geom = read("isoframe_stand_designer/products/fabric/geometry.rb")
    f_place = read("isoframe_stand_designer/products/fabric/place_tool.rb")
    f_edge = read("isoframe_stand_designer/products/fabric/edge_snap_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.82'" in reg, "version 0.1.82")
    for rel in (
        "products/fabric/constants",
        "products/fabric/geometry",
        "products/fabric/place_tool",
        "products/fabric/edge_snap_tool",
        "products/fabric",
    ):
        assert_(rel in main_rb, f"main loads {rel}")

    # Shared floorspace above tabs
    assert_("New Job / Floorspace" in html.split('role="tablist"')[0], "floorspace above tabs")
    wave_panel = html.split('id="panel-wave"')[1].split('id="panel-fabric"')[0]
    assert_("run_floorspace" not in wave_panel, "floorspace not inside Wave panel")
    fabric_panel = html.split('id="panel-fabric"')[1].split('id="panel-lumen"')[0]
    assert_("run_fabric_place" in fabric_panel, "fabric place button")
    assert_("run_fabric_edge_snap" in fabric_panel, "fabric edge snap button")
    assert_("coming soon" in html.split('id="panel-lumen"')[1], "other shells empty")

    assert_("Floorspace.prompt_and_draw!" in dialog, "dialog shared floorspace")
    assert_("Products::Fabric.run_place_midi!" in dialog, "dialog fabric place")
    assert_("Products::Fabric.run_edge_snap!" in dialog, "dialog fabric snap")
    assert_("Products::Wave.run_starter!" in dialog, "wave still firewalled")

    assert_("install_fabric_submenu!" in menu, "fabric submenu")
    assert_("Products::Fabric.run_place_midi!" in menu, "menu fabric place")
    assert_("New Job / Floorspace" in menu, "menu shared floorspace")
    assert_("Products::Wave.run_floorspace!" not in menu, "wave menu no floorspace")

    # Fabric rules
    assert_("STARTER_WIDTH_MM = 900" in f_const, "900 starter")
    assert_("2270" in f_const and "2470" in f_const, "midi/maxi")
    assert_("3000" in f_const and "3470" in f_const, "super/ultra")
    assert_("1000" in f_const and "750" in f_const and "500" in f_const and "250" in f_const, "ext widths")
    assert_("POST_MM = 37" in f_const, "37mm posts")
    assert_("decompose_width_mm" in f_geom, "width compose")
    assert_("snap_height_key" in f_geom, "height snap")
    assert_("Tools::Flex" not in fabric and "FlexTool" not in fabric, "no flex facade")
    assert_("PlaceTool" in fabric and "EdgeSnapTool" in fabric, "fabric tools")
    assert_("TYPE_FABRIC_WALL" in constants, "type constant")
    assert_("fabric_wall?" in constraints, "floor clamp fabric")

    # Place / edge tools content
    assert_("900" in f_place and "2270" in f_place, "place midi sizes")
    assert_(":height" in f_edge and ":width" in f_edge, "edge modes")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    assert_(md5 == MD5_EXPECTED, f"md5 {md5} != {MD5_EXPECTED}")
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        for entry in (
            "isoframe_stand_designer.rb",
            "isoframe_stand_designer/products/fabric.rb",
            "isoframe_stand_designer/products/fabric/geometry.rb",
            "isoframe_stand_designer/products/fabric/place_tool.rb",
            "isoframe_stand_designer/products/fabric/edge_snap_tool.rb",
            "isoframe_stand_designer/ui/dialog.html",
        ):
            assert_(entry in names, f"{entry} in zip")

    reinstall = os.path.join(STORE, "docs", "v0182-reinstall.md")
    assert_(os.path.isfile(reinstall), "v0182-reinstall.md")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.82" in body, "reinstall version")
    assert_(md5 in body, f"reinstall md5 {md5}")
    assert_("Fabric" in body and "250" in body, "reinstall fabric snaps")

    print("OK — v0.1.82 checks passed")
    print(f"Proof: Fabric place+snap + shared floorspace; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
