#!/usr/bin/env python3
"""v0.1.66: wrap texture must be VISIBLE (planar UV, no hide, correct face side)."""
from __future__ import annotations

import os
import sys

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

    assert_("EXTENSION_VERSION = '0.1.66'" in reg, "version 0.1.66")
    assert_("ISOframe Table Keyboard SKP v66" in tables, "def v66")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("Tables.follow_hosts!" in flex, "flex follow")
    assert_("SKP_GRAPHIC_WRAP = 'Keyboard_table_graphic_wrap.skp'" in tables, "wrap skp target")

    # Selection no longer dumps thousands of faces
    sel = tables.split("def select_graphic_wrap_front_faces", 1)[1].split("\n      def ", 1)[0]
    assert_("first(2500)" not in sel, "no 2500 dump cap")
    assert_("first(400)" in sel, "cap large faces reasonably")
    assert_("view_sign" in sel, "dominant outward side")

    # Paint path = wall-style visible texture
    assert_("def paint_graphic_wrap_front!" in artwork, "paint wrap front")
    assert_("def wrap_planar_uv_frame" in artwork, "planar UV frame")
    assert_("def ensure_table_wrap_material!" in artwork, "wrap material helper")
    assert_("def soften_smooth_graphic_front_edges!" in artwork, "soft without hide")
    pgw = artwork.split("def paint_graphic_wrap_front!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.material = material" in pgw, "sets face.material")
    assert_("face.back_material = material" in pgw, "opaque reverse")
    assert_("position_material" in pgw, "UV position")
    assert_("e.hidden = true" not in pgw, "paint path must not hide edges")
    assert_("soften_smooth_graphic_front_edges!" in pgw, "uses soft-only helper")
    assert_("apron_uv_mapping" not in pgw, "not cylindrical apron UV on wrap")

    soft = artwork.split("def soften_smooth_graphic_front_edges!", 1)[1].split(
        "\n      def ", 1
    )[0]
    assert_("e.soft = true" in soft, "soft edges")
    assert_("e.smooth = true" in soft, "smooth edges")
    # No assignment that hides edges (comments may mention hide).
    assert_("e.hidden =" not in soft.replace("Do not hide", ""), "must not hide (visibility)")
    # Legacy alias must delegate to soft-only helper
    sh = artwork.split("def soften_hide_graphic_front_edges!", 1)[1].split(
        "\n      def ", 1
    )[0]
    assert_("soften_smooth_graphic_front_edges!" in sh, "hide helper redirects to soft-only")

    em = artwork.split("def ensure_table_wrap_material!", 1)[1].split("\n      def ", 1)[0]
    assert_("mat.texture =" in em, "assigns texture")
    assert_("set_texture_size!" in em, "sets texture size")
    assert_("alpha = 1.0" in em, "opaque material")

    # Wall still dual-side wallpaper
    pfn = artwork.split("def paint_front_face!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.back_material = material" in pfn, "wall dual wallpaper")

    wrap = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_table_graphic_wrap.skp"
    )
    assert_(os.path.isfile(wrap), "wrap SKP still bundled")

    print("OK — v0.1.66 checks passed")
    print(
        "Proof: planar UV + texture.size + face.material; soft no-hide; "
        "no 2500 dump; wrap SKP kept; host-follow locked"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
