#!/usr/bin/env python3
"""v0.1.69: wrap SKP resolved via __FILE__/models + must ship inside release zip."""
from __future__ import annotations

import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"
WRAP_NAME = "Keyboard_table_graphic_wrap.skp"
ZIP_NAME = "isoframe-sketchup-plugins-v0.1.69.zip"
ZIP_ENTRY = f"isoframe_stand_designer/models/{WRAP_NAME}"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    mesh = read("isoframe_stand_designer/mesh_import.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.69'" in reg, "version 0.1.69")
    assert_("ISOframe Table Keyboard SKP v69" in tables, "def v69")

    # Locks kept
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("def follow_hosts!" in tables, "host-follow")
    assert_("Tables.follow_hosts!" in flex, "flex follow")

    # Path resolution hardened
    assert_("def graphic_wrap_skp_candidates" in tables, "candidates helper")
    assert_("def graphic_wrap_skp_path!" in tables, "bang path helper")
    assert_("File.dirname(File.expand_path(__FILE__))" in tables, "__FILE__ based")
    assert_("File.join(here, 'models', SKP_GRAPHIC_WRAP)" in tables, "models next to tables.rb")
    assert_("def models_dir" in mesh, "mesh models_dir at call time")
    assert_("graphic_wrap_skp_path!" in tables, "ensure uses bang path")
    assert_("raise" in tables.split("def ensure_graphic_wrap_target!", 1)[1][:2500], "ensure raises on fail")

    # Instancing still required
    assert_("ensure_graphic_wrap_target!(defn, model)" in tables, "bake ensures wrap")
    mti = artwork.split("def map_table_instance!", 1)[1].split("\n      def ", 1)[0]
    assert_("ensure_graphic_wrap_target!" in mti, "apply ensures wrap")
    assert_("select_keyboard_apron_faces" not in mti, "no apron fallback")
    assert_("paint_front_face!" in artwork, "wall paint path kept")

    # Source models/
    wrap = os.path.join(ROOT, "isoframe_stand_designer", "models", WRAP_NAME)
    assert_(os.path.isfile(wrap), "wrap SKP in workspace models/")
    assert_(os.path.getsize(wrap) > 1_000_000, "wrap SKP not empty stub")
    raw = zipfile.ZipFile(wrap).read("model.dat").decode("latin-1", "ignore")
    assert_("Graphic Keyboard Attachment" in raw, "wrap SKP has Graphic Keyboard Attachment")

    # Release zip must contain models/Keyboard_table_graphic_wrap.skp
    zip_path = os.path.join(STORE, "docs", ZIP_NAME)
    assert_(os.path.isfile(zip_path), f"release zip missing: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        assert_(ZIP_ENTRY in names, f"{ZIP_ENTRY} NOT in release zip")
        info = zf.getinfo(ZIP_ENTRY)
        assert_(info.file_size > 1_000_000, f"zip entry too small: {info.file_size}")
        assert_(
            abs(info.file_size - os.path.getsize(wrap)) < 16,
            f"zip size {info.file_size} != source {os.path.getsize(wrap)}",
        )

    print("OK — v0.1.69 checks passed")
    print(
        f"Proof: __FILE__/models path+logging; bang raise; "
        f"release zip contains {ZIP_ENTRY} ({os.path.getsize(wrap)} bytes); locks kept"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
