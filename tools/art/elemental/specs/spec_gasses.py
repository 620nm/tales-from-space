#!/usr/bin/env python3
"""
Procedural pixel-art specification for Tales from Space Gasses (v2.1 — 18 assets):
  - Light Mist   (single & smooth_strip x still / gentle / stirred)
  - Medium Smoke (single & smooth_strip x still / gentle / stirred)
  - Dense Cloud  (single & smooth_strip x still / gentle / stirred)

v2.1 Architecture & Audit Fixes:
  1. Exact periodic block-topology wrapping across all 5 smooth_strip blocks:
     - Vertical wrap (`y mod 32`) on Blocks 1, 3, 4 (`v` connected)
     - Horizontal wrap (`x mod 32`) on Blocks 2, 3, 4 (`h` connected)
     - Analytical C1 outer-rim normal `r_ny` (zero on vertical corridor Block 1 and
       interior Block 4; continuous across Block 0/1/2/3/4 joins).
  2. Dry, matte, low-contrast overcast & haze fields (no frogspawn spheres, no
     repeating 32x32 chevron bars on Cloud, no diagonal fishnet lattice on Mist).
  3. Wide 14px wispy outer alpha taper across 4-5 disjoint opacity layers
     (Mist [18,30,44,56], Smoke [28,56,88,120,148], Cloud [36,76,122,166,204])
     for invisible nested contour-shell blending (`mist -> smoke -> cloud`).
  4. Calm 8-frame rolling toroidal advection with exact integer temporal phase
     multipliers (`f8 -> f1` wraps with zero loop jump):
     - still:   1 frame  @ 200ms
     - gentle:  8 frames @ 600ms (4.8s cycle)
     - stirred: 8 frames @ 300ms (2.4s cycle)
"""
from __future__ import annotations

import math
from typing import Any

TAU = 2.0 * math.pi
OMEGA = TAU / 32.0

# Strictly neutral (R == G == B) swatches from tales-from-space.gpl (dark -> light).
# Never include #0A0A0D (10,10,13 has chroma 3 > 0).
NEUTRAL_RAMP: list[tuple[str, str]] = [
    ("3", "#626262"),  # 0: neutral-4 (98)  - outer south smoke wisp only
    ("4", "#929292"),  # 1: neutral-5 (146) - smoke fold / outer south cloud base
    ("5", "#AAAAAA"),  # 2: neutral-6 (170) - matte smoke/cloud outer lower-mid
    ("6", "#C4C4C4"),  # 3: neutral-7 (196) - matte vapor midtone
    ("7", "#D9D9D9"),  # 4: neutral-8 (217) - matte vapor upper-mid
    ("8", "#EEEEEE"),  # 5: near-white (238)- soft upper vapor drift
    ("9", "#FFFFFF"),  # 6: white-glint(255)- small soft cloud crest highlight
]
FULL_LEGEND: dict[str, str] = dict(NEUTRAL_RAMP)
CHAR_TO_IDX: dict[str, int] = {ch: i for i, (ch, _) in enumerate(NEUTRAL_RAMP)}
IDX_TO_CHAR: list[str] = [ch for ch, _ in NEUTRAL_RAMP]


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


def smoothstep(e0: float, e1: float, x: float) -> float:
    if e0 == e1:
        return 1.0 if x >= e1 else 0.0
    t = clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def smoothstep_deriv(e0: float, e1: float, x: float) -> float:
    """Derivative d/dx smoothstep(e0, e1, x)."""
    if e1 == e0:
        return 0.0
    t = clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    if t <= 0.0 or t >= 1.0:
        return 0.0
    return 6.0 * t * (1.0 - t) / (e1 - e0)


def block_edge_distance_and_normal_y(block: int, tx: int, ty: int) -> tuple[float, float]:
    """
    Exact C1 quadrant-compatible distance from empty exterior AND its analytical
    vertical normal d(bdist)/dy for 5-block smooth_strip:
      block 0: convex (!v && !h)      -> radial circle matching block 1 at y=15.5 & block 2 at x=15.5
      block 1: vertical (v && !h)     -> horizontal distance du (ny = 0.0 everywhere!)
      block 2: horizontal (!v && h)   -> vertical distance dw (ny = +1 top, -1 bottom)
      block 3: concave (v && h && !d) -> corner radial hypot(du, dw) matching block 1 & 2
      block 4: flat (v && h && d)     -> deep interior constant (20.0, ny = 0.0)
    """
    du = (tx + 0.5) if tx < 16 else (31.5 - tx)
    dw = (ty + 0.5) if ty < 16 else (31.5 - ty)
    sign_y = 1.0 if ty < 16 else -1.0

    if block == 0:
        dx = 15.5 - du
        dy = 15.5 - dw
        r = math.hypot(dx, dy)
        ny = sign_y * (dy / r) if r > 1e-6 else 0.0
        return 15.5 - r, ny
    if block == 1:
        return du, 0.0
    if block == 2:
        return dw, sign_y
    if block == 3:
        r = math.hypot(du, dw)
        ny = sign_y * (dw / r) if r > 1e-6 else 0.0
        return r, ny
    return 20.0, 0.0


def advection_offsets(motion: str, frame_idx: int) -> tuple[float, float, float, float, float]:
    """
    Exact 32-periodic toroidal advection across 8 frames (f = 0..7):
      step = (f * 4) % 32 -> 4px/frame progressive wrap (8 * 4 = 32px exact loop!).
      ang  = TAU * (f / 8) -> exact 1x integer temporal harmonic (f8 == f0!).
    """
    if motion == "still":
        return 0.0, 0.0, 0.0, 0.0, 0.0
    step = float((frame_idx * 4) % 32)
    ang = TAU * (frame_idx / 8.0)
    if motion == "gentle":
        return step, 0.0, step, -step, ang
    return step, -step, -step, -step, ang


def edge_wisp_modulation(
    tx: int,
    ty: int,
    motion: str,
    ang: float,
    seed: float,
    amp_static: float,
) -> float:
    """
    Low-frequency 32-periodic wispy contour undulation + ultra-subtle (<= 0.65..0.90px)
    integer-harmonic 8-frame breathing wave.
    """
    px = OMEGA * (tx + 0.5)
    py = OMEGA * (ty + 0.5)
    static_wisp = amp_static * (
        0.64 * math.sin(px + py + seed)
        + 0.36 * math.cos(px - py + 1.7 * seed)
    )
    if motion == "still":
        return static_wisp
    breath_amp = 0.60 if motion == "gentle" else 0.90
    breath = breath_amp * math.sin(px - py - ang + 0.9 * seed)
    return static_wisp + breath


def compute_envelope_and_rim_ny(
    kind: str,
    block: int,
    tx: int,
    ty: int,
    motion: str,
    ang: float,
    seed: float,
    wisp_amp: float,
) -> tuple[float, float]:
    """
    Wide ~10-11px gradual wispy outer envelope reaching 1.0 before x=15|16 and y=15|16,
    paired with analytical C1 top-down rim normal `r_ny` (scaled to match finite-diff range).
    """
    wisp = edge_wisp_modulation(tx, ty, motion, ang, seed, wisp_amp)
    if kind == "single":
        cx = tx + 0.5 - 15.5
        cy = ty + 0.5 - 15.8
        ang_theta = math.atan2(cy, cx)
        asym = (
            1.60 * math.cos(2.0 * ang_theta + 0.25 * seed)
            + 1.30 * math.sin(3.0 * ang_theta + 1.1 * seed)
            + 0.70 * math.cos(ang_theta - 0.8 * seed)
        )
        r = math.hypot(cx * 0.92, cy * 1.06)
        bdist = 14.8 + asym - r
        eff_d = bdist + smoothstep(13.0, 2.5, bdist) * wisp
        env = smoothstep(0.9, 9.8, eff_d)
        # Smooth analytical vertical normal pointing + on north crown, - on south base
        ny_dir = (-cy * 1.06) / max(r, 1.5)
        r_ny = 5.6 * smoothstep_deriv(0.9, 13.0, bdist) * ny_dir
        return env, r_ny

    bdist, b_ny = block_edge_distance_and_normal_y(block, tx, ty)
    # Wide 14px wispy outer taper reaching 1.0 smoothly at the 15|16 quadrant seam (bdist=15.5)
    eff_d = bdist + smoothstep(15.0, 3.2, bdist) * wisp
    env = smoothstep(0.8, 14.8, eff_d)
    # Pure C1 boundary normal: 0.0 on Block 1 & Block 4, smooth across Block 0/1/2/3/4 seams
    r_ny = 5.6 * smoothstep_deriv(0.8, 14.8, bdist) * b_ny
    return env, r_ny


def sample_vap_gradients(
    vap: list[list[float]],
    kind: str,
    b_idx: int,
    lx: int,
    y: int,
    delta: int = 3,
) -> tuple[float, float]:
    """
    Sample (v_nx, v_ny) respecting exact block periodicity:
      - Horizontal wrap (`lx mod 32`) on Blocks 2, 3, 4
      - Vertical wrap (`y mod 32`) on Blocks 1, 3, 4
    """
    b_off = b_idx * 32
    wrap_x = kind == "smooth_strip" and b_idx in (2, 3, 4)
    wrap_y = kind == "smooth_strip" and b_idx in (1, 3, 4)

    if wrap_x:
        xw = (lx - delta) % 32
        xe = (lx + delta) % 32
        v_nx = vap[y][b_off + xe] - vap[y][b_off + xw]
    else:
        xw = max(0, lx - delta)
        xe = min(31, lx + delta)
        v_nx = (vap[y][b_off + xe] - vap[y][b_off + xw]) * (2.0 * delta / max(1, xe - xw))

    if wrap_y:
        yn = (y - delta) % 32
        ys = (y + delta) % 32
        v_ny = vap[ys][b_off + lx] - vap[yn][b_off + lx]
    else:
        yn = max(0, y - delta)
        ys = min(31, y + delta)
        v_ny = (vap[ys][b_off + lx] - vap[yn][b_off + lx]) * (2.0 * delta / max(1, ys - yn))

    return v_nx, v_ny


def clean_unified_grid(
    tiers: list[list[int]],
    swatches: list[list[int]],
    kind: str,
) -> tuple[list[list[int]], list[list[int]]]:
    """
    Despeckle the unified (alpha_tier, swatch_idx) grid BEFORE splitting into
    disjoint opacity layers, wrapping modulo 32 on:
      - x for Blocks 2, 3, 4 (`h` connected)
      - y for Blocks 1, 3, 4 (`v` connected)
    """
    h = len(tiers)
    t_grid = [r[:] for r in tiers]
    s_grid = [r[:] for r in swatches]
    n_blocks = 1 if kind == "single" else 5

    def get_ts(b_idx: int, lx: int, ly: int) -> tuple[int, int]:
        b_off = b_idx * 32
        wrap_x = kind == "smooth_strip" and b_idx in (2, 3, 4)
        wrap_y = kind == "smooth_strip" and b_idx in (1, 3, 4)
        if wrap_x:
            lx %= 32
        elif lx < 0 or lx >= 32:
            return -1, 0
        if wrap_y:
            ly %= 32
        elif ly < 0 or ly >= h:
            return -1, 0
        return t_grid[ly][b_off + lx], s_grid[ly][b_off + lx]

    # Pass 1: remove isolated 1px outer specks and fill 1px interior pinholes
    for _ in range(2):
        nt = [r[:] for r in t_grid]
        ns = [r[:] for r in s_grid]
        for b_idx in range(n_blocks):
            b_off = b_idx * 32
            for ly in range(h):
                for lx in range(32):
                    tv = t_grid[ly][b_off + lx]
                    n8 = [
                        get_ts(b_idx, lx + dx, ly + dy)
                        for dy in (-1, 0, 1)
                        for dx in (-1, 0, 1)
                        if not (dx == 0 and dy == 0)
                    ]
                    n8_act = [p for p in n8 if p[0] >= 0]
                    n4_act = [
                        p
                        for p in (
                            get_ts(b_idx, lx - 1, ly),
                            get_ts(b_idx, lx + 1, ly),
                            get_ts(b_idx, lx, ly - 1),
                            get_ts(b_idx, lx, ly + 1),
                        )
                        if p[0] >= 0
                    ]
                    if tv >= 0 and len(n8_act) <= 1:
                        nt[ly][b_off + lx] = -1
                    elif tv < 0 and len(n4_act) == 4:
                        nt[ly][b_off + lx] = sorted(p[0] for p in n4_act)[2]
                        ns[ly][b_off + lx] = sorted(p[1] for p in n4_act)[2]
        t_grid, s_grid = nt, ns

    # Pass 2: smooth isolated 1px single-tier or single-swatch speckles
    nt = [r[:] for r in t_grid]
    ns = [r[:] for r in s_grid]
    for b_idx in range(n_blocks):
        b_off = b_idx * 32
        wrap_x = kind == "smooth_strip" and b_idx in (2, 3, 4)
        wrap_y = kind == "smooth_strip" and b_idx in (1, 3, 4)
        for ly in range(h):
            for lx in range(32):
                # Preserve internal 15|16 quadrant join lines on non-flat blocks
                if kind == "smooth_strip" and b_idx < 4:
                    if lx in (15, 16) or ly in (15, 16):
                        continue
                    if not wrap_x and lx in (0, 31):
                        continue
                    if not wrap_y and ly in (0, 31):
                        continue
                tv = t_grid[ly][b_off + lx]
                sv = s_grid[ly][b_off + lx]
                if tv < 0:
                    continue
                n8_act = [
                    p
                    for p in (
                        get_ts(b_idx, lx + dx, ly + dy)
                        for dy in (-1, 0, 1)
                        for dx in (-1, 0, 1)
                        if not (dx == 0 and dy == 0)
                    )
                    if p[0] >= 0
                ]
                if n8_act:
                    t_neighbors = [p[0] for p in n8_act]
                    s_neighbors = [p[1] for p in n8_act]
                    if tv not in t_neighbors:
                        nt[ly][b_off + lx] = sorted(t_neighbors)[len(t_neighbors) // 2]
                    if sv not in s_neighbors:
                        ns[ly][b_off + lx] = sorted(s_neighbors)[len(s_neighbors) // 2]
    return nt, ns


def emit_disjoint_layers(
    layer_defs: list[tuple[str, int]],
    tiers: list[list[int]],
    swatches: list[list[int]],
    kind: str,
) -> list[dict[str, Any]]:
    """Emit K disjoint opacity layers from the unified (tiers, swatches) grids."""
    clean_t, clean_s = clean_unified_grid(tiers, swatches, kind)
    h = len(clean_t)
    w = len(clean_t[0])
    layers: list[dict[str, Any]] = []
    for t_idx, (lname, opacity) in enumerate(layer_defs):
        rows: list[str] = []
        used: set[str] = set()
        for y in range(h):
            row_chars: list[str] = []
            for x in range(w):
                if clean_t[y][x] == t_idx:
                    ch = IDX_TO_CHAR[clean_s[y][x]]
                    row_chars.append(ch)
                    used.add(ch)
                else:
                    row_chars.append(".")
            rows.append("".join(row_chars))
        if not used:
            used.add("6")
        legend = {ch: FULL_LEGEND[ch] for ch in sorted(used)}
        layers.append(
            {
                "name": lname,
                "opacity": opacity,
                "blend_mode": "normal",
                "rows": rows,
                "legend": legend,
            }
        )
    return layers


# ---------------------------------------------------------------------------
# Family 1: LIGHT MIST — Disjoint opacities [18, 30, 44, 56]
# Calm, broad, low-frequency non-grid haze veil (#C4C4C4, #D9D9D9, #EEEEEE).
# ---------------------------------------------------------------------------
MIST_LAYERS: list[tuple[str, int]] = [
    ("mist_edge_18", 18),
    ("mist_veil_30", 30),
    ("mist_wisp_44", 44),
    ("mist_haze_56", 56),
]


def mist_vapor_field(tx: int, ty: int, motion: str, frame_idx: int) -> float:
    dx1, dy1, dx2, dy2, ang = advection_offsets(motion, frame_idx)
    x1 = tx + 0.5 - dx1
    y1 = ty + 0.5 - dy1
    x2 = tx + 0.5 - dx2
    y2 = ty + 0.5 - dy2

    if motion == "stirred":
        x1 += 1.2 * math.sin(OMEGA * y1 + ang)
        y1 += 0.9 * math.cos(OMEGA * x1 - ang)

    # Broad, calm amorphous stratus/haze veil — gentle (1,0) + (0,1) swells
    # with soft cross-phase drift (no diagonal pills, no crossed fishnet grid).
    s1 = (
        0.54 * math.cos(OMEGA * x1 + 0.32 * math.sin(OMEGA * y1 + 0.5) + 0.3)
        + 0.46 * math.sin(OMEGA * y1 - 0.28 * math.cos(OMEGA * x1 - 0.4) + 1.0)
    )
    s2 = (
        0.65 * math.cos(OMEGA * x2 - 0.9)
        + 0.35 * math.sin(OMEGA * (x2 + y2) + 0.7)
    )
    raw = 0.72 * s1 + 0.28 * s2
    return clamp(0.52 + 0.44 * raw, 0.0, 1.0)


def generate_mist_frame(kind: str, motion: str, frame_idx: int) -> list[dict[str, Any]]:
    _, _, _, _, ang = advection_offsets(motion, frame_idx)
    width = 32 if kind == "single" else 160

    vap = [[0.0] * width for _ in range(32)]
    env_g = [[0.0] * width for _ in range(32)]
    rny_g = [[0.0] * width for _ in range(32)]

    for y in range(32):
        for x in range(width):
            tx = x % 32
            block = x // 32
            vap[y][x] = mist_vapor_field(tx, y, motion, frame_idx)
            env_g[y][x], rny_g[y][x] = compute_envelope_and_rim_ny(
                kind, block, tx, y, motion, ang, seed=0.7, wisp_amp=2.2
            )

    tiers = [[-1] * width for _ in range(32)]
    swatches = [[3] * width for _ in range(32)]

    for y in range(32):
        for x in range(width):
            tx = x % 32
            b_idx = 0 if kind == "single" else (x // 32)
            v = vap[y][x]
            env = env_g[y][x]
            r_ny = rny_g[y][x]

            # Outer boundary feathers wispy across [18, 30, 44, 56], while interior
            # (env == 1.0 on Block 4) stays uniformly at alpha 56 with zero alpha islands!
            dens = env * (1.0 - 0.22 * (1.0 - env) * (1.0 - v))
            if dens < 0.10:
                continue

            if dens < 0.30:
                tiers[y][x] = 0  # alpha 18
            elif dens < 0.54:
                tiers[y][x] = 1  # alpha 30
            elif dens < 0.78:
                tiers[y][x] = 2  # alpha 44
            else:
                tiers[y][x] = 3  # alpha 56

            _, v_ny = sample_vap_gradients(vap, kind, b_idx, tx, y, delta=3)
            # Soft, low-contrast mist veil balanced across #C4C4C4(3), #D9D9D9(4), #EEEEEE(5)
            # (with subtle #AAAAAA(2) only on the outermost south wisp).
            shade = 0.50 + 0.85 * (v - 0.52) + 0.50 * v_ny + 0.52 * r_ny
            if r_ny < -0.10 and env < 0.58 and shade < 0.38:
                swatches[y][x] = 2  # #AAAAAA outer south mist wisp
            elif shade < 0.41:
                swatches[y][x] = 3  # #C4C4C4 (~33%)
            elif shade < 0.57:
                swatches[y][x] = 4  # #D9D9D9 (~35%)
            else:
                swatches[y][x] = 5  # #EEEEEE (~32%)

    return emit_disjoint_layers(MIST_LAYERS, tiers, swatches, kind)


# ---------------------------------------------------------------------------
# Family 2: MEDIUM SMOKE — Disjoint opacities [28, 56, 88, 120, 148]
# Broad curling matte smoke drifts (#626262 outer south wisp, #929292..#EEEEEE).
# ---------------------------------------------------------------------------
SMOKE_LAYERS: list[tuple[str, int]] = [
    ("smoke_wisp_28", 28),
    ("smoke_taper_56", 56),
    ("smoke_drift_88", 88),
    ("smoke_plume_120", 120),
    ("smoke_core_148", 148),
]


def smoke_vapor_field(tx: int, ty: int, motion: str, frame_idx: int) -> float:
    dx1, dy1, dx2, dy2, ang = advection_offsets(motion, frame_idx)
    x1 = tx + 0.5 - dx1
    y1 = ty + 0.5 - dy1
    x2 = tx + 0.5 - dx2
    y2 = ty + 0.5 - dy2

    # Exact integer temporal multiplier (1.0 * ang) so f8 -> f1 wraps seamlessly!
    curl_a = 1.4 if motion != "stirred" else 2.0
    wx = x1 + curl_a * math.sin(OMEGA * y1 + ang + 0.9)
    wy = y1 - curl_a * math.cos(OMEGA * x1 - ang + 0.4)

    b1 = (
        0.54 * math.cos(OMEGA * wx + 0.30 * math.sin(OMEGA * wy) - 0.5)
        + 0.34 * math.sin(OMEGA * wy - 0.28 * math.cos(OMEGA * wx) + 1.2)
        + 0.12 * math.cos(OMEGA * (wx - wy) + 0.7)
    )
    b2 = (
        0.60 * math.cos(OMEGA * x2 + 1.4)
        + 0.40 * math.sin(OMEGA * y2 - 1.1)
    )
    raw = 0.70 * b1 + 0.30 * b2
    return clamp(0.53 + 0.45 * raw, 0.0, 1.0)


def generate_smoke_frame(kind: str, motion: str, frame_idx: int) -> list[dict[str, Any]]:
    _, _, _, _, ang = advection_offsets(motion, frame_idx)
    width = 32 if kind == "single" else 160

    vap = [[0.0] * width for _ in range(32)]
    env_g = [[0.0] * width for _ in range(32)]
    rny_g = [[0.0] * width for _ in range(32)]

    for y in range(32):
        for x in range(width):
            tx = x % 32
            block = x // 32
            vap[y][x] = smoke_vapor_field(tx, y, motion, frame_idx)
            env_g[y][x], rny_g[y][x] = compute_envelope_and_rim_ny(
                kind, block, tx, y, motion, ang, seed=2.1, wisp_amp=2.3
            )

    tiers = [[-1] * width for _ in range(32)]
    swatches = [[3] * width for _ in range(32)]

    for y in range(32):
        for x in range(width):
            tx = x % 32
            b_idx = 0 if kind == "single" else (x // 32)
            v = vap[y][x]
            env = env_g[y][x]
            r_ny = rny_g[y][x]

            # Wide 14px wispy outer taper [28 -> 56 -> 88 -> 120 -> 148];
            # interior Block 4 stays uniformly at alpha 148 so no alpha islands form!
            dens = env * (1.0 - 0.22 * (1.0 - env) * (1.0 - v))
            if dens < 0.10:
                continue

            if dens < 0.26:
                tiers[y][x] = 0  # alpha 28
            elif dens < 0.45:
                tiers[y][x] = 1  # alpha 56
            elif dens < 0.64:
                tiers[y][x] = 2  # alpha 88
            elif dens < 0.82:
                tiers[y][x] = 3  # alpha 120
            else:
                tiers[y][x] = 4  # alpha 148

            _, v_ny = sample_vap_gradients(vap, kind, b_idx, tx, y, delta=3)
            # Matte smoke interior: #AAAAAA(2), #C4C4C4(3), #D9D9D9(4), #EEEEEE(5),
            # with #929292(1) on outer lower folds and #626262(0) on outer south wisp only.
            shade = 0.50 + 0.80 * (v - 0.53) + 0.55 * v_ny + 0.95 * r_ny
            if r_ny < -0.08 and env < 0.64 and shade < 0.26:
                idx = 0  # #626262 outer south wisp only
            elif r_ny < -0.05 and shade < 0.36:
                idx = 1  # #929292 outer south fold
            elif shade < 0.39:
                idx = 2  # #AAAAAA matte smoke shadow
            elif shade < 0.50:
                idx = 3  # #C4C4C4 matte smoke mid
            elif shade < 0.62:
                idx = 4  # #D9D9D9 matte smoke upper-mid
            else:
                idx = 5  # #EEEEEE soft upper smoke drift
            swatches[y][x] = idx

    return emit_disjoint_layers(SMOKE_LAYERS, tiers, swatches, kind)


# ---------------------------------------------------------------------------
# Family 3: DENSE CLOUD — Disjoint opacities [36, 76, 122, 166, 204]
# Plush, low-contrast overcast vapor blanket (#C4C4C4, #D9D9D9, #EEEEEE + small
# soft #FFFFFF crest patch; #AAAAAA/#929292 ONLY on outer south margin!).
# ---------------------------------------------------------------------------
CLOUD_LAYERS: list[tuple[str, int]] = [
    ("cloud_wisp_36", 36),
    ("cloud_taper_76", 76),
    ("cloud_mid_122", 122),
    ("cloud_bank_166", 166),
    ("cloud_core_204", 204),
]


def cloud_vapor_field(tx: int, ty: int, motion: str, frame_idx: int) -> float:
    dx1, dy1, dx2, dy2, ang = advection_offsets(motion, frame_idx)
    x1 = tx + 0.5 - dx1
    y1 = ty + 0.5 - dy1
    x2 = tx + 0.5 - dx2
    y2 = ty + 0.5 - dy2

    if motion == "stirred":
        x1 += 1.1 * math.sin(OMEGA * y1 + ang)
        y1 -= 0.9 * math.cos(OMEGA * x1 - ang)

    # Multi-scale asymmetric overcast vapor field: combines (1,0), (0,1), (1,1)
    # saddles with (2,1), (1,-2), (3,1) secondary cloud tufts so contours
    # percolate organically across tile edges with ZERO concentric bullseyes,
    # ZERO chevron bars, and ZERO topographic isolines!
    b1 = (
        0.34 * math.cos(OMEGA * x1 + 0.3)
        + 0.30 * math.sin(OMEGA * y1 + 1.1)
        + 0.28 * math.cos(OMEGA * (x1 - y1) - 0.8)
        + 0.26 * math.sin(2.0 * OMEGA * x1 + OMEGA * y1 + 0.5)
        + 0.22 * math.cos(OMEGA * x1 - 2.0 * OMEGA * y1 + 2.1)
    )
    b2 = (
        0.48 * math.sin(OMEGA * (x2 + y2) + 1.7)
        + 0.34 * math.cos(2.0 * OMEGA * x2 - OMEGA * y2 - 0.6)
        + 0.18 * math.sin(3.0 * OMEGA * x2 + 2.0 * OMEGA * y2 + 0.9)
    )
    raw = 0.68 * b1 + 0.32 * b2
    return clamp(0.52 + 0.42 * raw, 0.0, 1.0)


def generate_cloud_frame(kind: str, motion: str, frame_idx: int) -> list[dict[str, Any]]:
    _, _, _, _, ang = advection_offsets(motion, frame_idx)
    width = 32 if kind == "single" else 160

    vap = [[0.0] * width for _ in range(32)]
    env_g = [[0.0] * width for _ in range(32)]
    rny_g = [[0.0] * width for _ in range(32)]

    for y in range(32):
        for x in range(width):
            tx = x % 32
            block = x // 32
            vap[y][x] = cloud_vapor_field(tx, y, motion, frame_idx)
            env_g[y][x], rny_g[y][x] = compute_envelope_and_rim_ny(
                kind, block, tx, y, motion, ang, seed=3.5, wisp_amp=2.4
            )

    tiers = [[-1] * width for _ in range(32)]
    swatches = [[3] * width for _ in range(32)]

    for y in range(32):
        for x in range(width):
            tx = x % 32
            b_idx = 0 if kind == "single" else (x // 32)
            v = vap[y][x]
            env = env_g[y][x]
            r_ny = rny_g[y][x]

            # Wide 14px wispy outer taper [36 -> 76 -> 122 -> 166 -> 204] so Cloud
            # melts invisibly into Smoke; interior Block 4 stays uniformly at alpha 204!
            dens = env * (1.0 - 0.22 * (1.0 - env) * (1.0 - v))
            if dens < 0.10:
                continue

            if dens < 0.26:
                tiers[y][x] = 0  # alpha 36
            elif dens < 0.45:
                tiers[y][x] = 1  # alpha 76
            elif dens < 0.64:
                tiers[y][x] = 2  # alpha 122
            elif dens < 0.82:
                tiers[y][x] = 3  # alpha 166
            else:
                tiers[y][x] = 4  # alpha 204

            _, v_ny = sample_vap_gradients(vap, kind, b_idx, tx, y, delta=3)

            # Plush overcast interior blanket:
            # Percolating #D9D9D9(4) body (~50%) with irregular #C4C4C4(3) troughs (~25%)
            # and soft #EEEEEE(5) drifts (~22%) + tiny localized #FFFFFF(6) crest (~3%).
            interior_shade = 0.50 + 0.86 * (v - 0.52) + 0.36 * v_ny
            if interior_shade < 0.41:
                idx = 3  # #C4C4C4 (~25% irregular overcast trough)
            elif interior_shade < 0.59:
                idx = 4  # #D9D9D9 (~50% plush percolating overcast body)
            else:
                idx = 5  # #EEEEEE (~22% soft irregular upper cloud drift)

            if v >= 0.82 and v_ny >= 0.03 and r_ny >= -0.02:
                idx = 6  # small soft #FFFFFF highlight patch (~3% localized crest)
            elif (kind == "single" or b_idx == 0) and r_ny > 0.12 and interior_shade >= 0.46:
                idx = min(6, idx + 1)  # sunlit north crown on isolated 1-tile puffs
            elif r_ny < -0.14:
                idx = 1 if (env < 0.68 and interior_shade < 0.50) else 2  # #929292 / #AAAAAA south base
            elif r_ny < -0.05:
                idx = min(idx, 2 if interior_shade < 0.44 else 3)  # soft south transition
            swatches[y][x] = idx

    return emit_disjoint_layers(CLOUD_LAYERS, tiers, swatches, kind)


# ---------------------------------------------------------------------------
# Assemble all 18 Gas Asset Entries
# ---------------------------------------------------------------------------
MIST_TINTS = [
    {"name": "Water Vapor / O2", "hex": "#7ED8FF"},
    {"name": "Ammonia Mist", "hex": "#D8E8D0"},
    {"name": "Cryo Freon", "hex": "#80FFFF"},
    {"name": "Steam Wisps", "hex": "#C8D4E0"},
]

SMOKE_TINTS = [
    {"name": "Sulfur / Mustard", "hex": "#E6D36A"},
    {"name": "Soot Smoke", "hex": "#787882"},
    {"name": "Plasma Plume", "hex": "#D95BFF"},
    {"name": "Acrid Chlorine", "hex": "#58C84D"},
]

CLOUD_TINTS = [
    {"name": "Chlorine / Miasma", "hex": "#58C84D"},
    {"name": "Plasma Cloud", "hex": "#D95BFF"},
    {"name": "Dense Steam", "hex": "#7ED8FF"},
    {"name": "Sulfur Bank", "hex": "#E6D36A"},
]


def make_gas_entry(
    family: str,
    kind: str,
    motion: str,
    n_frames: int,
    duration_ms: int,
    title: str,
    default_tint: str,
    sample_tints: list[dict[str, str]],
    description: str,
    physics_notes: str,
) -> dict[str, Any]:
    kind_slug = "single" if kind == "single" else "smooth"
    sid = f"gas_{family}_{kind_slug}_{motion}"
    gen_fn = {
        "mist": generate_mist_frame,
        "smoke": generate_smoke_frame,
        "cloud": generate_cloud_frame,
    }[family]

    frames: list[dict[str, Any]] = [
        {
            "duration_ms": duration_ms,
            "layers": gen_fn(kind, motion, i),
        }
        for i in range(n_frames)
    ]

    return {
        "id": sid,
        "title": title,
        "element": "gas",
        "category": f"gas_{family}",
        "kind": kind,
        "colorable": True,
        "require_top_light": family == "cloud",
        "default_tint": default_tint,
        "sample_tints": sample_tints,
        "ase_relpath": f"assets/originals/art/matter/gasses/{sid}.aseprite",
        "tag": "idle",
        "description": description,
        "physics_notes": physics_notes,
        "frames": frames,
    }


def build_sprites() -> list[dict[str, Any]]:
    return [
        # 1. Light Mist (6 assets — disjoint opacities [18, 30, 44, 56])
        make_gas_entry(
            "mist", "single", "still", 1, 200,
            "Light Mist — Single Patch (Still)", "#7ED8FF", MIST_TINTS,
            "Calm, airy haze veil (#C4C4C4..#EEEEEE) across 4 disjoint alpha tiers [18,30,44,56] with a 14px feathered outer taper.",
            "Low optical depth (>=0.35 mol) suspended aerosol shell; high floor visibility.",
        ),
        make_gas_entry(
            "mist", "single", "gentle", 8, 600,
            "Light Mist — Single Patch (Gentle Drift)", "#7ED8FF", MIST_TINTS,
            "Eight-frame @ 600ms (4.8s loop) calmly gliding mist veil across 4 disjoint opacity tiers [18,30,44,56].",
            "Slow laminar advection (4px/frame toroidal phase wrap) with <=0.6px edge breathing.",
        ),
        make_gas_entry(
            "mist", "single", "stirred", 8, 300,
            "Light Mist — Single Patch (Stirred Roll)", "#7ED8FF", MIST_TINTS,
            "Eight-frame @ 300ms (2.4s loop) briskly rolling mist veil with soft shear undulation.",
            "Continuous rolling ventilation draft across 8 progressive steps without strobe oscillation.",
        ),
        make_gas_entry(
            "mist", "smooth_strip", "still", 1, 200,
            "Light Mist — Smooth Multi-Tile (Still)", "#7ED8FF", MIST_TINTS,
            "160x32 5-block smooth strip with a 14px wispy outer alpha taper [18->30->44->56] and calm non-grid interior haze.",
            "Outer nested contour shell (>=0.35 mol) connecting seamlessly across all 47 junctions.",
        ),
        make_gas_entry(
            "mist", "smooth_strip", "gentle", 8, 600,
            "Light Mist — Smooth Multi-Tile (Gentle Drift)", "#7ED8FF", MIST_TINTS,
            "Eight-frame @ 600ms (4.8s loop) 5-block smooth mist strip with continuous 4px/frame periodic drift.",
            "Calm room-scale vapor convection gliding seamlessly across 32x32 tile boundaries.",
        ),
        make_gas_entry(
            "mist", "smooth_strip", "stirred", 8, 300,
            "Light Mist — Smooth Multi-Tile (Stirred Roll)", "#7ED8FF", MIST_TINTS,
            "Eight-frame @ 300ms (2.4s loop) 5-block smooth mist strip with progressive diagonal rolling advection.",
            "Brisk cross-tile airflow rolling thin mist smoothly across corridors and L-junctions.",
        ),
        # 2. Medium Smoke (6 assets — disjoint opacities [28, 56, 88, 120, 148])
        make_gas_entry(
            "smoke", "single", "still", 1, 200,
            "Medium Smoke — Single Plume (Still)", "#E6D36A", SMOKE_TINTS,
            "Broad curling matte smoke drift (#626262 outer south wisp, #929292..#EEEEEE) across 5 disjoint alpha tiers [28..148].",
            "Intermediate optical depth (>=3.5 mol) suspended particulate plume with wide diffusive rim.",
        ),
        make_gas_entry(
            "smoke", "single", "gentle", 8, 600,
            "Medium Smoke — Single Plume (Gentle Roll)", "#E6D36A", SMOKE_TINTS,
            "Eight-frame @ 600ms (4.8s loop) slowly rolling matte smoke plume with calm <=0.6px contour breathing.",
            "Steady buoyant smoke drift advecting continuously across an 8-step toroidal cycle.",
        ),
        make_gas_entry(
            "smoke", "single", "stirred", 8, 300,
            "Medium Smoke — Single Plume (Stirred Billow)", "#E6D36A", SMOKE_TINTS,
            "Eight-frame @ 300ms (2.4s loop) briskly billowing matte smoke drift with counter-rolling shear.",
            "Continuous turbulent smoke roll at 300ms steps without high-frequency jello oscillation.",
        ),
        make_gas_entry(
            "smoke", "smooth_strip", "still", 1, 200,
            "Medium Smoke — Smooth Multi-Tile (Still)", "#787882", SMOKE_TINTS,
            "160x32 5-block smooth smoke strip with wide 11px wispy taper [28->56->88->120->148] that melts seamlessly into mist.",
            "Middle nested contour shell (>=3.5 mol) with broad curling matte interior smoke banks.",
        ),
        make_gas_entry(
            "smoke", "smooth_strip", "gentle", 8, 600,
            "Medium Smoke — Smooth Multi-Tile (Gentle Roll)", "#787882", SMOKE_TINTS,
            "Eight-frame @ 600ms (4.8s loop) multi-tile smooth smoke strip with 4px/frame toroidal plume advection.",
            "Room-scale smoke bank rolling calmly and continuously across connected junctions.",
        ),
        make_gas_entry(
            "smoke", "smooth_strip", "stirred", 8, 300,
            "Medium Smoke — Smooth Multi-Tile (Stirred Billow)", "#787882", SMOKE_TINTS,
            "Eight-frame @ 300ms (2.4s loop) multi-tile smooth smoke strip with brisk diagonal rolling S-drifts.",
            "Pressurized ventilation shear driving smooth continuous multi-tile smoke billows.",
        ),
        # 3. Dense Cloud (6 assets — disjoint opacities [36, 76, 122, 166, 204], require_top_light=True)
        make_gas_entry(
            "cloud", "single", "still", 1, 200,
            "Dense Cloud — Single Bank (Still)", "#58C84D", CLOUD_TINTS,
            "Dry, matte overcast vapor bank (#C4C4C4..#EEEEEE, localized #FFFFFF north crest, #AAAAAA/#929292 south base) across [36..204] alpha.",
            "High optical depth (>=12.0 mol) dry atmospheric vapor pocket with wide 11px feathered rim.",
        ),
        make_gas_entry(
            "cloud", "single", "gentle", 8, 600,
            "Dense Cloud — Single Bank (Gentle Drift)", "#58C84D", CLOUD_TINTS,
            "Eight-frame @ 600ms (4.8s loop) calmly billowing matte gas bank under soft top-down lighting.",
            "Slow baroclinic cloud drift advecting smoothly over 8 toroidal steps.",
        ),
        make_gas_entry(
            "cloud", "single", "stirred", 8, 300,
            "Dense Cloud — Single Bank (Stirred Billow)", "#D95BFF", CLOUD_TINTS,
            "Eight-frame @ 300ms (2.4s loop) briskly rolling dense matte vapor bank with soft billowing shear.",
            "Energetic internal cloud roll maintaining dry matte vapor shading and soft edge taper.",
        ),
        make_gas_entry(
            "cloud", "smooth_strip", "still", 1, 200,
            "Dense Cloud — Smooth Multi-Tile (Still)", "#58C84D", CLOUD_TINTS,
            "160x32 5-block smooth cloud strip with plush overcast interior vapor (#C4C4C4..#EEEEEE + soft #FFFFFF patch) and [36..204] taper.",
            "Inner nested contour shell (>=12.0 mol) free of bubble spheres, chevron bars, or vertical corridor seams.",
        ),
        make_gas_entry(
            "cloud", "smooth_strip", "gentle", 8, 600,
            "Dense Cloud — Smooth Multi-Tile (Gentle Drift)", "#58C84D", CLOUD_TINTS,
            "Eight-frame @ 600ms (4.8s loop) 5-block smooth cloud strip with calm 4px/frame periodic overcast drift.",
            "Dense multi-tile atmospheric bank gliding smoothly across 32x32 tile joins.",
        ),
        make_gas_entry(
            "cloud", "smooth_strip", "stirred", 8, 300,
            "Dense Cloud — Smooth Multi-Tile (Stirred Billow)", "#D95BFF", CLOUD_TINTS,
            "Eight-frame @ 300ms (2.4s loop) 5-block smooth cloud strip with continuous rolling overcast swells.",
            "Briskly rolling high-concentration gas bank across all 47 connected junctions.",
        ),
    ]


SPRITES: list[dict[str, Any]] = build_sprites()
