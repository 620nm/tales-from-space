r"""
Neutral-greyscale pixel-art generators and specs for Tales from Space Terrestrial
12-frame 4-layer ocean/shoreline surf and broadband botanical decals (`OCEAN_NATURE_SPRITES`).
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
from typing import Any

if __package__:
    from .helpers import (
        broadband_torus_field,
        build_layers,
        det_hash,
        make_grid,
        periodic_delta,
        poisson_seeds_32,
        prune_lone_pixels_per_block,
        put_exclusive,
        quad_base_sdf,
        quantile_threshold,
        sym_cos,
    )
else:
    _TERRESTRIAL_DIR = str(Path(__file__).resolve().parents[1])
    if _TERRESTRIAL_DIR not in sys.path:
        sys.path.insert(0, _TERRESTRIAL_DIR)
    from specs.helpers import (  # type: ignore[import-not-found]
        broadband_torus_field,
        build_layers,
        det_hash,
        make_grid,
        periodic_delta,
        poisson_seeds_32,
        prune_lone_pixels_per_block,
        put_exclusive,
        quad_base_sdf,
        quantile_threshold,
        sym_cos,
    )


# ==============================================================================
# 1..4. 12-Frame 4-Layer Planetary Ocean & Shoreline System (`12f @ 200ms`)
# ==============================================================================
_OCEAN_INSET = 2.15
_OCEAN_R_CONV = 7.6
_OCEAN_FRAMES = 12


def _ocean_shore_wave(px: float, py: float) -> float:
    return (
        0.55 * sym_cos(px, 1)
        + 0.30 * sym_cos(px, 2)
        + 0.50 * sym_cos(py, 1)
        + 0.28 * sym_cos(py, 2)
    )


def _ocean_shore_sdf(block: int, px: float, py: float) -> float:
    if block == 4:
        return 24.0
    return quad_base_sdf(block, px, py, _OCEAN_INSET, _OCEAN_R_CONV) + _ocean_shore_wave(px, py)


_WATER_PTS = poisson_seeds_32(17, aspect_y=1.56, seed_id=3191, iters=4)
_WATER_SEEDS: list[tuple[float, float, float, float, float, float]] = [
    (
        sx,
        sy,
        0.82 + 0.44 * det_hash(i, 1, 907),
        0.92 + 0.30 * det_hash(i, 2, 907),
        0.46 + 0.16 * det_hash(i, 3, 907),
        2.0 * math.pi * det_hash(i, 4, 907),
    )
    for i, (sx, sy) in enumerate(_WATER_PTS)
]


def _water_caustic_grid_32(frame_idx: int, n_frames: int = _OCEAN_FRAMES) -> list[list[str]]:
    r"""
    Modeled on `tgstation` `icons/turf/floors.dmi:riverwater_motion` (`code/game/turfs/open/water.dm:1-7`)
    & `icons/turf/beach.dmi:water` (`code/game/turfs/open/water.dm:106-115`):
    17 non-crystalline multi-scale foreshortened Worley cells (`C` calm interiors + continuous
    1px `L` cellular caustic lace + delicate `E` cusps) with k=3,4,5-only curvature so k=1,2
    macro-grid energy stays near zero across 4x4+ ocean expanses.
    """
    tau = 2.0 * math.pi / 32.0
    t_phase = 2.0 * math.pi * frame_idx / n_frames

    anim_seeds: list[tuple[float, float, float]] = []
    for i, (sx, sy, sc, orx, ory, ph0) in enumerate(_WATER_SEEDS):
        d_sign = 1.0 if (i % 2 == 0) else -1.0
        ox = (sx + orx * math.cos(d_sign * t_phase + ph0)) % 32.0
        oy = (sy + ory * math.sin(d_sign * t_phase + ph0 + 0.65)) % 32.0
        anim_seeds.append((ox, oy, sc))

    grid = make_grid(32, 32, "C")
    for y in range(32):
        for x in range(32):
            tx = tau * (x + 0.5)
            ty = tau * (y + 0.5)
            wx = (
                x
                + 0.62 * math.sin(3.0 * tx + 2.0 * ty - t_phase + 0.5)
                + 0.38 * math.cos(4.0 * ty - 3.0 * tx + t_phase)
            )
            wy = (
                y
                + 0.42 * math.cos(3.0 * ty - 2.0 * tx + t_phase - 0.4)
                + 0.28 * math.sin(5.0 * tx + 2.0 * ty - t_phase)
            )

            d1, d2, d3 = 1e9, 1e9, 1e9
            for ax, ay, sc in anim_seeds:
                dx = periodic_delta(wx, ax, 32.0)
                dy = periodic_delta(wy, ay, 32.0) * 1.58
                dist = math.hypot(dx, dy) / sc
                if dist < d1:
                    d3 = d2
                    d2 = d1
                    d1 = dist
                elif dist < d2:
                    d3 = d2
                    d2 = dist
                elif dist < d3:
                    d3 = dist

            e1 = d2 - d1
            e2 = d3 - d1
            shimmer = (
                0.52 * math.sin(3.0 * tx - 4.0 * ty + t_phase + 0.9)
                + 0.48 * math.cos(4.0 * tx + 3.0 * ty - t_phase - 0.5)
            )
            if e1 < 0.38 and (e2 < 1.35 or shimmer > 0.18):
                grid[y][x] = "E"
            elif e1 < 1.08 + 0.14 * shimmer:
                grid[y][x] = "L"
            else:
                grid[y][x] = "C"

    snap = [row[:] for row in grid]
    for y in range(32):
        for x in range(32):
            if snap[y][x] == "E":
                has_l = any(
                    snap[(y + dy) % 32][(x + dx) % 32] in ("L", "E")
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                if not has_l:
                    grid[y][(x + 1) % 32] = "L"
    return grid


def gen_ocean_body_smooth() -> list[dict[str, Any]]:
    layer_defs = [
        ("nearshore_shallows_outer", 112),
        ("nearshore_shallows_mid", 168),
        ("nearshore_shelf", 216),
        ("deep_ocean_body", 255),
    ]
    frames: list[dict[str, Any]] = []
    shift_x, shift_y = 5, 0

    for f in range(_OCEAN_FRAMES):
        grids = [make_grid(160, 32) for _ in layer_defs]
        raw32 = _water_caustic_grid_32(f, _OCEAN_FRAMES)
        w32 = [[raw32[(y + shift_y) % 32][(x + shift_x) % 32] for x in range(32)] for y in range(32)]
        for block in range(5):
            ox = block * 32
            for y in range(32):
                for x in range(32):
                    s = _ocean_shore_sdf(block, x, y)
                    if s < 0.0:
                        continue
                    ch = w32[y][x]
                    if block != 4 and s < 6.40:
                        li = 0 if s < 2.00 else (1 if s < 4.20 else 2)
                        put_exclusive(grids, li, ox + x, y, ch)
                    else:
                        put_exclusive(grids, 3, ox + x, y, ch)

        prune_lone_pixels_per_block(grids)
        frames.append({"duration_ms": 200, "layers": build_layers(layer_defs, grids)})

    return frames


def gen_ocean_backwash_smooth() -> list[dict[str, Any]]:
    r"""
    Dedicated Wet-Shore Soak & Receding Backwash Sheen (`12f @ 200ms`).
    Smoothly darkens the beach slope as the wave crests (`F3..F6`), holds a glossy wet film
    as the swash glides seaward (`F6..F9`), and continuously trickles down-slope across all
    12 frames (`F1..F12`) with natural longshore undulation and zero frozen frames.
    """
    layer_defs = [
        ("damp_sand_fringe", 44),
        ("wet_backwash_sheen", 78),
        ("soaked_runup_glaze", 110),
    ]
    frames: list[dict[str, Any]] = []

    for f in range(_OCEAN_FRAMES):
        grids = [make_grid(160, 32) for _ in layer_defs]
        theta_base = 2.0 * math.pi * ((f - 4.8) / _OCEAN_FRAMES)
        drain_phase = 2.0 * math.pi * f / _OCEAN_FRAMES

        for block in range(4):  # Block 4 deep ocean has zero dry beach to soak
            ox = block * 32
            for y in range(32):
                for x in range(32):
                    d = _ocean_shore_sdf(block, x, y)
                    # Symmetric longshore phase lag keeps quadrant/tile joins 100% exact (`alphaMAX=0`)
                    lag = 0.68 * sym_cos(x, 1) + 0.68 * sym_cos(y, 1)
                    wet_pulse = 0.5 * (1.0 + math.cos(theta_base + lag))

                    glaze_landward = -1.35 - 0.35 * wet_pulse
                    glaze_seaward = 2.65 + 1.55 * wet_pulse

                    cusp = 0.18 * sym_cos(x, 2) + 0.18 * sym_cos(y, 2)
                    d_eff = d + cusp
                    if d_eff < glaze_landward or d_eff > glaze_seaward:
                        continue

                    # Depth-oscillating drainage wave guarantees B/S/M tonal variety even inside 4px concave corners
                    rivulet = math.sin(2.35 * d - drain_phase + 0.55 * (sym_cos(x, 4) - sym_cos(y, 4)))
                    band_val = 0.52 * wet_pulse + 0.48 * (0.5 + 0.5 * rivulet)

                    if rivulet < -0.25:
                        tok = "B"
                    elif rivulet < 0.28:
                        tok = "S"
                    else:
                        tok = "M"

                    if band_val > 0.64 and d_eff < glaze_seaward - 0.35:
                        put_exclusive(grids, 2, ox + x, y, tok)
                    elif band_val > 0.36:
                        put_exclusive(grids, 1, ox + x, y, tok)
                    else:
                        put_exclusive(grids, 0, ox + x, y, tok)

        prune_lone_pixels_per_block(grids)
        frames.append({"duration_ms": 200, "layers": build_layers(layer_defs, grids)})

    return frames


def gen_ocean_swash_smooth() -> list[dict[str, Any]]:
    r"""
    Primary Translucent Swash Sheet & Unbroken Curved Leading Lip (`12f @ 200ms`).
    Modeled on `tgstation` `icons/turf/beach.dmi:beach` (`code/game/turfs/open/sand.dm:63-73`):
      - Harmonic cosine turnaround with gentle symmetric longshore scalloping (`0.92 * sym_cos`)
        so every shoreline column hovers smoothly through high-water turnaround (`F4->F5->F6`)
        without rigid-piston stalls or shattering.
    """
    layer_defs = [
        ("swash_tongue_tail", 96),
        ("swash_tongue_body", 152),
        ("swash_lip_soft", 204),
        ("swash_lip_crest", 255),
    ]
    frames: list[dict[str, Any]] = []

    for f in range(_OCEAN_FRAMES):
        grids = [make_grid(160, 32) for _ in layer_defs]
        theta_base = 2.0 * math.pi * ((f - 4.15) / _OCEAN_FRAMES)
        surf_phase = 2.0 * math.pi * f / _OCEAN_FRAMES

        for block in range(4):  # Block 4 open ocean stays 100% bubble-free
            ox = block * 32
            for y in range(32):
                for x in range(32):
                    d = _ocean_shore_sdf(block, x, y)
                    lag = 0.92 * sym_cos(x, 1) + 0.92 * sym_cos(y, 1)
                    theta = theta_base + lag
                    d_lip = 0.44 - 0.84 * math.cos(theta)
                    surge = -math.sin(theta)
                    tongue_len = 2.95 + 0.30 * math.cos(theta)

                    cusp = 0.18 * sym_cos(x, 2) + 0.16 * sym_cos(y, 2)
                    rel = (d + cusp) - d_lip
                    if rel < 0.0 or rel > tongue_len:
                        continue

                    shimmer = 0.58 * math.cos(surf_phase - 1.55 * rel) + 0.42 * (sym_cos(x, 3) - sym_cos(y, 3))
                    if rel <= 1.05:
                        lip_energy = 0.48 * surge + 0.52 * math.cos(theta - 0.40) + 0.22 * shimmer
                        if lip_energy > 0.36:
                            tok = "W" if (rel <= 0.48 and shimmer > -0.15) else "E"
                            put_exclusive(grids, 3, ox + x, y, tok)
                        elif lip_energy > -0.22:
                            tok = "E" if (rel <= 0.58 and shimmer > -0.10) else "L"
                            put_exclusive(grids, 2, ox + x, y, tok)
                        else:
                            tok = "L" if (rel <= 0.56 or shimmer > 0.10) else "C"
                            put_exclusive(grids, 1, ox + x, y, tok)
                    elif rel <= 2.15:
                        tok = "E" if shimmer > 0.48 else ("L" if shimmer > -0.08 else "C")
                        put_exclusive(grids, 1 + (1 if shimmer > 0.56 else 0), ox + x, y, tok)
                    else:
                        tok = "L" if shimmer > 0.38 else ("C" if shimmer > -0.18 else "A")
                        put_exclusive(grids, 0 + (1 if shimmer > 0.50 else 0), ox + x, y, tok)

        prune_lone_pixels_per_block(grids)
        frames.append({"duration_ms": 200, "layers": build_layers(layer_defs, grids)})

    return frames


def gen_ocean_foam_lace_smooth() -> list[dict[str, Any]]:
    r"""
    Secondary Overlapping Shoreline Animation Layer (`12f @ 200ms`):
      1. Soft high-water foam veil that lingers and melts gently across `F5..F10` behind the
         receding `ocean_swash_smooth` lip.
      2. Phase-offset nearshore wave crest rolling smoothly shoreward from `d ~ 7.2` to `2.3`
         along clean shoreline-parallel contours across all 12 frames (`F1..F12`).
    """
    layer_defs = [
        ("dissolving_foam_veil", 58),
        ("aerated_surf_lace", 112),
        ("incoming_swell_crest", 168),
    ]
    frames: list[dict[str, Any]] = []

    for f in range(_OCEAN_FRAMES):
        grids = [make_grid(160, 32) for _ in layer_defs]
        u = ((f - 3.5) % _OCEAN_FRAMES) / _OCEAN_FRAMES
        d_roller = 7.4 - 5.3 * u
        roller_strength = math.sin(math.pi * u)
        roller_half_w = 0.44 + 0.48 * roller_strength
        roller_core_w = 0.48 * roller_half_w
        veil_strength = max(0.0, math.sin(math.pi * (u / 0.56))) if u < 0.56 else 0.0

        for block in range(4):
            ox = block * 32
            for y in range(32):
                for x in range(32):
                    d = _ocean_shore_sdf(block, x, y)
                    cusp = 0.22 * sym_cos(x, 2) + 0.20 * sym_cos(y, 2)
                    d_eff = d + cusp
                    if d_eff < -1.05 or d_eff > 8.4:
                        continue

                    ripple = 0.5 * sym_cos(x, 3) + 0.5 * sym_cos(y, 3)

                    # 1) Incoming secondary nearshore wave crest (smooth shoreline-parallel ribbon)
                    if abs(d_eff - d_roller) <= roller_half_w:
                        core = abs(d_eff - d_roller) <= roller_core_w
                        if roller_strength > 0.68:
                            li = 2 if core else 1
                            tok = "E" if core else ("L" if ripple > -0.2 else "C")
                        elif roller_strength > 0.34:
                            li = 1 if core else 0
                            tok = "L" if core else ("C" if ripple > 0.0 else "A")
                        else:
                            li = 0
                            tok = "L" if (core and ripple > 0.0) else ("C" if (core or ripple > 0.1) else "A")
                        put_exclusive(grids, li, ox + x, y, tok)
                        continue

                    # 2) Gently dissolving high-water foam veil during receding phase (F5..F10)
                    if veil_strength > 0.16 and (-0.75 <= d_eff <= 1.45):
                        lace = 0.55 * sym_cos(x, 4) + 0.45 * sym_cos(y, 4)
                        v_thresh = 0.52 - 0.70 * veil_strength
                        if lace > v_thresh:
                            li = 1 if (veil_strength > 0.60 and lace > v_thresh + 0.34) else 0
                            tok = "E" if li == 1 else ("L" if lace > v_thresh + 0.16 else "C")
                            put_exclusive(grids, li, ox + x, y, tok)

        prune_lone_pixels_per_block(grids)
        frames.append({"duration_ms": 200, "layers": build_layers(layer_defs, grids)})

    return frames


# ==============================================================================
# 5. `decal_nature_grass_smooth` — Broadband Diagonal Meadow Blade Weave
#    Modeled directly on `tgstation` `icons/turf/floors/grass.dmi:grass` (`code/game/turfs/open/grass.dm:1-22`):
#    3-tone luminance contrast ratios (`N:146 : C:196 : E:238` = `1.00 : 1.34 : 1.63`),
#    ~70% calm meandering `N` clearings, ~25% diagonal `/` & `\` `C` blade wisps,
#    ~5% sunlit `E` blade tips, broadband k=2.9..14.2 spectrum.
# ==============================================================================
def _build_grass_interior_32() -> list[list[str]]:
    drift = broadband_torus_field(k_min=2.9, k_max=6.4, seed=4127, aniso_x=1.0, aniso_y=1.0, falloff=0.55)
    blade_slash = broadband_torus_field(k_min=6.2, k_max=14.2, seed=5237, aniso_x=1.0, aniso_y=1.0, falloff=0.22)
    blade_back = broadband_torus_field(k_min=6.2, k_max=14.2, seed=6353, aniso_x=1.0, aniso_y=1.0, falloff=0.22)
    lean_zone = broadband_torus_field(k_min=3.2, k_max=7.5, seed=7411, aniso_x=1.0, aniso_y=1.0, falloff=0.45)

    score = [[0.0] * 32 for _ in range(32)]
    tip_score = [[0.0] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            s_slash = 0.56 * blade_slash[y][x] + 0.44 * blade_slash[(y + 1) % 32][(x - 1) % 32]
            s_back = 0.56 * blade_back[y][x] + 0.44 * blade_back[(y + 1) % 32][(x + 1) % 32]
            w = 0.5 + 0.5 * math.tanh(1.6 * lean_zone[y][x])
            diag_stroke = w * s_slash + (1.0 - w) * s_back
            ortho_pen = 0.16 * (blade_slash[y][(x - 1) % 32] + blade_back[(y - 1) % 32][x])
            score[y][x] = 0.46 * drift[y][x] + 0.78 * (diag_stroke - ortho_pen)
            upper_tip = diag_stroke - 0.30 * max(
                blade_slash[(y - 1) % 32][(x + 1) % 32],
                blade_back[(y - 1) % 32][(x - 1) % 32],
            )
            tip_score[y][x] = 0.52 * drift[y][x] + 0.74 * upper_tip

    flat_s = [score[y][x] for y in range(32) for x in range(32)]
    flat_t = [tip_score[y][x] for y in range(32) for x in range(32)]
    th_c = quantile_threshold(flat_s, 0.345)
    th_e = quantile_threshold(flat_t, 0.068)

    tile = make_grid(32, 32, "N")
    for y in range(32):
        for x in range(32):
            if score[y][x] >= th_c:
                tile[y][x] = "C"
            if tip_score[y][x] >= th_e and drift[y][x] > -0.10:
                tile[y][x] = "E"

    # Break any 4+ horizontal bars or 4+ vertical pillars so every stroke stays a crisp diagonal `/` or `\` blade
    for y in range(32):
        for x in range(32):
            if all(tile[y][(x + k) % 32] != "N" for k in range(4)):
                tile[y][(x + 2) % 32] = "N"
            if all(tile[(y + k) % 32][x] != "N" for k in range(4)):
                tile[(y + 2) % 32][x] = "N"

    for y in range(32):
        for x in range(32):
            if tile[y][x] == "E":
                has_diag_root = any(
                    tile[(y + dy) % 32][(x + dx) % 32] in ("C", "E")
                    for dx, dy in ((-1, 1), (1, 1), (-1, 0), (1, 0))
                )
                if not has_diag_root:
                    dx_r = -1 if lean_zone[y][x] >= 0.0 else 1
                    tile[(y + 1) % 32][(x + dx_r) % 32] = "C"

    snap = [row[:] for row in tile]
    for y in range(32):
        for x in range(32):
            if snap[y][x] == "C":
                nb_ce = sum(
                    1
                    for dy in (-1, 0, 1)
                    for dx in (-1, 0, 1)
                    if (dx or dy) and snap[(y + dy) % 32][(x + dx) % 32] in ("C", "E")
                )
                if nb_ce == 0:
                    tile[y][x] = "N"
                elif nb_ce >= 6 and det_hash(x, y, 743) > 0.22:
                    tile[y][x] = "N"
            elif snap[y][x] == "E":
                nb_e = sum(
                    1
                    for dy in (-1, 0, 1)
                    for dx in (-1, 0, 1)
                    if (dx or dy) and snap[(y + dy) % 32][(x + dx) % 32] == "E"
                )
                if nb_e >= 4:
                    tile[y][x] = "C"

    return tile


def gen_decal_nature_grass_smooth() -> list[dict[str, Any]]:
    layer_defs = [
        ("meadow_blade_bed", 255),
        ("meadow_blade_tufts", 255),
    ]
    grids = [make_grid(160, 32) for _ in layer_defs]
    raw_32 = _build_grass_interior_32()
    shift_x, shift_y = 15, 0
    base_32 = [[raw_32[(y + shift_y) % 32][(x + shift_x) % 32] for x in range(32)] for y in range(32)]
    inset = 2.65
    r_conv = 3.4

    for block in range(5):
        ox = block * 32

        def sdf_b(px: float, py: float, b: int = block) -> float:
            if b == 4:
                return 24.0
            blades = (
                0.78 * sym_cos(px, 1)
                + 0.62 * sym_cos(px, 2)
                - 0.72 * sym_cos(px, 5)
                + 0.56 * sym_cos(px, 7)
                + 0.74 * sym_cos(py, 1)
                + 0.58 * sym_cos(py, 2)
                - 0.68 * sym_cos(py, 5)
                + 0.52 * sym_cos(py, 7)
            )
            return quad_base_sdf(b, px, py, inset, r_conv) + blades

        for y in range(32):
            for x in range(32):
                if sdf_b(x, y) < 0.0:
                    continue
                tok = base_32[y][x]
                li = 0 if tok == "N" else 1
                put_exclusive(grids, li, ox + x, y, tok)

    prune_lone_pixels_per_block(grids)
    return [{"duration_ms": 200, "layers": build_layers(layer_defs, grids)}]


# ==============================================================================
# 6. `decal_nature_moss_smooth` — Broadband Multi-Scale Bryophyte Cushion Mat
#    Modeled on `tgstation` `icons/turf/floors/grass_damaged.dmi:grass_damaged` (`code/game/turfs/open/grass.dm:20-26`):
#    Interlocking multi-scale moss cushions (`N:#929292, A:#AAAAAA, C:#C4C4C4, L:#D9D9D9`),
#    NNW top-down slope shading, ZERO holes, ZERO cobblestone rings, ZERO 32x32 grid tells.
# ==============================================================================
def _build_moss_stipple_32() -> list[list[str]]:
    canopy = broadband_torus_field(k_min=2.8, k_max=6.8, seed=8123, aniso_x=1.0, aniso_y=1.08, falloff=0.60)
    fronds = broadband_torus_field(k_min=6.2, k_max=13.0, seed=9311, aniso_x=1.0, aniso_y=1.0, falloff=0.30)
    h_map = [[0.68 * canopy[y][x] + 0.46 * fronds[y][x] for x in range(32)] for y in range(32)]

    lit = [[0.0] * 32 for _ in range(32)]
    spore = [[0.0] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            slope_nnw = h_map[y][x] - (0.68 * h_map[(y - 1) % 32][x] + 0.32 * h_map[(y - 1) % 32][(x - 1) % 32])
            lit[y][x] = 0.54 * h_map[y][x] + 0.68 * slope_nnw
            spore[y][x] = 0.55 * canopy[y][x] + 0.65 * fronds[y][x] + 0.45 * slope_nnw

    flat_lit = [lit[y][x] for y in range(32) for x in range(32)]
    flat_sp = [spore[y][x] for y in range(32) for x in range(32)]
    th_c = quantile_threshold(flat_lit, 0.275)
    th_n = quantile_threshold(flat_lit, 1.0 - 0.175)
    th_l = quantile_threshold(flat_sp, 0.024)

    tile = make_grid(32, 32, "A")
    for y in range(32):
        for x in range(32):
            if lit[y][x] >= th_c:
                tile[y][x] = "C"
            elif lit[y][x] <= th_n:
                tile[y][x] = "N"
            if spore[y][x] >= th_l and canopy[y][x] > 0.20:
                tile[y][x] = "L"

    snap = [row[:] for row in tile]
    for y in range(32):
        for x in range(32):
            cur = snap[y][x]
            if cur in ("C", "N"):
                same = sum(
                    1
                    for dy in (-1, 0, 1)
                    for dx in (-1, 0, 1)
                    if (dx or dy) and snap[(y + dy) % 32][(x + dx) % 32] == cur
                )
                if same == 0:
                    tile[y][x] = "A"
            elif cur == "L":
                if not any(
                    snap[(y + dy) % 32][(x + dx) % 32] == "C"
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                ):
                    tile[y][(x + 1) % 32] = "C"

    return tile


def gen_decal_nature_moss_smooth() -> list[dict[str, Any]]:
    layer_defs = [
        ("velvet_moss_bed", 255),
        ("moss_frond_clusters", 255),
    ]
    grids = [make_grid(160, 32) for _ in layer_defs]
    raw_32 = _build_moss_stipple_32()
    shift_x, shift_y = 3, 0
    moss_32 = [[raw_32[(y + shift_y) % 32][(x + shift_x) % 32] for x in range(32)] for y in range(32)]
    inset = 3.45
    r_conv = 4.8

    for block in range(5):
        ox = block * 32

        def sdf_b(px: float, py: float, b: int = block) -> float:
            if b == 4:
                return 24.0
            lobes = (
                1.15 * sym_cos(px, 1)
                + 0.72 * sym_cos(px, 2)
                - 0.42 * sym_cos(px, 4)
                + 0.28 * sym_cos(px, 6)
                + 1.08 * sym_cos(py, 1)
                + 0.68 * sym_cos(py, 2)
                - 0.38 * sym_cos(py, 4)
                + 0.26 * sym_cos(py, 6)
            )
            return quad_base_sdf(b, px, py, inset, r_conv) + lobes

        for y in range(32):
            for x in range(32):
                if sdf_b(x, y) < 0.0:
                    continue
                tok = moss_32[y][x]
                li = 0 if tok in ("N", "A") else 1
                put_exclusive(grids, li, ox + x, y, tok)

    prune_lone_pixels_per_block(grids)
    return [{"duration_ms": 200, "layers": build_layers(layer_defs, grids)}]


# ==============================================================================
# Exported Ocean Shoreline & Botanical Decal Sprite Specs
# ==============================================================================
OCEAN_NATURE_SPRITES: list[dict[str, Any]] = [
    {
        "id": "ocean_body_smooth",
        "title": "Planetary Ocean / Ammonia Sea Sheet (12f Cellular Caustic Lace)",
        "element": "terrestrial",
        "category": "ocean",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/ocean_body_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#5EB5C4",
        "citation": "assets/originals/art/terrestrial/ocean_body_smooth.aseprite (ref: tgstation icons/turf/floors.dmi:riverwater_motion, code/game/turfs/open/water.dm:1-7)",
        "description": "12-frame (200ms) 160x32 ocean body with 4 nearshore-to-deep opacity tiers (112/168/216/255) and non-crystalline Worley caustic lace.",
        "frames": gen_ocean_body_smooth(),
    },
    {
        "id": "ocean_backwash_smooth",
        "title": "Shoreline Wet Soak & Receding Backwash Glaze (12f Layer)",
        "element": "terrestrial",
        "category": "ocean",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/ocean_backwash_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#4A2218",
        "citation": "assets/originals/art/terrestrial/ocean_backwash_smooth.aseprite (ref: tgstation icons/turf/beach.dmi:beach, code/game/turfs/open/sand.dm:63-73)",
        "description": "12-frame (200ms) 160x32 wet-shore soak and receding drainage sheen across 3 translucent dark-glaze tiers (44/78/110).",
        "frames": gen_ocean_backwash_smooth(),
    },
    {
        "id": "ocean_swash_smooth",
        "title": "Ocean Surf Swash Tongue & Curved Lip (12f Harmonic Turnaround)",
        "element": "terrestrial",
        "category": "ocean",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/ocean_swash_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#E6F7F5",
        "citation": "assets/originals/art/terrestrial/ocean_swash_smooth.aseprite (ref: tgstation icons/turf/beach.dmi:beach, code/game/turfs/open/sand.dm:63-73)",
        "description": "12-frame (200ms) 160x32 translucent surf tongue and unbroken curved foam lip across 4 opacity tiers (96/152/204/255) with harmonic turnaround.",
        "frames": gen_ocean_swash_smooth(),
    },
    {
        "id": "ocean_foam_lace_smooth",
        "title": "Overlapping Nearshore Roller & Dissolving Foam Veil (12f Layer)",
        "element": "terrestrial",
        "category": "ocean",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/ocean_foam_lace_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#E6F7F5",
        "citation": "assets/originals/art/terrestrial/ocean_foam_lace_smooth.aseprite (ref: tgstation icons/turf/beach.dmi:beach, code/game/turfs/open/sand.dm:63-73)",
        "description": "12-frame (200ms) 160x32 secondary incoming nearshore roller crest and lingering high-water dissolving foam veil (58/112/168).",
        "frames": gen_ocean_foam_lace_smooth(),
    },
    {
        "id": "decal_nature_grass_smooth",
        "title": "Botanical Meadow Grass Decal (Broadband Diagonal Blade Weave)",
        "element": "terrestrial",
        "category": "decal",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/decal_nature_grass_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#86C44A",
        "citation": "assets/originals/art/terrestrial/decal_nature_grass_smooth.aseprite (ref: tgstation icons/turf/floors/grass.dmi:grass, code/game/turfs/open/grass.dm:1-22)",
        "description": "160x32 5-block botanical meadow decal with broadband k=2.9..14.2 diagonal blade wisps (#929292/#C4C4C4/#EEEEEE) and tufted outer margins.",
        "frames": gen_decal_nature_grass_smooth(),
    },
    {
        "id": "decal_nature_moss_smooth",
        "title": "Velvety Creeping Moss & Bryophyte Decal (Broadband Cushion Mat)",
        "element": "terrestrial",
        "category": "decal",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "allow_multipart": False,
        "ase_relpath": "assets/originals/art/terrestrial/decal_nature_moss_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#5A9842",
        "citation": "assets/originals/art/terrestrial/decal_nature_moss_smooth.aseprite (ref: tgstation icons/turf/floors/grass_damaged.dmi:grass_damaged, code/game/turfs/open/grass.dm:20-26)",
        "description": "160x32 5-block creeping bryophyte cushion mat with broadband k=2.8..13.0 canopy shading (#929292..#D9D9D9) and scalloped outer lobes.",
        "frames": gen_decal_nature_moss_smooth(),
    },
]
