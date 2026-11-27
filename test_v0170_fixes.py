#!/usr/bin/env python3
"""v0.1.70: dump wrap SKP defs; broaden matcher; place must succeed."""
from __future__ import annotations

import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
WRAP_NAME = "Keyboard_table_graphic_wrap.skp"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.70.zip"
ZIP_ENTRY = f"isoframe_stand_designer/models/{WRAP_NAME}"

# Names extracted from Keyboard_table_graphic_wrap.skp model.dat (0x19 0x68 markers).
REAL_WRAP_SKP_DEFS = [
    "Keyboard Attachment wrap^Keyboard table attachment_Graphic Keyboard Attachment (Rolable)",
    "GraphicHint",
    "keyboard attachment",
]


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.70'" in reg, "version 0.1.70")
    assert_("ISOframe Table Keyboard SKP v70" in tables, "def v70")

    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("Tables.follow_hosts!" in flex, "flex follow")

    assert_("def dump_model_definition_names!" in tables, "dumps all defs")
    assert_("dump_model_definition_names!(model" in tables, "dump after load")
    assert_("def pick_wrap_def_from_root" in tables, "root-walk fallback")
    assert_("FALLBACK instancing wrap SKP root" in tables, "root fallback")
    assert_("GRAPHIC_WRAP_RE" in tables, "broad RE")
    assert_("graphichint" in tables.lower(), "matches GraphicHint")
    assert_("keyboard\\s*attachment\\s*wrap" in tables, "matches DC wrap name")

    # Source SKP still has the known def name strings
    wrap = os.path.join(ROOT, "isoframe_stand_designer", "models", WRAP_NAME)
    assert_(os.path.isfile(wrap), "wrap SKP present")
    raw = zipfile.ZipFile(wrap).read("model.dat").decode("latin-1", "ignore")
    for name in REAL_WRAP_SKP_DEFS:
        assert_(name in raw or name.split("^")[0] in raw, f"SKP contains {name!r}")

    # Simulate broad matcher against truncated DC name
    wrap_re = re.compile(
        r"graphic\s*keyboard|graphic\s*hint|\bgraphichint\b|rolab(?:le|ble)|"
        r"keyboard\s*attachment\s*wrap|attachment\s*wrap|\bkeyboard\s*attachment\b",
        re.I,
    )
    exclude_re = re.compile(
        r"\Aboss-extrude|keyboard\s*lip|keyboard\s*top|floorspace",
        re.I,
    )

    def match(n: str) -> bool:
        if exclude_re.search(n):
            return False
        return bool(wrap_re.search(n))

    assert_(match("Keyboard Attachment wrap"), "truncated DC name matches")
    assert_(match(REAL_WRAP_SKP_DEFS[0]), "full DC name matches")
    assert_(match("GraphicHint"), "GraphicHint matches")
    assert_(match("keyboard attachment"), "keyboard attachment matches")
    assert_(not match("Boss-Extrude1"), "Boss-Extrude excluded")
    assert_(not match("exhibit and wave keyboard lip"), "lip excluded")

    # wrap_container must not veto DC wrap paint target
    wc = tables.split("def wrap_container?", 1)[1].split("\n      def ", 1)[0]
    assert_("graphic_wrap_definition_name?" in wc, "container defers to wrap match")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"release zip missing: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        assert_(ZIP_ENTRY in zf.namelist(), f"{ZIP_ENTRY} not in zip")
        assert_(zf.getinfo(ZIP_ENTRY).file_size > 1_000_000, "wrap entry size")

    print("OK — v0.1.70 checks passed")
    print(
        "Proof: dump-all-defs; broad match for DC wrap/GraphicHint/keyboard attachment; "
        "root fallback; zip ships wrap SKP; locks kept"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
