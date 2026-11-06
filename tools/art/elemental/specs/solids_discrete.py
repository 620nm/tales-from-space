r"""
Discrete `32x32` single-tile solid generators and specs (`DISCRETE_SOLID_SPRITES`)
for crystalline grains, ore chunks, faceted heaps, shards, powder drifts, rubble, and loam.
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
from typing import Any

if __package__:
    from .solids_helpers import (
        build_layer,
        make_grid,
        periodic_delta,
        periodic_wave,
        point_in_convex_poly,
        prune_lone_pixels,
        rasterize_chiseled_chunk,
        rasterize_crystal_shard,
        render_faceted_pyramid_heap,
        split_by_token_sets,
        stamp_template,
    )
    from .solids_surfaces import flour_interior_token, soil_clod_token
else:
    _SPECS_DIR = str(Path(__file__).resolve().parent)
    if _SPECS_DIR not in sys.path:
        sys.path.insert(0, _SPECS_DIR)
    from solids_helpers import (  # type: ignore[import-not-found]
        build_layer,
        make_grid,
        periodic_delta,
        periodic_wave,
        point_in_convex_poly,
        prune_lone_pixels,
        rasterize_chiseled_chunk,
        rasterize_crystal_shard,
        render_faceted_pyramid_heap,
        split_by_token_sets,
        stamp_template,
    )
    from solids_surfaces import (  # type: ignore[import-not-found]
        flour_interior_token,
        soil_clod_token,
    )


# ==============================================================================
# 1. `solid_sprinkles` — Crisp Crystalline Salt / Sugar / Nitrate Grains
# ==============================================================================
def gen_solid_sprinkles() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    grains: list[tuple[int, int, list[str]]] = [
        (10, 4, ["WE", ".B"]),
        (19, 4, ["W", "M"]),
        (6, 7, [".WW", "EMB"]),
        (14, 6, ["WE", "NB"]),
        (24, 7, ["WE.", ".MB"]),
        (9, 10, ["WW.", "ENB"]),
        (14, 10, ["WE", "MB"]),
        (18, 9, [".WW", "ENB"]),
        (23, 11, ["W.", "MB"]),
        (5, 12, ["WE", ".B"]),
        (11, 13, ["WWE", "NMB"]),
        (16, 13, ["WE.", ".NB"]),
        (20, 13, ["WW", "MB"]),
        (26, 13, ["E", "M"]),
        (7, 16, [".WE", "EMB"]),
        (13, 16, ["WW.", "EMB"]),
        (18, 17, ["WE", "NB"]),
        (23, 16, ["EL.", ".MB"]),
        (9, 19, ["WE", "MB"]),
        (15, 20, [".WE", "NMB"]),
        (21, 20, ["EL", "MB"]),
        (6, 22, ["E.", "MB"]),
        (12, 23, ["EL", "MB"]),
        (18, 24, ["EC.", ".MB"]),
        (24, 23, ["L", "B"]),
    ]
    for gx, gy, tpl in grains:
        stamp_template(master, gx, gy, tpl)

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("contact_pixels", {"B"}, 255),
            ("refraction_facets", {"M", "N", "C"}, 255),
            ("crystal_glints", {"L", "E", "W"}, 255),
        ],
    )


# ==============================================================================
# 2. `solid_scattering` — Chiseled Polyhedral Mineral / Ore Fragments
# ==============================================================================
def gen_solid_scattering() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    chunks: list[tuple[tuple[float, float], list[tuple[float, float]], list[str]]] = [
        ((8.4, 5.6), [(6.2, 5.2), (9.8, 3.8), (11.6, 5.8), (9.4, 7.8), (6.4, 7.2)], ["W", "L", "N", "S", "A"]),
        ((19.5, 5.8), [(16.4, 5.0), (20.8, 3.6), (23.6, 5.4), (22.6, 8.2), (17.2, 8.0)], ["E", "L", "N", "S", "A"]),
        ((26.8, 8.6), [(25.2, 8.0), (28.2, 7.4), (28.8, 9.8), (25.8, 10.2)], ["E", "A", "S", "N"]),
        ((6.0, 12.2), [(3.6, 11.8), (6.8, 9.6), (8.8, 12.0), (6.8, 14.6), (4.0, 14.0)], ["W", "C", "S", "M", "L"]),
        ((13.6, 12.4), [(10.4, 11.4), (13.8, 9.4), (17.6, 10.8), (17.8, 14.4), (13.8, 15.6), (10.6, 14.2)], ["W", "E", "A", "S", "M", "C"]),
        ((22.4, 13.0), [(19.6, 12.2), (22.8, 10.6), (25.8, 12.6), (24.6, 15.6), (20.2, 15.0)], ["E", "C", "S", "M", "A"]),
        ((6.8, 18.8), [(4.2, 18.2), (7.4, 16.6), (9.8, 18.6), (8.6, 21.2), (4.8, 20.8)], ["E", "L", "N", "S", "A"]),
        ((13.4, 19.8), [(11.0, 18.8), (14.6, 17.6), (16.4, 19.8), (14.8, 22.2), (11.2, 21.6)], ["E", "C", "S", "M", "A"]),
        ((20.2, 19.6), [(17.6, 18.8), (20.8, 17.2), (23.8, 19.0), (22.8, 22.0), (18.2, 21.8)], ["E", "L", "N", "S", "A"]),
        ((26.8, 18.2), [(25.2, 17.4), (28.2, 16.8), (28.6, 19.4), (25.6, 19.8)], ["L", "A", "S", "M"]),
        ((8.6, 24.8), [(6.4, 24.2), (9.6, 23.0), (11.2, 25.0), (8.8, 26.8)], ["L", "C", "S", "M"]),
        ((17.8, 25.0), [(15.4, 24.4), (18.6, 23.2), (20.8, 25.0), (18.8, 27.0), (15.8, 26.6)], ["L", "A", "S", "M", "C"]),
    ]
    for apex, ring, ftoks in chunks:
        rasterize_chiseled_chunk(master, apex, ring, ftoks, shadow_south=True)

    stamp_template(master, 13, 5, ["EL", "SO"])
    stamp_template(master, 23, 24, ["LC.", "NMO"])
    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("contact_and_cliff_shadows", {"O", "D", "B", "S"}, 255),
            ("mid_planes", {"M", "N", "A"}, 255),
            ("sunlit_planes", {"C", "L", "E", "W"}, 255),
        ],
    )


# ==============================================================================
# 3 & 4. Faceted Pyramidal Heaps (`solid_pile_small`, `solid_pile_large`)
# ==============================================================================
def gen_solid_pile_small() -> list[dict[str, Any]]:
    pyramids = [
        (
            (15.4, 17.2, 8.8),
            [(15.2, 9.6), (8.6, 12.6), (7.4, 19.2), (15.0, 23.4), (22.8, 20.0), (22.2, 13.0)],
        ),
        (
            (10.0, 19.0, 5.4),
            [(9.6, 14.2), (5.2, 17.6), (6.6, 22.4), (12.6, 23.4), (14.6, 19.0)],
        ),
        (
            (20.8, 19.0, 5.0),
            [(20.6, 14.6), (16.6, 18.6), (18.8, 23.2), (24.8, 21.6), (24.6, 17.0)],
        ),
    ]
    skirt_chunks = [
        (4, 20, ["WE.", ".MB"]),
        (25, 20, ["EL", "MB"]),
        (6, 24, ["WL.", "NMD"]),
        (12, 25, ["EL", "SD"]),
        (19, 25, ["LC.", "MSD"]),
        (24, 23, ["CA", "SD"]),
    ]
    return render_faceted_pyramid_heap(pyramids, skirt_chunks, seed=4)


def gen_solid_pile_large() -> list[dict[str, Any]]:
    pyramids = [
        (
            (13.6, 16.4, 11.2),
            [(13.4, 6.8), (6.2, 10.6), (4.8, 18.8), (13.2, 24.2), (21.6, 20.6), (21.0, 11.2)],
        ),
        (
            (21.8, 18.0, 8.8),
            [(21.6, 10.2), (15.6, 14.0), (16.4, 22.0), (23.6, 24.8), (28.6, 20.4), (27.6, 13.8)],
        ),
        (
            (7.6, 19.2, 7.2),
            [(7.4, 12.6), (2.4, 16.8), (3.4, 22.6), (9.8, 25.0), (14.0, 20.4)],
        ),
        (
            (16.6, 21.4, 6.2),
            [(16.2, 15.8), (10.6, 20.4), (12.6, 26.2), (20.0, 26.4), (23.0, 21.8)],
        ),
    ]
    skirt_chunks = [
        (1, 20, ["WE", "MB"]),
        (2, 24, ["WL.", "NMD"]),
        (7, 26, ["EL.", "MSD"]),
        (15, 27, ["LC", "SD"]),
        (22, 26, ["ELC", "MSD"]),
        (27, 23, ["LC", "SD"]),
        (28, 18, ["WE", "MB"]),
        (4, 9, ["WW", "MB"]),
        (25, 9, ["WE", "NB"]),
    ]
    return render_faceted_pyramid_heap(pyramids, skirt_chunks, seed=11)


# ==============================================================================
# 5 & 6. Straight-Edged Crystal / Glass Shards (`shards_small`, `shards_large`)
# ==============================================================================
def gen_solid_shards_small() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    shards = [
        ([(4.2, 3.8), (8.2, 5.2), (11.8, 9.8), (6.8, 7.8)], (4.2, 3.8), (11.8, 9.8), "E", "W", "M", "D"),
        ([(22.8, 3.2), (24.4, 6.8), (20.2, 11.4), (19.0, 7.6)], (22.8, 3.2), (20.2, 11.4), "E", "W", "N", "D"),
        ([(13.8, 11.4), (11.2, 15.8), (4.6, 15.6)], (4.6, 15.6), (12.8, 13.4), "W", "W", "M", "D"),
        ([(16.6, 12.6), (22.2, 13.8), (26.8, 17.8), (20.4, 16.4)], (16.6, 12.6), (26.8, 17.8), "E", "W", "M", "D"),
        ([(8.6, 18.8), (9.8, 22.0), (5.4, 26.6), (4.8, 23.0)], (8.6, 18.8), (5.4, 26.6), "E", "W", "N", "D"),
        ([(12.4, 19.6), (16.8, 21.4), (19.8, 26.2), (14.6, 24.0)], (12.4, 19.6), (19.8, 26.2), "E", "W", "M", "D"),
        ([(26.8, 20.6), (26.2, 24.8), (21.4, 25.6)], (26.8, 20.6), (21.4, 25.6), "E", "W", "N", "D"),
    ]
    for verts, s0, s1, ltok, rtok, stok, etok in shards:
        rasterize_crystal_shard(master, verts, s0, s1, ltok, rtok, stok, etok, cut_shadow_on_overlap=False)

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("fracture_lips", {"O", "D", "S"}, 255),
            ("refraction_planes", {"M", "N"}, 255),
            ("sunlit_facets_and_ridges", {"E", "W"}, 255),
        ],
    )


def gen_solid_shards_large() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    shards = [
        ([(2.4, 3.6), (7.4, 5.2), (11.2, 10.2), (5.6, 8.2)], (2.4, 3.6), (11.2, 10.2), "E", "W", "M", "D"),
        ([(18.8, 2.2), (20.8, 7.4), (16.4, 12.8), (15.0, 7.6)], (18.8, 2.2), (16.4, 12.8), "E", "W", "N", "D"),
        ([(29.4, 5.4), (27.6, 10.2), (22.2, 9.6)], (29.4, 5.4), (22.2, 9.6), "W", "W", "M", "D"),
        ([(17.4, 11.4), (14.8, 16.4), (3.0, 17.6), (8.8, 12.4)], (3.0, 17.6), (17.4, 11.4), "E", "W", "M", "D"),
        ([(12.6, 10.8), (19.6, 13.0), (26.4, 18.6), (18.2, 16.4)], (12.6, 10.8), (26.4, 18.6), "E", "W", "N", "D"),
        ([(25.2, 12.2), (30.2, 13.6), (27.4, 16.4)], (30.2, 13.6), (25.2, 12.2), "W", "W", "M", "D"),
        ([(8.4, 19.6), (9.8, 23.2), (4.2, 28.2), (3.8, 24.0)], (8.4, 19.6), (4.2, 28.2), "E", "W", "N", "D"),
        ([(11.2, 19.8), (20.6, 22.8), (14.4, 27.6)], (11.2, 19.8), (20.2, 23.2), "E", "W", "M", "D"),
        ([(22.2, 20.8), (26.8, 22.4), (29.6, 27.6), (24.4, 25.4)], (22.2, 20.8), (29.6, 27.6), "E", "W", "N", "D"),
    ]
    for verts, s0, s1, ltok, rtok, stok, etok in shards:
        rasterize_crystal_shard(master, verts, s0, s1, ltok, rtok, stok, etok, cut_shadow_on_overlap=True)

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("fracture_cuts_and_lips", {"O", "D", "S"}, 255),
            ("refraction_planes", {"M", "N"}, 255),
            ("sunlit_facets_and_ridges", {"E", "W"}, 255),
        ],
    )


# ==============================================================================
# 7. Fine Powder Drift (`solid_dusting_flour_single`)
# ==============================================================================
def gen_solid_dusting_flour_single() -> list[dict[str, Any]]:
    fringe = make_grid(32, 32)
    halo = make_grid(32, 32)
    apron = make_grid(32, 32)
    core = make_grid(32, 32)
    lobes = [
        (15.0, 15.5, 11.4, 9.8),
        (21.8, 18.2, 8.2, 7.0),
        (8.8, 18.4, 7.8, 6.6),
        (16.2, 10.0, 8.4, 5.8),
        (10.5, 11.5, 6.8, 5.4),
    ]
    for y in range(32):
        for x in range(32):
            wob = 1.05 * periodic_wave(x, y, seed=5)
            best = max((1.0 - math.hypot((x - cx) / rx, (y - cy) / ry)) * 10.0 + wob for cx, cy, rx, ry in lobes)
            north_bias = (15.5 - y) * 0.011
            if best >= 2.8:
                rim = 0.10 if (best < 4.2 and y < 14) else (-0.06 if (best < 4.0 and y > 20) else 0.0)
                core[y][x] = flour_interior_token(x, y, north_rim_boost=north_bias + rim)
            elif best >= 1.3:
                apron[y][x] = "E" if y < 14 else ("L" if y < 20 else "C")
            elif best >= -0.1:
                halo[y][x] = "L" if y < 15 else ("C" if y < 21 else "A")
            elif best >= -1.35:
                fringe[y][x] = "C" if y < 16 else "A"

    stamp_template(fringe, 2, 10, ["LC", "CA"])
    stamp_template(fringe, 27, 10, ["LC", "AA"])
    stamp_template(fringe, 3, 25, ["CA", "AA"])
    stamp_template(fringe, 26, 25, ["CA", "AN"])

    prune_lone_pixels([fringe, halo, apron, core])
    return [
        build_layer("wisp_fringe", fringe, opacity=48),
        build_layer("dust_halo", halo, opacity=104),
        build_layer("powder_apron", apron, opacity=172),
        build_layer("flour_drift", core, opacity=255),
    ]


# ==============================================================================
# 8. Jagged Rubble Patch (`solid_debris_jagged_single`)
# ==============================================================================
_QUAD_ANGLES: list[tuple[float, float, float, float]] = [
    (0.18, 1.62, 3.38, 4.88),
    (0.52, 2.15, 3.72, 5.24),
    (0.08, 1.88, 3.12, 4.65),
    (0.36, 1.54, 3.55, 5.05),
]

_RUBBLE_SEEDS: list[tuple[float, float, float, str]] = [
    (5.4, 4.8, 1.24, "L"),
    (15.8, 4.0, 1.04, "C"),
    (25.2, 5.8, 1.22, "L"),
    (10.2, 8.8, 0.88, "C"),
    (13.8, 10.6, 0.82, "A"),
    (20.6, 10.2, 0.90, "A"),
    (29.8, 12.2, 0.96, "C"),
    (4.2, 14.6, 1.02, "C"),
    (15.2, 15.8, 1.26, "L"),
    (22.4, 14.2, 0.86, "C"),
    (25.8, 16.4, 0.82, "N"),
    (8.8, 21.4, 1.18, "A"),
    (18.6, 22.8, 0.94, "N"),
    (27.6, 21.4, 1.12, "C"),
    (2.0, 24.6, 0.86, "C"),
    (5.2, 27.6, 0.84, "A"),
    (13.4, 28.4, 1.12, "C"),
    (22.8, 28.8, 0.94, "A"),
    (30.2, 27.8, 0.84, "N"),
]


def quad_dist_periodic(x: float, y: float, sx: float, sy: float, scale: float, idx: int) -> float:
    dx, dy = periodic_delta(x, sx, 32.0), periodic_delta(y, sy, 32.0)
    angs = _QUAD_ANGLES[idx % len(_QUAD_ANGLES)]
    best = 0.0
    for k, a in enumerate(angs):
        stretch = 1.18 if (k + idx) % 2 == 0 else 0.88
        proj = (dx * math.cos(a) + dy * math.sin(a)) * stretch
        if proj > best:
            best = proj
    return best / scale


def rubble_cell_info(x: int, y: int) -> tuple[int, float]:
    d1, d2, id1 = 999.0, 999.0, 0
    for idx, (sx, sy, sc, _) in enumerate(_RUBBLE_SEEDS):
        d = quad_dist_periodic(x + 0.5, y + 0.5, sx, sy, sc, idx)
        if d < d1:
            d2, d1, id1 = d1, d, idx
        elif d < d2:
            d2 = d
    return id1, (d2 - d1)


def rubble_interior_token(x: int, y: int) -> str:
    cid, crack = rubble_cell_info(x, y)
    cid_n, crack_n = rubble_cell_info(x, (y - 1) % 32)
    cid_s, crack_s = rubble_cell_info(x, (y + 1) % 32)
    cid_w, crack_w = rubble_cell_info((x - 1) % 32, y)
    cid_e, crack_e = rubble_cell_info((x + 1) % 32, y)
    _, _, _, flat_tok = _RUBBLE_SEEDS[cid]

    if crack < 0.48:
        return "O" if (crack < 0.20 and (cid + x + y) % 4 == 0) else "D"
    if cid_n != cid or crack_n < 0.48:
        return "E" if flat_tok in ("L", "C") else "L"
    if cid_w != cid or crack_w < 0.48:
        return "E" if flat_tok == "L" else "C"
    if cid_s != cid or crack_s < 0.48:
        return "M" if flat_tok in ("L", "C") else "S"
    if cid_e != cid or crack_e < 0.48:
        return "N" if flat_tok == "L" else "M"
    return flat_tok


def gen_solid_debris_jagged_single() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    patch_verts = [
        (6.5, 4.5), (18.5, 3.5), (27.5, 8.5), (28.0, 20.5),
        (20.5, 26.5), (7.5, 25.5), (3.5, 16.5),
    ]

    def tri_ang(t: float) -> float:
        return 1.0 - 4.0 * abs((t % 1.0) - 0.5)

    for y in range(32):
        for x in range(32):
            jx = x + 0.5 + 1.4 * tri_ang((x + 2 * y) / 9.0)
            jy = y + 0.5 + 1.4 * tri_ang((2 * x - y) / 11.0)
            if point_in_convex_poly(jx, jy, patch_verts):
                tok = rubble_interior_token(x, y)
                if y <= 10 and tok == "A":
                    tok = "C"
                elif y >= 21 and tok == "L":
                    tok = "A"
                master[y][x] = tok

    orig = [row[:] for row in master]
    for y in range(32):
        for x in range(32):
            if orig[y][x] == ".":
                continue
            s_empty = y == 31 or orig[y + 1][x] == "."
            e_empty = x == 31 or orig[y][x + 1] == "."
            n_empty = y == 0 or orig[y - 1][x] == "."
            if s_empty:
                master[y][x] = "O"
            elif e_empty:
                master[y][x] = "D"
            elif n_empty and y + 1 < 32 and orig[y + 1][x] != ".":
                master[y][x] = "E" if x % 2 == 0 else "L"

    splinters = [
        (2, 7, ["WE.", ".MD"]),
        (25, 4, [".WE", "EMD"]),
        (1, 19, ["EL.", ".MD"]),
        (27, 16, ["WEL", ".MD"]),
        (4, 26, ["EL.", "NDO"]),
        (23, 26, [".LC", "MDO"]),
        (13, 27, ["CA.", ".DO"]),
    ]
    for cx_i, cy_i, tpl in splinters:
        stamp_template(master, cx_i, cy_i, tpl)

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("cracks_and_undercuts", {"O", "D", "B", "S", "M"}, 255),
            ("flat_stone_slabs", {"N", "A", "C", "L"}, 255),
            ("fracture_bevels", {"E", "W"}, 255),
        ],
    )


# ==============================================================================
# 9. Loose Clodded Soil Patch (`solid_soil_patch_single`)
# ==============================================================================
def gen_solid_soil_patch_single() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    lobes = [
        (15.5, 16.2, 10.8, 9.4),
        (10.0, 18.2, 7.4, 6.2),
        (21.2, 17.8, 7.6, 6.4),
        (15.8, 11.0, 8.0, 5.8),
    ]
    for y in range(32):
        for x in range(32):
            wob = 0.85 * periodic_wave(x, y, seed=9)
            best = max((1.0 - math.hypot((x - cx) / rx, (y - cy) / ry)) * 10.0 + wob for cx, cy, rx, ry in lobes)
            if best >= 0.0:
                if best < 1.05:
                    master[y][x] = "B" if y >= 15 else "S"
                elif best < 2.15:
                    master[y][x] = "L" if y < 12 else ("M" if y >= 21 else "N")
                else:
                    tok = soil_clod_token(x, y)
                    if y >= 23 and tok in ("E", "W"):
                        tok = "C"
                    elif y <= 10 and tok == "N":
                        tok = "C"
                    master[y][x] = tok

    stamp_template(master, 4, 22, ["CA", "MB"])
    stamp_template(master, 25, 22, ["LC", "SB"])
    stamp_template(master, 6, 9, ["LC", "NM"])

    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("soil_curb_and_pores", {"B", "S", "M"}, 255),
            ("loam_clods", {"N", "A", "C"}, 255),
            ("clod_highlights", {"L", "E", "W"}, 255),
        ],
    )


DISCRETE_SOLID_SPRITES: dict[str, dict[str, Any]] = {
    "solid_sprinkles": {
        "id": "solid_sprinkles",
        "title": "Crystalline Granular Sprinkles",
        "element": "solid",
        "category": "solid_discrete",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_sprinkles.aseprite",
        "tag": "idle",
        "default_tint": "#60A584",
        "sample_tints": [
            {"name": "Saltpeter", "label": "Saltpeter", "hex": "#60A584"},
            {"name": "Table Salt / Sugar", "label": "Table Salt / Sugar", "hex": "#FFFFFF"},
            {"name": "Sulfur Grains", "label": "Sulfur Grains", "hex": "#BF8C00"},
            {"name": "Black Powder", "label": "Black Powder", "hex": "#515151"},
        ],
        "description": "25 crisp micro-cubes, 3x2 rhomboids, and 2px glinting crystal specks with hard #FFFFFF/#EEEEEE facets and 1px #2B2B2B SE contact pixels.",
        "physics_notes": "Low-volume discrete particulate (1-5 mL): individual cleaved crystals rest independently with sharp specular corners.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_sprinkles()}],
    },
    "solid_scattering": {
        "id": "solid_scattering",
        "title": "Coarse Ore & Gravel Scattering",
        "element": "solid",
        "category": "solid_discrete",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_scattering.aseprite",
        "tag": "idle",
        "default_tint": "#D4803D",
        "sample_tints": [
            {"name": "Native Copper", "label": "Native Copper", "hex": "#D4803D"},
            {"name": "Sulfur Nuggets", "label": "Sulfur Nuggets", "hex": "#BF8C00"},
            {"name": "Iron Pellets", "label": "Iron Pellets", "hex": "#606060"},
            {"name": "Iron Oxide Clinker", "label": "Iron Oxide Clinker", "hex": "#8B4513"},
        ],
        "description": "Chiseled straight-edged polyhedral mineral and ore fragments divided into 3-4 flat-shaded planes + 1px #1D1D1D south contact shadow.",
        "physics_notes": "Coarse discrete solids (5-15 mL): cleaved metallic/mineral polyhedra exhibit flat planar fracture faces without rounded pebble wear.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_scattering()}],
    },
    "solid_pile_small": {
        "id": "solid_pile_small",
        "title": "Compact Faceted Solid Heap",
        "element": "solid",
        "category": "solid_discrete",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_pile_small.aseprite",
        "tag": "idle",
        "default_tint": "#F5E04A",
        "sample_tints": [
            {"name": "Sulfur Heap", "label": "Sulfur Heap", "hex": "#F5E04A"},
            {"name": "Salt Pile", "label": "Salt Pile", "hex": "#FFFFFF"},
            {"name": "Settled Ash", "label": "Settled Ash", "hex": "#515151"},
            {"name": "Iron Oxide / Thermite", "label": "Iron Oxide / Thermite", "hex": "#8B4513"},
        ],
        "description": "Angular multi-faceted pyramidal heap with crisp ridge crests, flat-shaded planar slopes, zigzag base, and spilled crystal/grain chunks.",
        "physics_notes": "Medium bulk crystalline/granular heap (15-35 mL): interlocking angular grains form sharp slump ridges and planar faces.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_pile_small()}],
    },
    "solid_pile_large": {
        "id": "solid_pile_large",
        "title": "Broad Multi-Ridged Solid Mound",
        "element": "solid",
        "category": "solid_discrete",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_pile_large.aseprite",
        "tag": "idle",
        "default_tint": "#A8694A",
        "sample_tints": [
            {"name": "Crushed Copper / Rust", "label": "Crushed Copper / Rust", "hex": "#A8694A"},
            {"name": "Heavy Ash Mound", "label": "Heavy Ash Mound", "hex": "#515151"},
            {"name": "Bulk Salt Mound", "label": "Bulk Salt Mound", "hex": "#FFFFFF"},
            {"name": "Sulfur Bulk", "label": "Sulfur Bulk", "hex": "#BF8C00"},
        ],
        "description": "Multi-peaked angular pyramidal mound with sharp intersecting ridge spines, flat planar facets, valley creases, and spilled angular chunks.",
        "physics_notes": "High-volume bulk crystalline/granular mound (35+ mL): intersecting angular slump pyramids preserve crisp ridge geometry.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_pile_large()}],
    },
    "solid_shards_small": {
        "id": "solid_shards_small",
        "title": "Sparse Razor Crystal & Glass Shards",
        "element": "solid",
        "category": "solid_discrete",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_shards_small.aseprite",
        "tag": "idle",
        "default_tint": "#C4EAF5",
        "sample_tints": [
            {"name": "Water Ice / Glass", "label": "Water Ice / Glass", "hex": "#C4EAF5"},
            {"name": "Silicon Wafer Shards", "label": "Silicon Wafer Shards", "hex": "#A8A8A8"},
            {"name": "Solid Plasma Splinters", "label": "Solid Plasma Splinters", "hex": "#E03997"},
            {"name": "Radium Crystal", "label": "Radium Crystal", "hex": "#50FF31"},
        ],
        "description": "Seven straight-edged geometric crystal prisms, acute triangles, and 1px-tip daggers with flat bimodal facets across a central spine.",
        "physics_notes": "Brittle cleavage/conchoidal fracture (low volume): flat planar facets jump sharply across longitudinal ridges with zero radial falloff.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_shards_small()}],
    },
    "solid_shards_large": {
        "id": "solid_shards_large",
        "title": "Dense Shattered Crystal Fracture Field",
        "element": "solid",
        "category": "solid_discrete",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_shards_large.aseprite",
        "tag": "idle",
        "default_tint": "#E03997",
        "sample_tints": [
            {"name": "Solid Plasma Shards", "label": "Solid Plasma Shards", "hex": "#E03997"},
            {"name": "Shattered Ice / Glass", "label": "Shattered Ice / Glass", "hex": "#C4EAF5"},
            {"name": "Polysilicon Shards", "label": "Polysilicon Shards", "hex": "#A8A8A8"},
            {"name": "Phenol Crystal", "label": "Phenol Crystal", "hex": "#E7EA91"},
        ],
        "description": "Dense shattered cluster of 10-14px crystal spires, overlapping cleavage blades, and 1px-tip daggers with flat bimodal planar facets.",
        "physics_notes": "High-energy crystalline shatter (high volume): elongated overlapping prisms cast crisp 1px cut lines and razor specular spines.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_shards_large()}],
    },
    "solid_dusting_flour_single": {
        "id": "solid_dusting_flour_single",
        "title": "Spilled Flour & Fine Powder Drift (Single)",
        "element": "solid",
        "category": "solid_dusting",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_dusting_flour_single.aseprite",
        "tag": "idle",
        "default_tint": "#F7F0E2",
        "sample_tints": [
            {"name": "Wheat Flour", "label": "Wheat Flour", "hex": "#F7F0E2"},
            {"name": "Fine Soot / Ash", "label": "Fine Soot / Ash", "hex": "#515151"},
            {"name": "Sulfur Dusting", "label": "Sulfur Dusting", "hex": "#F5E04A"},
            {"name": "Rust / Iron Oxide Dust", "label": "Rust / Iron Oxide Dust", "hex": "#A45729"},
        ],
        "description": "High-luma spilled fine powder sheet across 4 alpha layers (48/104/172/255) with wide feathered dust halo and billowed drift core.",
        "physics_notes": "Cohesive fine powder (<50 um): van der Waals cohesion holds soft billowed drifts ringed by a wide 4-step airborne-settled dust halo.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_dusting_flour_single()}],
    },
    "solid_debris_jagged_single": {
        "id": "solid_debris_jagged_single",
        "title": "Jagged Rock & Concrete Rubble Patch (Single)",
        "element": "solid",
        "category": "solid_debris",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_debris_jagged_single.aseprite",
        "tag": "idle",
        "default_tint": "#968471",
        "sample_tints": [
            {"name": "Spalled Concrete", "label": "Spalled Concrete", "hex": "#968471"},
            {"name": "Basalt Tunnel Scree", "label": "Basalt Tunnel Scree", "hex": "#565A63"},
            {"name": "Siderite / Regolith", "label": "Siderite / Regolith", "hex": "#824B32"},
            {"name": "Station Slag", "label": "Station Slag", "hex": "#777B83"},
        ],
        "description": "Sharp 4-sided angular rock/concrete slabs with constant flat top faces, 1px #EEEEEE NW bevels, #1D1D1D cracks, and perimeter splinters.",
        "physics_notes": "Spalled structural/mineral rubble: brittle masonry fractures into flat-topped quadrilateral wedges separated by sharp dark joints.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_debris_jagged_single()}],
    },
    "solid_soil_patch_single": {
        "id": "solid_soil_patch_single",
        "title": "Loose Clodded Loam & Soil Patch (Single)",
        "element": "solid",
        "category": "solid_soil",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "ase_relpath": "assets/originals/art/matter/solids/solid_soil_patch_single.aseprite",
        "tag": "idle",
        "default_tint": "#70533B",
        "sample_tints": [
            {"name": "Garden Loam", "label": "Garden Loam", "hex": "#70533B"},
            {"name": "Rich Organic Loam", "label": "Rich Organic Loam", "hex": "#6E4B2E"},
            {"name": "Martian Regolith", "label": "Martian Regolith", "hex": "#8C5338"},
            {"name": "Wet Peat", "label": "Wet Peat", "hex": "#3D352E"},
        ],
        "description": "Isotropic mounded patch of quasi-randomly packed rounded organic loam clods (#626262..#EEEEEE) with moist pores and mineral specks.",
        "physics_notes": "Humic soil aggregation: moisture and organic matter bind silt/clay into soft rounded non-aligned peds/clods.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_soil_patch_single()}],
    },
}
