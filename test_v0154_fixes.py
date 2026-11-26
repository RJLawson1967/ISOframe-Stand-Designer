#!/usr/bin/env python3
"""v0.1.54 self-check: keyboard table attach orientation correction."""
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

    assert_("EXTENSION_VERSION = '0.1.54'" in reg, "version must be 0.1.54")
    assert_("ISOframe Table Keyboard SKP v54" in tables, "fresh baked def v54")
    assert_("apply_keyboard_orientation_correction" in tables, "orientation helper")
    assert_("Keyboard_with_Extension.skp" in tables, "authoritative SKP")

    # Exact rotation order / axes from Richard
    assert_("-90.0 * Math::PI / 180.0" in tables, "−90° about +X (CW from right)")
    assert_("180.0 * Math::PI / 180.0" in tables, "180° about +Z (from above)")
    assert_("r_from_above * r_from_right * local" in tables, "apply right then above")
    assert_(
        "apply_keyboard_orientation_correction(local)" in tables,
        "correction applied after discover",
    )

    # Attach/detach + name match from v0.1.53 must remain
    assert_("KB_WRAP_RE" in tables, "wrap def regex kept")
    assert_("resolve_keyboard_source" in tables, "source resolve kept")
    assert_("KEY_TABLE_HOST" in tables or "Constants::KEY_TABLE_HOST" in tables, "host attr")

    skp = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    assert_(os.path.isfile(skp), "SKP bundled")

    # Locks unchanged
    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.54 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
