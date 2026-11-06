r"""
Shared grid, exclusive multi-layer, seam-safe lone-pixel pruning, broadband Fourier,
Poisson blue-noise, 5-block quadrant SDF, and 4-connected basalt plate helpers for
Tales from Space Terrestrial & Planetary Art specs (`tools/art/terrestrial/specs/`).
"""
from __future__ import annotations

from collections import Counter
from collections.abc import Callable
import math
from pathlib import Path
import sys
from typing import Any

if __package__ and "." in __package__:
    from ..schema_contract import NEUTRAL_GRAYS
else:
    _TERRESTRIAL_DIR = str(Path(__file__).resolve().parents[1])
    if _TERRESTRIAL_DIR not in sys.path:
        sys.path.insert(0, _TERRESTRIAL_DIR)
    from schema_contract import NEUTRAL_GRAYS  # type: ignore[import-not-found]

GRAY: dict[str, str] = dict(NEUTRAL_GRAYS)

LIGHT_X = -0.38
LIGHT_Y = -0.925


# ==============================================================================
# Core Grid, Exclusive Multi-Layer, & Lone-Pixel Helpers
# ==============================================================================
def make_grid(w: int, h: int = 32, fill: str = ".") -> list[list[str]]:
    return [[fill for _ in range(w)] for _ in range(h)]


def put_exclusive(
    layers: list[list[list[str]]],
    layer_idx: int,
    x: int,
    y: int,
    ch: str,
) -> None:
    r"""Assign pixel (x, y) to at most ONE layer so flattened export stays 100% on-palette."""
    h = len(layers[0])
    w = len(layers[0][0])
    if 0 <= x < w and 0 <= y < h:
        for i, g in enumerate(layers):
            g[y][x] = ch if i == layer_idx else "."


def build_layers(
    layer_defs: list[tuple[str, int]],
    grids: list[list[list[str]]],
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for (name, opacity), grid in zip(layer_defs, grids, strict=True):
        rows = ["".join(r) for r in grid]
        used = sorted({ch for r in rows for ch in r if ch != "."})
        if not used:
            used = ["A"]
        legend = {ch: GRAY[ch] for ch in used}
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


def split_by_token_sets(
    master: list[list[str]],
    layer_defs: list[tuple[str, set[str], int]],
) -> list[dict[str, Any]]:
    h = len(master)
    w = len(master[0])
    grids: list[list[list[str]]] = []
    defs: list[tuple[str, int]] = []
    for lname, tokens, opacity in layer_defs:
        g = [
            [master[y][x] if master[y][x] in tokens else "." for x in range(w)]
            for y in range(h)
        ]
        grids.append(g)
        defs.append((lname, opacity))
    return build_layers(defs, grids)


def prune_lone_pixels_per_block(
    grids: list[list[list[str]]],
    block_w: int = 32,
    protect_seams: bool = True,
) -> None:
    r"""
    Prune isolated 1px islands within each 16x16 quadrant of each 32x32 block.
    When `protect_seams=True`, seam pixels `{0, 15, 16, 31}` are bridged inward rather than
    deleted asymmetrically so `alphaMAX == 0` holds across all 47 junctions.
    """
    seam_coords = {0, 15, 16, 31}
    h = len(grids[0])
    total_w = len(grids[0][0])
    n_blocks = total_w // block_w

    for b in range(n_blocks):
        ox = b * block_w
        changed = True
        while changed:
            changed = False
            occ = [
                [any(g[y][ox + x] != "." for g in grids) for x in range(block_w)]
                for y in range(h)
            ]
            for y in range(h):
                for x in range(block_w):
                    if not occ[y][x]:
                        continue
                    qx0 = 0 if x < 16 else 16
                    qy0 = 0 if y < 16 else 16
                    has_quad_nb = False
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if dx == 0 and dy == 0:
                                continue
                            nx, ny = x + dx, y + dy
                            if qx0 <= nx < qx0 + 16 and qy0 <= ny < qy0 + 16 and occ[ny][nx]:
                                has_quad_nb = True
                                break
                        if has_quad_nb:
                            break
                    if not has_quad_nb:
                        if protect_seams and (x in seam_coords or y in seam_coords):
                            ix = x + (1 if x in (0, 16) else (-1 if x in (15, 31) else 0))
                            iy = y + (1 if y in (0, 16) else (-1 if y in (15, 31) else 0))
                            for li, g in enumerate(grids):
                                if g[y][ox + x] != ".":
                                    put_exclusive(grids, li, ox + ix, iy, g[y][ox + x])
                                    break
                            changed = True
                        else:
                            for g in grids:
                                g[y][ox + x] = "."
                            changed = True


# ==============================================================================
# Periodic Math, Broadband Torus Field, & Poisson Blue-Noise Seed Helpers
# ==============================================================================
def periodic_delta(a: float, b: float, period: float = 32.0) -> float:
    d = (a - b) % period
    if d > period * 0.5:
        d -= period
    return d


def sym_cos(t: float, k: int) -> float:
    r"""
    Seam-symmetric harmonic for OUTER BORDER contours (`blocks 0..3`), guaranteeing
    f(31) == f(0) AND f(15) == f(16) along outer shorelines/cliffs/margins.
    """
    return math.cos(2.0 * math.pi * k * (((t % 32.0) + 0.5) / 32.0))


def torus_wave(x: float, y: float, seed: float = 0.0) -> float:
    r"""Asymmetric 32x32-periodic multi-harmonic field in [-1, 1]."""
    tau = 2.0 * math.pi / 32.0
    return (
        0.38 * math.sin(tau * x + 0.8 + seed) * math.cos(tau * y - 0.6 * seed)
        + 0.28 * math.cos(tau * (2.0 * x + y) + 1.7 + 1.1 * seed)
        + 0.22 * math.sin(tau * (x - 2.0 * y) + 2.5 - 0.9 * seed)
        + 0.12 * math.cos(tau * (2.0 * x - 2.0 * y) + 0.4 + seed)
    )


def det_hash(x: int, y: int, seed: int) -> float:
    h = (((x & 0xFFFF) * 374761393) + ((y & 0xFFFF) * 668265263) + (seed * 1442695041)) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF) / float(0x1000000)


def broadband_torus_field(
    k_min: float,
    k_max: float,
    seed: int,
    aniso_x: float = 1.0,
    aniso_y: float = 1.0,
    falloff: float = 0.65,
) -> list[list[float]]:
    r"""
    Zero-mean, unit-std 32x32 periodic scalar field summing ALL 2D Fourier modes in [k_min, k_max]
    with deterministic pseudo-random phases and strictly zero energy below k_min (eliminating
    k=1,2 macro-grid repetition AND k=4 hexagonal crystal lattices).
    """
    modes: list[tuple[int, int, float, float]] = []
    for ky in range(0, 16):
        kx_start = 1 if ky == 0 else -15
        for kx in range(kx_start, 16):
            rk = math.hypot(kx * aniso_x, ky * aniso_y)
            if k_min <= rk <= k_max:
                amp = (1.0 / (rk ** falloff)) * (0.70 + 0.60 * det_hash(kx + 32, ky + 32, seed))
                phase = 2.0 * math.pi * det_hash(kx + 99, ky + 99, seed ^ 0x5A5A)
                modes.append((kx, ky, amp, phase))

    tau = 2.0 * math.pi / 32.0
    raw = [[0.0] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            acc = 0.0
            for kx, ky, amp, phase in modes:
                acc += amp * math.cos(tau * (kx * x + ky * y) + phase)
            raw[y][x] = acc

    mean = sum(sum(r) for r in raw) / 1024.0
    var = sum((raw[y][x] - mean) ** 2 for y in range(32) for x in range(32)) / 1024.0
    std = max(var ** 0.5, 1e-6)
    return [[(raw[y][x] - mean) / std for x in range(32)] for y in range(32)]


def quantile_threshold(vals: list[float], share_above: float) -> float:
    s = sorted(vals)
    idx = max(0, min(len(s) - 1, int(round((1.0 - share_above) * len(s)))))
    return s[idx]


def poisson_seeds_32(
    n_seeds: int,
    aspect_y: float,
    seed_id: int,
    iters: int = 4,
) -> list[tuple[float, float]]:
    r"""Mildly-relaxed blue-noise points on 32x32 torus (iters=4 prevents honeycomb crystallization)."""
    pts: list[tuple[float, float]] = []
    for i in range(n_seeds):
        u = ((i * 0.61803398875 + 0.23 * det_hash(i, 3, seed_id)) % 1.0) * 32.0
        v = ((i * 0.32471795724 + 0.29 * det_hash(i, 9, seed_id)) % 1.0) * 32.0
        pts.append((u, v))

    res = 64
    step = 32.0 / res
    for _ in range(iters):
        acc_dx = [0.0] * n_seeds
        acc_dy = [0.0] * n_seeds
        counts = [0] * n_seeds
        for gy in range(res):
            py = (gy + 0.5) * step
            for gx in range(res):
                px = (gx + 0.5) * step
                best_i = 0
                best_d = 1e9
                for i, (sx, sy) in enumerate(pts):
                    dx = periodic_delta(px, sx, 32.0)
                    dy = periodic_delta(py, sy, 32.0) * aspect_y
                    d = dx * dx + dy * dy
                    if d < best_d:
                        best_d = d
                        best_i = i
                sx, sy = pts[best_i]
                acc_dx[best_i] += periodic_delta(px, sx, 32.0)
                acc_dy[best_i] += periodic_delta(py, sy, 32.0)
                counts[best_i] += 1
        pts = [
            (
                (pts[i][0] + 0.65 * (acc_dx[i] / max(counts[i], 1))) % 32.0,
                (pts[i][1] + 0.65 * (acc_dy[i] / max(counts[i], 1))) % 32.0,
            )
            for i in range(n_seeds)
        ]
    return pts


# ==============================================================================
# Shared 5-Block Smooth-Strip SDF & `tg_basalt` 4-Connected Plate Builder
# ==============================================================================
def quad_base_sdf(block: int, x: float, y: float, inset: float, r_conv: float) -> float:
    u_h = (x + 0.5) if x < 16.0 else (31.5 - x)
    u_v = (y + 0.5) if y < 16.0 else (31.5 - y)
    if block == 4:
        return 24.0
    if block == 1:
        return u_h - inset
    if block == 2:
        return u_v - inset
    if block == 3:
        dh = max(0.0, u_h - 0.5)
        dv = max(0.0, u_v - 0.5)
        return math.hypot(dh, dv) + 0.5 - inset
    pivot = inset + r_conv
    dx = max(0.0, pivot - u_h)
    dy = max(0.0, pivot - u_v)
    if dx > 0.0 and dy > 0.0:
        return r_conv - math.hypot(dx, dy)
    return min(u_h - inset, u_v - inset)


def sdf_outward_normal(
    sdf_fn: Callable[[float, float], float],
    x: float,
    y: float,
) -> tuple[float, float]:
    eps = 0.35
    gx = sdf_fn(x + eps, y) - sdf_fn(x - eps, y)
    gy = sdf_fn(x, y + eps) - sdf_fn(x, y - eps)
    mag = math.hypot(gx, gy)
    if mag < 1e-6:
        return (0.0, -1.0)
    return (-gx / mag, -gy / mag)


def edge_distance_32(x: int, y: int) -> int:
    r"""Pixels from (x, y) to the nearest edge of a `32x32` tile (`0` on the outer ring)."""
    return min(x, y, 31 - x, 31 - y)


def _plate_cells_32(
    seeds: list[tuple[float, float, float, float]],
    warp_amp: float,
    warp_seed: float,
    inner_seeds: list[tuple[float, float, float, float]],
    inner_reach: float,
) -> list[list[int]]:
    r"""
    Warped anisotropic Voronoi cell ids over `seeds`, then `inner_seeds` (ids continue).
    An inner seed's distance grows by `inner_reach / (1 + edge distance)`, so inner cells
    stay off the tile's outer band and only re-cut its interior.
    """
    cid = [[0 for _ in range(32)] for _ in range(32)]
    all_seeds = [(s, False) for s in seeds] + [(s, True) for s in inner_seeds]
    for y in range(32):
        for x in range(32):
            w1 = torus_wave(x, y, warp_seed)
            w2 = torus_wave(x * 2, y * 2, warp_seed + 1.9)
            wx = (x + 0.5 + warp_amp * (0.72 * w1 + 0.28 * w2)) % 32.0
            wy = (
                y
                + 0.5
                + warp_amp
                * (
                    0.72 * torus_wave(x, y, warp_seed + 3.1)
                    + 0.28 * torus_wave(x * 2, y * 2, warp_seed + 5.2)
                )
            ) % 32.0
            edge = edge_distance_32(x, y)
            best_d = 1e9
            best_i = 0
            for idx, ((sx, sy, sc, ang), inner) in enumerate(all_seeds):
                dx = periodic_delta(wx, sx, 32.0)
                dy = periodic_delta(wy, sy, 32.0)
                ca, sa = math.cos(ang), math.sin(ang)
                ux = (dx * ca + dy * sa) * 0.82
                uy = (-dx * sa + dy * ca) * 1.22
                d = math.hypot(ux, uy) / sc
                if inner:
                    d += inner_reach / (1.0 + edge)
                if d < best_d:
                    best_d = d
                    best_i = idx
            cid[y][x] = best_i
    return cid


def build_basalt_plate_32(
    seeds: list[tuple[float, float, float, float]],
    ramp: tuple[str, str, str, str, str],
    warp_amp: float = 1.85,
    warp_seed: float = 1.0,
    pocket_thresh: float = 0.45,
    taper_thresh: float = -0.22,
    lip_thresh: float = 0.08,
    inner_seeds: list[tuple[float, float, float, float]] | None = None,
    inner_reach: float = 6.0,
    edge_keep: int = 4,
) -> list[list[str]]:
    r"""
    Build a `32x32`-periodic stone/ice tile modeled directly on `tgstation` `basalt`
    (`icons/turf/floors.dmi:"basalt"`, `asteroid.dm:177-183`):
      1. Multi-scale asymmetric slabs + strong domain warp + open-ended crack tapering ->
         wandering stepped ledges & branching crevices over broad calm stone (ZERO uniform
         cobblestone/honeycomb pavement!).
      2. Discrete orthogonal boundary detection + 2x2 diagonal elbow completion ->
         100% 4-connected crevices with ZERO missing pixels and ZERO corner-only dots!
      3. Graded `tg_basalt` cushioning (sparse `t5` crest glints -> `t1/t2` 4-connected
         crevice -> `t2/t3` tucked shadow recovery -> `t4` calm flat stone body).
    With `inner_seeds` it builds a flat variant: cells within `edge_keep` px of the tile
    edge are the plain tile's, so the variant's outer pixels match it and it joins any
    neighbor the plain tile joins (`flat_variant_ring_mismatch` checks the result).
    """
    t1_pocket, t2_crev, t3_slope, t4_body, t5_lip = ramp

    cid = _plate_cells_32(seeds, warp_amp, warp_seed, [], 0.0)
    if inner_seeds:
        plain = cid
        cid = _plate_cells_32(seeds, warp_amp, warp_seed, inner_seeds, inner_reach)
        for y in range(32):
            for x in range(32):
                if edge_distance_32(x, y) < edge_keep:
                    cid[y][x] = plain[y][x]

    # Clean 1px boundary spurs so plate contours step cleanly
    for _ in range(2):
        nxt = [row[:] for row in cid]
        for y in range(32):
            for x in range(32):
                c0 = cid[y][x]
                nbs = [
                    cid[(y - 1) % 32][x],
                    cid[(y + 1) % 32][x],
                    cid[y][(x - 1) % 32],
                    cid[y][(x + 1) % 32],
                ]
                if sum(1 for nb in nbs if nb == c0) <= 1:
                    nxt[y][x] = Counter(nbs).most_common(1)[0][0]
        cid = nxt

    # Primary boundary mask across N and W orthogonal neighbors, with crack tapering
    crevice = [[False for _ in range(32)] for _ in range(32)]
    soft_seam = [[False for _ in range(32)] for _ in range(32)]
    horiz_drop = [[False for _ in range(32)] for _ in range(32)]
    for y in range(32):
        yn = (y - 1) % 32
        for x in range(32):
            xw = (x - 1) % 32
            dn = cid[y][x] != cid[yn][x]
            dw = cid[y][x] != cid[y][xw]
            if dn or dw:
                gate = torus_wave(x, y, warp_seed + 4.7)
                if gate >= taper_thresh:
                    crevice[y][x] = True
                    if dn:
                        horiz_drop[y][x] = True
                else:
                    soft_seam[y][x] = True

    # Prune isolated 1px crevice dots left at tapered crack tips (turn into soft_seam)
    for y in range(32):
        for x in range(32):
            if not crevice[y][x]:
                continue
            has_nb = any(
                crevice[(y + dy) % 32][(x + dx) % 32]
                for dy in (-1, 0, 1)
                for dx in (-1, 0, 1)
                if (dx, dy) != (0, 0)
            )
            if not has_nb:
                crevice[y][x] = False
                horiz_drop[y][x] = False
                soft_seam[y][x] = True

    # 2x2 Diagonal Elbow Completion: eliminates EVERY diagonal-only jump
    bridged = True
    while bridged:
        bridged = False
        for y in range(32):
            y1 = (y + 1) % 32
            for x in range(32):
                x1 = (x + 1) % 32
                a = crevice[y][x]
                b = crevice[y][x1]
                c = crevice[y1][x]
                d = crevice[y1][x1]
                if a and d and (not b) and (not c):
                    crevice[y1][x] = True
                    bridged = True
                elif b and c and (not a) and (not d):
                    crevice[y1][x1] = True
                    bridged = True

    # Verify mathematically zero diagonal-only 2x2 gaps remain
    for y in range(32):
        y1 = (y + 1) % 32
        for x in range(32):
            x1 = (x + 1) % 32
            a, b, c, d = crevice[y][x], crevice[y][x1], crevice[y1][x], crevice[y1][x1]
            if (a and d and not b and not c) or (b and c and not a and not d):
                raise RuntimeError("Unbridged diagonal crevice gap detected!")

    tile = make_grid(32, 32, t4_body)
    for y in range(32):
        yn = (y - 1) % 32
        yn2 = (y - 2) % 32
        ys = (y + 1) % 32
        for x in range(32):
            xw = (x - 1) % 32
            w_mod = torus_wave(x, y, warp_seed + 2.3)

            if crevice[y][x]:
                if horiz_drop[y][x] and w_mod > pocket_thresh:
                    tile[y][x] = t1_pocket
                else:
                    tile[y][x] = t2_crev
                continue

            if soft_seam[y][x]:
                tile[y][x] = t3_slope
                continue

            # Sparse +1 step crest glint ONLY on select overhanging horizontal ledges (like tg_basalt `9`)
            if horiz_drop[ys][x] and w_mod > lip_thresh:
                tile[y][x] = t5_lip
                continue

            # 1px SOUTH or EAST of a crevice -> cushioned shadow recovery on tucked lower plate
            if crevice[yn][x] or crevice[y][xw]:
                if horiz_drop[yn][x] and w_mod > 0.32:
                    tile[y][x] = t2_crev
                else:
                    tile[y][x] = t3_slope
                continue

            # 2px SOUTH of a horizontal overhang -> gentle secondary transition into calm plate body
            if horiz_drop[yn2][x] and w_mod > 0.08:
                tile[y][x] = t3_slope
                continue

            # Calm stone body with subtle organic variation
            if cid[y][x] % 2 == 1 and w_mod < -0.22:
                tile[y][x] = t3_slope
            else:
                tile[y][x] = t4_body

    return tile


def flat_variant_ring_mismatch(plain: list[list[str]], variant: list[list[str]], ring: int = 2) -> int:
    r"""Count tokens within `ring` px of the tile edge where a flat variant leaves the plain tile."""
    return sum(
        1
        for y in range(32)
        for x in range(32)
        if edge_distance_32(x, y) < ring and plain[y][x] != variant[y][x]
    )
