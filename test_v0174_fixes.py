#!/usr/bin/env python3
"""v0.1.74: soft/hide edges on SKP/OBJ imports; upright + table place locks kept."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.74.zip"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    geom = read("isoframe_stand_designer/geometry.rb")
    counters = read("isoframe_stand_designer/counters.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    lights = read("isoframe_stand_designer/lights.rb")
    mesh = read("isoframe_stand_designer/mesh_import.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")

    assert_("EXTENSION_VERSION = '0.1.74'" in reg, "version 0.1.74")
    assert_("def soften_definition_edges!" in geom, "shared soft helper")
    assert_("e.soft = true" in geom and "e.smooth = true" in geom and "e.hidden = true" in geom, "soft+smooth+hide")

    # Counters + tables + lights + mesh call shared helper
    assert_("Geometry.soften_definition_edges!(defn)" in counters, "counter bake soft")
    assert_("Geometry.soften_definition_edges!(existing)" in counters, "counter cache soft")
    assert_("Geometry.soften_definition_edges!(defn)" in tables, "table bake soft")
    assert_("Geometry.soften_definition_edges!(existing)" in tables, "table cache soft")
    assert_("Geometry.soften_definition_edges!(gdef)" in tables, "wrap soft")
    assert_("Geometry.soften_definition_edges!(defn)" in lights, "LED soft")
    assert_("def soften_definition_edges!" not in lights, "lights no local soften")
    assert_("Geometry.soften_definition_edges!(defn)" in mesh, "OBJ soft")

    # Locks kept
    assert_("OVAL_UPRIGHT_ROT_X_DEG = 90.0" in counters, "upright locked")
    assert_("def prompt_and_add!" in artwork, "Add Artwork kept")
    start = tables.index("def keyboard_definition!(model, entry)")
    rest = tables[start + 10 :]
    m = re.search(r"\n      def ", rest)
    body = tables[start : start + 10 + m.start()]
    assert_("ensure_graphic_wrap_target!(" not in body, "no wrap on table place")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        assert_("isoframe_stand_designer/models/Oval_Counter.skp" in zf.namelist(), "oval in zip")
        assert_("isoframe_stand_designer/geometry.rb" in zf.namelist(), "geometry in zip")

    md5 = hashlib.md5(open(zip_path, "rb").read()).hexdigest()
    print("OK — v0.1.74 checks passed")
    print(f"Proof: soft edges on counter/table/light/OBJ/wrap; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
