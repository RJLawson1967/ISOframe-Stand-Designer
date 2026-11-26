#!/usr/bin/env python3
"""v0.1.59: keyboard apron continuous UV + wall wallpaper front-only."""
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

    assert_("EXTENSION_VERSION = '0.1.59'" in reg, "version 0.1.59")
    assert_("ISOframe Table Keyboard SKP v59" in tables, "fresh def v59")

    # Locks unchanged
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode bake kept")

    # Apron-only selection
    assert_("TABLETOP_THICKNESS_MM = 15.0" in tables, "15mm top")
    assert_("select_keyboard_apron_faces" in tables, "apron selector")
    assert_("span <= edge_max_h" in tables or "edge_max_h" in tables, "exclude edge strip")
    assert_("paint_apron_continuous!" in artwork, "continuous UV")
    assert_("apron_uv_frame" in artwork, "UV frame")
    assert_("apron_u(" in artwork and "apron_v(" in artwork, "U angle / V height")
    assert_("apron.size > 8000" in artwork, "guard against 146k paint")
    assert_("find_keyboard_lip_entity" in artwork, "lip only path")

    # Must not use old per-face bay tiling for apron success path
    assert_("paint_apron_faces!" not in artwork or "paint_apron_continuous!" in artwork, "continuous preferred")

    # Wall front-only
    assert_("front_outward_normal_at" in artwork, "outward normal")
    assert_("n.dot(outward) > 0.25" in artwork, "front-facing filter")
    assert_("clear_non_front_wall_materials!" in artwork, "clear rear wallpaper")
    assert_("back_material = nil" in artwork, "no reverse-side wallpaper")
    assert_("Rear faces toward" in artwork or "framework / flex-link" in artwork, "docs rear unpainted")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.59 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
