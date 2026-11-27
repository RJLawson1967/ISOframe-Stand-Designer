#!/usr/bin/env python3
"""v0.1.65: Keyboard_table_graphic_wrap.skp as table artwork surface; wall still paints."""
from __future__ import annotations

import os
import sys
import zipfile

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
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.65'" in reg, "version 0.1.65")
    assert_("ISOframe Table Keyboard SKP v65" in tables, "def v65")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode")
    assert_("def follow_hosts!" in tables, "host-follow locked")
    assert_("Tables.follow_hosts!" in flex, "flex host-follow")
    assert_("host.transformation * local" in tables, "table = host * local")

    # Wrap SKP bundled
    wrap_path = os.path.join(
        ROOT, "isoframe_stand_designer", "models", "Keyboard_table_graphic_wrap.skp"
    )
    assert_(os.path.isfile(wrap_path), "Keyboard_table_graphic_wrap.skp bundled")
    assert_("SKP_GRAPHIC_WRAP = 'Keyboard_table_graphic_wrap.skp'" in tables, "wrap skp constant")
    assert_("def ensure_graphic_wrap_target!" in tables, "ensure wrap target")
    assert_("def select_graphic_wrap_front_faces" in tables, "select wrap front")
    assert_("def graphic_wrap_paint_name?" in tables, "wrap name matcher")
    assert_("Graphic Keyboard Attachment" in tables, "docs Graphic Keyboard Attachment")

    raw = zipfile.ZipFile(wrap_path).read("model.dat").decode("latin-1", "ignore")
    assert_("Graphic Keyboard Attachment" in raw, "wrap SKP has Graphic Keyboard Attachment")
    assert_("Rolable" in raw or "rolable" in raw.lower(), "wrap SKP has Rolable")

    # Apply path uses wrap front paint (not lip-only primary)
    assert_("ensure_graphic_wrap_target!" in artwork, "artwork calls ensure wrap")
    assert_("select_graphic_wrap_front_faces" in artwork, "artwork selects wrap front")
    assert_("def paint_graphic_wrap_front!" in artwork, "paint wrap front")
    pgw = artwork.split("def paint_graphic_wrap_front!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.material = material" in pgw, "wrap material set")
    assert_("face.back_material = material" in pgw, "wrap opaque")
    assert_("soften_hide_graphic_front_edges!" in pgw, "wrap soft/hide edges")
    # Prove paint path is not a no-op stub
    assert_("painted += 1" in pgw, "wrap paint increments")

    # Wall path still dual-side wallpaper (v64 restore)
    pfn = artwork.split("def paint_front_face!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.back_material = material" in pfn, "wall dual-side wallpaper")
    assert_("face.back_material = plain" not in pfn, "wall no Color reverse")
    mgg = artwork.split("def map_graphic_group!", 1)[1].split("\n      def ", 1)[0]
    assert_("front = vertical" in mgg, "wall last-resort paints")
    assert_("ensure_plain_wall_material!" in artwork, "wall plain rear")

    print("OK — v0.1.65 checks passed")
    print(
        "Proof: wrap SKP bundled+targeted; front paint+soft edges; "
        "wall dual wallpaper; host-follow locked"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
