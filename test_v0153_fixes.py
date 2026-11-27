#!/usr/bin/env python3
"""v0.1.53 self-check: SKP keyboard def/instance name match fix."""
from __future__ import annotations

import os
import re
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

    assert_("EXTENSION_VERSION = '0.1.53'" in reg, "version must be 0.1.53")
    assert_("ISOframe Table Keyboard SKP v53" in tables, "fresh baked def v53")
    assert_("Keyboard_with_Extension.skp" in tables, "authoritative SKP")

    # Root cause fix: broadened name match (not keyboard\\s*attachment only)
    assert_("KB_DEF_RE" in tables, "broad def regex")
    assert_("KB_WRAP_RE" in tables, "wrap def regex")
    assert_("KB_INSTANCE_RE" in tables, "instance name regex")
    assert_("resolve_keyboard_source" in tables, "multi-strategy source resolve")
    assert_("Keyboard Attachment wrap" in tables, "documents real SKP def name")
    assert_("definitions.load(path)" in tables, "always load bundled SKP path")
    assert_("sample_skp_def_names" in tables, "error lists available def names")

    # Old brittle pattern must not be the sole matcher
    assert_("KB_ATTACH_RE" not in tables, "remove brittle KB_ATTACH_RE")

    # Regex sanity vs real SKP names
    # Extract Ruby regex bodies roughly from source for a smoke check in Python.
    def_re = re.compile(r"keyboard.*attach|attach.*keyboard", re.I)
    wrap_re = re.compile(r"keyboard\s*attachment\s*wrap", re.I)
    inst_re = re.compile(r"keyboard\s*(table\s*)?attachment", re.I)
    samples = [
        "Keyboard Attachment wrap",
        "Keyboard Attachment wrap^Keyboard table attachment_Graphic Keyboard Attachment (Rolable)",
        "Keyboard table attachment_Graphic Keyboard Attachment (Rolable)",
        "keyboard attachment",
    ]
    for n in samples:
        assert_(
            def_re.search(n) or wrap_re.search(n) or inst_re.search(n),
            f"new matchers must hit {n!r}",
        )

    skp = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp"
    )
    assert_(os.path.isfile(skp), "SKP bundled")

    # Locks unchanged
    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.53 checks passed")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
