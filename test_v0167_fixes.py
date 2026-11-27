#!/usr/bin/env python3
"""v0.1.67: wrap paint must reuse wall path and prove face.material.texture non-nil."""
from __future__ import annotations

import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.67'" in reg, "version 0.1.67")
    assert_("ISOframe Table Keyboard SKP v67" in tables, "def v67")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("Tables.follow_hosts!" in flex, "flex follow")
    assert_("SKP_GRAPHIC_WRAP = 'Keyboard_table_graphic_wrap.skp'" in tables, "wrap SKP")

    wrap = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_table_graphic_wrap.skp"
    )
    assert_(os.path.isfile(wrap), "wrap SKP bundled")
    raw = zipfile.ZipFile(wrap).read("model.dat").decode("latin-1", "ignore")
    assert_("Graphic Keyboard Attachment" in raw, "wrap has Graphic Keyboard Attachment")

    # map_table_instance must NOT fall back to apron/2500
    mti = artwork.split("def map_table_instance!", 1)[1].split("\n      def ", 1)[0]
    assert_("select_keyboard_apron_faces" not in mti, "no apron fallback in map_table")
    assert_("2500" not in mti, "no 2500 in map_table")
    assert_("prepare_graphic_wrap_for_paint!" in mti, "prepare wrap")
    assert_("ensure_wrap_material_like_wall!" in mti, "wall-style material")
    assert_("map_wrap_faces_like_wall!" in mti, "wall-style face paint")
    assert_("count_faces_with_texture" in mti, "texture proof call")
    assert_("face.material.texture is nil" in mti or "texture is nil" in mti, "raises if texture nil")

    # Wall path reuse
    assert_("def ensure_wrap_material_like_wall!" in artwork, "ensure like wall")
    em = artwork.split("def ensure_wrap_material_like_wall!", 1)[1].split("\n      def ", 1)[0]
    assert_("mat.texture =" in em, "assigns texture")
    assert_("set_texture_size!" in em, "sets texture size like wall")
    assert_("mat.texture.nil?" in em, "checks texture non-nil")

    mw = artwork.split("def map_wrap_faces_like_wall!", 1)[1].split("\n      def ", 1)[0]
    assert_("paint_front_face!" in mw, "reuses paint_front_face! exactly")

    # paint_front_face still wall dual-side
    pfn = artwork.split("def paint_front_face!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.material = material" in pfn, "sets face.material")
    assert_("face.back_material = material" in pfn, "sets back_material")
    assert_("position_material" in pfn or "try_position_uv!" in pfn, "UV path")

    # Proof helper
    assert_("def count_faces_with_texture" in artwork, "count_faces_with_texture")
    cft = artwork.split("def count_faces_with_texture", 1)[1].split("\n      def ", 1)[0]
    assert_("m.texture" in cft, "checks material.texture")

    # Dialog reports texture size + material name
    att = artwork.split("def apply_to_table!", 1)[1].split("\n      def ", 1)[0]
    assert_("texture size=" in att, "dialog texture size")
    assert_("material=" in att, "dialog material name")
    assert_("textured=" in att, "dialog textured count")

    # make_unique nested
    assert_("def make_unique_wrap_tree!" in tables, "make_unique wrap tree")
    assert_("def prepare_graphic_wrap_for_paint!" in tables, "prepare wrap")

    # Simulated proof: wall material contract markers exist end-to-end
    assert_("def ensure_bay_material!" in artwork, "wall ensure still present")
    assert_("def set_texture_size!" in artwork, "shared set_texture_size")

    print("OK — v0.1.67 checks passed")
    print(
        "Proof: no apron/2500 fallback; wall ensure+paint_front_face reused; "
        "count_faces_with_texture required; dialog reports tex size+material; "
        "make_unique wrap tree; wrap SKP kept"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
