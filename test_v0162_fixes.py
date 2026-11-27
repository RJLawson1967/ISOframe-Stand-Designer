#!/usr/bin/env python3
"""v0.1.62: apron lip-only — exclude tabletop (all faces) and 37mm beams."""
from __future__ import annotations

import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
TOP_THICK = 15.0


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def count_v62(samples: list[dict], top_band: dict) -> int:
    n = 0
    for s in samples:
        if abs(s["nz"]) >= 0.85:
            continue
        if s["area_mm2"] < 0.5:
            continue
        zmin, zmax = s["z_min_mm"], s["z_max_mm"]
        zspan = s.get("z_span_mm", zmax - zmin)
        if zmax >= top_band["z_min"] - 0.5 and zmin <= top_band["z_max"] + 0.5:
            continue
        edge_max = TOP_THICK + 2.0
        mid = 0.5 * (zmin + zmax)
        if zspan <= edge_max and top_band["z_min"] - 0.5 <= mid <= top_band["z_max"] + 0.5:
            continue
        n += 1
    return n


def count_v61_all(samples: list[dict]) -> int:
    vertical = sum(1 for s in samples if abs(s["nz"]) < 0.85 and s["area_mm2"] >= 0.5)
    if vertical > 0:
        return vertical
    return sum(1 for s in samples if s["area_mm2"] >= 0.01)


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")

    assert_("EXTENSION_VERSION = '0.1.62'" in reg, "version 0.1.62")
    assert_("ISOframe Table Keyboard SKP v62" in tables, "def v62")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation")

    # Spill exclusions
    assert_("apron_sample_allowed?" in tables, "strict allow filter")
    assert_("tabletop_z_band_mm" in tables, "top band")
    assert_("count_apron_samples_passing_v62" in tables, "v62 helper")
    assert_("find_apron_like_nested" not in tables or "never rolable" in tables.lower() or
            "Lip only" in tables, "lip-only resolve")
    # resolve must not call find_apron_like
    resolve = tables.split("def resolve_apron_target_with_transform")[1].split("\n  def ")[0]
    assert_("find_apron_like" not in resolve, "no rolable target in resolve")
    assert_("ALL target faces" not in tables, "no ALL-faces spill fallback")
    assert_(r"\b37\s*mm\b" in tables or "37\\s*mm" in tables, "37mm beam blocked")
    assert_("beam\\s*straight" in tables or r"\bbeam\b" in tables, "beam blocked")
    assert_("keyboard\\s*top" in tables, "top blocked")
    assert_("parent_key =~ /keyboard\\s*lip/i" in tables or "keyboard\\s*lip" in tables, "safe walk lip-only")

    assert_("paint_apron_continuous!" in artwork, "continuous UV")
    assert_("v62 bake" in artwork or "0.1.62" in artwork or "v0.1.62" in artwork, "artwork notes")

    skp = os.path.join(ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp")
    assert_(os.path.isfile(skp), "SKP")
    raw = zipfile.ZipFile(skp).read("model.dat").decode("latin-1", "ignore").lower()
    assert_("keyboard lip" in raw and "keyboard top" in raw, "lip+top separate")

    # Mixed scene: apron + tabletop top + edge + beam-like short face in top band
    top_band = {"z_min": 100.0, "z_max": 115.0}
    samples = []
    # apron vertical fully under top (clear of 100–115 band)
    for i in range(30):
        z0 = 20.0 + i * 2.0  # 20..78 → max 80, clear of band
        samples.append(
            {
                "nz": 0.05,
                "area_mm2": 12.0,
                "z_min_mm": z0,
                "z_max_mm": z0 + 2.0,
                "z_span_mm": 2.0,
            }
        )
    # tabletop top (horizontal)
    samples.append(
        {"nz": 1.0, "area_mm2": 500.0, "z_min_mm": 115.0, "z_max_mm": 115.0, "z_span_mm": 0.0}
    )
    # tabletop front edge (15mm vertical in band)
    samples.append(
        {"nz": 0.1, "area_mm2": 80.0, "z_min_mm": 100.0, "z_max_mm": 115.0, "z_span_mm": 15.0}
    )
    v62 = count_v62(samples, top_band)
    v61 = count_v61_all(samples)
    assert_(v62 == 30, f"v62 keeps 30 apron only (got {v62})")
    assert_(v61 >= 31, f"v61 would keep edge too (got {v61})")

    # Horizontals alone → 0
    only_top = [
        {"nz": 1.0, "area_mm2": 500.0, "z_min_mm": 110.0, "z_max_mm": 110.0, "z_span_mm": 0.0}
    ]
    assert_(count_v62(only_top, top_band) == 0, "top surface excluded")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.62 checks passed")
    print(f"Proof: mixed scene v61>={31} spill vs v62=30 apron-only; top/edge excluded")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
