#!/usr/bin/env python3
"""v0.1.71: place = table SKP only; Semi/Square registered; zip ships all three SKPs."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.71.zip"
MODELS = [
    "Keyboard_with_Extension.skp",
    "Semi-circular_Table_Attachment.skp",
    "Square_Table_Attachment.skp",
]


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def keyboard_definition_body(tables: str) -> str:
    start = tables.index("def keyboard_definition!(model, entry)")
    rest = tables[start + 10 :]
    m = re.search(r"\n      def ", rest)
    assert_(m is not None, "keyboard_definition! body end")
    return tables[start : start + 10 + m.start()]


def main() -> int:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    dialog_html = read("isoframe_stand_designer/ui/dialog.html")
    dialog_rb = read("isoframe_stand_designer/ui/dialog.rb")
    menu = read("isoframe_stand_designer/ui/menu.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.71'" in reg, "version 0.1.71")
    assert_("ISOframe Table Keyboard SKP v71" in tables, "keyboard def v71")
    assert_("ISOframe Table Semi-circular SKP v71" in tables, "semi def v71")
    assert_("ISOframe Table Square SKP v71" in tables, "square def v71")

    # Registry + panel labels (Richard's names)
    assert_("'semi_circular'" in tables, "semi registry key")
    assert_("'square'" in tables, "square registry key")
    assert_("Semi-circular_Table_Attachment.skp" in tables, "semi skp")
    assert_("Square_Table_Attachment.skp" in tables, "square skp")
    assert_("Semi-circular table attachment" in dialog_html, "semi panel label")
    assert_("Square Table attachment" in dialog_html, "square panel label")
    assert_("run_table_semi_circular" in dialog_rb, "semi callback")
    assert_("run_table_square" in dialog_rb, "square callback")
    assert_("Semi-circular table attachment" in menu, "semi menu")
    assert_("Square Table attachment" in menu, "square menu")

    # Locks kept (shared across all three tables)
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("Tables.follow_hosts!" in flex, "flex follow")
    assert_("erase_flexi_beam!" in tables, "flexilink delete on attach")
    assert_("apply_keyboard_orientation_correction" in tables, "orientation shared")

    # Place path: no wrap-on-place call; Apply still uses ensure
    body = keyboard_definition_body(tables)
    assert_("ensure_graphic_wrap_target!(" not in body, "place must not call ensure")
    assert_("do NOT load/instance Keyboard_table_graphic_wrap" in body, "place skip documented")
    assert_("def ensure_graphic_wrap_target!" in tables, "ensure still defined for Apply")
    mti = artwork.split("def map_table_instance!", 1)[1].split("\n      def ", 1)[0]
    assert_("ensure_graphic_wrap_target!" in mti, "Apply still ensures wrap")
    # artwork.rb must be untouched by this release's place revert intent
    assert_("select_keyboard_apron_faces" not in mti, "no apron fallback on apply")

    # Broad attachment name match covers Semi/Square SKP defs
    assert_("semicircle\\s*attachment\\s*wrap" in tables, "semi wrap re")
    assert_("square\\s*attachment\\s*wrap" in tables, "square wrap re")

    # Source models present
    for name in MODELS:
        path = os.path.join(ROOT, "isoframe_stand_designer", "models", name)
        assert_(os.path.isfile(path), f"models/{name} missing")
        assert_(os.path.getsize(path) > 100_000, f"models/{name} too small")

    # Release zip
    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"release zip missing: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        for name in MODELS:
            entry = f"isoframe_stand_designer/models/{name}"
            assert_(entry in names, f"{entry} NOT in release zip")
            info = zf.getinfo(entry)
            src = os.path.join(ROOT, "isoframe_stand_designer", "models", name)
            assert_(
                abs(info.file_size - os.path.getsize(src)) < 16,
                f"zip {name} size {info.file_size} != source {os.path.getsize(src)}",
            )
        # keyboard wrap SKP still ships (Apply path); just not instanced on place
        wrap_entry = "isoframe_stand_designer/models/Keyboard_table_graphic_wrap.skp"
        assert_(wrap_entry in names, "wrap SKP still in zip for Apply")

    md5 = hashlib.md5(open(zip_path, "rb").read()).hexdigest()
    print("OK — v0.1.71 checks passed")
    print(
        f"Proof: place skips wrap ensure; Semi+Square registered; "
        f"zip ships Keyboard/Semi/Square SKPs; md5={md5}; locks kept"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
