#!/usr/bin/env python3
"""v0.1.56: keyboard placement offsets + keyboard-lip artwork target."""
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

    assert_("EXTENSION_VERSION = '0.1.56'" in reg, "version must be 0.1.56")
    assert_("ISOframe Table Keyboard SKP v56" in tables, "fresh baked def v56")

    # Placement offsets (Wave-local)
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "19.5 mm closer")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "19.6 mm left")
    assert_("placement_offset_transform" in tables, "placement helper")
    assert_("PLACE_LEFT_MM.mm, -PLACE_CLOSER_MM.mm, 0" in tables, "+X left, −Y closer")
    assert_("cache_attach_local!(model, placement_offset_transform)" in tables, "cache offset")

    # Orientation stack kept
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation kept")

    # Artwork root-cause fix: keyboard lip (not Wave GraphicHint)
    assert_("keyboard\\s*lip" in tables, "lip in graphic regex")
    assert_("find_keyboard_lip_entity" in tables, "lip finder")
    assert_("synthesize_table_graphic_panel!" in tables, "synthesize fallback")
    assert_("explode_nested_instances_once!" in tables, "explode nested for faces")
    assert_("under-table apron is SKP" in artwork or "keyboard lip" in artwork, "artwork documents lip")
    assert_("Tables.find_keyboard_lip_entity" in artwork, "apply uses lip finder")
    assert_("Tables.ensure_table_graphic_group!" in artwork, "ensure at apply")

    # Documented root cause present
    assert_("Wave modules" in tables or "wall-only" in artwork or "wall panels" in tables,
            "documents GraphicHint are wall-only")

    skp = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    assert_(os.path.isfile(skp), "SKP bundled")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.56 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
