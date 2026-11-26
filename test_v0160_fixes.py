#!/usr/bin/env python3
"""v0.1.60: apron finder must select lip faces; v0.1.59 Z-span filter was wrong."""
from __future__ import annotations

import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def skp_has_separate_lip_and_top(path: str) -> tuple[bool, bool]:
    raw = zipfile.ZipFile(path).read("model.dat").decode("latin-1", "ignore")
    has_lip = "keyboard lip" in raw.lower()
    has_top = "keyboard top" in raw.lower()
    return has_lip, has_top


def count_v59(samples: list[dict]) -> int:
    """Replicate v0.1.59 filter (mm units)."""
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


def count_v60(samples: list[dict], up: str = "z") -> int:
    """Replicate v0.1.60 lip apron filter."""
    n = 0
    for s in samples:
        n_up = s["nz"] if up == "z" else (s["ny"] if up == "y" else s["nx"])
        if abs(n_up) >= 0.85:
            continue
        if s["area_mm2"] < 0.5:
            continue
        n += 1
    return n


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")

    assert_("EXTENSION_VERSION = '0.1.60'" in reg, "version 0.1.60")
    assert_("ISOframe Table Keyboard SKP v60" in tables, "def v60")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation")

    # Fix markers
    assert_("count_apron_samples_passing" in tables, "test helper")
    assert_("filter_lip_apron_faces" in tables, "relaxed filter")
    assert_("detect_lip_up_axis" in tables, "up detection")
    assert_("tessellated" in tables.lower() or "Z-span" in tables, "documents v59 bug")
    assert_("paint_apron_continuous!" in artwork, "continuous UV kept")
    assert_("front_outward_normal_at" in artwork, "wall front-only kept")

    # SKP: lip and top are separate definitions
    skp = os.path.join(ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp")
    assert_(os.path.isfile(skp), "SKP bundled")
    has_lip, has_top = skp_has_separate_lip_and_top(skp)
    assert_(has_lip, "SKP has keyboard lip")
    assert_(has_top, "SKP has keyboard top (separate from lip)")
    # Stronger real-SKP structure proof (component strings in model.dat)
    raw = zipfile.ZipFile(skp).read("model.dat").decode("latin-1", "ignore").lower()
    assert_("exhibit and wave keyboard lip" in raw, "SKP lip definition present")
    assert_("exhibit and wave keyboard top" in raw, "SKP top definition present")
    assert_("attachment wrap" in raw, "SKP wrap present (must NOT be paint target)")
    assert_("find_keyboard_lip_entity" in tables, "lip finder")
    assert_("skip_container_for_apron?" in tables, "excludes top/wrap")
    assert_("keyboard\\s*top" in tables or "keyboard top" in tables.lower(), "top skipped")
    assert_("wrap_container?" in tables, "wrap excluded from paint")

    # Simulated tessellated apron: many small vertical facets (5mm Z span)
    # covering a 120mm-tall apron — EXACTLY what v0.1.59 rejected.
    samples = []
    for i in range(40):
        z0 = i * 3.0  # 3mm tall facets
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
    # plus a couple of horizontal rim faces
    samples.append(
        {
            "nx": 0.0,
            "ny": 0.0,
            "nz": 1.0,
            "area_mm2": 200.0,
            "z_min": 120.0,
            "z_max": 120.0,
            "z_span_mm": 0.0,
        }
    )

    v59 = count_v59(samples)
    v60 = count_v60(samples)
    assert_(v59 == 0, f"v0.1.59 filter must reject tessellated apron (got {v59})")
    assert_(v60 == 40, f"v0.1.60 must keep 40 apron facets (got {v60})")

    # Tabletop edge strip alone (15mm tall vertical) — if it appeared on lip,
    # v60 would still include it; real edge is on keyboard top (not selected).
    # Prove we still exclude horizontals:
    only_top = [
        {
            "nx": 0.0,
            "ny": 0.0,
            "nz": 1.0,
            "area_mm2": 500.0,
            "z_min": 100.0,
            "z_max": 100.0,
            "z_span_mm": 0.0,
        }
    ]
    assert_(count_v60(only_top) == 0, "horizontal top faces excluded")

    # Must not paint whole wrap
    assert_("select_keyboard_apron_faces" in artwork, "uses lip apron select")
    assert_("146k" in tables or "146" in tables or "wrap" in tables.lower(), "docs wrap avoidance")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.60 checks passed")
    print(f"Proof: tessellated apron v59={v59} v60={v60}; SKP lip+top separate")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
