#!/usr/bin/env python3
"""v0.1.57: no synthetic table artwork panel; paint real keyboard lip."""
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

    assert_("EXTENSION_VERSION = '0.1.57'" in reg, "version must be 0.1.57")
    assert_("ISOframe Table Keyboard SKP v57" in tables, "fresh baked def v57")

    # Position lock unchanged
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("LOCKED v0.1.56" in tables, "offset lock comment")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation kept")

    # No synthesize
    assert_("def synthesize_table_graphic_panel!" not in tables, "synthesize method removed")
    assert_("synthesize_table_graphic_panel!" not in tables, "no synthesize calls")
    assert_("purge_synthetic_table_graphic_panels!" in tables, "purge synthetics")
    assert_("synthetic_table_graphic?" in tables, "synthetic detector")
    assert_("map_table_lip_faces!" in artwork, "paint lip facets")
    assert_("Refusing to paint synthetic flat panel" in artwork, "refuse synthetic")
    assert_("Tables.purge_synthetic_table_graphic_panels!" in artwork, "purge at apply")

    skp = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    assert_(os.path.isfile(skp), "SKP bundled")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    prefs = open(
        "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955/preferences.md",
        encoding="utf-8",
    ).read()
    assert_("19.6 mm" in prefs and "19.5 mm" in prefs, "prefs lock offsets")
    assert_("never synthesize" in prefs.lower() or "Never synthesize" in prefs or "never synthesize a flat" in prefs, "prefs artwork lock")

    print("OK — v0.1.57 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
