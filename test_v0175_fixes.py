#!/usr/bin/env python3
"""v0.1.75: Media Screen Small/Large on straight S+E; flexilink stays."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.75.zip"
SKPS = ["Media_screen_-_small.skp", "Media_screen_-_Large.skp"]


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    screens = read("isoframe_stand_designer/screens.rb")
    dialog = read("isoframe_stand_designer/ui/dialog.html")
    dialog_rb = read("isoframe_stand_designer/ui/dialog.rb")
    menu = read("isoframe_stand_designer/ui/menu.rb")
    main_rb = read("isoframe_stand_designer/main.rb")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")
    constants = read("isoframe_stand_designer/constants.rb")

    assert_("EXTENSION_VERSION = '0.1.75'" in reg, "version")
    assert_("KEY_SCREEN_TYPE" in constants, "screen type key")
    assert_("SCREEN_CENTER_Z_MM = 1500.0" in screens, "1500 AFF")
    assert_("SCREEN_IN_FRONT_OF_GRAPHIC_MM = 50.0" in screens, "50mm front")
    assert_("erase_flexi_beam" not in screens, "flexilink stays")
    assert_("Geometry.soften_definition_edges!" in screens, "soft edges")
    assert_("Media Screen Small" in dialog and "Media Screen Large" in dialog, "panel")
    assert_("run_screen_small" in dialog_rb and "run_screen_large" in dialog_rb, "callbacks")
    assert_("Media Screen Small" in menu and "Media Screen Large" in menu, "menu")
    assert_("screens" in main_rb and "add_screen" in main_rb, "main loads")
    assert_("Screens.screen_on?" in flex, "flex blocks screen")
    assert_("def attach_local_transform" in screens, "attach math")
    assert_("hinge_center_local" in screens and "end_post_center_local" in screens, "bay centre")

    for name in SKPS:
        path = os.path.join(ROOT, "isoframe_stand_designer", "models", name)
        assert_(os.path.isfile(path), f"models/{name}")
        assert_(os.path.getsize(path) > 100_000, f"{name} size")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        for name in SKPS:
            entry = f"isoframe_stand_designer/models/{name}"
            assert_(entry in names, f"{entry} in zip")

    md5 = hashlib.md5(open(zip_path, "rb").read()).hexdigest()
    print("OK — v0.1.75 checks passed")
    print(f"Proof: Small+Large screens; 1500/50 locks; flexilink kept; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
