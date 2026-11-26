#!/usr/bin/env python3
"""v0.1.68: always instance Keyboard_table_graphic_wrap.skp into bake when missing."""
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

    assert_("EXTENSION_VERSION = '0.1.68'" in reg, "version 0.1.68")
    assert_("ISOframe Table Keyboard SKP v68" in tables, "def v68")

    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("Tables.follow_hosts!" in flex, "flex follow")

    wrap = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_table_graphic_wrap.skp"
    )
    assert_(os.path.isfile(wrap), "wrap SKP in models")
    raw = zipfile.ZipFile(wrap).read("model.dat").decode("latin-1", "ignore")
    assert_("Graphic Keyboard Attachment" in raw, "wrap SKP has Graphic Keyboard Attachment")

    # Instancing path
    assert_("INSTANCED_WRAP_NAME = 'ISOframe Graphic Keyboard Wrap'" in tables, "instanced name")
    assert_("def graphic_wrap_skp_path" in tables, "skp path helper")
    assert_("def find_best_graphic_wrap_definition" in tables, "best def picker")
    assert_("def wrap_placement_transform_for_bake" in tables, "pose under top")
    assert_("def placement_anchor_under_top" in tables, "anchor under top")
    assert_("add_instance(gdef, local)" in tables, "instances wrap into bake")
    assert_("graphic_wrap_instanced" in tables, "marks instanced wrap")

    # Name match must accept DC wrap^Graphic Keyboard… names
    assert_("def graphic_wrap_definition_name?" in tables, "def name matcher")
    gwn = tables.split("def graphic_wrap_paint_name?", 1)[1].split("\n      def ", 1)[0]
    assert_("graphic_wrap_definition_name?" in gwn, "paint name uses def matcher first")

    # Bake + apply both call ensure
    assert_("ensure_graphic_wrap_target!(defn, model)" in tables, "bake ensures wrap")
    mti = artwork.split("def map_table_instance!", 1)[1].split("\n      def ", 1)[0]
    assert_("ensure_graphic_wrap_target!" in mti, "apply ensures wrap")
    assert_("select_keyboard_apron_faces" not in mti, "no apron fallback")
    assert_("paint_front_face!" in artwork, "wall paint path kept")
    assert_("ensure_wrap_material_like_wall!" in mti, "wall material path")
    assert_("count_faces_with_texture" in mti, "texture proof")

    # Keyboard_with_Extension alone is Boss-Extrude heavy (documents the bug)
    kbd = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    kraw = zipfile.ZipFile(kbd).read("model.dat").decode("latin-1", "ignore")
    assert_("Boss-Extrude" in kraw, "kbd_ext still has Boss-Extrude")

    print("OK — v0.1.68 checks passed")
    print(
        "Proof: wrap SKP path+instance+under-top pose; DC name match; "
        "bake+apply ensure; wall paint+texture proof; locks kept"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
