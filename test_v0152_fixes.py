#!/usr/bin/env python3
"""v0.1.52 self-check: Keyboard_with_Extension.skp attach + separate table artwork."""
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
    const = read("isoframe_stand_designer/constants.rb")
    menu = read("isoframe_stand_designer/ui/menu.rb")
    dialog = read("isoframe_stand_designer/ui/dialog.rb")
    html = read("isoframe_stand_designer/ui/dialog.html")

    assert_("EXTENSION_VERSION = '0.1.52'" in reg, "version must be 0.1.52")

    # Authoritative SKP
    assert_("Keyboard_with_Extension.skp" in tables, "must use Keyboard_with_Extension.skp")
    assert_("ISOframe Table Keyboard SKP v52" in tables, "fresh baked def name v52")
    assert_("add_prism!" not in tables, "no procedural table remodel")
    assert_("discover_attach_local" in tables, "SKP pair attach discovery")
    assert_("attach_local_plausible?" in tables, "reject tipped/far transforms")
    assert_("bay_center_upright_fallback" in tables, "upright fallback if pair fails")
    assert_("1500.mm" in tables, "plausible origin cap tightened vs 2.5m bug")

    # Attach onto existing module; detach leaves module + Flex restore
    assert_("place_table_instance!" in tables, "sibling table instance")
    assert_("erase_flexi_beam!" in tables, "remove Flex-link on attach")
    assert_("handle_table_erased!" in tables, "Delete table restores host")
    assert_("rebuild_definition!" in tables, "detach rebuilds host (Flex back)")
    assert_("KEY_TABLE_HOST" in const, "host link attr")

    # Separate under-table artwork (wall wallpaper untouched)
    assert_("KEY_TABLE_ARTWORK_PATH" in const, "table artwork path attr")
    assert_("prompt_and_apply_table!" in artwork, "table artwork prompt")
    assert_("map_table_instance!" in artwork, "paint under-table graphic")
    assert_("TableGraphicHint" in tables, "stable under-table graphic tag")
    assert_("Apply Artwork paints one photo" in html or "Apply Artwork" in html, "wall artwork retained")
    assert_("run_table_artwork" in dialog and "run_table_artwork" in html, "panel table artwork")
    assert_("Apply Table Artwork" in menu, "menu table artwork")

    skp = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    assert_(os.path.isfile(skp), "Keyboard_with_Extension.skp bundled")
    assert_(os.path.getsize(skp) > 1_000_000, "SKP looks complete")

    # Locked prefs: lights / graphic thickness / bend not touched this release
    lights = read("isoframe_stand_designer/lights.rb")
    geom = read("isoframe_stand_designer/geometry.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")
    assert_("GEOM_VERSION = 30" in geom, "graphic 3mm geom version locked")

    print("OK — v0.1.52 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
