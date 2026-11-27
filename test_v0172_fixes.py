#!/usr/bin/env python3
"""v0.1.72: Oval Counter freestanding + unified Add Artwork; table place locks kept."""
from __future__ import annotations

import hashlib
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.72.zip"
OVAL = "Oval_Counter.skp"
TABLE_SKPS = [
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
    counters = read("isoframe_stand_designer/counters.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")
    dialog_html = read("isoframe_stand_designer/ui/dialog.html")
    dialog_rb = read("isoframe_stand_designer/ui/dialog.rb")
    menu = read("isoframe_stand_designer/ui/menu.rb")
    main_rb = read("isoframe_stand_designer/main.rb")
    place = read("isoframe_stand_designer/tools/place_counter.rb")
    constants = read("isoframe_stand_designer/constants.rb")

    assert_("EXTENSION_VERSION = '0.1.72'" in reg, "version 0.1.72")
    assert_("TYPE_COUNTER" in constants, "TYPE_COUNTER")
    assert_("KEY_COUNTER_KIND" in constants, "KEY_COUNTER_KIND")

    # Oval freestanding
    assert_("'oval'" in counters, "oval registry")
    assert_("Oval_Counter.skp" in counters, "oval skp")
    assert_("Oval Counter" in dialog_html, "oval panel")
    assert_("run_counter_oval" in dialog_rb, "oval callback")
    assert_("PlaceCounterTool" in place, "place tool")
    assert_("Floorspace.module_base_z" in place, "floor Z")
    assert_("erase_flexi_beam" not in counters, "no flexilink delete on counter")
    assert_("KEY_TABLE_HOST" not in counters, "not parented to S+E")
    assert_("counters" in main_rb, "main loads counters")
    assert_("place_counter" in main_rb, "main loads place_counter")

    # Unified Add Artwork
    assert_("def prompt_and_add!" in artwork, "unified entry")
    assert_("Add Artwork" in dialog_html, "panel label")
    assert_("run_table_artwork" not in dialog_html, "no separate table artwork button")
    assert_("Apply Table Artwork" not in dialog_html, "no table artwork label")
    assert_("Artwork.prompt_and_add!" in dialog_rb, "dialog wires unified")
    assert_("Add Artwork" in menu, "menu unified")
    assert_("Apply Table Artwork" not in menu, "menu dropped table artwork")
    assert_("map_counter_instance!" in artwork, "counter paint")
    assert_("select_wrap_faces" in counters, "oval wrap face pick")
    assert_("ensure_wrap_material_like_wall!" in artwork, "wall texture path reused")

    # Table place locks from v0.1.71
    body = keyboard_definition_body(tables)
    assert_("ensure_graphic_wrap_target!(" not in body, "no wrap on place")
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("'semi_circular'" in tables and "'square'" in tables, "semi+square kept")

    # Models present
    oval_path = os.path.join(ROOT, "isoframe_stand_designer", "models", OVAL)
    assert_(os.path.isfile(oval_path), "Oval_Counter.skp in models/")
    assert_(os.path.getsize(oval_path) > 100_000, "oval skp size")
    for name in TABLE_SKPS:
        p = os.path.join(ROOT, "isoframe_stand_designer", "models", name)
        assert_(os.path.isfile(p), f"models/{name}")

    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"release zip missing: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        entry = f"isoframe_stand_designer/models/{OVAL}"
        assert_(entry in names, f"{entry} NOT in zip")
        info = zf.getinfo(entry)
        assert_(abs(info.file_size - os.path.getsize(oval_path)) < 16, "oval zip size")
        for name in TABLE_SKPS:
            assert_(f"isoframe_stand_designer/models/{name}" in names, f"{name} in zip")

    md5 = hashlib.md5(open(zip_path, "rb").read()).hexdigest()
    print("OK — v0.1.72 checks passed")
    print(f"Proof: Oval freestanding + Add Artwork unified; table place no wrap; md5={md5}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
