#!/usr/bin/env python3
"""v0.1.55: keyboard side-flip + Apply Table Artwork GraphicHint match."""
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

    assert_("EXTENSION_VERSION = '0.1.55'" in reg, "version must be 0.1.55")
    assert_("ISOframe Table Keyboard SKP v55" in tables, "fresh baked def v55")
    assert_("apply_keyboard_orientation_correction" in tables, "orientation helper")
    assert_("Keyboard_with_Extension.skp" in tables, "authoritative SKP")

    # Keep v0.1.54 rotations + v0.1.55 side flip
    assert_("-90.0 * Math::PI / 180.0" in tables, "−90° about +X kept")
    assert_("r_from_above" in tables, "180° about +Z kept")
    assert_("r_side_flip" in tables, "side-view flip")
    assert_(
        "r_side_flip * r_from_above * r_from_right * local" in tables,
        "order: right → above → side flip",
    )

    # Artwork / GraphicHint match (root cause of Apply Table Artwork failure)
    assert_("TABLE_GRAPHIC_FIND_RE" in tables, "broad find regex")
    assert_("graphic\\s*hint" in tables or "graphic\\s*hint" in tables.replace("\n", ""), "GraphicHint in TABLE_GRAPHIC_RE")
    assert_("table_graphic_name?" in tables, "shared name helper")
    assert_("ensure_table_graphic_group!" in tables, "ensure graphic group")
    assert_("create_table_graphic_hint_group!" in tables, "create fallback group")
    assert_("ensure_table_graphic_group!(defn" in tables, "ensure at bake")
    assert_("depth > 0" not in tables.split("walk_tag_graphics!")[1].split("def table_graphic_name?")[0],
            "no depth>0 GraphicHint skip in walk_tag")
    assert_("Tables.ensure_table_graphic_group!" in artwork, "ensure at apply time")
    assert_("Tables.table_graphic_name?" in artwork, "apply uses broad name match")

    skp = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    assert_(os.path.isfile(skp), "SKP bundled")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.55 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
