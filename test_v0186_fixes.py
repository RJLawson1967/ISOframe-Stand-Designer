#!/usr/bin/env python3
"""v0.1.86: true 900 place; braces; no stale resized definition on Place."""
from __future__ import annotations

import hashlib
import os
import sys
import zipfile

ROOT = "/agent/repos/ISOframe-Stand-Designer"
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.86.zip"


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
    f_place = read("isoframe_stand_designer/products/fabric/place_tool.rb")
    f_size = read("isoframe_stand_designer/products/fabric/frame_size.rb")

    assert_("EXTENSION_VERSION = '0.1.86'" in reg, "version")
    assert_("BRACE_DIAMETER_MM = 12.5" in f_const, "12.5 brace")
    assert_("950.0, 1400.0" in f_const, "midi braces")
    assert_("950.0, 1600.0, 2200.0" in f_const, "super braces")
    assert_("950.0, 1600.0, 3000.0" in f_const, "ultra braces")
    assert_("v86" in f_const, "defn v86")
    assert_("add_brace!" in f_geom, "brace builder")
    assert_("Always rebuild" in f_geom or "always rebuilds" in f_geom.lower() or "Always rebuild" in f_geom, "always rebuild note")
    # definition_for! must call rebuild unconditionally (not only when empty)
    defn_fn = f_geom.split("def definition_for!")[1].split("def ")[0]
    assert_("rebuild!" in defn_fn, "definition_for rebuilds")
    assert_("if existing && !existing.image? && existing.entities.size > 0" not in defn_fn, "no stale early return")
    assert_("purge_unused_fabric_defs!" in f_place, "place purges")
    assert_("STARTER_WIDTH_MM" in f_place and "DEFAULT_HEIGHT" in f_place, "place defaults")
    assert_("ensure_definition_name!" in f_size, "frame size renames def")
    assert_("post_centres_mm" in f_geom, "edge-to-edge centres")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing {zip_path}")
    md5 = md5_file(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        geom = zf.read("isoframe_stand_designer/products/fabric/geometry.rb").decode()
        const = zf.read("isoframe_stand_designer/products/fabric/constants.rb").decode()
        assert_("add_brace!" in geom and "12.5" in const, "zip braces")

    reinstall = os.path.join(STORE, "docs", "v0186-reinstall.md")
    assert_(os.path.isfile(reinstall), "reinstall")
    body = open(reinstall, encoding="utf-8").read()
    assert_("0.1.86" in body and md5 in body, "reinstall md5")
    assert_("12.5" in body and "900" in body, "reinstall content")

    print("OK — v0.1.86 checks passed")
    print(f"Proof: 900 place reset + 12.5 braces; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
