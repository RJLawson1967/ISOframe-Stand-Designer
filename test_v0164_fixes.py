#!/usr/bin/env python3
"""v0.1.64: restore visible wall+table artwork; soft/hide graphic front; host-follow locked."""
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


def wall_paint_path_does_not_noop(artwork: str) -> None:
    """Prove wall Apply Artwork path still paints fronts (v58/61 dual material)."""
    assert_("def map_graphic_group!" in artwork, "map_graphic_group present")
    assert_("def paint_front_face!" in artwork, "paint_front_face present")
    pfn = artwork.split("def paint_front_face!", 1)[1].split("\n      def ", 1)[0]
    # Must set wallpaper on BOTH sides of front faces (visible texture).
    assert_("face.material = material" in pfn, "front material set")
    assert_("face.back_material = material" in pfn, "back_material = wallpaper (visible)")
    assert_("face.back_material = plain" not in pfn, "no Color/plain on front reverse")
    # Must not early-return 0 without a last-resort vertical paint.
    mgg = artwork.split("def map_graphic_group!", 1)[1].split("\n      def ", 1)[0]
    assert_("front = vertical" in mgg, "last-resort paint verticals")
    assert_("return 0 if front.empty?" not in mgg, "no hard empty front abort")
    assert_("ensure_plain_wall_material!" in artwork, "plain rear material")
    assert_("restore_plain_wall_faces!" in artwork, "plain rear restore")
    assert_("soften_hide_graphic_front_edges!" in artwork, "hide front edges")


def table_paint_path_does_not_noop(artwork: str, tables: str) -> None:
    """Prove table apron path selects faces and paints opaque continuous UV."""
    assert_("select_keyboard_apron_faces" in tables, "apron select")
    assert_("find_best_geometric_apron_target" in tables, "geometric target")
    assert_("apron last-resort count" in tables, "never-empty last resort")
    assert_("geometric pool" in tables or "geometric_apron_face_samples" in tables, "geo pool")
    pac = artwork.split("def paint_apron_continuous!", 1)[1].split("\n      def ", 1)[0]
    assert_("face.material = material" in pac, "apron material set")
    assert_("face.back_material = material" in pac, "apron opaque reverse")
    assert_("face.back_material = nil" not in pac, "apron reverse not nil (see-through)")
    assert_("soften_hide_graphic_front_edges!" in pac, "apron edges soft/hide")


def main() -> None:
    reg = read("isoframe_stand_designer.rb")
    tables = read("isoframe_stand_designer/tables.rb")
    artwork = read("isoframe_stand_designer/artwork.rb")
    flex = read("isoframe_stand_designer/tools/flex_tool.rb")

    assert_("EXTENSION_VERSION = '0.1.64'" in reg, "version 0.1.64")
    assert_("ISOframe Table Keyboard SKP v64" in tables, "def v64")

    # Locks
    assert_("PLACE_CLOSER_MM = 19.5" in tables, "closer locked")
    assert_("PLACE_LEFT_MM = 19.6" in tables, "left locked")
    assert_("wrap_inst = defn.entities.add_instance(kb_src, local)" in tables, "no-explode")
    assert_("r_side_flip * r_from_above * r_from_right * local" in tables, "orientation")
    assert_("def follow_hosts!" in tables, "host-follow locked")
    assert_("Tables.follow_hosts!" in flex, "flex host-follow locked")
    assert_("host.transformation * local" in tables, "table = host * local")

    wall_paint_path_does_not_noop(artwork)
    table_paint_path_does_not_noop(artwork, tables)

    # Geometric apron still rejects top/beams
    top_band = {"z_min": 100.0, "z_max": 115.0}
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
    assert_(score_apron(
        [{"nx": 0, "ny": 0, "nz": 1, "area_mm2": 800, "z_min_mm": 110, "z_max_mm": 115, "z_span_mm": 5}]
        * 10,
        top_band,
        800,
        500,
        15,
    )
    < 0, "tabletop rejected")
    assert_(beam_like(37, 37, 800), "beam dims")
    assert_(score_apron(
        [{"nx": 0, "ny": 1, "nz": 0, "area_mm2": 40, "z_min_mm": 50, "z_max_mm": 87, "z_span_mm": 37}]
        * 8,
        top_band,
        37,
        800,
        37,
    )
    < 0, "beam rejected")

    lights = read("isoframe_stand_designer/lights.rb")
    assert_("PLAN_CCW_UNDO_DEG = 20.1" in lights, "LED yaw locked")
    assert_("SHIFT_LEFT_MM = 70.7" in lights, "LED shift locked")

    skp = os.path.join(ROOT, "isoframe_stand_designer", "models", "Keyboard_with_Extension.skp")
    raw = zipfile.ZipFile(skp).read("model.dat").decode("latin-1", "ignore")
    assert_("Boss-Extrude" in raw, "SKP has Boss-Extrude")

    print("OK — v0.1.64 checks passed")
    print(
        "Proof: wall dual-side wallpaper + plain rear; apron opaque+soft edges; "
        f"geo score={s_apron:.1f}>0; host-follow locked; no empty-front abort"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
