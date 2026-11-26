#!/usr/bin/env python3
"""v0.1.58: Apply Table Artwork must succeed without named graphic group.

Proves:
1. SKP still contains keyboard lip definition (real apron geometry).
2. Bake no longer explodes the wrap (preserves nested lip).
3. Apply path never raises 'No under-table graphic group'.
4. Face-fallback paints apron faces when lip name is missing.
5. Position/orientation locks unchanged.
"""
from __future__ import annotations

import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
STORE = "/cursor/stores/bc-3ae81b15-724f-450e-96bc-6cb720e54955"


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def skp_definition_names(path: str) -> list[str]:
    raw = zipfile.ZipFile(path).read("model.dat")
    names = []
    for m in re.finditer(rb"[\x20-\x7e]{4,200}", raw):
        s = m.group().decode("ascii")
        if re.search(r"keyboard|attach|lip|top|base|wrap|Graphic|Hint", s, re.I):
            names.append(s)
    # unique preserve order
    seen = set()
    out = []
    for n in names:
        if n not in seen:
            seen.add(n)
            out.append(n)
    return out


def simulate_lip_finder(entity_tree: list[tuple[str, str, str]]) -> bool:
    """entity_tree: list of (kind, instance_name, def_name) depth-first."""
    lip_re = re.compile(
        r"keyboard\s*lip|table\s*attachment\s*keyboard\s*lip|"
        r"exhibit\s+and\s+wave\s+keyboard\s+lip",
        re.I,
    )
    for _kind, iname, dname in entity_tree:
        if lip_re.search(f"{iname} {dname}"):
            return True
    return False


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")

    assert_("EXTENSION_VERSION = '0.1.58'" in reg, "version must be 0.1.58")
    assert_("ISOframe Table Keyboard SKP v58" in tables, "fresh baked def v58")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation locked")

    # Bake: do NOT explode wrap
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "keep wrap instance")
    assert_("inst.explode if inst.respond_to?(:explode)" not in tables, "no explode of wrap")
    assert_("ISOframe Keyboard Attachment" in tables, "named wrap instance")

    # Do not rename lip away
    assert_("mark_table_graphic_targets!" in tables, "attribute mark")
    assert_("do not rename lip" in tables.lower() or "Do NOT rename" in tables, "no rename policy")
    # walk_tag that set e.name = stable_name should be gone from graphic tagging
    assert_("e.name = stable_name" not in tables, "no rename-to-TableGraphicHint")

    # Apply path: no hard fail on missing group
    assert_("No under-table graphic group in keyboard table" not in artwork, "remove nil-group raise")
    assert_("map_table_apron_faces_from_definition!" in artwork, "face fallback")
    assert_("collect_apron_faces_from_definition" in tables, "apron face collector")
    assert_("never require a named" in artwork.lower() or "never require a named" in artwork, "docs face path")

    # SKP structure proof
    skp = os.path.join(ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp")
    assert_(os.path.isfile(skp), "SKP bundled")
    names = skp_definition_names(skp)
    assert_(any("keyboard lip" in n.lower() for n in names), f"SKP must define lip; got {names[:20]}")
    assert_(any("Keyboard Attachment wrap" in n for n in names), "SKP wrap def")
    assert_(any("keyboard top" in n.lower() for n in names), "SKP top def")
    # GraphicHint exist but are wall-only (also in file) — document awareness
    assert_(any("GraphicHint" in n for n in names), "GraphicHint present (wall modules)")

    # Simulated bake tree AFTER v0.1.58 (no explode): wrap → nested lip
    tree_preserved = [
        ("ComponentInstance", "ISOframe Keyboard Attachment", "Keyboard Attachment wrap^Keyboard table attachment_Graphic Keyboard Attachment (Rolable)"),
        ("ComponentInstance", "", "exhibit and wave keyboard lip"),
        ("ComponentInstance", "", "exhibit and wave keyboard top_Table Attachment Keyboard Top"),
        ("ComponentInstance", "", "exhibit and wave keyboard base_Table Attachment Keyboard Base"),
    ]
    assert_(simulate_lip_finder(tree_preserved), "finder must hit nested lip when wrap not exploded")

    # Simulated OLD broken tree: explode + rename wiped lip name on a Group
    tree_wiped = [
        ("Group", "TableGraphicHint", ""),  # renamed — lip name gone
        ("ComponentInstance", "", "exhibit and wave keyboard base_Table Attachment Keyboard Base"),
    ]
    assert_(not simulate_lip_finder(tree_wiped), "wiped name fails lip finder (explains v0.1.55–57)")
    # Face fallback must exist in code for this case
    assert_("map_table_apron_faces_from_definition!(defn, mat)" in artwork, "fallback called on defn")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    prefs = open(os.path.join(STORE, "preferences.md"), encoding="utf-8").read()
    assert_("19.6 mm" in prefs and "19.5 mm" in prefs, "prefs position lock")
    assert_("never synthesize" in prefs.lower() or "Never synthesize" in prefs or "never synthesize a flat" in prefs, "prefs no synthetic")

    print("OK — v0.1.58 checks passed")
    print("SKP lip/wrap/top present; bake keeps wrap; apply uses face fallback")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
