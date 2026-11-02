r"""
47-state `160x32` smooth-strip solid surface generators and specs (`SURFACE_SOLID_SPRITES`)
for fine powder dustings, 4-connected basaltic scree, clodded soil, and tilled furrows.
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
from typing import Any

if __package__:
    from .solids_helpers import (
        LIGHT_X,
        LIGHT_Y,
        border_ns_weight,
        build_basalt_plate_32,
        build_layer,
        make_grid,
        periodic_delta,
        periodic_wave,
        prune_lone_pixels,
        prune_lone_pixels_per_block,
        quad_base_sdf,
        quadrant_sdf,
        sdf_outward_normal,
        split_by_token_sets,
        sym_cos,
        torus_wave,
    )
else:
    _SPECS_DIR = str(Path(__file__).resolve().parent)
    if _SPECS_DIR not in sys.path:
        sys.path.insert(0, _SPECS_DIR)
    from solids_helpers import (  # type: ignore[import-not-found]
        LIGHT_X,
        LIGHT_Y,
        border_ns_weight,
        build_basalt_plate_32,
        build_layer,
        make_grid,
        periodic_delta,
        periodic_wave,
        prune_lone_pixels,
        prune_lone_pixels_per_block,
        quad_base_sdf,
        quadrant_sdf,
        sdf_outward_normal,
        split_by_token_sets,
        sym_cos,
        torus_wave,
    )


# ==============================================================================
# 1. Fine Cohesive Powder / Flour Dusting (`solid_dusting_flour_smooth`)
# ==============================================================================
_POWDER_DRIFTS: list[tuple[float, float, float, float, float]] = [
    (6.2, 5.8, 9.2, 7.4, 0.46),
    (19.4, 4.6, 10.4, 7.8, 0.50),
    (28.2, 11.2, 8.4, 7.2, 0.40),
    (11.6, 15.2, 10.6, 8.2, 0.52),
    (23.2, 18.4, 9.4, 8.0, 0.46),
    (3.8, 23.6, 8.8, 7.0, 0.42),
    (16.4, 25.8, 10.2, 7.4, 0.47),
]


def _powder_height(px: float, py: float) -> float:
    h = 0.0
    for cx, cy, rx, ry, wt in _POWDER_DRIFTS:
        dx = periodic_delta(px, cx, 32.0) / rx
        dy = periodic_delta(py, cy, 32.0) / ry
        r2 = dx * dx + dy * dy
        if r2 < 1.65:
            v = 1.0 - r2 / 1.65
            h += wt * v * v
    h += 0.09 * periodic_wave(px, py, seed=7)
    return h


def flour_interior_token(x: int, y: int, north_rim_boost: float = 0.0) -> str:
    h_c = _powder_height(x + 0.5, y + 0.5)
    h_n = _powder_height(x + 0.5, (y - 1.0) % 32.0 + 0.5)
    h_s = _powder_height(x + 0.5, (y + 1.0) % 32.0 + 0.5)
    north_slope = (h_c - h_n) - (h_s - h_c) * 0.55
    val = 0.28 + 0.58 * h_c + 1.45 * north_slope + north_rim_boost

    if val >= 0.72:
        return "W"
    if val >= 0.59:
        return "E"
    if val >= 0.46:
        return "L"
    if val >= 0.33:
        return "C"
    return "A" if val >= 0.20 else "N"


def gen_solid_dusting_flour_smooth() -> list[dict[str, Any]]:
    fringe = make_grid(160, 32)
    halo = make_grid(160, 32)
    apron = make_grid(160, 32)
    core = make_grid(160, 32)

    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                sdf, _, _, u, w = quadrant_sdf(block, x, y, margin=1.8, corner_radius=5.4)
                ns_w = border_ns_weight(block, u, w, margin=1.8, corner_radius=5.4)
                is_ns = ns_w >= 0.70
                d = sdf + 1.15 * periodic_wave(x, y, seed=5)
                rim_boost = (0.14 if y < 16 else -0.11) * ns_w if w < 8.5 else 0.0

                if d >= 4.4:
                    core[y][ox + x] = flour_interior_token(x, y, north_rim_boost=rim_boost)
                elif d >= 2.8:
                    apron[y][ox + x] = "E" if (is_ns and y < 16) else ("L" if (x + y) % 4 != 0 else "C")
                elif d >= 1.3:
                    halo[y][ox + x] = "L" if (is_ns and y < 16) else ("C" if (x + 2 * y) % 2 == 0 else "A")
                elif d >= 0.0:
                    fringe[y][ox + x] = "C" if (is_ns and y < 16) else "A"

    prune_lone_pixels([fringe, halo, apron, core])
    return [
        build_layer("wisp_fringe", fringe, opacity=48),
        build_layer("dust_halo", halo, opacity=104),
        build_layer("powder_apron", apron, opacity=172),
        build_layer("flour_drift", core, opacity=255),
    ]


# ==============================================================================
# 2. 4-Connected Basaltic Scree / Rubble (`solid_debris_jagged_smooth`)
# ==============================================================================
_RUBBLE_BASALT_SEEDS: list[tuple[float, float, float, float]] = [
    (5.2, 4.4, 1.48, 0.36),
    (20.6, 3.8, 0.96, -0.34),
    (29.0, 9.6, 0.74, 0.44),
    (11.4, 13.8, 1.54, -0.28),
    (24.4, 16.4, 1.18, 0.32),
    (3.6, 22.4, 0.92, -0.40),
    (15.8, 25.8, 1.38, 0.24),
    (27.8, 27.2, 0.82, -0.32),
]


def gen_solid_debris_jagged_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)
    rubble_32 = build_basalt_plate_32(
        _RUBBLE_BASALT_SEEDS,
        ramp=("S", "M", "N", "C", "L"),
        warp_amp=2.15,
        warp_seed=5.5,
        pocket_thresh=0.46,
        taper_thresh=-0.16,
        lip_thresh=0.16,
    )
    for y in range(32):
        for x in range(32):
            if rubble_32[y][x] == "C" and torus_wave(x, y, seed=8.1) < -0.10:
                rubble_32[y][x] = "A"

    inset, r_conv = 3.10, 1.45
    for block in range(5):
        ox = block * 32

        def sdf_b(px: float, py: float, b: int = block) -> float:
            if b == 4:
                return 24.0
            jag = (
                0.52 * sym_cos(px, 2)
                - 0.44 * sym_cos(px, 4)
                + 0.26 * sym_cos(px, 5)
                + 0.48 * sym_cos(py, 2)
                - 0.40 * sym_cos(py, 4)
                + 0.28 * sym_cos(px, 3) * sym_cos(py, 3)
            )
            return quad_base_sdf(b, px, py, inset, r_conv) + jag

        for y in range(32):
            for x in range(32):
                s = sdf_b(x, y)
                if s < 0.0:
                    continue
                if block == 4 or s >= 2.25:
                    master[y][ox + x] = rubble_32[y][x]
                else:
                    nx, ny = sdf_outward_normal(sdf_b, x, y)
                    ldot = nx * LIGHT_X + ny * LIGHT_Y
                    if ldot >= 0.20:
                        master[y][ox + x] = "N" if s < 0.85 else ("L" if ldot > 0.50 else "C")
                    elif ldot <= -0.15:
                        master[y][ox + x] = "B" if s < 0.90 else ("S" if s < 1.75 else "M")
                    else:
                        master[y][ox + x] = "S" if s < 0.85 else "A"

    prune_lone_pixels_per_block([master])
    return split_by_token_sets(
        master,
        [
            ("crevices_and_undercuts", {"B", "S", "M"}, 255),
            ("basaltic_scree_slabs", {"N", "A", "C"}, 255),
            ("slab_rims", {"L"}, 255),
        ],
    )


# ==============================================================================
# 3 & 4. Soil Bed & Tilled Furrows (`solid_soil_smooth`, `solid_soil_tilled_smooth`)
# ==============================================================================
_SOIL_CLODS: list[tuple[float, float, float, float, float]] = [
    (
        ((_i * 0.7548776662) % 1.0) * 32.0,
        ((_i * 0.5698402910) % 1.0) * 32.0,
        2.05 + (_i % 5) * 0.34,
        1.90 + ((_i * 3) % 4) * 0.30,
        ((_i * 7) % 5 - 2) * 0.08,
    )
    for _i in range(52)
]

_SOIL_SPECKS: set[tuple[int, int]] = {
    (5, 4), (6, 4), (21, 3), (22, 3), (14, 6), (15, 6), (12, 9), (13, 9),
    (27, 8), (28, 8), (4, 15), (5, 15), (18, 16), (19, 16), (10, 23), (11, 23),
}


def soil_clod_token(x: int, y: int) -> str:
    best_z, best_ny, best_lift = -9.0, 0.0, 0.0
    px, py = x + 0.5, y + 0.5
    for cx, cy, rx, ry, lift in _SOIL_CLODS:
        dx = periodic_delta(px, cx, 32.0) / rx
        dy = periodic_delta(py, cy, 32.0) / ry
        r2 = dx * dx + dy * dy
        if r2 < 1.32:
            z = math.sqrt(max(0.0, 1.32 - r2)) + lift
            if z > best_z:
                best_z, best_ny, best_lift = z, dy, lift

    if best_z < 0.34:
        return "S" if (x * 3 + y * 5) % 4 == 0 else "M"
    if (x % 32, y % 32) in _SOIL_SPECKS and best_z > 0.55:
        return "W" if best_ny <= 0.0 else "E"

    illum = 0.53 - 0.33 * best_ny + 0.22 * (best_z - 0.58) + 0.55 * best_lift
    if illum >= 0.80:
        return "E"
    if illum >= 0.64:
        return "L"
    if illum >= 0.48:
        return "C"
    if illum >= 0.32:
        return "A"
    return "N" if illum >= 0.17 else "M"


def gen_solid_soil_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)
    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                sdf, _, _, u, w = quadrant_sdf(block, x, y, margin=3.4, corner_radius=4.6)
                ns_w = border_ns_weight(block, u, w, margin=3.4, corner_radius=4.6)
                is_ns = ns_w >= 0.70
                d = sdf + 0.65 * periodic_wave(x, y, seed=9)
                if d >= 0.0:
                    if d < 1.0:
                        master[y][ox + x] = "B" if (is_ns and y >= 16) else "S"
                    elif d < 2.2:
                        if is_ns and y < 16:
                            master[y][ox + x] = "E" if (x % 8 == 0) else "L"
                        elif is_ns and y >= 16:
                            master[y][ox + x] = "M" if ((x + y) % 2 == 0) else "S"
                        else:
                            master[y][ox + x] = "A" if y < 16 else "N"
                    else:
                        master[y][ox + x] = soil_clod_token(x, y)

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("soil_curb_and_pores", {"B", "S", "M"}, 255),
            ("loam_clods", {"N", "A", "C"}, 255),
            ("clod_highlights", {"L", "E", "W"}, 255),
        ],
    )


def tilled_furrow_token(x: int, y: int, edge_taper: float = 1.0) -> str:
    row_idx, ry_i = y // 8, y % 8
    tau_x = 2.0 * math.pi / 32.0
    crumb = (
        0.045 * math.sin(tau_x * 3.0 * x + 1.7 * row_idx)
        + 0.040 * math.cos(tau_x * 5.0 * x + 2.9 * row_idx)
        + 0.030 * math.sin(tau_x * 9.0 * x + 0.8 * row_idx)
    )
    base_profile = (0.10, 0.48, 0.83, 0.72, 0.55, 0.36, 0.20, 0.09)[ry_i]
    lum = 0.34 + edge_taper * (base_profile - 0.34) + crumb

    if edge_taper > 0.85 and ry_i == 2 and ((x * 7 + row_idx * 11) % 16 == 3):
        return "W"
    if lum >= 0.79:
        return "E"
    if lum >= 0.65:
        return "L"
    if lum >= 0.50:
        return "C"
    if lum >= 0.35:
        return "A"
    if lum >= 0.22:
        return "N"
    return "M" if lum >= 0.12 else "S"


def gen_solid_soil_tilled_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)
    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                sdf, _, _, u, w = quadrant_sdf(block, x, y, margin=3.25, corner_radius=4.0)
                ns_w = border_ns_weight(block, u, w, margin=3.25, corner_radius=4.0)
                is_ns = ns_w >= 0.70
                ry_i = y % 8
                furrow_indent = -0.85 if ry_i in (0, 7) else (0.40 if ry_i in (2, 3, 4) else 0.0)
                h_expose = (1.0 - ns_w) ** 2
                d = sdf + h_expose * furrow_indent + 0.14 * h_expose * periodic_wave(x, y, seed=14)

                if d >= 0.0:
                    if d < 1.0:
                        master[y][ox + x] = "B" if (is_ns and y >= 16) else "S"
                    elif d < 2.1 and is_ns:
                        master[y][ox + x] = ("L" if x % 4 != 0 else "C") if y < 16 else ("M" if x % 4 != 0 else "S")
                    else:
                        taper = min(1.0, max(0.18, (d - 1.0) / 3.0))
                        master[y][ox + x] = tilled_furrow_token(x, y, edge_taper=taper)

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("furrow_troughs_and_curb", {"B", "S", "M"}, 255),
            ("ridge_slopes", {"N", "A", "C"}, 255),
            ("ridge_crests", {"L", "E", "W"}, 255),
        ],
    )


SURFACE_SOLID_SPRITES: dict[str, dict[str, Any]] = {
    "solid_dusting_flour_smooth": {
        "id": "solid_dusting_flour_smooth",
        "title": "Spilled Flour & Fine Powder Dusting (47-State Smooth)",
        "element": "solid",
        "category": "solid_dusting",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "ase_relpath": "assets/originals/art/matter/solids/solid_dusting_flour_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#F7F0E2",
        "sample_tints": [
            {"name": "Wheat Flour", "label": "Wheat Flour", "hex": "#F7F0E2"},
            {"name": "Settled Soot", "label": "Settled Soot", "hex": "#36313E"},
            {"name": "Sulfur Dust Sheet", "label": "Sulfur Dust Sheet", "hex": "#F5E04A"},
            {"name": "Caustic Lye Powder", "label": "Caustic Lye Powder", "hex": "#FFFFD6"},
        ],
        "description": "160x32 5-block bitmask strip for multi-tile fine powder carpeting with 4-tier feathered alpha borders (48/104/172/255).",
        "physics_notes": "Multi-tile powder blanket: seamless 32x32-periodic powder billows join with 0.00 seam MAE while outer borders feather across 4 opacity steps.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_dusting_flour_smooth()}],
    },
    "solid_debris_jagged_smooth": {
        "id": "solid_debris_jagged_smooth",
        "title": "Jagged Tunnel Rubble Carpeting (47-State Smooth)",
        "element": "solid",
        "category": "solid_debris",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_debris_jagged_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#968471",
        "sample_tints": [
            {"name": "Concrete / Sandstone", "label": "Concrete / Sandstone", "hex": "#968471"},
            {"name": "Mined Basalt Scree", "label": "Mined Basalt Scree", "hex": "#565A63"},
            {"name": "Martian Breccia", "label": "Martian Breccia", "hex": "#A8694A"},
            {"name": "Hull Breach Rubble", "label": "Hull Breach Rubble", "hex": "#777B83"},
        ],
        "description": "160x32 5-block bitmask strip of 4-connected basaltic scree slabs (#2B2B2B..#D9D9D9) with open-ended crevices, cushioned shadow recovery, and sparse ledge glints.",
        "physics_notes": "Continuous mined-tunnel or planetary scree bed: multi-scale angular basaltic slabs separated by 4-connected stepped crevices tile seamlessly across neighbors.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_debris_jagged_smooth()}],
    },
    "solid_soil_smooth": {
        "id": "solid_soil_smooth",
        "title": "Untilled Organic Soil Bed (47-State Smooth)",
        "element": "solid",
        "category": "solid_soil",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "ase_relpath": "assets/originals/art/matter/solids/solid_soil_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#6E4B2E",
        "sample_tints": [
            {"name": "Rich Loam", "label": "Rich Loam", "hex": "#6E4B2E"},
            {"name": "Martian Regolith", "label": "Martian Regolith", "hex": "#8C5338"},
            {"name": "Wet Peat", "label": "Wet Peat", "hex": "#3D352E"},
            {"name": "Dry Silt Bed", "label": "Dry Silt Bed", "hex": "#968471"},
        ],
        "description": "160x32 5-block bitmask strip of continuous isotropic clodded organic soil framed by a neat rounded earth plot curb.",
        "physics_notes": "Untilled farm/botany soil bed: high-value non-aligned neutral clods (#626262..#EEEEEE) preserve multi-tone soil depth under dark tints.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_soil_smooth()}],
    },
    "solid_soil_tilled_smooth": {
        "id": "solid_soil_tilled_smooth",
        "title": "Tilled Farm Plot Furrows (47-State Smooth)",
        "element": "solid",
        "category": "solid_soil",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "ase_relpath": "assets/originals/art/matter/solids/solid_soil_tilled_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#8C5338",
        "sample_tints": [
            {"name": "Martian Regolith Plot", "label": "Martian Regolith Plot", "hex": "#8C5338"},
            {"name": "Rich Tilled Loam", "label": "Rich Tilled Loam", "hex": "#6E4B2E"},
            {"name": "Moist Peat Furrows", "label": "Moist Peat Furrows", "hex": "#3D352E"},
            {"name": "Alluvial Earth", "label": "Alluvial Earth", "hex": "#7D563C"},
        ],
        "description": "160x32 5-block bitmask strip with 4 unbroken horizontal east-west raised planting ridges per tile, moist troughs, and scalloped headlands.",
        "physics_notes": "Cultivated hydroponic/farm plot: continuous hoed east-west ridges aerate root zones across multi-tile plots while rounding off at plot borders.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_soil_tilled_smooth()}],
    },
}
