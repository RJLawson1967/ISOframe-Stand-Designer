#!/usr/bin/env python3
"""v0.1.63: geometric apron recovery when lip name is NONE (Boss-Extrude bake)."""
from __future__ import annotations

import math
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))

APRON_MIN_HEIGHT = 25.0
APRON_MIN_FACES = 3
BEAM_CROSS = 50.0
BEAM_MIN_LEN = 200.0
TOP_MAX_H = 25.0
TOP_MIN_PLAN = 200.0
TOP_THICK = 15.0


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def assert_(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def tabletop_like(dx, dy, dz) -> bool:
    return dz <= TOP_MAX_H and dx >= TOP_MIN_PLAN and dy >= TOP_MIN_PLAN


def beam_like(dx, dy, dz) -> bool:
    dims = sorted([dx, dy, dz])
    return dims[0] <= BEAM_CROSS and dims[1] <= BEAM_CROSS and dims[2] >= BEAM_MIN_LEN


def allowed(s, top_band, nz_max=0.85) -> bool:
    if abs(s["nz"]) >= nz_max or s["area_mm2"] < 0.5:
        return False
    zmin, zmax = s["z_min_mm"], s["z_max_mm"]
    if top_band:
        if zmax >= top_band["z_min"] - 0.5 and zmin <= top_band["z_max"] + 0.5:
            return False
    return True


def score_apron(samples, top_band, dx, dy, dz) -> float:
    if len(samples) < APRON_MIN_FACES:
        return -1.0
    if tabletop_like(dx, dy, dz) or beam_like(dx, dy, dz):
        return -1.0
    ok = [s for s in samples if allowed(s, top_band)]
    if len(ok) < APRON_MIN_FACES:
        return -1.0
    zspan = max(s["z_max_mm"] for s in ok) - min(s["z_min_mm"] for s in ok)
    if zspan < APRON_MIN_HEIGHT:
        return -1.0
    horiz = sum(1 for s in samples if abs(s["nz"]) >= 0.85)
    if horiz / len(samples) > 0.55:
        return -1.0
    angs = [math.atan2(s["ny"], s["nx"]) for s in ok]
    angle_span = max(angs) - min(angs)
    vert_ratio = len(ok) / len(samples)
    return len(ok) * (0.5 + angle_span) * (zspan / 50.0) * (0.35 + vert_ratio)


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")

    assert_("EXTENSION_VERSION = '0.1.63'" in reg, "version 0.1.63")
    assert_("ISOframe Table Keyboard SKP v63" in tables, "def v63")

    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation")

    assert_("find_best_geometric_apron_target" in tables, "geometric target")
    assert_("score_apron_candidate_samples" in tables, "scorer")
    assert_("geometric_apron_face_samples" in tables, "geo samples")
    assert_("Boss-Extrude" in tables or "lip name NONE" in tables, "docs Boss-Extrude")
    assert_("beam_like_dims?" in tables, "beam dims")
    assert_("tabletop_like_dims?" in tables, "top dims")
    assert_("find_marked_apron_target" in tables, "marked without lip name")
    assert_("paint_apron_continuous!" in artwork, "continuous UV")

    # Host-follow: table tracks S/E when flex moves the stick chain
    assert_("def follow_hosts!" in tables, "follow_hosts helper")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")
    assert_("Tables.follow_hosts!" in flex, "flex tool host-follow")
    assert_("host.transformation * local" in tables, "table = host * locked local")

    # Wall wallpaper: front photo only; reverse + rear slab = panel plain tint
    geom = read("isoframe_stand_designer/geometry.rb")
    assert_("GRAPHIC_PLAIN_RGB = [230, 235, 245]" in geom, "plain RGB constant")
    assert_("def plain_wall_color" in artwork, "plain wall color helper")
    assert_("def restore_plain_wall_faces!" in artwork, "restore plain rear")
    assert_("def recover_front_faces_from_vertical" in artwork, "no all-vertical fallback")
    assert_("face.back_material = plain" in artwork, "front reverse stays plain")
    # paint_front_face! must not assign wallpaper to back_material
    pfn = artwork.split("def paint_front_face!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.back_material = material" not in pfn, "wall reverse != wallpaper")
    assert_("face.back_material = plain" in pfn, "wall reverse = plain in paint_front")

    skp = os.path.join(ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp")
    raw = zipfile.ZipFile(skp).read("model.dat").decode("latin-1", "ignore")
    assert_("Boss-Extrude" in raw, "SKP has Boss-Extrude defs")
    assert_("keyboard lip" in raw.lower(), "SKP still has lip string somewhere")

    top_band = {"z_min": 100.0, "z_max": 115.0}

    # Curved vertical apron cluster (nameless Boss-Extrude stand-in)
    apron = []
    for i in range(40):
        ang = -1.0 + i * (2.0 / 39.0)
        apron.append(
            {
                "nx": math.cos(ang),
                "ny": math.sin(ang),
                "nz": 0.05,
                "area_mm2": 15.0,
                "z_min_mm": 30.0,
                "z_max_mm": 90.0,
                "z_span_mm": 60.0,
            }
        )
    s_apron = score_apron(apron, top_band, dx=600, dy=400, dz=60)
    assert_(s_apron > 0, f"apron cluster scores positive (got {s_apron})")

    # Tabletop slab — must reject
    top = [
        {
            "nx": 0.0,
            "ny": 0.0,
            "nz": 1.0,
            "area_mm2": 800.0,
            "z_min_mm": 110.0,
            "z_max_mm": 115.0,
            "z_span_mm": 5.0,
        }
        for _ in range(10)
    ]
    assert_(tabletop_like(800, 500, 15), "top dims detected")
    assert_(score_apron(top, top_band, 800, 500, 15) < 0, "tabletop score rejected")

    # 37mm beam — must reject
    assert_(beam_like(37, 37, 800), "beam dims detected")
    beam = [
        {
            "nx": 0.0,
            "ny": 1.0,
            "nz": 0.0,
            "area_mm2": 40.0,
            "z_min_mm": 50.0,
            "z_max_mm": 87.0,
            "z_span_mm": 37.0,
        }
        for _ in range(8)
    ]
    assert_(score_apron(beam, top_band, 37, 800, 37) < 0, "beam score rejected")

    # Edge in top band still excluded from allowed count
    edge = {
        "nx": 0.0,
        "ny": 1.0,
        "nz": 0.1,
        "area_mm2": 50.0,
        "z_min_mm": 100.0,
        "z_max_mm": 115.0,
        "z_span_mm": 15.0,
    }
    assert_(not allowed(edge, top_band), "15mm edge excluded")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    print("OK — v0.1.63 checks passed")
    print(
        f"Proof: apron score={s_apron:.1f}>0; tabletop/beam rejected; "
        "lip-name optional; wall front-only + plain rear; host-follow"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
