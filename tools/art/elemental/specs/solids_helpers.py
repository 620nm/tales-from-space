r"""
Shared neutral-greyscale palette, grid/layer builders, lone-pixel pruners, 2D/3D polygon
and prism rasterizers, 5-block smooth-strip SDFs, and 4-connected basalt-plate helpers
for Tales from Space — Solid Matter & Soil (`tools/art/elemental/specs/`).
"""
from __future__ import annotations

from collections import Counter
from collections.abc import Callable
import math
from typing import Any

# Strictly neutral greyscale (`R == G == B`) swatches from `tales-from-space.gpl` ONLY.
# Never use `#0A0A0D` (chroma = 3).
GRAY: dict[str, str] = {
    "K": "#1B1B1B",  # 27  stripe-dark-1
    "O": "#1D1D1D",  # 29  neutral-1-outline
    "D": "#262626",  # 38  stripe-dark-2
    "B": "#2B2B2B",  # 43  neutral-2
    "S": "#444444",  # 68  neutral-3-wall-face
    "M": "#626262",  # 98  neutral-4
    "N": "#929292",  # 146 neutral-5
    "A": "#AAAAAA",  # 170 neutral-6
    "C": "#C4C4C4",  # 196 neutral-7
    "L": "#D9D9D9",  # 217 neutral-8-highlight
    "E": "#EEEEEE",  # 238 near-white
    "W": "#FFFFFF",  # 255 white-glint
}

LIGHT_X = -0.38
LIGHT_Y = -0.925


def make_grid(w: int, h: int = 32, fill: str = ".") -> list[list[str]]:
    return [[fill for _ in range(w)] for _ in range(h)]


def stamp_template(
    grid: list[list[str]],
    x0: int,
    y0: int,
    rows: list[str],
    keep_tokens: set[str] | None = None,
) -> None:
    h, w = len(grid), len(grid[0])
    for dy, row in enumerate(rows):
        y = y0 + dy
        if not (0 <= y < h):
            continue
        for dx, ch in enumerate(row):
            x = x0 + dx
            if 0 <= x < w and ch != "." and (keep_tokens is None or ch in keep_tokens):
                grid[y][x] = ch


def put_exclusive(
    layers: list[list[list[str]]], layer_idx: int, x: int, y: int, ch: str,
) -> None:
    r"""Assign pixel (x, y) to at most ONE layer so flattened export stays 100% on-palette."""
    h, w = len(layers[0]), len(layers[0][0])
    if 0 <= x < w and 0 <= y < h:
        for i, g in enumerate(layers):
            g[y][x] = ch if i == layer_idx else "."


def prune_lone_pixels(grids: list[list[list[str]]]) -> None:
    r"""Remove any isolated 1px island (no 8-neighbors across combined layers)."""
    h, w = len(grids[0]), len(grids[0][0])
    changed = True
    while changed:
        changed = False
        occ = [[any(g[y][x] != "." for g in grids) for x in range(w)] for y in range(h)]
        for y in range(h):
            for x in range(w):
                if not occ[y][x]:
                    continue
                has_nb = any(
                    0 <= y + dy < h and 0 <= x + dx < w and occ[y + dy][x + dx]
                    for dy in (-1, 0, 1)
                    for dx in (-1, 0, 1)
                    if (dx, dy) != (0, 0)
                )
                if not has_nb:
                    for g in grids:
                        g[y][x] = "."
                    changed = True


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
    h, total_w = len(grids[0]), len(grids[0][0])
    for b in range(total_w // block_w):
        ox = b * block_w
        changed = True
        while changed:
            changed = False
            occ = [[any(g[y][ox + x] != "." for g in grids) for x in range(block_w)] for y in range(h)]
            for y in range(h):
                for x in range(block_w):
                    if not occ[y][x]:
                        continue
                    qx0, qy0 = (0 if x < 16 else 16), (0 if y < 16 else 16)
                    has_quad_nb = any(
                        qx0 <= x + dx < qx0 + 16 and qy0 <= y + dy < qy0 + 16 and occ[y + dy][x + dx]
                        for dy in (-1, 0, 1)
                        for dx in (-1, 0, 1)
                        if (dx, dy) != (0, 0)
                    )
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


def build_layer(
    name: str, grid: list[list[str]], opacity: int = 255, blend_mode: str = "normal",
) -> dict[str, Any]:
    rows = ["".join(r) for r in grid]
    used = sorted({ch for r in rows for ch in r if ch != "."}) or ["A"]
    return {
        "name": name,
        "opacity": opacity,
        "blend_mode": blend_mode,
        "rows": rows,
        "legend": {ch: GRAY[ch] for ch in used},
    }


def split_by_token_sets(
    master: list[list[str]], layer_defs: list[tuple[str, set[str], int]],
) -> list[dict[str, Any]]:
    h, w = len(master), len(master[0])
    return [
        build_layer(
            lname,
            [[master[y][x] if master[y][x] in tokens else "." for x in range(w)] for y in range(h)],
            opacity=opacity,
        )
        for lname, tokens, opacity in layer_defs
    ]


def periodic_delta(a: float, b: float, period: float = 32.0) -> float:
    d = (a - b) % period
    return d - period if d > period * 0.5 else d


def periodic_wave(x: float, y: float, seed: int = 0) -> float:
    r"""Isotropic 32x32-periodic multi-harmonic field in [-1, 1]."""
    tau = 2.0 * math.pi / 32.0
    s1 = math.sin(tau * x + 0.7 * seed) * math.cos(tau * y - 0.5 * seed)
    s2 = math.cos(tau * (2 * x + y) + 1.4 * seed)
    s3 = math.sin(tau * (x - 2 * y) + 2.3 * seed)
    s4 = math.cos(tau * (2 * x - 2 * y) + 0.9 * seed)
    return 0.36 * s1 + 0.26 * s2 + 0.24 * s3 + 0.14 * s4


def sym_cos(t: float, k: int) -> float:
    r"""Seam-symmetric harmonic for outer border contours (`blocks 0..3`)."""
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


def quadrant_sdf(
    block: int, x: int, y: int, margin: float = 3.8, corner_radius: float = 4.4,
) -> tuple[float, bool, bool, float, float]:
    r"""Exact continuous signed distance inside the 5-block 47-junction bitmask footprint."""
    u = (x + 0.5) if x < 16 else (31.5 - x)
    w = (y + 0.5) if y < 16 else (31.5 - y)
    v, h, d = (
        (False, False, False) if block == 0 else
        (True, False, False) if block == 1 else
        (False, True, False) if block == 2 else
        (True, True, False) if block == 3 else
        (True, True, True)
    )
    if v and h and d:
        sdf = 99.0
    elif v and not h:
        sdf = u - margin
    elif not v and h:
        sdf = w - margin
    elif v and h and not d:
        sdf = math.hypot(u, w) - margin
    else:
        du = max(0.0, (margin + corner_radius) - u)
        dw = max(0.0, (margin + corner_radius) - w)
        sdf = (corner_radius - math.hypot(du, dw)) if (du > 0.0 and dw > 0.0) else min(u - margin, w - margin)
    return sdf, v, h, u, w


def border_ns_weight(
    block: int, u: float, w: float, margin: float, corner_radius: float,
) -> float:
    r"""Continuous N/S border normal weight in [0.0, 1.0] across quadrant and tile joins."""
    if block == 2:
        return 1.0
    if block in (1, 4):
        return 0.0
    if block == 3:
        return w / max(1e-5, math.hypot(u, w))
    du = max(0.0, (margin + corner_radius) - u)
    dw = max(0.0, (margin + corner_radius) - w)
    if du > 0.0 and dw > 0.0:
        return dw / max(1e-5, math.hypot(du, dw))
    return 1.0 if (w - margin) <= (u - margin) else 0.0


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
        return math.hypot(max(0.0, u_h - 0.5), max(0.0, u_v - 0.5)) + 0.5 - inset
    pivot = inset + r_conv
    dx, dy = max(0.0, pivot - u_h), max(0.0, pivot - u_v)
    return (r_conv - math.hypot(dx, dy)) if (dx > 0.0 and dy > 0.0) else min(u_h - inset, u_v - inset)


def sdf_outward_normal(
    sdf_fn: Callable[[float, float], float], x: float, y: float,
) -> tuple[float, float]:
    eps = 0.35
    gx = sdf_fn(x + eps, y) - sdf_fn(x - eps, y)
    gy = sdf_fn(x, y + eps) - sdf_fn(x, y - eps)
    mag = math.hypot(gx, gy)
    return (0.0, -1.0) if mag < 1e-6 else (-gx / mag, -gy / mag)


def point_in_convex_poly(px: float, py: float, verts: list[tuple[float, float]]) -> bool:
    r"""Exact straight half-plane inclusion test for a convex polygon (CW or CCW)."""
    n, pos, neg = len(verts), 0, 0
    for i in range(n):
        x1, y1 = verts[i]
        x2, y2 = verts[(i + 1) % n]
        cross = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)
        if cross > 1e-6:
            pos += 1
        elif cross < -1e-6:
            neg += 1
        if pos and neg:
            return False
    return True


def barycentric_2d(
    px: float,
    py: float,
    a: tuple[float, float],
    b: tuple[float, float],
    c: tuple[float, float],
) -> tuple[float, float, float] | None:
    r"""Return barycentric weights `(wa, wb, wc)` if `(px, py)` lies inside triangle `(a, b, c)`."""
    denom = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(denom) < 1e-6:
        return None
    wa = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / denom
    wb = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / denom
    wc = 1.0 - wa - wb
    return (wa, wb, wc) if (wa >= -1e-5 and wb >= -1e-5 and wc >= -1e-5) else None


def rasterize_crystal_shard(
    grid: list[list[str]],
    verts: list[tuple[float, float]],
    spine_start: tuple[float, float],
    spine_end: tuple[float, float],
    lit_tok: str = "E",
    ridge_tok: str = "W",
    shade_tok: str = "N",
    edge_tok: str = "D",
    cut_shadow_on_overlap: bool = True,
) -> None:
    r"""Rasterize a straight-edged polygonal crystal splinter with hard flat planar facets."""
    sx0, sy0 = spine_start
    sx1, sy1 = spine_end
    sdx, sdy = sx1 - sx0, sy1 - sy0
    slen = max(1e-5, math.hypot(sdx, sdy))
    nx, ny = -sdy / slen, sdx / slen
    if nx * 0.65 + ny * 0.76 < 0.0:
        nx, ny = -nx, -ny

    mask = [[False for _ in range(32)] for _ in range(32)]
    s_dist = [[0.0 for _ in range(32)] for _ in range(32)]
    for y in range(32):
        py = y + 0.5
        for x in range(32):
            px = x + 0.5
            if point_in_convex_poly(px, py, verts):
                mask[y][x] = True
                s_dist[y][x] = (px - sx0) * nx + (py - sy0) * ny

    for y in range(32):
        py = y + 0.5
        for x in range(32):
            if not mask[y][x]:
                continue
            px = x + 0.5
            sd = s_dist[y][x]
            near_tip = min(math.hypot(px - sx0, py - sy0), math.hypot(px - sx1, py - sy1)) < 1.35
            s_out = (y == 31) or (not mask[y + 1][x])
            e_out = (x == 31) or (not mask[y][x + 1])
            n_out = (y == 0) or (not mask[y - 1][x])
            w_out = (x == 0) or (not mask[y][x - 1])

            if cut_shadow_on_overlap and (n_out or w_out) and grid[y][x] != "." and sd > 0.2:
                grid[y][x] = "O"
                continue
            if near_tip and sd <= 0.35:
                grid[y][x] = ridge_tok
            elif sd >= 0.25 and (s_out or e_out) and not near_tip:
                grid[y][x] = edge_tok
            elif -0.45 <= sd <= 0.38:
                grid[y][x] = ridge_tok
            elif sd < -0.45:
                grid[y][x] = lit_tok
            else:
                grid[y][x] = shade_tok


def rasterize_chiseled_chunk(
    grid: list[list[str]],
    apex: tuple[float, float],
    ring: list[tuple[float, float]],
    face_tokens: list[str],
    shadow_south: bool = True,
) -> None:
    r"""Rasterize a chiseled angular polyhedron made of flat constant-tone triangular planes."""
    occ = [[False for _ in range(32)] for _ in range(32)]
    tok_buf = [["." for _ in range(32)] for _ in range(32)]
    n = len(ring)
    for i in range(n):
        v1, v2, ftok = ring[i], ring[(i + 1) % n], face_tokens[i]
        for y in range(32):
            py = y + 0.5
            for x in range(32):
                if barycentric_2d(x + 0.5, py, apex, v1, v2) is not None:
                    occ[y][x] = True
                    tok_buf[y][x] = ftok

    for y in range(32):
        for x in range(32):
            if not occ[y][x]:
                continue
            grid[y][x] = tok_buf[y][x]
            if shadow_south and y + 1 < 32 and not occ[y + 1][x] and tok_buf[y][x] in ("S", "M", "N"):
                if grid[y + 1][x] == ".":
                    grid[y + 1][x] = "O"


def render_faceted_pyramid_heap(
    pyramids: list[tuple[tuple[float, float, float], list[tuple[float, float]]]],
    skirt_chunks: list[tuple[int, int, list[str]]],
    seed: int,
) -> list[dict[str, Any]]:
    r"""Z-buffered 3D flat-faceted polyhedral pyramid heap under overhead-north-west light."""
    master = make_grid(32, 32)
    z_buf = [[-1.0 for _ in range(32)] for _ in range(32)]
    face_id = [[(-1, -1) for _ in range(32)] for _ in range(32)]
    face_shade: dict[tuple[int, int], float] = {}
    lx, ly, lz = -0.26, -0.66, 0.70

    for p_idx, ((ax, ay_f, height), ring) in enumerate(pyramids):
        apex_scr = (ax, ay_f - 0.34 * height)
        n = len(ring)
        for i in range(n):
            v1, v2 = ring[i], ring[(i + 1) % n]
            u1 = (v1[0] - ax, v1[1] - ay_f, -height)
            u2 = (v2[0] - ax, v2[1] - ay_f, -height)
            nx = u1[1] * u2[2] - u1[2] * u2[1]
            ny = u1[2] * u2[0] - u1[0] * u2[2]
            nz = u1[0] * u2[1] - u1[1] * u2[0]
            if nz < 0.0:
                nx, ny, nz = -nx, -ny, -nz
            nlen = max(1e-5, math.sqrt(nx * nx + ny * ny + nz * nz))
            face_shade[(p_idx, i)] = (nx * lx + ny * ly + nz * lz) / nlen

            for y in range(32):
                py = y + 0.5
                for x in range(32):
                    bary = barycentric_2d(x + 0.5, py, apex_scr, v1, v2)
                    if bary is not None:
                        depth = bary[0] * height + 0.04 * py
                        if depth > z_buf[y][x]:
                            z_buf[y][x] = depth
                            face_id[y][x] = (p_idx, i)

    tone_steps = ["S", "M", "N", "A", "C", "L", "E", "W"]

    def quantize_face(ndotl: float) -> int:
        if ndotl >= 0.78:
            return 6
        if ndotl >= 0.62:
            return 5
        if ndotl >= 0.46:
            return 4
        if ndotl >= 0.30:
            return 3
        if ndotl >= 0.14:
            return 2
        return 1 if ndotl >= -0.02 else 0

    for y in range(32):
        for x in range(32):
            fid = face_id[y][x]
            if fid == (-1, -1):
                continue
            ndotl = face_shade[fid]
            idx = quantize_face(ndotl)
            n_fid = face_id[y - 1][x] if y > 0 else (-1, -1)
            s_fid = face_id[y + 1][x] if y < 31 else (-1, -1)
            w_fid = face_id[y][x - 1] if x > 0 else (-1, -1)
            e_fid = face_id[y][x + 1] if x < 31 else (-1, -1)

            if s_fid == (-1, -1) and n_fid != (-1, -1):
                master[y][x] = "D" if idx <= 2 else "S"
                continue

            ridge_boost = False
            for nb in (e_fid, s_fid, w_fid):
                if nb != (-1, -1) and nb != fid:
                    if nb[0] == fid[0] and ndotl > face_shade[nb] + 0.14 and ndotl > 0.10:
                        ridge_boost = True
                    elif nb[0] != fid[0] and ndotl < face_shade[nb] - 0.10:
                        idx = max(0, idx - 1)
            if ridge_boost:
                idx = min(7, idx + 1)
            else:
                gx = (x + (y % 2)) // 2
                hgrain = (gx * 13 + y * 23 + seed * 7 + fid[1] * 5) % 11
                if hgrain == 0 and idx >= 2:
                    idx = min(7, idx + 1)
                elif hgrain == 5 and idx <= 5:
                    idx = max(0, idx - 1)
            master[y][x] = tone_steps[idx]

    for sx, sy, tpl in skirt_chunks:
        stamp_template(master, sx, sy, tpl)
    prune_lone_pixels([master])
    return split_by_token_sets(
        master,
        [
            ("skirt_and_shadow_facets", {"O", "D", "B", "S", "M"}, 255),
            ("mid_planar_facets", {"N", "A", "C"}, 255),
            ("sunlit_ridges_and_facets", {"L", "E", "W"}, 255),
        ],
    )


def build_basalt_plate_32(
    seeds: list[tuple[float, float, float, float]],
    ramp: tuple[str, str, str, str, str],
    warp_amp: float = 1.85,
    warp_seed: float = 1.0,
    pocket_thresh: float = 0.45,
    taper_thresh: float = -0.22,
    lip_thresh: float = 0.08,
) -> list[list[str]]:
    r"""Build a `32x32`-periodic stone tile with 4-connected `tg_basalt`-style crevices."""
    t1_pocket, t2_crev, t3_slope, t4_body, t5_lip = ramp
    cid = [[0 for _ in range(32)] for _ in range(32)]
    for y in range(32):
        for x in range(32):
            w1 = torus_wave(x, y, warp_seed)
            w2 = torus_wave(x * 2, y * 2, warp_seed + 1.9)
            wx = (x + 0.5 + warp_amp * (0.72 * w1 + 0.28 * w2)) % 32.0
            wy = (
                y + 0.5
                + warp_amp * (0.72 * torus_wave(x, y, warp_seed + 3.1) + 0.28 * torus_wave(x * 2, y * 2, warp_seed + 5.2))
            ) % 32.0
            best_d, best_i = 1e9, 0
            for idx, (sx, sy, sc, ang) in enumerate(seeds):
                dx, dy = periodic_delta(wx, sx, 32.0), periodic_delta(wy, sy, 32.0)
                ca, sa = math.cos(ang), math.sin(ang)
                d = math.hypot((dx * ca + dy * sa) * 0.82, (-dx * sa + dy * ca) * 1.22) / sc
                if d < best_d:
                    best_d, best_i = d, idx
            cid[y][x] = best_i

    for _ in range(2):
        nxt = [row[:] for row in cid]
        for y in range(32):
            for x in range(32):
                c0 = cid[y][x]
                nbs = [cid[(y - 1) % 32][x], cid[(y + 1) % 32][x], cid[y][(x - 1) % 32], cid[y][(x + 1) % 32]]
                if sum(1 for nb in nbs if nb == c0) <= 1:
                    nxt[y][x] = Counter(nbs).most_common(1)[0][0]
        cid = nxt

    crevice = [[False for _ in range(32)] for _ in range(32)]
    soft_seam = [[False for _ in range(32)] for _ in range(32)]
    horiz_drop = [[False for _ in range(32)] for _ in range(32)]
    for y in range(32):
        yn = (y - 1) % 32
        for x in range(32):
            xw = (x - 1) % 32
            dn, dw = cid[y][x] != cid[yn][x], cid[y][x] != cid[y][xw]
            if dn or dw:
                if torus_wave(x, y, warp_seed + 4.7) >= taper_thresh:
                    crevice[y][x] = True
                    if dn:
                        horiz_drop[y][x] = True
                else:
                    soft_seam[y][x] = True

    for y in range(32):
        for x in range(32):
            if crevice[y][x] and not any(
                crevice[(y + dy) % 32][(x + dx) % 32]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx, dy) != (0, 0)
            ):
                crevice[y][x] = False
                horiz_drop[y][x] = False
                soft_seam[y][x] = True

    bridged = True
    while bridged:
        bridged = False
        for y in range(32):
            y1 = (y + 1) % 32
            for x in range(32):
                x1 = (x + 1) % 32
                a, b, c, d = crevice[y][x], crevice[y][x1], crevice[y1][x], crevice[y1][x1]
                if a and d and (not b) and (not c):
                    crevice[y1][x] = True
                    bridged = True
                elif b and c and (not a) and (not d):
                    crevice[y1][x1] = True
                    bridged = True

    for y in range(32):
        y1 = (y + 1) % 32
        for x in range(32):
            x1 = (x + 1) % 32
            a, b, c, d = crevice[y][x], crevice[y][x1], crevice[y1][x], crevice[y1][x1]
            if (a and d and not b and not c) or (b and c and not a and not d):
                raise RuntimeError("Unbridged diagonal crevice gap detected!")

    tile = make_grid(32, 32, t4_body)
    for y in range(32):
        yn, yn2, ys = (y - 1) % 32, (y - 2) % 32, (y + 1) % 32
        for x in range(32):
            xw = (x - 1) % 32
            w_mod = torus_wave(x, y, warp_seed + 2.3)
            if crevice[y][x]:
                tile[y][x] = t1_pocket if (horiz_drop[y][x] and w_mod > pocket_thresh) else t2_crev
            elif soft_seam[y][x]:
                tile[y][x] = t3_slope
            elif horiz_drop[ys][x] and w_mod > lip_thresh:
                tile[y][x] = t5_lip
            elif crevice[yn][x] or crevice[y][xw]:
                tile[y][x] = t2_crev if (horiz_drop[yn][x] and w_mod > 0.32) else t3_slope
            elif horiz_drop[yn2][x] and w_mod > 0.08:
                tile[y][x] = t3_slope
            else:
                tile[y][x] = t3_slope if (cid[y][x] % 2 == 1 and w_mod < -0.22) else t4_body

    return tile
