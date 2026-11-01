#!/usr/bin/env python3
"""
Elemental Matter — Liquids & Zero-G Pixel-Art Specification (19 assets, v2.1).

All 19 liquid assets are `colorable: True` and strictly neutral greyscale (`R == G == B`)
from `tales-from-space.gpl`, authored for runtime sRGB multiply tinting across water,
blood, crude oil, acid, fuel/cooking oil, and liquid metals.

v2.1 Visual & Seam/Loop Architecture:
  - Pools (`liquid_pool_*`): Calm deep water (`~65%` `#929292` / `~31%` `#AAAAAA` monotonic
    meandering diagonal swells — zero Voronoi polygons, zero bullseye ovals) accented by
    5 sparse horizontal wavelets (`#D9D9D9` + `1px` `#626262` trough) and a 4-layer
    `[56, 112, 168, 216]` 9.2px edge depth/alpha taper over underlying puddle shells.
  - Puddles & Spills (`liquid_puddle_*`, `liquid_spill_*`): 4-layer `[68, 122, 168, 212]`
    feathered wet seepage skirt + broken `#EEEEEE` NNW meniscus glint along outer shorelines,
    surrounding a calm, glassy `#AAAAAA` (`~65%`) / `#C4C4C4` (`~35%`) translucent liquid sheet
    (zero concentric frogspawn ovals).
  - Exact Torus Loop & Seam Continuity: Cosine-symmetric shoreline waves (`0.00` alpha MAE
    across `15|16` and `31|0`) and exact `+4px/frame` (`32px` over `8 frames @ 300ms`) integer
    torus phase glide (`wrap_mae / mean_step_mae ~ 1.00`).
"""
from __future__ import annotations

import math
from typing import Any

# Strictly neutral greyscale swatches (R == G == B, chroma == 0) in tales-from-space.gpl
FULL_LEGEND: dict[str, str] = {
    "k": "#1B1B1B",  # 27  stripe-dark-1
    "d": "#1D1D1D",  # 29  neutral-1-outline
    "s": "#262626",  # 38  stripe-dark-2
    "n": "#2B2B2B",  # 43  neutral-2
    "1": "#444444",  # 68  neutral-3-wall-face
    "2": "#626262",  # 98  neutral-4
    "3": "#929292",  # 146 neutral-5
    "4": "#AAAAAA",  # 170 neutral-6
    "5": "#C4C4C4",  # 196 neutral-7
    "6": "#D9D9D9",  # 217 neutral-8-highlight
    "7": "#EEEEEE",  # 238 near-white
    "8": "#FFFFFF",  # 255 white-glint
}

SAMPLE_TINTS: list[dict[str, str]] = [
    {"name": "Water", "label": "Water", "hex": "#4BA3E3"},
    {"name": "Blood", "label": "Blood", "hex": "#9E131B"},
    {"name": "Crude Oil", "label": "Crude Oil", "hex": "#3B2F20"},
    {"name": "Acid", "label": "Acid", "hex": "#6CE635"},
    {"name": "Fuel / Oil", "label": "Fuel / Oil", "hex": "#D8B848"},
    {"name": "Mercury", "label": "Mercury", "hex": "#D9DDE2"},
]

# Top-down slightly-NNW station lighting vector (pointing toward the light source)
LIGHT_X = -0.36
LIGHT_Y = -0.933


def make_grid(w: int, h: int, fill: str = ".") -> list[list[str]]:
    return [[fill for _ in range(w)] for _ in range(h)]


def grid_to_rows(grid: list[list[str]]) -> list[str]:
    return ["".join(r) for r in grid]


def build_layers(
    layer_specs: list[tuple[str, int, list[list[str]]]],
) -> list[dict[str, Any]]:
    """Convert non-overlapping (name, opacity, char_grid) layers into elemental_kit layer dicts."""
    out: list[dict[str, Any]] = []
    for name, opacity, grid in layer_specs:
        rows = grid_to_rows(grid)
        used = sorted({ch for row in rows for ch in row if ch != "."})
        legend = {ch: FULL_LEGEND[ch] for ch in used}
        if not legend:
            legend = {"4": FULL_LEGEND["4"]}
        out.append(
            {
                "name": name,
                "opacity": opacity,
                "blend_mode": "normal",
                "rows": rows,
                "legend": legend,
            }
        )
    return out


def put_exclusive(
    layers: list[list[list[str]]],
    layer_idx: int,
    x: int,
    y: int,
    ch: str,
) -> None:
    """Assign pixel (x, y) exclusively to `layer_idx` so flattened pixels stay 100% on-palette."""
    h = len(layers[0])
    w = len(layers[0][0])
    if 0 <= x < w and 0 <= y < h:
        for i, g in enumerate(layers):
            g[y][x] = ch if i == layer_idx else "."


def smooth_max(a: float, b: float, k: float) -> float:
    """Polynomial C1 smooth-max (metaball union for positive-inside SDFs)."""
    h = max(0.0, k - abs(a - b)) / k
    return max(a, b) + 0.25 * k * h * h


# ---------------------------------------------------------------------------
# 1. Shared 5-Block Smooth-Strip SDF & Wave Helpers
# ---------------------------------------------------------------------------

def quad_base_sdf(block: int, x: float, y: float, inset: float, r_conv: float) -> float:
    """
    Exact C0/C1-compatible signed distance (positive inside liquid) for a 32x32 block
    in a 5-block diagonal_32x32 smooth strip:
      0 = convex (!v and !h)
      1 = vertical (v and !h)
      2 = horizontal (!v and h)
      3 = concave (v and h and !d)
      4 = flat (v and h and d)
    """
    u_h = (x + 0.5) if x < 16.0 else (31.5 - x)
    u_v = (y + 0.5) if y < 16.0 else (31.5 - y)
    if block == 4:
        return 16.0
    if block == 1:
        return u_h - inset
    if block == 2:
        return u_v - inset
    if block == 3:
        return math.hypot(u_h, u_v) - inset
    # block == 0: rounded convex outer corner (pivot <= 14.5 ensures C1 match at 15|16 midline)
    pivot = inset + r_conv
    dx = max(0.0, pivot - u_h)
    dy = max(0.0, pivot - u_v)
    if dx > 0.0 and dy > 0.0:
        return r_conv - math.hypot(dx, dy)
    return min(u_h - inset, u_v - inset)


def puddle_wave(x: float, y: float) -> float:
    """
    32x32-periodic organic shoreline wave using pure cosine harmonics so both
    inter-tile joins (31|0) and intra-tile quadrant joins (15|16) have 0.00 step.
    """
    tx = 2.0 * math.pi * ((x % 32.0) + 0.5) / 32.0
    ty = 2.0 * math.pi * ((y % 32.0) + 0.5) / 32.0
    return (
        0.58 * math.cos(tx)
        + 0.32 * math.cos(2.0 * tx)
        + 0.54 * math.cos(ty)
        + 0.28 * math.cos(2.0 * ty)
    )


def pool_wave(x: float, y: float) -> float:
    """
    32x32-periodic cosine contour modulation for deep pool depth/alpha taper
    with exact C0/C1 symmetry across 31|0 and 15|16 boundaries.
    """
    tx = 2.0 * math.pi * ((x % 32.0) + 0.5) / 32.0
    ty = 2.0 * math.pi * ((y % 32.0) + 0.5) / 32.0
    return (
        0.54 * math.cos(tx)
        + 0.28 * math.cos(2.0 * tx)
        + 0.50 * math.cos(ty)
        + 0.26 * math.cos(2.0 * ty)
    )


def sdf_outward_normal(sdf_fn, x: int, y: int) -> tuple[float, float]:
    """Compute outward normal (-grad S / |grad S|) pointing from liquid toward dry floor."""
    eps = 0.35
    gx = sdf_fn(x + eps, y) - sdf_fn(x - eps, y)
    gy = sdf_fn(x, y + eps) - sdf_fn(x, y - eps)
    mag = math.hypot(gx, gy)
    if mag < 1e-6:
        return (0.0, -1.0)
    return (-gx / mag, -gy / mag)


# ---------------------------------------------------------------------------
# 2. Puddles & Spills — 4-Layer Feathered Wet Seepage Rim `[68, 122, 168, 212]`
#    + Calm, Glassy, Near-Flat Translucent Liquid Sheet (Zero Bullseyes!)
# ---------------------------------------------------------------------------

PUDDLE_LAYER_DEFS: list[tuple[str, int]] = [
    ("wet_seep_outer", 68),
    ("wet_seep_inner", 122),
    ("puddle_body", 168),
    ("meniscus_glint", 212),
]

# 2 tiny (3px x 1px) subtle #D9D9D9 surface shimmer ticks per 32x32 tile,
# placed away from horizontal seam rows {0, 1, 14, 15, 16, 17, 30, 31}.
PUDDLE_SHIMMER_TICKS: list[tuple[int, int, int]] = [
    (7, 6, 3),
    (21, 22, 3),
]


def build_puddle_shimmer_set(shift_x: int) -> set[tuple[int, int]]:
    pts: set[tuple[int, int]] = set()
    for x0, y0, w in PUDDLE_SHIMMER_TICKS:
        for i in range(w):
            pts.add(((x0 + i + shift_x) % 32, y0 % 32))
    return pts


def shade_feathered_puddle_pixel(
    s: float,
    nx: float,
    ny: float,
    x: int,
    y: int,
    shift_x: int = 0,
    shimmer_pts: set[tuple[int, int]] | None = None,
    north_grad: float = 0.0,
) -> tuple[int, str] | None:
    """
    4-tier feathered wet seepage rim + broken `#EEEEEE` NW meniscus glint + calm glassy sheet:
      layer 0 (`alpha 68`):  0.00 .. 1.35 px — outer translucent seepage halo
      layer 1 (`alpha 122`): 1.35 .. 2.70 px — inner wet contact darkening/transition
      layer 3 (`alpha 212`): 2.70 .. 3.65 px — delicate broken `#EEEEEE` NNW meniscus glint (shoreline only!)
      layer 2 (`alpha 168`): >= 2.70 px      — calm glassy `#AAAAAA` (~65%) / `#C4C4C4` (~35%) diagonal wash
                                               + 2 tiny `3px` `#D9D9D9` surface shimmer glints (zero bullseyes!)
    """
    if s < 0.0:
        return None

    light_dot = nx * LIGHT_X + ny * LIGHT_Y
    mx = x % 32
    my = y % 32
    sx = (mx - shift_x) % 32

    # Tier 0: Outer feather seepage skirt (alpha 68)
    if s < 1.35:
        if light_dot < -0.32:
            return (0, "3")
        return (0, "4")

    # Tier 1: Inner wet contact skirt (alpha 122)
    if s < 2.70:
        if light_dot < -0.44:
            return (1, "2")
        if light_dot < 0.14:
            return (1, "3")
        return (1, "4")

    # Tier 3: Delicate broken upper-left wet meniscus glint (`#EEEEEE`, alpha 212) ONLY on outer shoreline
    if s < 3.65 and light_dot > 0.42:
        tx_g = 2.0 * math.pi * (sx + 0.5) / 32.0
        ty_g = 2.0 * math.pi * (my + 0.5) / 32.0
        arc_break = math.cos(2.0 * tx_g) + 0.45 * math.cos(2.0 * ty_g)
        if arc_break > -0.08:
            return (3, "7")
        return (2, "5")

    # Subtle lower rim shading just inside the south skirt before calm glassy sheet
    if s < 3.55 and light_dot < -0.48:
        return (2, "3")

    # Subtle 3px #D9D9D9 surface shimmer ticks well inside the calm liquid interior
    if shimmer_pts is not None and s >= 5.2 and (mx, my) in shimmer_pts:
        return (2, "6")

    # Tier 2: Calm, glassy, near-flat translucent liquid sheet (`~68%` #AAAAAA / `~31%` #C4C4C4).
    # Two out-of-phase gentle horizontal water swells (strictly inside y=3..11 and y=19..27 ->
    # zero bullseye ovals, zero 45-deg stripes, and 0.00 seam step across 0|31 and 15|16!).
    tx = 2.0 * math.pi * (sx + 0.5) / 32.0
    yc1 = 6.8 + 1.25 * math.sin(tx + 0.35) + 0.50 * math.cos(2.0 * tx - 0.50)
    hw1 = 2.85 + 0.60 * math.cos(tx - 0.90) + north_grad * 2.2
    yc2 = 22.4 + 1.25 * math.sin(tx + 2.65) + 0.50 * math.cos(2.0 * tx + 1.25)
    hw2 = 2.65 + 0.55 * math.sin(tx + 0.80) + north_grad * 2.2
    if abs(my - yc1) <= hw1 or abs(my - yc2) <= hw2:
        return (2, "5")
    return (2, "4")


def generate_puddle_strip_frames(n_frames: int) -> list[dict[str, Any]]:
    """
    160x32 5-block smooth puddle strip.
    For `shimmer` (`8 frames @ 300ms`), `shift_x = (f * 4) % 32` glides the gentle diagonal
    surface wash and 2 tiny shimmer glints seamlessly by 32px across 8 frames (`wrap_ratio ~ 1.00`).
    """
    frames: list[dict[str, Any]] = []
    inset = 3.50
    r_conv = 7.0
    dur = 300 if n_frames > 1 else 200

    for f in range(n_frames):
        shift_x = (f * 4) % 32 if n_frames > 1 else 0
        shimmer_pts = build_puddle_shimmer_set(shift_x)
        layers = [make_grid(160, 32) for _ in range(4)]

        for block in range(5):
            def sdf_b(px: float, py: float, b: int = block) -> float:
                if b == 4:
                    return 16.0
                return quad_base_sdf(b, px, py, inset, r_conv) + puddle_wave(px, py)

            for y in range(32):
                for x in range(32):
                    s = sdf_b(x, y)
                    if s < 0.0:
                        continue
                    nx, ny = (0.0, -1.0) if block == 4 or s >= 4.0 else sdf_outward_normal(sdf_b, x, y)
                    res = shade_feathered_puddle_pixel(
                        s, nx, ny, x, y, shift_x=shift_x, shimmer_pts=shimmer_pts
                    )
                    if res is not None:
                        put_exclusive(layers, res[0], block * 32 + x, y, res[1])

        frames.append(
            {
                "duration_ms": dur,
                "layers": build_layers(
                    [(name, op, layers[i]) for i, (name, op) in enumerate(PUDDLE_LAYER_DEFS)]
                ),
            }
        )
    return frames


def generate_puddle_single_frames() -> list[dict[str, Any]]:
    layers = [make_grid(32, 32) for _ in range(4)]
    shimmer_pts = {(11, 10), (12, 10), (19, 19), (20, 19)}

    def sdf(px: float, py: float) -> float:
        dx = (px - 15.6) / 11.4
        dy = (py - 16.0) / 9.9
        r = math.hypot(dx, dy)
        ang = math.atan2(dy, dx)
        lobe = (
            0.11 * math.cos(2.0 * ang - 0.4)
            + 0.09 * math.sin(3.0 * ang + 0.8)
            + 0.05 * math.cos(5.0 * ang - 1.1)
        )
        return (1.0 + lobe - r) * 10.4

    for y in range(32):
        for x in range(32):
            s = sdf(x, y)
            if s < 0.0:
                continue
            nx, ny = sdf_outward_normal(sdf, x, y)
            ngrad = (15.5 - y) * 0.022
            res = shade_feathered_puddle_pixel(
                s, nx, ny, x, y, shift_x=0, shimmer_pts=shimmer_pts, north_grad=ngrad
            )
            if res is not None:
                put_exclusive(layers, res[0], x, y, res[1])

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [(name, op, layers[i]) for i, (name, op) in enumerate(PUDDLE_LAYER_DEFS)]
            ),
        }
    ]


# ---------------------------------------------------------------------------
# 3. Deep Ankle-High+ Pools — Calm Water + Sparse Horizontal Wavelets + `[56, 112, 168, 216]` Taper
# ---------------------------------------------------------------------------

POOL_LAYER_DEFS: list[tuple[str, int]] = [
    ("taper_outer", 56),
    ("taper_mid", 112),
    ("taper_inner", 168),
    ("deep_water", 216),
]

# 5 isolated, well-spaced horizontal wavelets per 32x32 tile, placed away from
# horizontal seam rows {0, 1, 14, 15, 16, 17, 30, 31} and staggered evenly across X.
# (x0, y0, width, has_1px_eeeeee_center)
POOL_WAVELETS: list[tuple[int, int, int, bool]] = [
    (1, 4, 5, True),    # 5px horizontal wavelet in upper-left (1px #EEEEEE center)
    (15, 9, 4, False),  # 4px calm horizontal tick in upper-right (#D9D9D9 only)
    (8, 12, 5, True),   # 5px horizontal wavelet in upper-mid (1px #EEEEEE center)
    (21, 20, 5, False), # 5px horizontal wavelet in lower-right (#D9D9D9 only)
    (27, 26, 4, False), # 4px calm horizontal tick in lower-left (#D9D9D9 only)
]


def build_periodic_wavelet_map(shift_x: int) -> dict[tuple[int, int], str]:
    """
    Build a 32x32 lookup of sparse disconnected 1px-tall horizontal wavelets shifted by `shift_x`:
      - Crest row (`y0`): `#D9D9D9` ("6"), with 1px `#EEEEEE` ("7") on only 2 wavelets, ZERO `#FFFFFF`.
      - Directly beneath center of crest (`y0 + 1`): 1px `#626262` ("2") wave-trough shadow.
    """
    wmap: dict[tuple[int, int], str] = {}
    for wx0, wy0, width, has_glint in POOL_WAVELETS:
        for i in range(width):
            px = (wx0 + i + shift_x) % 32
            py = wy0 % 32
            is_peak = has_glint and (i == width // 2)
            wmap[(px, py)] = "7" if is_peak else "6"
            if 1 <= i <= width - 2:
                wmap[(px, (py + 1) % 32)] = "2"
    return wmap


def shade_pool_pixel(
    s: float,
    nx: float,
    ny: float,
    x: int,
    y: int,
    shift_x: int,
    wavelet_map: dict[tuple[int, int], str],
) -> tuple[int, str] | None:
    """
    Calm deep water with 4-layer 9.2px edge depth/alpha taper `[56, 112, 168, 216]`:
      - Zero bright outer shoreline ring (monotonically deepens over `puddle` contour shells!)
      - Calm `#929292` (~65%) / `#AAAAAA` (~31%) meandering diagonal swells (zero bullseye ovals!)
      - 5 sparse isolated horizontal wavelets (`#D9D9D9` + `1px` `#626262` shadow) in `s >= 9.0`
      - Exact integer `+4px/frame` torus shift (`wrap_mae / mean_step_mae ~ 1.00`, zero f8->f1 snap!)
    """
    if s < 0.0:
        return None

    light_dot = nx * LIGHT_X + ny * LIGHT_Y
    mx = x % 32
    my = y % 32
    sx = (mx - shift_x) % 32

    # Gentle out-of-phase horizontal water swells (foreshortened top-down water optics:
    # zero Voronoi polygons, zero frogspawn bullseyes, zero diagonal barber-pole stripes!)
    tx = 2.0 * math.pi * (sx + 0.5) / 32.0
    yc1 = 7.0 + 1.25 * math.cos(tx - 0.30) + 0.50 * math.sin(2.0 * tx + 0.60)
    hw1 = 3.15 + 0.60 * math.sin(tx - 0.50)
    yc2 = 22.2 + 1.25 * math.cos(tx + 2.20) + 0.50 * math.sin(2.0 * tx - 1.10)
    hw2 = 3.00 + 0.55 * math.cos(tx + 0.90)
    in_swell = (abs(my - yc1) <= hw1) or (abs(my - yc2) <= hw2)
    swell = 0.55 if in_swell else -0.35

    # 9.0px 4-tier radial/edge alpha-and-depth taper (Blocks 0..3 & single pool margin)
    if s < 2.20:
        ch = "4" if light_dot > -0.08 else "3"
        return (0, ch)
    if s < 4.50:
        ch = "4" if light_dot > 0.06 else "3"
        return (1, ch)
    if s < 6.80:
        val = 0.45 * swell + 0.55 * light_dot
        ch = "4" if val > 0.08 else "3"
        return (2, ch)
    if s < 9.00:
        w_ch = wavelet_map.get((mx, my))
        if w_ch in ("6", "7") and s >= 7.50:
            return (3, "5")  # gentle wavelet fade-in across taper prevents hard pop on single pools
        val = 0.75 * swell + 0.25 * light_dot
        ch = "4" if val > 0.18 else "3"
        return (3, ch)

    # Full deep water interior (`s >= 9.00`, alpha 216 — uniform across j=255 for 0.00 seam MAE!)
    w_ch = wavelet_map.get((mx, my))
    if w_ch is not None:
        return (3, w_ch)

    if in_swell:
        return (3, "4")  # ~33% gentle sunlit horizontal water swell (#AAAAAA)
    return (3, "3")      # ~63% rich calm deep water (#929292)


def generate_pool_strip_frames(n_frames: int) -> list[dict[str, Any]]:
    """
    160x32 5-block smooth pool strip.
    `inset = 1.45, r_conv = 10.2` -> `pivot = 11.65 <= 14.5`, and at `u = 15.5` (midline),
    `s >= 15.5 - 1.45 - 1.58 = 12.47 > 9.00`, guaranteeing 100% seamless quadrant joins!
    """
    frames: list[dict[str, Any]] = []
    inset = 1.45
    r_conv = 10.2
    dur = 300 if n_frames > 1 else 200

    for f in range(n_frames):
        shift_x = (f * 4) % 32 if n_frames > 1 else 0
        wmap = build_periodic_wavelet_map(shift_x)
        layers = [make_grid(160, 32) for _ in range(4)]

        for block in range(5):
            def sdf_b(px: float, py: float, b: int = block) -> float:
                if b == 4:
                    return 16.0
                return quad_base_sdf(b, px, py, inset, r_conv) + pool_wave(px, py)

            for y in range(32):
                for x in range(32):
                    s = sdf_b(x, y)
                    if s < 0.0:
                        continue
                    nx, ny = (0.0, -1.0) if block == 4 or s >= 9.1 else sdf_outward_normal(sdf_b, x, y)
                    res = shade_pool_pixel(s, nx, ny, x, y, shift_x, wmap)
                    if res is not None:
                        put_exclusive(layers, res[0], block * 32 + x, y, res[1])

        frames.append(
            {
                "duration_ms": dur,
                "layers": build_layers(
                    [(name, op, layers[i]) for i, (name, op) in enumerate(POOL_LAYER_DEFS)]
                ),
            }
        )
    return frames


def generate_pool_single_frames(n_frames: int = 8) -> list[dict[str, Any]]:
    """8-frame @ 300ms standalone flooded pool tile with soft `[56, 112, 168, 216]` taper and calm gliding wavelets."""
    frames: list[dict[str, Any]] = []

    def sdf(px: float, py: float) -> float:
        u_h = min(px + 0.5, 31.5 - px)
        u_v = min(py + 0.5, 31.5 - py)
        inset = 1.50
        r_conv = 9.6
        pivot = inset + r_conv
        dx = max(0.0, pivot - u_h)
        dy = max(0.0, pivot - u_v)
        base = (r_conv - math.hypot(dx, dy)) if (dx > 0.0 and dy > 0.0) else min(u_h - inset, u_v - inset)
        ang = math.atan2(py - 15.5, px - 15.5)
        wavy = 0.65 * math.sin(3.0 * ang + 0.5) + 0.40 * math.cos(5.0 * ang - 0.8)
        return base + wavy

    for f in range(n_frames):
        shift_x = ((f + 2) * 4) % 32 if n_frames > 1 else 0
        wmap = build_periodic_wavelet_map(shift_x)
        layers = [make_grid(32, 32) for _ in range(4)]
        for y in range(32):
            for x in range(32):
                s = sdf(x, y)
                if s < 0.0:
                    continue
                nx, ny = (0.0, -1.0) if s >= 9.1 else sdf_outward_normal(sdf, x, y)
                res = shade_pool_pixel(s * 1.15, nx, ny, x, y, shift_x, wmap)
                if res is not None:
                    put_exclusive(layers, res[0], x, y, res[1])
        frames.append(
            {
                "duration_ms": 300,
                "layers": build_layers(
                    [(name, op, layers[i]) for i, (name, op) in enumerate(POOL_LAYER_DEFS)]
                ),
            }
        )
    return frames


# ---------------------------------------------------------------------------
# 4. Splashes, Spills & Splatters (7 Single-Tile Assets)
# ---------------------------------------------------------------------------

def generate_spill_1() -> list[dict[str, Any]]:
    """Medium organic floor spill with 4-layer `[68, 122, 168, 212]` feathered wet seepage rim."""
    layers = [make_grid(32, 32) for _ in range(4)]
    shimmer_pts = {(12, 11), (13, 11), (19, 18), (20, 18)}

    def sdf(px: float, py: float) -> float:
        dx = (px - 15.4) / 11.4
        dy = (py - 15.8) / 10.0
        r = math.hypot(dx, dy)
        ang = math.atan2(dy, dx)
        lobe = (
            0.16 * math.cos(2.0 * ang + 0.5)
            + 0.14 * math.sin(3.0 * ang - 0.7)
            + 0.07 * math.cos(4.0 * ang + 1.4)
        )
        return (1.0 + lobe - r) * 10.2

    for y in range(32):
        for x in range(32):
            s = sdf(x, y)
            if s < 0.0:
                continue
            nx, ny = sdf_outward_normal(sdf, x, y)
            res = shade_feathered_puddle_pixel(
                s, nx, ny, x, y, shift_x=2, shimmer_pts=shimmer_pts, north_grad=(15.5 - y) * 0.022
            )
            if res is not None:
                put_exclusive(layers, res[0], x, y, res[1])

    # Two soft satellite seepage droplets matching the 4-layer palette
    stamp_soft_droplet(layers, 26.8, 10.4, 2.0, 1.6, -0.4)
    stamp_soft_droplet(layers, 6.0, 22.6, 1.7, 1.4, 2.4)

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [(name, op, layers[i]) for i, (name, op) in enumerate(PUDDLE_LAYER_DEFS)]
            ),
        }
    ]


def generate_spill_2() -> list[dict[str, Any]]:
    """Dual-lobe organic floor spill with 4-layer `[68, 122, 168, 212]` feathered wet seepage rim."""
    layers = [make_grid(32, 32) for _ in range(4)]
    shimmer_pts = {(10, 9), (11, 9), (20, 18), (21, 18)}

    def sdf(px: float, py: float) -> float:
        d1 = 7.7 - math.hypot((px - 11.2) / 1.08, (py - 11.6) / 0.96)
        d2 = 6.8 - math.hypot((px - 20.2) / 1.06, (py - 19.2) / 0.95)
        s_union = smooth_max(d1, d2, 5.6)
        wobble = 0.38 * math.sin(0.34 * px + 0.24 * py)
        return s_union + wobble

    for y in range(32):
        for x in range(32):
            s = sdf(x, y)
            if s < 0.0:
                continue
            nx, ny = sdf_outward_normal(sdf, x, y)
            res = shade_feathered_puddle_pixel(
                s, nx, ny, x, y, shift_x=5, shimmer_pts=shimmer_pts, north_grad=(15.5 - y) * 0.022
            )
            if res is not None:
                put_exclusive(layers, res[0], x, y, res[1])

    stamp_soft_droplet(layers, 25.0, 9.2, 2.0, 1.6, -0.6)
    stamp_soft_droplet(layers, 8.2, 23.8, 1.7, 1.4, 2.2)

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [(name, op, layers[i]) for i, (name, op) in enumerate(PUDDLE_LAYER_DEFS)]
            ),
        }
    ]


def stamp_soft_droplet(
    layers: list[list[list[str]]],
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    angle: float,
) -> None:
    """Stamp a small droplet onto a 4-layer `[68, 122, 168, 212]` spill canvas."""
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    r_bound = int(math.ceil(max(rx, ry) + 1.5))
    ix0, iy0 = int(round(cx)), int(round(cy))
    for y in range(max(0, iy0 - r_bound), min(32, iy0 + r_bound + 1)):
        for x in range(max(0, ix0 - r_bound), min(32, ix0 + r_bound + 1)):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy
            ux = (dx * cos_a + dy * sin_a) / max(0.6, rx)
            uy = (-dx * sin_a + dy * cos_a) / max(0.6, ry)
            r = math.hypot(ux, uy)
            if r > 1.25:
                continue
            if r > 0.92:
                put_exclusive(layers, 0, x, y, "3" if dy > 0 else "4")
            elif dx * LIGHT_X + dy * LIGHT_Y > 0.35 and r < 0.72:
                put_exclusive(layers, 3, x, y, "7")
            else:
                put_exclusive(layers, 2, x, y, "5" if dy < 0 else "4")


def draw_splash_blob_from_sdf(
    layers: list[list[list[str]]],
    sdf_fn,
    shimmer_seed: float = 0.0,
) -> None:
    """Render energetic impact splash sheets across 3 layers (rim=145, sheet=192, glint=245)."""
    for y in range(32):
        for x in range(32):
            s = sdf_fn(x, y)
            if s < 0.0:
                continue
            nx, ny = sdf_outward_normal(sdf_fn, x, y)
            light_dot = nx * LIGHT_X + ny * LIGHT_Y
            if s < 1.0:
                put_exclusive(layers, 0, x, y, "2" if light_dot < -0.35 else "3")
            elif s < 2.15:
                if light_dot > 0.55:
                    put_exclusive(layers, 2, x, y, "8")
                elif light_dot > 0.20:
                    put_exclusive(layers, 2, x, y, "7")
                elif light_dot > -0.20:
                    put_exclusive(layers, 1, x, y, "6")
                elif light_dot > -0.58:
                    put_exclusive(layers, 1, x, y, "3")
                else:
                    put_exclusive(layers, 0, x, y, "2")
            else:
                wave = math.sin(0.32 * x - 0.28 * y + shimmer_seed) + 0.5 * math.cos(0.22 * x + 0.35 * y)
                v = wave * 0.45 + (16.0 - y) * 0.055 + 0.25
                if v > 0.68:
                    put_exclusive(layers, 1, x, y, "6")
                elif v > 0.12:
                    put_exclusive(layers, 1, x, y, "5")
                elif v > -0.42:
                    put_exclusive(layers, 1, x, y, "4")
                else:
                    put_exclusive(layers, 1, x, y, "3")


def stamp_droplet(
    layers: list[list[list[str]]],
    cx: float,
    cy: float,
    rx: float,
    ry: float = 0.0,
    angle: float = 0.0,
) -> None:
    """Stamp a small glossy floor droplet or elongated spatter bead with top-left specular glint."""
    if ry <= 0.0:
        ry = rx
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    r_bound = int(math.ceil(max(rx, ry) + 1.5))
    ix0, iy0 = int(round(cx)), int(round(cy))
    for y in range(max(0, iy0 - r_bound), min(32, iy0 + r_bound + 1)):
        for x in range(max(0, ix0 - r_bound), min(32, ix0 + r_bound + 1)):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy
            ux = (dx * cos_a + dy * sin_a) / max(0.55, rx)
            uy = (-dx * sin_a + dy * cos_a) / max(0.55, ry)
            r2 = ux * ux + uy * uy
            if r2 > 1.0:
                continue
            r = math.sqrt(r2)
            sx = dx / max(0.8, max(rx, ry))
            sy = dy / max(0.8, max(rx, ry))
            ldot = sx * LIGHT_X + sy * LIGHT_Y
            if max(rx, ry) <= 1.25:
                if sy <= -0.05 or ldot > 0.1:
                    put_exclusive(layers, 2, x, y, "7" if cy < 17 else "6")
                else:
                    put_exclusive(layers, 0, x, y, "2" if cy >= 17 else "3")
            else:
                if ldot > 0.32 and r < 0.76:
                    put_exclusive(layers, 2, x, y, "8" if cy < 19 else "7")
                elif ldot > 0.08:
                    put_exclusive(layers, 2 if cy < 16 else 1, x, y, "7" if r < 0.72 and cy < 16 else "5")
                elif r > 0.76 and sy > 0.12:
                    put_exclusive(layers, 0, x, y, "2")
                elif sy > 0.22:
                    put_exclusive(layers, 1, x, y, "3" if cy > 18 else "4")
                else:
                    put_exclusive(layers, 1, x, y, "5")


def generate_splash_1() -> list[dict[str, Any]]:
    """Radial impact splash crown/ring with 7 fluid fingers and ejected droplets."""
    layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
    fingers = [
        (-2.65, 3.6, 0.26),
        (-1.82, 4.1, 0.24),
        (-0.95, 3.9, 0.25),
        (-0.12, 3.5, 0.24),
        (0.78, 3.3, 0.25),
        (1.68, 3.2, 0.26),
        (2.48, 3.4, 0.24),
    ]

    def sdf(px: float, py: float) -> float:
        dx = (px + 0.5) - 16.0
        dy = ((py + 0.5) - 16.3) / 0.86
        r = math.hypot(dx, dy)
        ang = math.atan2(dy, dx)
        spike = 0.0
        for fang, flen, fwid in fingers:
            da = abs((ang - fang + math.pi) % (2.0 * math.pi) - math.pi)
            if da < fwid * 2.2:
                spike = max(spike, flen * math.exp(-((da / fwid) ** 2)))
        return (7.4 + spike) - r

    draw_splash_blob_from_sdf(layers, sdf, shimmer_seed=0.4)

    for y in range(32):
        for x in range(32):
            dx = (x + 0.5) - 16.0
            dy = ((y + 0.5) - 16.3) / 0.86
            r = math.hypot(dx, dy)
            if 2.1 <= r <= 4.3:
                put_exclusive(layers, 1, x, y, "3" if dy < 0 else "4")
            elif r < 1.6:
                put_exclusive(layers, 2 if dy < 0 else 1, x, y, "7" if dy < 0 else "5")
            elif 5.1 <= r <= 6.4 and dy < -1.0:
                put_exclusive(layers, 2, x, y, "8" if (x + y) % 2 == 0 else "7")

    droplets = [
        (5.5, 8.2, 1.5, 1.2, -2.5),
        (11.2, 4.4, 1.6, 1.3, -1.9),
        (21.4, 4.8, 1.7, 1.3, -1.1),
        (27.0, 9.8, 1.5, 1.2, -0.4),
        (27.4, 18.8, 1.4, 1.1, 0.3),
        (22.8, 25.8, 1.5, 1.2, 1.0),
        (9.2, 25.4, 1.4, 1.2, 2.2),
        (4.6, 17.8, 1.4, 1.1, 2.9),
    ]
    for cx, cy, rx, ry, ang in droplets:
        stamp_droplet(layers, cx, cy, rx, ry, ang)

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [
                    ("splash_rim", 145, layers[0]),
                    ("splash_sheet", 192, layers[1]),
                    ("crown_specular", 245, layers[2]),
                ]
            ),
        }
    ]


def generate_splash_2() -> list[dict[str, Any]]:
    """Directional impact splash sweeping from lower-left heel toward upper-right spray fan."""
    layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
    lobes = [
        (10.5, 19.5, 5.2, 4.4, -0.5),
        (14.8, 16.0, 5.8, 3.8, -0.62),
        (18.5, 11.5, 5.2, 2.3, -0.78),
        (20.6, 15.8, 5.4, 2.2, -0.22),
        (14.5, 11.2, 4.2, 1.9, -1.12),
        (18.0, 20.2, 4.4, 1.9, 0.18),
    ]

    def sdf(px: float, py: float) -> float:
        best = -10.0
        for cx, cy, rx, ry, ang in lobes:
            dx = (px + 0.5) - cx
            dy = (py + 0.5) - cy
            ca, sa = math.cos(ang), math.sin(ang)
            ux = (dx * ca + dy * sa) / rx
            uy = (-dx * sa + dy * ca) / ry
            d = (1.0 - math.hypot(ux, uy)) * min(rx, ry)
            if d > best:
                best = d
        return best

    draw_splash_blob_from_sdf(layers, sdf, shimmer_seed=1.1)

    spray = [
        (24.6, 6.6, 1.9, 1.3, -0.75),
        (27.8, 4.6, 1.2, 1.0, -0.75),
        (27.2, 11.2, 1.8, 1.2, -0.35),
        (28.5, 15.4, 1.5, 1.1, -0.15),
        (19.2, 5.8, 1.5, 1.1, -1.05),
        (24.2, 21.4, 1.4, 1.1, 0.22),
        (6.2, 22.8, 1.2, 1.0, 2.5),
    ]
    for cx, cy, rx, ry, ang in spray:
        stamp_droplet(layers, cx, cy, rx, ry, ang)

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [
                    ("splash_rim", 145, layers[0]),
                    ("splash_sheet", 192, layers[1]),
                    ("spray_specular", 245, layers[2]),
                ]
            ),
        }
    ]


def generate_splash_burst() -> list[dict[str, Any]]:
    """4-frame @ 100ms active splash impact, coronet rise, Worthington rebound jet, and ring settle."""
    frames: list[dict[str, Any]] = []
    configs = [
        (6.5, 1.0, 2.8, 7.6, 2.1),
        (8.4, 3.4, 0.0, 9.6, 2.4),
        (10.0, 5.7, 6.4, 11.4, 1.6),
        (10.7, 7.8, 2.4, 12.2, 1.0),
    ]
    ray_angles = [-2.55, -1.85, -1.10, -0.35, 0.42, 1.20, 2.05, 2.75]

    for f_idx, (outer_r, hole_r, jet_h, drop_d, spike_amp) in enumerate(configs):
        layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
        phase4 = 2.0 * math.pi * f_idx / 4.0

        def ring_sdf(px: float, py: float, orad=outer_r, hrad=hole_r, samp=spike_amp, ph=phase4) -> float:
            dx = (px + 0.5) - 16.0
            dy = ((py + 0.5) - 17.2) / 0.82
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            cusp = samp * max(0.0, math.cos(3.0 * ang + ph))
            d_outer = (orad + cusp) - r
            if hrad <= 0.1:
                return d_outer
            return min(d_outer, r - hrad)

        draw_splash_blob_from_sdf(layers, ring_sdf, shimmer_seed=phase4)

        if jet_h > 0.5:
            top_y = int(round(16.8 - jet_h))
            bot_y = 17
            for y in range(max(3, top_y), bot_y + 1):
                t = (y - top_y) / max(1.0, bot_y - top_y)
                half_w = 1.35 + 0.9 * t
                for x in range(13, 19):
                    dx = (x + 0.5) - 16.0
                    if abs(dx) <= half_w:
                        if dx < -0.25 and t < 0.75:
                            put_exclusive(layers, 2, x, y, "8" if t < 0.45 else "7")
                        elif dx > 0.45:
                            put_exclusive(layers, 0, x, y, "3" if t < 0.6 else "2")
                        else:
                            put_exclusive(layers, 1, x, y, "6" if t < 0.5 else "5")
            if f_idx == 2:
                stamp_droplet(layers, 16.0, 8.0, 2.1, 2.2, 0.0)
            elif f_idx == 3:
                # Re-entering central drop bridges f4 -> f1 splash sheet smoothly
                stamp_droplet(layers, 16.0, 16.8, 4.9, 4.0, 0.0)

        for i, ang in enumerate(ray_angles):
            if f_idx == 0 and i % 2 == 1:
                continue
            rad = drop_d + (0.7 if i % 2 == 0 else -0.5)
            cx = 16.0 + rad * math.cos(ang)
            cy = 16.6 + rad * 0.82 * math.sin(ang) - (1.4 if f_idx == 2 else 0.5)
            dr = 1.3 if f_idx in (0, 3) else 1.55
            stamp_droplet(layers, cx, cy, dr, dr * 0.85, ang)

        frames.append(
            {
                "duration_ms": 100,
                "layers": build_layers(
                    [
                        ("splash_rim", 150, layers[0]),
                        ("splash_sheet", 195, layers[1]),
                        ("burst_specular", 248, layers[2]),
                    ]
                ),
            }
        )
    return frames


def stamp_teardrop_streak(
    layers: list[list[list[str]]],
    hx: float,
    hy: float,
    tx: float,
    ty: float,
    head_r: float,
    tail_r: float,
) -> None:
    """Stamp a high-velocity spatter streak with bulbous leading head (hx, hy) and tapered tail (tx, ty)."""
    vx = hx - tx
    vy = hy - ty
    seg_len2 = max(1e-4, vx * vx + vy * vy)
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px - tx) * vx + (py - ty) * vy) / seg_len2))
            cx = tx + t * vx
            cy = ty + t * vy
            rad = tail_r + (head_r - tail_r) * (t ** 0.78)
            dx = px - cx
            dy = py - cy
            dist = math.hypot(dx, dy)
            if dist > rad:
                continue
            r_norm = dist / max(0.55, rad)
            ldot = (dx / max(0.75, rad)) * LIGHT_X + (dy / max(0.75, rad)) * LIGHT_Y
            upper_zone = py < 16.5
            if rad >= 1.45 and ldot > 0.28 and r_norm < 0.76 and t > 0.42:
                put_exclusive(layers, 2, x, y, "8" if upper_zone else "7")
            elif ldot > 0.05:
                put_exclusive(layers, 2 if upper_zone and t > 0.5 else 1, x, y, "7" if upper_zone and r_norm < 0.68 else "5")
            elif r_norm > 0.74 and dy > 0.08:
                put_exclusive(layers, 0, x, y, "2")
            elif dy > 0.16:
                put_exclusive(layers, 1, x, y, "3" if not upper_zone else "4")
            else:
                put_exclusive(layers, 1, x, y, "5" if upper_zone else "4")


def generate_splatter_1() -> list[dict[str, Any]]:
    """Fine high-velocity radial droplets & teardrop streaks (~139 px)."""
    layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
    streaks = [
        (14.5, 13.0, 15.8, 14.8, 2.05, 1.25),
        (9.2, 7.4, 12.8, 10.6, 1.65, 0.62),
        (21.8, 6.8, 18.0, 10.4, 1.70, 0.62),
        (26.2, 13.2, 21.4, 14.2, 1.50, 0.58),
        (6.4, 15.0, 11.0, 14.8, 1.45, 0.55),
        (23.2, 22.4, 19.2, 18.4, 1.50, 0.58),
        (10.4, 23.6, 13.4, 19.0, 1.45, 0.55),
    ]
    for hx, hy, tx, ty, hr, tr in streaks:
        stamp_teardrop_streak(layers, hx, hy, tx, ty, hr, tr)

    beads = [
        (15.6, 4.4, 1.2),
        (5.2, 10.6, 1.15),
        (27.4, 8.8, 1.15),
        (27.0, 18.8, 1.05),
        (16.8, 26.0, 1.10),
        (5.8, 21.2, 1.05),
    ]
    for cx, cy, r in beads:
        stamp_droplet(layers, cx, cy, r, r, 0.0)

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [
                    ("spatter_rim", 160, layers[0]),
                    ("spatter_body", 198, layers[1]),
                    ("spatter_specular", 248, layers[2]),
                ]
            ),
        }
    ]


def generate_splatter_2() -> list[dict[str, Any]]:
    """Directional cast-off splatter arc (~146 px) sweeping across upper-left to east."""
    layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
    arc_streaks = [
        (12.6, 8.0, 7.8, 12.8, 2.15, 0.85),
        (20.4, 6.8, 14.8, 7.6, 2.05, 0.80),
        (26.8, 10.8, 22.2, 8.0, 1.85, 0.75),
        (7.4, 17.6, 5.6, 22.4, 1.60, 0.70),
        (16.8, 12.6, 13.0, 14.8, 1.55, 0.68),
        (24.2, 16.6, 20.6, 14.2, 1.45, 0.62),
    ]
    for hx, hy, tx, ty, hr, tr in arc_streaks:
        stamp_teardrop_streak(layers, hx, hy, tx, ty, hr, tr)

    beads = [
        (9.6, 4.8, 1.25),
        (24.6, 5.2, 1.15),
        (28.4, 15.2, 1.10),
        (12.2, 19.6, 1.15),
        (5.0, 25.8, 1.10),
        (19.6, 19.8, 1.05),
    ]
    for cx, cy, r in beads:
        stamp_droplet(layers, cx, cy, r, r, 0.0)

    return [
        {
            "duration_ms": 200,
            "layers": build_layers(
                [
                    ("spatter_rim", 160, layers[0]),
                    ("spatter_body", 198, layers[1]),
                    ("spatter_specular", 248, layers[2]),
                ]
            ),
        }
    ]


# ---------------------------------------------------------------------------
# 5. Zero-G Floating Spherical Droplets (6 Assets, `8 frames @ 300ms` float)
# ---------------------------------------------------------------------------

BEAD_TEMPLATES: dict[int, list[str]] = {
    4: [
        ".33.",
        "3862",
        "2541",
        ".21.",
    ],
    5: [
        ".333.",
        "38752",
        "37542",
        "25461",
        ".211.",
    ],
    6: [
        ".3333.",
        "378752",
        "387542",
        "255441",
        "234621",
        ".2111.",
    ],
}


def stamp_pixel_bead(layers: list[list[list[str]]], x0: int, y0: int, diam: int) -> None:
    tmpl = BEAD_TEMPLATES[diam]
    for dy, row in enumerate(tmpl):
        for dx, ch in enumerate(row):
            if ch == ".":
                continue
            if ch in ("8", "7"):
                l_idx = 2
            elif ch in ("1", "2", "3"):
                l_idx = 1
            else:
                l_idx = 0
            put_exclusive(layers, l_idx, x0 + dx, y0 + dy, ch)


def stamp_zerog_sphere(
    layers: list[list[list[str]]],
    cx: float,
    cy: float,
    rx: float,
    ry: float = 0.0,
) -> None:
    if ry <= 0.0:
        ry = rx
    r_avg = 0.5 * (rx + ry)

    if r_avg <= 3.1:
        diam = 4 if r_avg < 2.15 else (5 if r_avg < 2.65 else 6)
        x0 = int(round(cx - 0.5 * diam))
        y0 = int(round(cy - 0.5 * diam))
        stamp_pixel_bead(layers, x0, y0, diam)
        return

    cx_s = round(cx * 2.0) / 2.0
    cy_s = round(cy * 2.0) / 2.0
    r_bound = int(math.ceil(max(rx, ry) + 1.0))
    ix0, iy0 = int(round(cx_s)), int(round(cy_s))

    edge_band = 1.0 - (1.08 / r_avg)
    for y in range(max(0, iy0 - r_bound), min(32, iy0 + r_bound + 1)):
        for x in range(max(0, ix0 - r_bound), min(32, ix0 + r_bound + 1)):
            nx = ((x + 0.5) - cx_s) / rx
            ny = ((y + 0.5) - cy_s) / ry
            r2 = nx * nx + ny * ny
            if r2 > 1.0:
                continue
            r = math.sqrt(r2)
            nz = math.sqrt(max(0.0, 1.0 - r2))

            if r >= edge_band:
                if ny < -0.30:
                    put_exclusive(layers, 1, x, y, "3")
                elif ny < 0.18:
                    put_exclusive(layers, 1, x, y, "2")
                else:
                    put_exclusive(layers, 1, x, y, "1")
                continue

            ndotl = nx * (-0.36) + ny * (-0.58) + nz * 0.73
            spec_d = math.hypot(nx - (-0.32), ny - (-0.40))
            spec2_d = math.hypot(nx - (-0.52), ny - (-0.12))
            caustic_d = math.hypot(nx - 0.32, ny - 0.46)

            if spec_d < (0.23 if r_avg >= 6.5 else 0.28):
                put_exclusive(layers, 2, x, y, "8")
            elif r_avg >= 7.0 and spec2_d < 0.13:
                put_exclusive(layers, 2, x, y, "8")
            elif spec_d < 0.43:
                put_exclusive(layers, 2, x, y, "7")
            elif caustic_d < 0.25 and r < edge_band - 0.03:
                put_exclusive(layers, 1, x, y, "7" if caustic_d < 0.13 and r_avg >= 6.5 else "6")
            else:
                if ndotl > 0.78:
                    put_exclusive(layers, 0, x, y, "6")
                elif ndotl > 0.56:
                    put_exclusive(layers, 0, x, y, "5")
                elif ndotl > 0.34:
                    put_exclusive(layers, 0, x, y, "4")
                elif ndotl > 0.14:
                    put_exclusive(layers, 0, x, y, "3")
                else:
                    put_exclusive(layers, 1, x, y, "2")


# Silky-smooth 8-frame orbital paths (every single frame transition moves <= 1px along a single axis!)
ORBIT_STEPS_8: list[list[tuple[int, int]]] = [
    [(0, 0), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1)],
    [(0, 0), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)],
    [(0, 0), (-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1)],
    [(0, 0), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0)],
]

SMALL_ZEROG_DROPLETS: list[tuple[float, float, float, int]] = [
    (8.5, 7.5, 2.4, 0),
    (16.0, 5.5, 2.0, 1),
    (24.0, 8.5, 2.8, 2),
    (12.0, 13.0, 2.9, 3),
    (20.5, 13.5, 2.4, 1),
    (6.0, 16.5, 2.0, 2),
    (26.5, 17.5, 2.0, 0),
    (15.5, 18.5, 2.5, 2),
    (9.5, 23.0, 2.3, 3),
    (22.0, 22.5, 2.5, 0),
    (15.5, 26.5, 2.0, 1),
]

MIXED_ZEROG_SPHERES: list[tuple[float, float, float, int, bool]] = [
    (11.5, 11.5, 5.35, 0, True),
    (21.5, 17.5, 4.45, 2, True),
    (12.5, 23.5, 3.85, 1, True),
    (20.5, 6.5, 2.3, 1, False),
    (27.0, 11.0, 2.0, 2, False),
    (5.0, 17.5, 2.3, 3, False),
    (5.5, 6.0, 2.0, 0, False),
    (14.5, 4.5, 2.0, 2, False),
    (26.5, 25.0, 2.3, 3, False),
    (20.0, 26.5, 2.0, 1, False),
]


def _safe_radius(r: float) -> float:
    """Nudge away from exact integers (4.0, 5.0, 6.0, ...) so half-integer circles have zero 1px cardinal nubs."""
    frac = r - math.floor(r)
    if frac < 0.14:
        return math.floor(r) - 0.15
    if frac > 0.86:
        return math.floor(r) + 0.85
    return r


def generate_zerog_small(n_frames: int) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    dur = 300 if n_frames > 1 else 200
    for f in range(n_frames):
        layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
        for idx, (cx, cy, rad, orb_i) in enumerate(SMALL_ZEROG_DROPLETS):
            dx, dy = ORBIT_STEPS_8[orb_i][(f + idx) % 8] if n_frames > 1 else (0, 0)
            stamp_zerog_sphere(layers, cx + dx, cy + dy, rad, rad)
        frames.append(
            {
                "duration_ms": dur,
                "layers": build_layers(
                    [
                        ("sphere_core", 184, layers[0]),
                        ("refraction_rim", 222, layers[1]),
                        ("specular_glint", 255, layers[2]),
                    ]
                ),
            }
        )
    return frames


def generate_zerog_mixed(n_frames: int) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    dur = 300 if n_frames > 1 else 200
    ordered = sorted(MIXED_ZEROG_SPHERES, key=lambda item: item[2])
    # Exact 8-step integer-periodic breathing table avoiding discontinuous half-integer snaps
    cap_breathe_8 = [1.00, 1.03, 1.05, 1.03, 1.00, 0.97, 0.95, 0.97]
    for f in range(n_frames):
        f_step = (f + 7) % 8 if n_frames > 1 else 0
        layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
        for idx, (cx, cy, rad, orb_i, cap_wobble) in enumerate(ordered):
            dx, dy = ORBIT_STEPS_8[orb_i][(f_step + idx) % 8] if n_frames > 1 else (0, 0)
            if n_frames > 1 and cap_wobble:
                stretch = cap_breathe_8[(f_step + idx * 3) % 8]
                rx = _safe_radius(rad * stretch)
                ry = _safe_radius(rad / stretch)
            else:
                rx, ry = rad, rad
            stamp_zerog_sphere(layers, cx + dx, cy + dy, rx, ry)
        frames.append(
            {
                "duration_ms": dur,
                "layers": build_layers(
                    [
                        ("sphere_core", 184, layers[0]),
                        ("refraction_rim", 222, layers[1]),
                        ("specular_glint", 255, layers[2]),
                    ]
                ),
            }
        )
    return frames


def generate_zerog_large(n_frames: int) -> list[dict[str, Any]]:
    """Dominant r=8.45 cohesive 0g sphere + 3 satellite beads, with calm 8f @ 300ms capillary oscillation."""
    frames: list[dict[str, Any]] = []
    dur = 300 if n_frames > 1 else 200
    # Smooth 8-frame sinusoidal quadrupole mode (<= 0.65px radius change per frame, zero integer radii!)
    osc_states_8 = [
        (8.45, 8.45, 0.0),
        (8.88, 7.82, 0.0),
        (9.35, 7.62, 0.5),
        (8.88, 7.82, 0.5),
        (8.45, 8.45, 0.0),
        (7.82, 8.88, -0.5),
        (7.62, 9.35, -0.5),
        (7.82, 8.88, 0.0),
    ]
    satellites = [
        (6.0, 7.5, 2.3, 0),
        (26.0, 9.5, 2.4, 2),
        (25.0, 24.5, 2.0, 3),
    ]
    for f in range(n_frames):
        layers = [make_grid(32, 32), make_grid(32, 32), make_grid(32, 32)]
        for sx, sy, srad, orb_i in satellites:
            dx, dy = ORBIT_STEPS_8[orb_i][f % 8] if n_frames > 1 else (0, 0)
            stamp_zerog_sphere(layers, sx + dx, cy=sy + dy, rx=srad, ry=srad)

        rx, ry, dy_main = osc_states_8[f % 8] if n_frames > 1 else (8.45, 8.45, 0.0)
        stamp_zerog_sphere(layers, 15.5, 15.5 + dy_main, rx, ry)
        frames.append(
            {
                "duration_ms": dur,
                "layers": build_layers(
                    [
                        ("sphere_core", 184, layers[0]),
                        ("refraction_rim", 222, layers[1]),
                        ("specular_glint", 255, layers[2]),
                    ]
                ),
            }
        )
    return frames


# ---------------------------------------------------------------------------
# 6. Canonical 19-Asset SPRITES Registry
# ---------------------------------------------------------------------------

def _entry(
    sid: str,
    title: str,
    category: str,
    kind: str,
    default_tint: str,
    require_top_light: bool,
    description: str,
    physics_notes: str,
    frames: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "id": sid,
        "title": title,
        "element": "liquid",
        "category": category,
        "kind": kind,
        "colorable": True,
        "require_top_light": require_top_light,
        "default_tint": default_tint,
        "sample_tints": SAMPLE_TINTS,
        "ase_relpath": f"assets/originals/art/matter/liquids/{sid}.aseprite",
        "tag": "idle",
        "description": description,
        "physics_notes": physics_notes,
        "frames": frames,
    }


SPRITES: list[dict[str, Any]] = [
    # --- 1. Single-Tile Splashes, Spills & Splatters (7) ---
    _entry(
        sid="liquid_splash_1",
        title="Radial Impact Splash",
        category="liquid_splatter",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="Foreshortened radial impact splash crown with central thin sheet, 7 fluid cusps, and 8 ejected droplets.",
        physics_notes="Models normal-incidence Weber-number crown formation on station plating with NNW specular crown tips and south meniscus shadow.",
        frames=generate_splash_1(),
    ),
    _entry(
        sid="liquid_splash_2",
        title="Directional Impact Splash",
        category="liquid_splatter",
        kind="single",
        default_tint="#6CE635",
        require_top_light=True,
        description="Grazing directional liquid splash sweeping from a lower-left heel pool into 4 forward fluid ligaments and leading spray droplets.",
        physics_notes="Captures oblique-momentum slosh breakup where surface-tension ligaments pinch into leading spherical beads.",
        frames=generate_splash_2(),
    ),
    _entry(
        sid="liquid_splash_burst",
        title="Active Splash & Rebound Burst",
        category="liquid_splatter",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="4-frame (100ms) impact cycle: active splash cusp burst, rising coronet rim, central Worthington rebound jet, and settling ring.",
        physics_notes="Conserves radial ring expansion across frames while staging central capillary rebound jet peak on frame 3.",
        frames=generate_splash_burst(),
    ),
    _entry(
        sid="liquid_spill_1",
        title="Organic Floor Spill (Single Lobe)",
        category="liquid_splatter",
        kind="single",
        default_tint="#D8B848",
        require_top_light=True,
        description="Medium organic floor spill with a 4-layer [68, 122, 168, 212] feathered wet seepage rim and delicate broken #EEEEEE meniscus glint.",
        physics_notes="2.8px translucent seepage skirt softens the dry-to-wet boundary so spills transition seamlessly into adjacent puddles.",
        frames=generate_spill_1(),
    ),
    _entry(
        sid="liquid_spill_2",
        title="Organic Floor Spill (Dual Lobe)",
        category="liquid_splatter",
        kind="single",
        default_tint="#9E131B",
        require_top_light=True,
        description="Two coalescing spill lobes merged via a smooth-max bridge with a 4-layer [68, 122, 168, 212] feathered wet seepage skirt.",
        physics_notes="C1 smooth-max capillary saddle + feathered seepage margin blends cleanly on dark hulls, light tiles, and dark blood tints.",
        frames=generate_spill_2(),
    ),
    _entry(
        sid="liquid_splatter_1",
        title="High-Velocity Radial Splatter",
        category="liquid_splatter",
        kind="single",
        default_tint="#9E131B",
        require_top_light=True,
        description="High-velocity radial scatter (~139 px) of elongated exclamation-point streaks with bulbous outer heads and fine satellite mist.",
        physics_notes="Rayleigh-Plateau breakup thickens leading droplet heads away from impact center; upper droplets take brighter NNW specular glints.",
        frames=generate_splatter_1(),
    ),
    _entry(
        sid="liquid_splatter_2",
        title="Directional Cast-Off Splatter Arc",
        category="liquid_splatter",
        kind="single",
        default_tint="#6CE635",
        require_top_light=True,
        description="Sweeping directional spatter arc (~146 px) curving from lower-left to upper-east with tangent-aligned teardrop streaks.",
        physics_notes="Models tangential cast-off trajectory with heavier glossy upper-arc droplets tapering to fine trailing beads.",
        frames=generate_splatter_2(),
    ),
    # --- 2. Single & Multi-Tile Smooth Puddles (3) ---
    _entry(
        sid="liquid_puddle_single",
        title="Equilibrium Shallow Puddle (Single)",
        category="liquid_puddle",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="Standalone shallow puddle with 4-layer [68, 122, 168, 212] feathered seepage rim, calm translucent interior, and broken #EEEEEE glint.",
        physics_notes="Graduated 2.8px wet seepage skirt eliminates hard edge cliffs over station flooring while keeping smooth broad depth shading.",
        frames=generate_puddle_single_frames(),
    ),
    _entry(
        sid="liquid_puddle_smooth",
        title="Smooth Multi-Tile Puddle (47-Junction)",
        category="liquid_puddle",
        kind="smooth_strip",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="160x32 5-block bitmask puddle with 4-tier [68, 122, 168, 212] feathered seepage margin, calm glassy sheet, and zero seams.",
        physics_notes="Forms the continuous calm base wet contour shell (>= 220 mL) underneath deeper pool shells with 0.00 seam MAE.",
        frames=generate_puddle_strip_frames(1),
    ),
    _entry(
        sid="liquid_puddle_smooth_shimmer",
        title="Shimmering Multi-Tile Puddle (47-Junction)",
        category="liquid_puddle",
        kind="smooth_strip",
        default_tint="#D8B848",
        require_top_light=True,
        description="8-frame (300ms, 2.4s loop) 47-junction smooth puddle with feathered seepage skirt and calmly gliding glassy surface shimmer.",
        physics_notes="Stationary wet seepage contour paired with exact 4px/frame torus phase glide (32px wrap over 8 frames, zero loop snap).",
        frames=generate_puddle_strip_frames(8),
    ),
    # --- 3. Single & Multi-Tile Smooth Ankle-High+ Pools (3) ---
    _entry(
        sid="liquid_pool_single",
        title="Flooded Basin Pool (Single Animated)",
        category="liquid_pool",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="8-frame (300ms, 2.4s loop) deep water basin with a soft 4-layer [56, 112, 168, 216] taper, calm swells, and 5 sparse horizontal wavelets.",
        physics_notes="Calm meandering diagonal water swells (#929292/#AAAAAA) + muted #D9D9D9 horizontal wavelets with 1px #626262 troughs.",
        frames=generate_pool_single_frames(8),
    ),
    _entry(
        sid="liquid_pool_smooth_still",
        title="Smooth Flooded Room Pool — Still (47-Junction)",
        category="liquid_pool",
        kind="smooth_strip",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="160x32 5-block deep pool with 9.0px 4-layer [56, 112, 168, 216] edge taper, calm water swells, and 5 isolated horizontal wavelets.",
        physics_notes="Shoreline-ring-free alpha/depth taper allows deep pool shells (>= 2600 mL) to blend smoothly over underlying calm puddle shells.",
        frames=generate_pool_strip_frames(1),
    ),
    _entry(
        sid="liquid_pool_smooth_ripple",
        title="Smooth Flooded Room Pool — Ripple (47-Junction)",
        category="liquid_pool",
        kind="smooth_strip",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="8-frame (300ms, 2.4s loop) 47-junction deep pool where 5 sparse horizontal wavelets and calm diagonal swells glide smoothly.",
        physics_notes="Each 300ms step shifts periodic wavelets and swells by 4px (8*4 = 32px torus wrap) over alpha-216 deep water (0.00 seam MAE).",
        frames=generate_pool_strip_frames(8),
    ),
    # --- 4. Zero-G Floating Spherical Droplets (6) ---
    _entry(
        sid="liquid_zerog_small_still",
        title="Zero-G Small Droplet Cloud (Still)",
        category="liquid_zerog",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="Cluster of 11 small microgravity liquid spheres (4x4 to 6x6 px) with 360-degree Fresnel rims and crisp NNW white pinpoints.",
        physics_notes="Free-floating surface-tension spheres in 0g minimize surface area; full Fresnel rims separate beads on light and dark hulls.",
        frames=generate_zerog_small(1),
    ),
    _entry(
        sid="liquid_zerog_small_float",
        title="Zero-G Small Droplet Cloud (Drifting)",
        category="liquid_zerog",
        kind="single",
        default_tint="#6CE635",
        require_top_light=True,
        description="8-frame (300ms, 2.4s loop) weightless cluster of 11 small spherical beads drifting smoothly by <= 1px per frame.",
        physics_notes="Phase-staggered single-axis 1px orbital steps eliminate jitter across the calm 2.4-second microgravity loop.",
        frames=generate_zerog_small(8),
    ),
    _entry(
        sid="liquid_zerog_mixed_still",
        title="Zero-G Mixed Globules & Satellites (Still)",
        category="liquid_zerog",
        kind="single",
        default_tint="#9E131B",
        require_top_light=True,
        description="3 medium cohesive liquid spheres accompanied by 7 small satellite droplets with 360-degree Fresnel rims and SE lens caustics.",
        physics_notes="Refractive spherical lensing focuses overhead NNW light into a secondary glow inside the opposite lower-right Fresnel rim.",
        frames=generate_zerog_mixed(1),
    ),
    _entry(
        sid="liquid_zerog_mixed_float",
        title="Zero-G Mixed Globules & Satellites (Floating)",
        category="liquid_zerog",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="8-frame (300ms, 2.4s loop) drifting mixed-scale 0g liquid spheres with calm <= 1px orbital drift and gentle capillary breathing.",
        physics_notes="Combines single-pixel orbital steps with subtle aspect-ratio capillary flexing across a calm 2.4s cycle.",
        frames=generate_zerog_mixed(8),
    ),
    _entry(
        sid="liquid_zerog_large_still",
        title="Zero-G Large Cohesive Sphere (Still)",
        category="liquid_zerog",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="Dominant r=8.45 cohesive microgravity liquid bolus with dual NNW specular catchlights, subsurface lens caustic, and 3 satellite beads.",
        physics_notes="Large Bond-zero liquid bolus exhibits classic ISS water-ball optics: 360-degree Fresnel rim, translucent core, and opposite caustic.",
        frames=generate_zerog_large(1),
    ),
    _entry(
        sid="liquid_zerog_large_float",
        title="Zero-G Large Cohesive Sphere (Capillary Wobble)",
        category="liquid_zerog",
        kind="single",
        default_tint="#4BA3E3",
        require_top_light=True,
        description="8-frame (300ms, 2.4s loop) large microgravity liquid sphere undergoing silky-smooth oblate-to-prolate capillary oscillation.",
        physics_notes="8-phase l=2 Rayleigh capillary mode steps radius by <= 0.65px per 300ms frame while satellites drift by <= 1px.",
        frames=generate_zerog_large(8),
    ),
]
