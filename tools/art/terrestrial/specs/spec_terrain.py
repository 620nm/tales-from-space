r"""
Neutral-greyscale pixel-art generators and specs for Tales from Space Terrestrial
terrain, glacial ice, stepped cliffs, and matte boulder outcrops (`TERRAIN_SPRITES`).
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
from typing import Any

if __package__:
    from .helpers import (
        LIGHT_X,
        LIGHT_Y,
        build_basalt_plate_32,
        build_layers,
        make_grid,
        prune_lone_pixels_per_block,
        put_exclusive,
        quad_base_sdf,
        sdf_outward_normal,
        split_by_token_sets,
        sym_cos,
        torus_wave,
    )
else:
    _TERRESTRIAL_DIR = str(Path(__file__).resolve().parents[1])
    if _TERRESTRIAL_DIR not in sys.path:
        sys.path.insert(0, _TERRESTRIAL_DIR)
    from specs.helpers import (  # type: ignore[import-not-found]
        LIGHT_X,
        LIGHT_Y,
        build_basalt_plate_32,
        build_layers,
        make_grid,
        prune_lone_pixels_per_block,
        put_exclusive,
        quad_base_sdf,
        sdf_outward_normal,
        split_by_token_sets,
        sym_cos,
        torus_wave,
    )


# ==============================================================================
# 1. `terrain_silicate_rough_smooth` — Calm Basalt-Style Regolith Plates
# ==============================================================================
_SILICATE_SEEDS: list[tuple[float, float, float, float]] = [
    # Strongly asymmetric multi-scale slabs (broad expanse + medium ledges + small flake, like tg_basalt!)
    (6.2, 5.4, 1.55, 0.34),
    (22.8, 4.2, 1.05, -0.42),
    (28.4, 13.6, 0.78, 0.50),
    (12.4, 16.8, 1.62, -0.28),
    (3.4, 24.8, 1.12, 0.38),
    (23.6, 25.4, 1.38, -0.35),
]


def gen_terrain_silicate_rough_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)
    # Tight 5-step ramp: M(rare pocket <3%) - N(crevice) - A(slope) - C(calm body) - L(sparse lip)
    plate_32 = build_basalt_plate_32(
        _SILICATE_SEEDS,
        ramp=("M", "N", "A", "C", "L"),
        warp_amp=2.25,
        warp_seed=1.4,
        pocket_thresh=0.44,
        taper_thresh=-0.12,
        lip_thresh=0.12,
    )
    inset = 2.35
    r_conv = 2.2

    for block in range(5):
        ox = block * 32

        def sdf_b(px: float, py: float, b: int = block) -> float:
            if b == 4:
                return 24.0
            wob = (
                0.44 * sym_cos(px, 1)
                + 0.36 * sym_cos(px, 2)
                - 0.28 * sym_cos(px, 3)
                + 0.42 * sym_cos(py, 1)
                + 0.34 * sym_cos(py, 2)
                - 0.26 * sym_cos(py, 3)
                + 0.20 * sym_cos(px, 2) * sym_cos(py, 2)
            )
            return quad_base_sdf(b, px, py, inset, r_conv) + wob

        for y in range(32):
            for x in range(32):
                s = sdf_b(x, y)
                if s < 0.0:
                    continue
                if block == 4 or s >= 2.85:
                    master[y][ox + x] = plate_32[y][x]
                else:
                    nx, ny = sdf_outward_normal(sdf_b, x, y)
                    ldot = nx * LIGHT_X + ny * LIGHT_Y
                    if ldot >= 0.18:
                        master[y][ox + x] = "N" if s < 0.90 else ("L" if ldot > 0.45 else "C")
                    elif ldot <= -0.15:
                        master[y][ox + x] = "S" if s < 0.95 else ("M" if s < 1.95 else "N")
                    else:
                        master[y][ox + x] = "M" if s < 0.90 else ("C" if ny < 0.0 else "A")

    layers = split_by_token_sets(
        master,
        [
            ("shelf_edge_and_crevices", {"S", "M", "N"}, 255),
            ("regolith_plates", {"A", "C"}, 255),
            ("plate_lips", {"L"}, 255),
        ],
    )
    return [{"duration_ms": 200, "layers": layers}]


# ==============================================================================
# 2. `terrain_ice_sheet_smooth` — Smooth Glacial Ice w/ 4-Connected Pale Seams
# ==============================================================================
_ICE_SEEDS: list[tuple[float, float, float, float]] = [
    (5.8, 5.2, 1.65, 0.28),
    (23.4, 6.4, 1.18, -0.36),
    (12.2, 17.6, 1.72, -0.22),
    (27.8, 18.8, 0.86, 0.42),
    (6.4, 26.8, 1.24, 0.32),
    (21.8, 27.4, 1.42, -0.30),
]


def gen_terrain_ice_sheet_smooth() -> list[dict[str, Any]]:
    layer_defs = [
        ("submerged_calving_skirt", 160),
        ("cleaved_ice_wall", 255),
        ("planar_ice_sheet", 255),
        ("specular_brow_glints", 255),
    ]
    grids = [make_grid(160, 32) for _ in layer_defs]
    # Whisper-soft 4-step pale ice ramp: A(170) - C(196) - L(217) - E(238), ZERO dark cracks!
    ice_32 = build_basalt_plate_32(
        _ICE_SEEDS,
        ramp=("A", "A", "C", "L", "E"),
        warp_amp=2.10,
        warp_seed=4.3,
        pocket_thresh=0.95,
        taper_thresh=-0.05,
        lip_thresh=0.14,
    )
    # Soft diagonal glacial sheen so plate interiors aren't dead-flat across quadrant boundaries
    for y in range(32):
        for x in range(32):
            if ice_32[y][x] == "L" and torus_wave(x, y, seed=5.9) < -0.18:
                ice_32[y][x] = "C"
    inset = 3.00
    r_conv = 1.75

    for block in range(5):
        ox = block * 32

        def sdf_b(px: float, py: float, b: int = block) -> float:
            if b == 4:
                return 24.0
            cleave = (
                0.48 * sym_cos(px, 1)
                - 0.34 * sym_cos(px, 2)
                + 0.20 * sym_cos(px, 3)
                + 0.44 * sym_cos(py, 1)
                - 0.30 * sym_cos(py, 2)
            )
            return quad_base_sdf(b, px, py, inset, r_conv) + cleave

        for y in range(32):
            for x in range(32):
                s = sdf_b(x, y)
                if s < -1.75:
                    continue
                if s < 0.0:
                    nx, ny = sdf_outward_normal(sdf_b, x, y)
                    ch = "C" if (ny < -0.2 or nx < -0.3) else ("A" if s > -0.90 else "N")
                    put_exclusive(grids, 0, ox + x, y, ch)
                    continue

                if block == 4 or s >= 4.10:
                    tok = ice_32[y][x]
                else:
                    nx, ny = sdf_outward_normal(sdf_b, x, y)
                    flute = sym_cos(x, 4) > 0.52
                    if ny > 0.30 and s < 4.10:
                        if s < 0.90:
                            tok = "S"
                        elif s < 2.10:
                            tok = "M" if flute else "N"
                        elif s < 3.25:
                            tok = "A" if flute else "C"
                        else:
                            tok = "W" if not flute else "E"
                    elif ny < -0.30 and s < 2.15:
                        tok = "A" if s < 0.75 else ("W" if s < 1.65 else "E")
                    elif s < 2.50:
                        if nx < 0.0:
                            tok = "A" if s < 0.85 else "E"
                        else:
                            tok = "M" if s < 0.85 else ("C" if s < 1.80 else "L")
                    else:
                        tok = ice_32[y][x]

                l_idx = 1 if tok in ("S", "M", "N") else (2 if tok in ("A", "C", "L") else 3)
                put_exclusive(grids, l_idx, ox + x, y, tok)

    prune_lone_pixels_per_block(grids)
    return [{"duration_ms": 200, "layers": build_layers(layer_defs, grids)}]


# ==============================================================================
# 3. `terrain_cliff_stepped_smooth` — 3/4 Oblique Stepped Planetary Escarpment
# ==============================================================================
_CLIFF_PLATEAU_SEEDS: list[tuple[float, float, float, float]] = [
    (4.4, 4.8, 1.38, 0.20),
    (17.6, 4.2, 1.42, -0.24),
    (28.2, 11.4, 1.32, 0.28),
    (10.2, 15.6, 1.36, -0.18),
    (22.4, 18.8, 1.38, 0.16),
    (5.2, 26.2, 1.34, -0.22),
    (18.2, 27.4, 1.40, 0.24),
]

_CLIFF_PLATEAU_32: list[list[str]] = build_basalt_plate_32(
    _CLIFF_PLATEAU_SEEDS,
    ramp=("N", "N", "A", "C", "L"),
    warp_amp=1.35,
    warp_seed=2.7,
    pocket_thresh=0.95,
)


def _shade_south_cliff_column(x: int, u_v: float, w_s: float) -> tuple[int, str] | None:
    s = u_v - w_s
    if s < 0.25:
        return None
    if s < 2.15:
        return (0, "K")
    if s < 3.05:
        return (1, "O")

    joint_field = sym_cos(x, 4) + 0.45 * sym_cos(x, 2)
    is_fissure = joint_field > 1.08
    is_col_lit = (-1.15 < joint_field < -0.45)

    if s < 5.75:
        if is_fissure:
            return (1, "O" if s < 4.2 else "B")
        if s < 4.25:
            return (1, "B")
        return (1, "M" if is_col_lit else "S")

    if s < 6.80:
        if is_fissure:
            return (1, "B")
        return (2, "C" if is_col_lit else "A")

    if s < 7.65:
        return (1, "B" if is_fissure else "S")

    if s < 9.65:
        if is_fissure:
            return (1, "S")
        if s < 8.65:
            return (1, "M")
        return (1, "N") if not is_col_lit else (2, "A")

    if s < 10.75:
        return (3, "E") if is_col_lit else (2, "L")

    py = int(round(31.5 - u_v)) % 32
    tok = _CLIFF_PLATEAU_32[py][x % 32]
    l_idx = 1 if tok == "N" else (3 if tok == "E" else 2)
    return (l_idx, tok)


def gen_terrain_cliff_stepped_smooth() -> list[dict[str, Any]]:
    layer_defs = [
        ("base_drop_shadow", 96),
        ("cliff_escarpment_face", 255),
        ("plateau_strata", 255),
        ("sunlit_brow_rim", 255),
    ]
    grids = [make_grid(160, 32) for _ in layer_defs]

    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                u_h = (x + 0.5) if x < 16 else (31.5 - x)
                u_v = (y + 0.5) if y < 16 else (31.5 - y)
                is_west = x < 16
                is_north = y < 16

                w_x = 0.35 * sym_cos(x, 1) + 0.22 * sym_cos(x, 2)
                w_y = 0.34 * sym_cos(y, 1) + 0.20 * sym_cos(y, 2)

                m_side = 0.95 + w_y
                side_total = m_side + 2.9
                m_north = 1.15 + w_x
                north_total = m_north + 2.7

                def put_plateau() -> None:
                    tok = _CLIFF_PLATEAU_32[y][x]
                    li = 1 if tok == "N" else 2
                    put_exclusive(grids, li, ox + x, y, tok)

                def put_side_wall(uh_val: float) -> None:
                    ds = uh_val - m_side
                    if ds < 0.0:
                        if (not is_west) and ds >= -0.95:
                            put_exclusive(grids, 0, ox + x, y, "K")
                        return
                    if ds < 0.95:
                        put_exclusive(grids, 1, ox + x, y, "O")
                        return
                    step_cut = sym_cos(y, 3) > 0.72
                    if is_west:
                        if ds < 2.05:
                            put_exclusive(grids, 2 if step_cut else 3, ox + x, y, "C" if step_cut else "E")
                        else:
                            put_exclusive(grids, 2, ox + x, y, "L" if not step_cut else "A")
                    else:
                        if ds < 2.05:
                            put_exclusive(grids, 1, ox + x, y, "B" if step_cut else "S")
                        else:
                            put_exclusive(grids, 1, ox + x, y, "M" if not step_cut else "N")

                def put_north_brow(uv_val: float) -> None:
                    dn = uv_val - m_north
                    if dn < 0.0:
                        return
                    if dn < 0.95:
                        put_exclusive(grids, 1, ox + x, y, "O")
                    elif dn < 2.15:
                        put_exclusive(grids, 3, ox + x, y, "E" if sym_cos(x, 3) > -0.4 else "W")
                    else:
                        put_exclusive(grids, 2, ox + x, y, "L")

                if block == 4:
                    put_plateau()
                elif block == 1:
                    if u_h < side_total:
                        put_side_wall(u_h)
                    else:
                        put_plateau()
                elif block == 2:
                    if is_north:
                        if u_v < north_total:
                            put_north_brow(u_v)
                        else:
                            put_plateau()
                    else:
                        res = _shade_south_cliff_column(x, u_v, w_x)
                        if res is not None:
                            put_exclusive(grids, res[0], ox + x, y, res[1])
                elif block == 0:
                    if is_north:
                        dx_c = max(0.0, (side_total + 1.6) - u_h)
                        dy_c = max(0.0, (north_total + 1.6) - u_v)
                        if dx_c > 0.0 and dy_c > 0.0:
                            rc = 1.6 + 2.8 - math.hypot(dx_c, dy_c)
                            if rc < 0.0:
                                continue
                            if rc < 0.95:
                                put_exclusive(grids, 1, ox + x, y, "O")
                            elif rc < 2.25:
                                put_exclusive(grids, 3 if is_west else 2, ox + x, y, "E" if is_west else "L")
                            else:
                                put_plateau()
                        elif u_h < side_total:
                            put_side_wall(u_h)
                        elif u_v < north_total:
                            put_north_brow(u_v)
                        else:
                            put_plateau()
                    else:
                        if u_h < m_side:
                            if (not is_west) and u_h >= m_side - 0.95 and u_v >= 2.15 + w_x:
                                put_exclusive(grids, 0, ox + x, y, "K")
                            continue
                        if u_h < m_side + 0.95:
                            if u_v >= 2.15 + w_x:
                                put_exclusive(grids, 1, ox + x, y, "O")
                            elif u_v >= 0.35 + w_x:
                                put_exclusive(grids, 0, ox + x, y, "K")
                            continue
                        if u_v >= 10.75 + w_x:
                            if u_h < side_total:
                                put_side_wall(u_h)
                            else:
                                put_plateau()
                        else:
                            res = _shade_south_cliff_column(x, u_v, w_x)
                            if res is not None:
                                li, ch = res
                                if u_h < side_total and li in (1, 2, 3) and (3.05 + w_x <= u_v < 9.65 + w_x):
                                    ch = "M" if is_west else "B"
                                    li = 1
                                put_exclusive(grids, li, ox + x, y, ch)
                elif block == 3:
                    dh = max(0.0, u_h - 0.5)
                    dv = max(0.0, u_v - 0.5)
                    s_side = side_total - 0.5
                    a = dh / s_side
                    a_outline = (m_side - 0.5) / s_side
                    a_shadow = a_outline if is_west else (m_side - 0.95 - 0.5) / s_side

                    if is_north:
                        s_north = north_total - 0.5
                        b = dv / s_north
                        rho = math.hypot(a, b)
                        if rho >= 1.0:
                            put_plateau()
                        else:
                            t = b / max(1e-6, a + b)
                            b_outline = (m_north - 0.5) / s_north
                            b_shadow = b_outline
                            rho_shadow = (1.0 - t) * a_shadow + t * b_shadow
                            rho_outline = (1.0 - t) * a_outline + t * b_outline
                            if rho < rho_shadow:
                                continue
                            if rho < rho_outline:
                                put_exclusive(grids, 0, ox + x, y, "K")
                            else:
                                frac = (rho - rho_outline) / max(1e-6, 1.0 - rho_outline)
                                if t >= 0.50:
                                    uv_eq = m_north + frac * (north_total - m_north)
                                    put_north_brow(uv_eq)
                                else:
                                    uh_eq = m_side + frac * (side_total - m_side)
                                    put_side_wall(uh_eq)
                    else:
                        h_south = 10.75 + w_x
                        s_south = h_south - 0.5
                        b = dv / s_south
                        rho = math.hypot(a, b)
                        if rho >= 1.0:
                            put_plateau()
                        else:
                            t = b / max(1e-6, a + b)
                            b_shadow = (w_x + 0.25 - 0.5) / s_south
                            b_outline = (w_x + 2.15 - 0.5) / s_south
                            rho_shadow = (1.0 - t) * a_shadow + t * b_shadow
                            rho_outline = (1.0 - t) * a_outline + t * b_outline
                            if rho < rho_shadow:
                                continue
                            if rho < rho_outline:
                                put_exclusive(grids, 0, ox + x, y, "K")
                            else:
                                frac = (rho - rho_outline) / max(1e-6, 1.0 - rho_outline)
                                if t >= 0.35:
                                    u_eq = (w_x + 2.15) + frac * (h_south - (w_x + 2.15))
                                    res = _shade_south_cliff_column(x, u_eq, w_x)
                                    if res is not None:
                                        put_exclusive(grids, res[0], ox + x, y, res[1])
                                else:
                                    uh_eq = m_side + frac * (side_total - m_side)
                                    put_side_wall(uh_eq)

    prune_lone_pixels_per_block(grids)
    return [{"duration_ms": 200, "layers": build_layers(layer_defs, grids)}]


# ==============================================================================
# 4. `prop_rough_outcrop_1` — Asymmetric Matte Fieldstone Cluster (32x32)
#    Modeled directly on `tgstation` `icons/obj/fluff/flora/jungleflora.dmi:rock1..3`
#    (`code/game/objects/structures/flora.dm:1152-1160`):
#    Interlocking chunky fieldstones (broad flat-topped hero boulder + overlapping angular
#    companion cobbles + 2 grounded satellite stones).
# ==============================================================================
_OUTCROP_1_ROWS: list[str] = [
    "................................",
    ".......................SSSS.....",
    ".....................SSNAAMSS...",
    "....................SNAACANMSS..",
    "....................SMNMNNMMSS..",
    ".......SSSS.........SSMNNMMMS...",
    ".....SSNAAMSS........BBBBBBB....",
    "....SCAACANNMSS....SSSSSS.......",
    "....SMANMNNNAMSSSSSNAACAAMSS....",
    "...SSNNMMNNAANMSMSCAAANMNNAMSS..",
    "...SMNMNMMNNNMMSSMAANMNNNACANMS.",
    "....SSMNNMMMMSSSMANNNMNNMNNNMMS.",
    ".....BBBBBSBSSSSMNNACANMMNNMMSS.",
    "..............SSMNNAANNMMMMSSSS.",
    "..............SMANNNMMMMSSNAAMSS",
    ".............SSMMNNMMMSSSCAAANMS",
    ".............SMNMMMMSSBSMAANMNMS",
    "..............SSMMMSSBSSMMNNMMMS",
    "...............BBBBBBB..SMMMMSS.",
    "........................BBBBBB..",
    "................................",
    "....SSSS........................",
    "...SNAAMSS..SSSSS......SSSS.....",
    "..SCAANNMSSSNACAMSS...SNACAMS...",
    "..SMNNMNMMSSNANNMMS..SMAANNMMS..",
    "...SMNMMMSSSMNNMMMS..SMNNMMMMS..",
    "....SMMMSS.SMMMMMS....SMMMMSS...",
    "....BBBBB..BBBBBBB.....BBBBB....",
    "................................",
    "................................",
    "................................",
    "................................",
]


def gen_prop_rough_outcrop_1() -> list[dict[str, Any]]:
    master = [list(r) for r in _OUTCROP_1_ROWS]
    layers = split_by_token_sets(
        master,
        [
            ("grounded_crevice_shadows", {"B", "S"}, 255),
            ("matte_stone_facets", {"M", "N"}, 255),
            ("flat_top_tables", {"A", "C"}, 255),
        ],
    )
    return [{"duration_ms": 200, "layers": layers}]


# ==============================================================================
# 5. `prop_rough_outcrop_2` — Craggy Stepped Basalt Outcrop (32x32)
#    Modeled directly on `tgstation` `icons/obj/fluff/flora/rocks.dmi:basalt2`
#    (`code/game/objects/structures/flora.dm:1045-1047`) &
#    `icons/obj/fluff/flora/largejungleflora.dmi:rocks1` (`code/game/objects/structures/flora.dm:1173-1179`):
#    Asymmetric craggy fracture peak, 1px `S` joint clefts, 45-degree jutting NW slab,
#    faceted eastern buttress, and nestled angular talus blocks along the southern base.
# ==============================================================================
_OUTCROP_2_ROWS: list[str] = [
    "................................",
    "................................",
    "................................",
    "................................",
    "..............SSSS..............",
    "...........SSSNAACSS............",
    "........SSSCCASAANACS...........",
    ".......SCANSCNNSNNNACSS.........",
    "......SCANASNNNNSMNNACCS........",
    ".....SCANMSNMSNNSMSNNACCS.......",
    ".....SNACSNNMNSNNSMSNNACCS......",
    "....SMSSMNNSNMNSNNSMSNNNACCS....",
    "....SSNANNNSNNNMSMMSMMNNNACCS...",
    "....SCANNNSSSNNNNSMMMNNNNNACCS..",
    "...SSCAANNSNMSSNNNNSNNNNMNNACCS.",
    "...SCAANNSNMMSSSSNNNNNNMMNNNACCS",
    "...SCANSSSSAANNSMSNNNNMMNNNNACSS",
    "...SNASSCAACAANNSMSNNNNNNNNSMMS.",
    "...SSCCAACAANNNNMSMSNNNNNNSSMMMS",
    "..SSCAACAAANNNNNMSSMSNNNNSSMMNAS",
    ".SSCAACAANNNNNMMMSMSMSNNSMSMMNNS",
    "SSCAACAANNNNMMMMMSMMMSSMSSMMMAMS",
    "SCAACAANNNNMMMMSMSSMMMSNMSMMNNS.",
    "SCAAANNNNMMMMSMSCCAASMMSCAASSMMS",
    "SAANNNNMMMSNNSMSCAACAMSCNAAACMS.",
    "SNNNNMMMSNAAASMSMSNNNMSCANNNNMMS",
    "SNNMMMMSNMNNNSMSCASNNSMANMSNNMMS",
    ".SMMMMMSSMMMSSSSCANMSSMNNMSSMMMS",
    "..SBBBBBSBBBSSSSSMMSS.SMMMSBBBBS",
    "...SSSSS.SSSSS..SBBBBBSBBBBSSSS.",
    ".................SSSSS.SSSS.....",
    "................................",
]


def gen_prop_rough_outcrop_2() -> list[dict[str, Any]]:
    master = [list(r) for r in _OUTCROP_2_ROWS]
    layers = split_by_token_sets(
        master,
        [
            ("fracture_joints_and_base", {"B", "S"}, 255),
            ("matte_column_faces", {"M", "N"}, 255),
            ("chiseled_nw_facets", {"A", "C"}, 255),
        ],
    )
    return [{"duration_ms": 200, "layers": layers}]


# ==============================================================================
# Exported Terrain, Ice, Cliff & Outcrop Sprite Specs
# ==============================================================================
TERRAIN_SPRITES: list[dict[str, Any]] = [
    {
        "id": "terrain_silicate_rough_smooth",
        "title": "Rough Silicate Regolith Shelf (Basalt-Style 4-Connected Seams)",
        "element": "terrestrial",
        "category": "terrain",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": True,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/terrain_silicate_rough_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#B85C3C",
        "citation": "assets/originals/art/terrestrial/terrain_silicate_rough_smooth.aseprite (ref: tgstation icons/turf/floors.dmi:basalt, code/game/turfs/open/asteroid.dm:177-183)",
        "description": "160x32 5-block smooth regolith shelf with 4-connected basalt-style open-ended plate seams, calm matte body, and directional edge bevels.",
        "frames": gen_terrain_silicate_rough_smooth(),
    },
    {
        "id": "terrain_ice_sheet_smooth",
        "title": "Planetary Calving Ice Sheet (Pale 4-Connected Seams)",
        "element": "terrestrial",
        "category": "ice",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": True,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/terrain_ice_sheet_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#D4EFF7",
        "citation": "assets/originals/art/terrestrial/terrain_ice_sheet_smooth.aseprite (ref: tgstation icons/turf/floors.dmi:basalt, code/game/turfs/open/asteroid.dm:177-183)",
        "description": "160x32 5-block calving glacial ice sheet with @160 submerged refraction skirt, cleaved vertical wall, and 4-step pale 4-connected seams.",
        "frames": gen_terrain_ice_sheet_smooth(),
    },
    {
        "id": "terrain_cliff_stepped_smooth",
        "title": "Stepped 3/4 Planetary Cliff Escarpment",
        "element": "terrestrial",
        "category": "cliff",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": True,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/terrain_cliff_stepped_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#9E482C",
        "citation": "assets/originals/art/terrestrial/terrain_cliff_stepped_smooth.aseprite (ref: tgstation icons/turf/cliff/icerock_cliff.dmi:icerock_wall, code/game/turfs/open/cliff.dm:123-128)",
        "description": "160x32 5-block oblique stepped escarpment with @96 base drop shadow, fissured south cliff wall, side ledges, sunlit north brow, and plateau top.",
        "frames": gen_terrain_cliff_stepped_smooth(),
    },
    {
        "id": "prop_rough_outcrop_1",
        "title": "Scattered Matte Fieldstones & Cobbles",
        "element": "terrestrial",
        "category": "prop",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "allow_multipart": True,
        "ase_relpath": "assets/originals/art/terrestrial/prop_rough_outcrop_1.aseprite",
        "tag": "idle",
        "default_tint": "#B85C3C",
        "citation": "assets/originals/art/terrestrial/prop_rough_outcrop_1.aseprite (ref: tgstation icons/obj/fluff/flora/jungleflora.dmi:rock1..3, code/game/objects/structures/flora.dm:1152-1160)",
        "description": "32x32 matte fieldstone cluster with flat-topped hero boulder, companion cobbles, and grounded satellite stones using #2B2B2B..#C4C4C4.",
        "frames": gen_prop_rough_outcrop_1(),
    },
    {
        "id": "prop_rough_outcrop_2",
        "title": "Weathered Layered Basalt Boulder Cluster",
        "element": "terrestrial",
        "category": "prop",
        "kind": "single",
        "colorable": True,
        "require_top_light": True,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/prop_rough_outcrop_2.aseprite",
        "tag": "idle",
        "default_tint": "#9E482C",
        "citation": "assets/originals/art/terrestrial/prop_rough_outcrop_2.aseprite (ref: tgstation icons/obj/fluff/flora/rocks.dmi:basalt2 & icons/obj/fluff/flora/largejungleflora.dmi:rocks1)",
        "description": "32x32 craggy stepped basalt boulder cluster with 1px #444444 joint clefts, chiseled NW slab facets, and grounded southern talus base.",
        "frames": gen_prop_rough_outcrop_2(),
    },
]
