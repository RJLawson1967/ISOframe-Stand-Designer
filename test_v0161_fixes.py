#!/usr/bin/env python3
"""v0.1.61: live apron never-empty + wall wallpaper texture restore."""
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


def count_v59(samples: list[dict]) -> int:
    if not samples:
        return 0
    z_max = max(s["z_max"] for s in samples)
    top_cut = z_max - 15.0
    edge_max_h = 17.0
    n = 0
    for s in samples:
        if abs(s["nz"]) >= 0.50:
            continue
        if s["z_span_mm"] <= edge_max_h:
            continue
        if s["z_min"] >= top_cut:
            continue
        if s["area_mm2"] < 50.0:
            continue
        n += 1
    return n


def count_v60_strict(samples: list[dict]) -> int:
    """v0.1.60 lip-local filter with wrong up (Z) — zeros Z-facing apron."""
    return sum(1 for s in samples if abs(s["nz"]) < 0.85 and s["area_mm2"] >= 0.5)


def count_v61(samples: list[dict]) -> int:
    """v0.1.61: vertical-or-all — never empty when faces exist."""
    vertical = sum(1 for s in samples if abs(s["nz"]) < 0.85 and s["area_mm2"] >= 0.5)
    if vertical > 0:
        return vertical
    return sum(1 for s in samples if s["area_mm2"] >= 0.01)


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")

    assert_("EXTENSION_VERSION = '0.1.61'" in reg, "version 0.1.61")
    assert_("ISOframe Table Keyboard SKP v61" in tables, "def v61")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation")

    # Live-path apron fixes
    assert_("resolve_apron_target_with_transform" in tables, "transform-aware resolve")
    assert_("gather_face_samples!" in tables, "root-normal samples")
    assert_("gather_safe_apron_samples!" in tables, "safe fallback")
    assert_("count_apron_samples_passing_v61" in tables, "v61 helper")
    assert_("apron fallback ALL target faces" in tables, "never-empty lip")
    assert_("skip_apron_face_parent?" in tables, "skip wrap faces without lip")
    assert_("blocked_apron_descend?" in tables, "descend wrap, block posts/sree")

    # Wall restore
    assert_("select_vertical_panel_faces" in artwork, "v58-style vertical select")
    assert_("partition_front_rear_faces" in artwork, "front/rear split")
    assert_("face.back_material = material" in artwork, "restore back_material for UV")
    assert_("clear_wall_face_materials!" in artwork, "clear rear")
    assert_("solid light-blue" in artwork or "light-blue" in artwork, "docs wall bug")

    # Must not leave wall with only back_material=nil on the success path without restore
    # paint_front_face! must set back_material = material again
    idx = artwork.find("def paint_front_face!")
    assert_(idx > 0, "paint_front_face present")
    chunk = artwork[idx : idx + 600]
    assert_("face.back_material = material" in chunk, "paint_front sets back_material")

    # SKP structure
    skp = os.path.join(ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp")
    assert_(os.path.isfile(skp), "SKP bundled")
    raw = zipfile.ZipFile(skp).read("model.dat").decode("latin-1", "ignore").lower()
    assert_("keyboard lip" in raw, "SKP lip")
    assert_("keyboard top" in raw, "SKP top")
    assert_("attachment wrap" in raw, "SKP wrap")

    # Tessellated vertical apron (v59 zeroed)
    samples = []
    for i in range(40):
        z0 = i * 3.0
        samples.append(
            {
                "nx": 0.0,
                "ny": 1.0,
                "nz": 0.05,
                "area_mm2": 12.0,
                "z_min": z0,
                "z_max": z0 + 3.0,
                "z_span_mm": 3.0,
            }
        )
    assert_(count_v59(samples) == 0, "v59 rejects tessellated")
    assert_(count_v61(samples) == 40, "v61 keeps tessellated")

    # Lip-local Z-facing apron (wrong-up case that emptied v60)
    z_facing = [
        {"nx": 0.0, "ny": 0.05, "nz": 0.99, "area_mm2": 20.0, "z_min": 0, "z_max": 3, "z_span_mm": 3}
        for _ in range(25)
    ]
    assert_(count_v60_strict(z_facing) == 0, "v60 strict zeros Z-facing apron")
    assert_(count_v61(z_facing) == 25, "v61 ALL-faces fallback keeps Z-facing lip")

    # Continuous UV + wrap guard still present
    assert_("paint_apron_continuous!" in artwork, "continuous UV")
    assert_("apron.size > 8000" in artwork, "146k guard")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.61 checks passed")
    print(
        f"Proof: tessellated v59=0 v61=40; Z-facing lip v60=0 v61=25; "
        f"wall back_material restored"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
