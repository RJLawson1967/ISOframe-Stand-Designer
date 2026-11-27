#!/usr/bin/env python3
"""v0.1.73: Oval Counter upright bake (+90° X); Add Artwork/tables untouched."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.73.zip"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    counters = read("isoframe_stand_designer/counters.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    place = read("isoframe_stand_designer/tools/place_counter.rb")

    assert_("EXTENSION_VERSION = '0.1.73'" in reg, "version 0.1.73")
    assert_("ISOframe Counter Oval v73" in counters, "defn v73")
    assert_("OVAL_UPRIGHT_ROT_X_DEG = 90.0" in counters, "locked +90 X")
    assert_("def upright_sit_transform" in counters, "upright helper")
    assert_("upright_sit_transform(src" in counters, "bake uses upright")

    # Place tool still translation-only at click (orientation baked into def).
    assert_("Geom::Transformation.new(origin)" in place, "place at floor origin")

    # Do not regress Add Artwork / table place
    assert_("def prompt_and_add!" in artwork, "Add Artwork kept")
    body_start = tables.index("def keyboard_definition!(model, entry)")
    rest = tables[body_start + 10 :]
    m = re.search(r"\n      def ", rest)
    body = tables[body_start : body_start + 10 + m.start()]
    assert_("ensure_graphic_wrap_target!(" not in body, "no wrap on table place")

    oval = os.path.join(ROOT, "isoframe_stand_designer", "models", "Oval_Counter.skp")
    assert_(os.path.isfile(oval), "Oval_Counter.skp present")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"zip missing: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        entry = "isoframe_stand_designer/models/Oval_Counter.skp"
        assert_(entry in zf.namelist(), "oval in zip")
        assert_(abs(zf.getinfo(entry).file_size - os.path.getsize(oval)) < 16, "size")

    md5 = hashlib.md5(open(zip_path, "rb").read()).hexdigest()
    print("OK — v0.1.73 checks passed")
    print(f"Proof: +90° X upright bake locked; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
