#!/usr/bin/env python3
"""
Procedural pixel-art specification for Tales from Space — Solid Matter & Soil (`solids`), v2.

v2 Geometric Sharpening Overhaul:
  - `solid_shards_small` & `solid_shards_large`: Exact straight half-plane polygon crystal prisms,
    acute triangular splinters, and 1px-tip daggers with HARD flat planar facets (`#FFFFFF`/`#EEEEEE`
    sunlit NW plane jumping sharply across a longitudinal ridge to flat `#929292`/`#626262` SE plane
    + 1px `#262626` SE lip; zero radial pillow falloff).
  - `solid_sprinkles`: Crisp hard-edged micro-cubes, `3x2` rhomboids, and 2-3px glinting crystal
    grains (`#FFFFFF`/`#EEEEEE` + `#929292`/`#626262` + 1px `#2B2B2B` SE contact pixel).
  - `solid_scattering`: Chiseled straight-edged polyhedral mineral/ore chunks divided into 2-3
    constant-tone flat planes meeting along crisp straight facet edges + `#1D1D1D` base shadow.
  - `solid_pile_small` & `solid_pile_large`: Z-buffered 3D flat-faceted angular pyramidal heaps with
    razor-straight ridge crests, flat planar slopes, granular micro-facets, zigzag polygonal base,
    and sharp angular crystalline chunks spilled across the skirt.
  - `solid_debris_jagged_single` & `solid_debris_jagged_smooth`: 4-sided asymmetric quadrilateral/
    wedge fracture slabs with constant flat planar top faces (`#D9D9D9`/`#C4C4C4`/`#AAAAAA`/`#929292`),
    1px `#EEEEEE` NW bevel, 1px `#626262` SE bevel, `#1D1D1D`/`#262626` angular cracks, and sharp
    rock splinters.
  - `solid_dusting_flour_single` & `solid_dusting_flour_smooth`: Soft high-luma cohesive powder
    drifts with widened 4-tier translucent dust-halo taper (`[48, 104, 172, 255]`).
  - `solid_soil_*`: Preserved clean isotropic clodded soil & unbroken east-west tilled furrows.
"""
from __future__ import annotations

import math
from typing import Any

# Strictly neutral greyscale (`R == G == B`) swatches from `tales-from-space.gpl` ONLY.
# Never use `#0A0A0D` (chroma = 3).
GREY: dict[str, str] = {
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


def make_grid(w: int, h: int = 32) -> list[list[str]]:
    return [["." for _ in range(w)] for _ in range(h)]


def stamp_template(
    grid: list[list[str]],
    x0: int,
    y0: int,
    rows: list[str],
    keep_tokens: set[str] | None = None,
) -> None:
    h = len(grid)
    w = len(grid[0])
    for dy, row in enumerate(rows):
        y = y0 + dy
        if not (0 <= y < h):
            continue
        for dx, ch in enumerate(row):
            x = x0 + dx
            if 0 <= x < w and ch != ".":
                if keep_tokens is None or ch in keep_tokens:
                    grid[y][x] = ch


def prune_lone_pixels(grids: list[list[list[str]]]) -> None:
    """Remove any isolated 1px island (no 8-neighbors across combined layers)."""
    h = len(grids[0])
    w = len(grids[0][0])
    changed = True
    while changed:
        changed = False
        occ = [
            [any(g[y][x] != "." for g in grids) for x in range(w)]
            for y in range(h)
        ]
        for y in range(h):
            for x in range(w):
                if not occ[y][x]:
                    continue
                has_nb = False
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and occ[ny][nx]:
                            has_nb = True
                            break
                    if has_nb:
                        break
                if not has_nb:
                    for g in grids:
                        g[y][x] = "."
                    changed = True


def build_layer(
    name: str,
    grid: list[list[str]],
    opacity: int = 255,
    blend_mode: str = "normal",
) -> dict[str, Any]:
    rows = ["".join(r) for r in grid]
    used = sorted({ch for r in rows for ch in r if ch != "."})
    if not used:
        used = ["A"]
    legend = {ch: GREY[ch] for ch in used}
    return {
        "name": name,
        "opacity": opacity,
        "blend_mode": blend_mode,
        "rows": rows,
        "legend": legend,
    }


def split_by_token_sets(
    master: list[list[str]],
    layer_defs: list[tuple[str, set[str], int]],
) -> list[dict[str, Any]]:
    h = len(master)
    w = len(master[0])
    out: list[dict[str, Any]] = []
    for lname, tokens, opacity in layer_defs:
        g = [
            [master[y][x] if master[y][x] in tokens else "." for x in range(w)]
            for y in range(h)
        ]
        out.append(build_layer(lname, g, opacity=opacity))
    return out


def periodic_delta(a: float, b: float, period: float = 32.0) -> float:
    d = (a - b) % period
    if d > period * 0.5:
        d -= period
    return d


def periodic_wave(x: float, y: float, seed: int = 0) -> float:
    """Isotropic 32x32-periodic multi-harmonic field in [-1, 1]."""
    tau = 2.0 * math.pi / 32.0
    s1 = math.sin(tau * x + 0.7 * seed) * math.cos(tau * y - 0.5 * seed)
    s2 = math.cos(tau * (2 * x + y) + 1.4 * seed)
    s3 = math.sin(tau * (x - 2 * y) + 2.3 * seed)
    s4 = math.cos(tau * (2 * x - 2 * y) + 0.9 * seed)
    return 0.36 * s1 + 0.26 * s2 + 0.24 * s3 + 0.14 * s4


def quadrant_sdf(
    block: int,
    x: int,
    y: int,
    margin: float = 3.8,
    corner_radius: float = 4.4,
) -> tuple[float, bool, bool, float, float]:
    """
    Exact continuous signed distance inside the 5-block 47-junction bitmask footprint:
      block 0: !v and !h  (convex outer corner)
      block 1:  v and !h  (vertical run, inset on W/E)
      block 2: !v and  h  (horizontal run, inset on N/S)
      block 3:  v and  h and !d (concave inner corner notch)
      block 4:  v and  h and  d (full periodic interior)
    """
    u = (x + 0.5) if x < 16 else (31.5 - x)
    w = (y + 0.5) if y < 16 else (31.5 - y)

    if block == 0:
        v, h, d = False, False, False
    elif block == 1:
        v, h, d = True, False, False
    elif block == 2:
        v, h, d = False, True, False
    elif block == 3:
        v, h, d = True, True, False
    else:
        v, h, d = True, True, True

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
        if du > 0.0 and dw > 0.0:
            sdf = corner_radius - math.hypot(du, dw)
        else:
            sdf = min(u - margin, w - margin)

    return sdf, v, h, u, w


def border_ns_weight(
    block: int,
    u: float,
    w: float,
    margin: float,
    corner_radius: float,
) -> float:
    """
    Continuous N/S border normal weight in [0.0, 1.0] across ALL quadrant & tile joins:
      - 1.0 on horizontal borders (Block 2, and Block 3 where u -> 0.5 meeting Block 2!)
      - 0.0 on vertical borders   (Block 1, and Block 3 where w -> 0.5 meeting Block 1!)
      - Smooth transition around Block 0 outer corners and Block 3 concave notches.
    """
    if block == 2:
        return 1.0
    if block == 1:
        return 0.0
    if block == 4:
        return 0.0
    if block == 3:
        # At x=0 or x=31 (u=0.5, w~margin), w/hypot(u,w) ~ 0.99 -> matches Block 2 (1.0)!
        # At y=0 or y=31 (w=0.5, u~margin), w/hypot(u,w) ~ 0.14 -> matches Block 1 (0.0)!
        return w / max(1e-5, math.hypot(u, w))
    # Block 0 convex corner
    du = max(0.0, (margin + corner_radius) - u)
    dw = max(0.0, (margin + corner_radius) - w)
    if du > 0.0 and dw > 0.0:
        return dw / max(1e-5, math.hypot(du, dw))
    return 1.0 if (w - margin) <= (u - margin) else 0.0


# ==============================================================================
# Exact Polygon & 3D Flat-Plane Geometry Helpers (Zero Radial Pillow Shading!)
# ==============================================================================
def point_in_convex_poly(px: float, py: float, verts: list[tuple[float, float]]) -> bool:
    """Exact straight half-plane inclusion test for a convex polygon (CW or CCW)."""
    n = len(verts)
    pos = 0
    neg = 0
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
    """Return barycentric weights (wa, wb, wc) if (px, py) lies inside triangle (a, b, c)."""
    denom = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(denom) < 1e-6:
        return None
    wa = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / denom
    wb = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / denom
    wc = 1.0 - wa - wb
    if wa >= -1e-5 and wb >= -1e-5 and wc >= -1e-5:
        return wa, wb, wc
    return None


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
    """
    Rasterize a straight-edged polygonal crystal/glass/ice splinter with HARD flat planar facets:
      - One longitudinal spine line (spine_start -> spine_end) divides the polygon into:
          * Sunlit NW/top planar facet (`lit_tok`: flat `#FFFFFF` or `#EEEEEE` right to outer edge!)
          * Central 1px specular ridge (`ridge_tok`: `#FFFFFF`)
          * Shaded SE/side planar facet (`shade_tok`: flat `#929292` or `#626262` — crisp jump!)
      - Crisp 1px `edge_tok` (`#262626`/`#444444`) ONLY along the outer SE/bottom silhouette lip,
        leaving acute 1px tips and sunlit NW edges razor-sharp!
    """
    sx0, sy0 = spine_start
    sx1, sy1 = spine_end
    sdx, sdy = sx1 - sx0, sy1 - sy0
    slen = max(1e-5, math.hypot(sdx, sdy))
    # Normal pointing toward SE (+x + +y); ensure consistent sunlit NW vs shaded SE orientation
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
            d_tip0 = math.hypot(px - sx0, py - sy0)
            d_tip1 = math.hypot(px - sx1, py - sy1)
            near_tip = min(d_tip0, d_tip1) < 1.35

            s_out = (y == 31) or (not mask[y + 1][x])
            e_out = (x == 31) or (not mask[y][x + 1])
            n_out = (y == 0) or (not mask[y - 1][x])
            w_out = (x == 0) or (not mask[y][x - 1])

            # Optional 1px dark overlap cut when a new shard crosses atop an older shard
            if cut_shadow_on_overlap and (n_out or w_out) and grid[y][x] != "." and sd > 0.2:
                grid[y][x] = "O"
                continue

            if near_tip and sd <= 0.35:
                # Razor 1px acute crystal tip glint
                grid[y][x] = ridge_tok
            elif sd >= 0.25 and (s_out or e_out) and not near_tip:
                # Crisp 1px SE/bottom fracture shadow lip ONLY on shaded side
                grid[y][x] = edge_tok
            elif -0.45 <= sd <= 0.38:
                # Longitudinal central specular ridge
                grid[y][x] = ridge_tok
            elif sd < -0.45:
                # Flat sunlit NW facet all the way to the outer silhouette edge
                grid[y][x] = lit_tok
            else:
                # Flat shaded SE refraction facet (hard step jump across spine!)
                grid[y][x] = shade_tok


def rasterize_chiseled_chunk(
    grid: list[list[str]],
    apex: tuple[float, float],
    ring: list[tuple[float, float]],
    face_tokens: list[str],
    shadow_south: bool = True,
) -> None:
    """
    Rasterize a chiseled angular mineral/ore polyhedron made of flat triangular planes
    `(apex, ring[i], ring[i+1])` — each plane has ONE constant flat shade (`face_tokens[i]`),
    plus a crisp 1px `#1D1D1D` bottom-SE contact shadow lip!
    """
    occ = [[False for _ in range(32)] for _ in range(32)]
    tok_buf = [["." for _ in range(32)] for _ in range(32)]
    n = len(ring)
    for i in range(n):
        v1 = ring[i]
        v2 = ring[(i + 1) % n]
        ftok = face_tokens[i]
        for y in range(32):
            py = y + 0.5
            for x in range(32):
                px = x + 0.5
                if barycentric_2d(px, py, apex, v1, v2) is not None:
                    occ[y][x] = True
                    tok_buf[y][x] = ftok

    for y in range(32):
        for x in range(32):
            if not occ[y][x]:
                continue
            grid[y][x] = tok_buf[y][x]
            # Crisp 1px bottom-SE floor contact shadow directly under south-east cliff edge
            if shadow_south:
                if y + 1 < 32 and not occ[y + 1][x] and tok_buf[y][x] in ("S", "M", "N"):
                    if grid[y + 1][x] == ".":
                        grid[y + 1][x] = "O"


# ==============================================================================
# 1. solid_sprinkles — Crisp Crystalline Salt / Sugar / Nitrate Grains
# ==============================================================================
def gen_solid_sprinkles() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    # 24 crisp, hard-edged micro-cubes, 3x2 angular rhomboids, and 2-3px glinting crystal specks!
    # Every grain jumps directly from #FFFFFF/#EEEEEE to #929292/#626262 + 1px #2B2B2B SE contact.
    grains: list[tuple[int, int, list[str]]] = [
        # Upper glinting micro-crystals
        (10, 4, ["WE", ".B"]),
        (19, 4, ["W", "M"]),
        (6, 7, [".WW", "EMB"]),
        (14, 6, ["WE", "NB"]),
        (24, 7, ["WE.", ".MB"]),
        # Central-left & central-right crisp cubic/rhomboid pinch
        (9, 10, ["WW.", "ENB"]),
        (14, 10, ["WE", "MB"]),
        (18, 9, [".WW", "ENB"]),
        (23, 11, ["W.", "MB"]),
        (5, 12, ["WE", ".B"]),
        (11, 13, ["WWE", "NMB"]),
        (16, 13, ["WE.", ".NB"]),
        (20, 13, ["WW", "MB"]),
        (26, 13, ["E", "M"]),
        # Lower-mid crystalline scatter
        (7, 16, [".WE", "EMB"]),
        (13, 16, ["WW.", "EMB"]),
        (18, 17, ["WE", "NB"]),
        (23, 16, ["EL.", ".MB"]),
        (9, 19, ["WE", "MB"]),
        (15, 20, [".WE", "NMB"]),
        (21, 20, ["EL", "MB"]),
        # Sparse lower outlier specks
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
# 2. solid_scattering — Chiseled Polyhedral Mineral / Ore Fragments
# ==============================================================================
def gen_solid_scattering() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    # 12 chiseled straight-edged polyhedral mineral chunks: each polygon splits into 3-4
    # completely FLAT planar facets meeting at sharp internal ridge vertices + #1D1D1D base shadow.
    chunks: list[tuple[tuple[float, float], list[tuple[float, float]], list[str]]] = [
        # 1. Upper-left sharp 4-facet angular ore wedge
        ((8.4, 5.6), [(6.2, 5.2), (9.8, 3.8), (11.6, 5.8), (9.4, 7.8), (6.4, 7.2)], ["W", "L", "N", "S", "A"]),
        # 2. Upper-mid-right broad cleaved galena/copper block
        ((19.5, 5.8), [(16.4, 5.0), (20.8, 3.6), (23.6, 5.4), (22.6, 8.2), (17.2, 8.0)], ["E", "L", "N", "S", "A"]),
        # 3. Far-right small angular chip
        ((26.8, 8.6), [(25.2, 8.0), (28.2, 7.4), (28.8, 9.8), (25.8, 10.2)], ["E", "A", "S", "N"]),
        # 4. Mid-left steep tetrahedral flint/slag fragment
        ((6.0, 12.2), [(3.6, 11.8), (6.8, 9.6), (8.8, 12.0), (6.8, 14.6), (4.0, 14.0)], ["W", "C", "S", "M", "L"]),
        # 5. Primary central chiseled polyhedral nugget (5 flat planes meeting at sharp ridge apex)
        ((13.6, 12.4), [(10.4, 11.4), (13.8, 9.4), (17.6, 10.8), (17.8, 14.4), (13.8, 15.6), (10.6, 14.2)], ["W", "E", "A", "S", "M", "C"]),
        # 6. Mid-right angular rhomboid clinker
        ((22.4, 13.0), [(19.6, 12.2), (22.8, 10.6), (25.8, 12.6), (24.6, 15.6), (20.2, 15.0)], ["E", "C", "S", "M", "A"]),
        # 7. Lower-left sharp cleaved chunk
        ((6.8, 18.8), [(4.2, 18.2), (7.4, 16.6), (9.8, 18.6), (8.6, 21.2), (4.8, 20.8)], ["E", "L", "N", "S", "A"]),
        # 8. Lower-center trapezoidal mineral prism
        ((13.4, 19.8), [(11.0, 18.8), (14.6, 17.6), (16.4, 19.8), (14.8, 22.2), (11.2, 21.6)], ["E", "C", "S", "M", "A"]),
        # 9. Lower-mid-right heavy angular block
        ((20.2, 19.6), [(17.6, 18.8), (20.8, 17.2), (23.8, 19.0), (22.8, 22.0), (18.2, 21.8)], ["E", "L", "N", "S", "A"]),
        # 10. Far-right small sharp tetrahedron
        ((26.8, 18.2), [(25.2, 17.4), (28.2, 16.8), (28.6, 19.4), (25.6, 19.8)], ["L", "A", "S", "M"]),
        # 11. Bottom-left flat-faceted chip
        ((8.6, 24.8), [(6.4, 24.2), (9.6, 23.0), (11.2, 25.0), (8.8, 26.8)], ["L", "C", "S", "M"]),
        # 12. Bottom-right angular ore stone
        ((17.8, 25.0), [(15.4, 24.4), (18.6, 23.2), (20.8, 25.0), (18.8, 27.0), (15.8, 26.6)], ["L", "A", "S", "M", "C"]),
    ]
    for apex, ring, ftoks in chunks:
        rasterize_chiseled_chunk(master, apex, ring, ftoks, shadow_south=True)

    # 2 crisp 3px angular companion chips
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
# 3 & 4. Angular Faceted Pyramidal / Crystalline Heaps (`pile_small` & `pile_large`)
# ==============================================================================
def render_faceted_pyramid_heap(
    pyramids: list[tuple[tuple[float, float, float], list[tuple[float, float]]]],
    skirt_chunks: list[tuple[int, int, list[str]]],
    seed: int,
) -> list[dict[str, Any]]:
    """
    Z-buffered 3D flat-faceted polyhedral pyramid heap under overhead-north light:
      each pyramid = ((ax, ay_floor, height), [(vx_0, vy_0), ...])
    Every face `(apex, v_i, v_{i+1})` is an EXACT flat 3D triangle with constant normal,
    meeting neighboring faces along razor-straight chiseled ridge and valley lines!
    """
    master = make_grid(32, 32)
    z_buf = [[-1.0 for _ in range(32)] for _ in range(32)]
    face_id = [[(-1, -1) for _ in range(32)] for _ in range(32)]
    face_shade: dict[tuple[int, int], float] = {}

    # Overhead-north-west directional light separating all 6 flat pyramid facets cleanly!
    lx, ly, lz = -0.26, -0.66, 0.70

    for p_idx, ((ax, ay_f, height), ring) in enumerate(pyramids):
        # Oblique top-down projection (~55 deg camera): apex shifts north by 0.34*height so
        # north sunlit facets AND south/east/west facets all remain cleanly visible!
        apex_scr = (ax, ay_f - 0.34 * height)
        n = len(ring)
        for i in range(n):
            v1 = ring[i]
            v2 = ring[(i + 1) % n]
            u1 = (v1[0] - ax, v1[1] - ay_f, -height)
            u2 = (v2[0] - ax, v2[1] - ay_f, -height)
            nx = u1[1] * u2[2] - u1[2] * u2[1]
            ny = u1[2] * u2[0] - u1[0] * u2[2]
            nz = u1[0] * u2[1] - u1[1] * u2[0]
            if nz < 0.0:
                nx, ny, nz = -nx, -ny, -nz
            nlen = max(1e-5, math.sqrt(nx * nx + ny * ny + nz * nz))
            nx, ny, nz = nx / nlen, ny / nlen, nz / nlen
            face_shade[(p_idx, i)] = nx * lx + ny * ly + nz * lz

            for y in range(32):
                py = y + 0.5
                for x in range(32):
                    px = x + 0.5
                    bary = barycentric_2d(px, py, apex_scr, v1, v2)
                    if bary is None:
                        continue
                    wa, _, _ = bary
                    # True 3D elevation z = wa * height (higher pyramid wins cleanly along linear valley seams!)
                    depth = wa * height + 0.04 * py
                    if depth > z_buf[y][x]:
                        z_buf[y][x] = depth
                        face_id[y][x] = (p_idx, i)

    # Map each flat face normal to a discrete flat palette step, plus crisp ridge glints
    # and sparse 2px angular crystal/grain micro-facets so slopes read as granular/crystalline!
    tone_steps = ["S", "M", "N", "A", "C", "L", "E", "W"]

    def quantize_face(ndotl: float) -> int:
        if ndotl >= 0.78:
            return 6  # E
        elif ndotl >= 0.62:
            return 5  # L
        elif ndotl >= 0.46:
            return 4  # C
        elif ndotl >= 0.30:
            return 3  # A
        elif ndotl >= 0.14:
            return 2  # N
        elif ndotl >= -0.02:
            return 1  # M
        else:
            return 0  # S

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

            # South base zigzag contact edge
            if s_fid == (-1, -1) and n_fid != (-1, -1):
                master[y][x] = "D" if idx <= 2 else "S"
                continue

            # Crisp 1px bright ridge spine where a sunlit face meets a darker adjacent face!
            ridge_boost = False
            for nb in (e_fid, s_fid, w_fid):
                if nb != (-1, -1) and nb != fid:
                    if nb[0] == fid[0] and ndotl > face_shade[nb] + 0.14 and ndotl > 0.10:
                        ridge_boost = True
                    elif nb[0] != fid[0] and ndotl < face_shade[nb] - 0.10:
                        # Crisp valley crease between intersecting pyramids
                        idx = max(0, idx - 1)
            if ridge_boost:
                idx = min(7, idx + 1)
            else:
                # Crisp 2x1 angular crystalline/granular facet glint on slopes (zero blur!)
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


def gen_solid_pile_small() -> list[dict[str, Any]]:
    # Sharp 6-facet central angular pyramid + 2 crisp flanking crystalline/granular spurs.
    # Note: apex_scr_y = ay_f - 0.34*H sits well inside [y_north..y_south] so all 6 flat faces show!
    pyramids = [
        (
            (15.4, 17.2, 8.8),  # apex_scr = (15.4, 14.2)
            [
                (15.2, 9.6),    # N vertex
                (8.6, 12.6),    # NW vertex
                (7.4, 19.2),    # SW vertex
                (15.0, 23.4),   # S vertex
                (22.8, 20.0),   # SE vertex
                (22.2, 13.0),   # NE vertex
            ],
        ),
        (
            (10.0, 19.0, 5.4),  # W-SW angular shoulder pyramid
            [
                (9.6, 14.2),
                (5.2, 17.6),
                (6.6, 22.4),
                (12.6, 23.4),
                (14.6, 19.0),
            ],
        ),
        (
            (20.8, 19.0, 5.0),  # E-SE angular shoulder pyramid
            [
                (20.6, 14.6),
                (16.6, 18.6),
                (18.8, 23.2),
                (24.8, 21.6),
                (24.6, 17.0),
            ],
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
    # Tall chiseled primary peak + sharp NE & W angular ridge peaks + fore-ridge
    pyramids = [
        (
            (13.6, 16.4, 11.2),  # apex_scr = (13.6, 12.6)
            [
                (13.4, 6.8),
                (6.2, 10.6),
                (4.8, 18.8),
                (13.2, 24.2),
                (21.6, 20.6),
                (21.0, 11.2),
            ],
        ),
        (
            (21.8, 18.0, 8.8),  # apex_scr = (21.8, 15.0)
            [
                (21.6, 10.2),
                (15.6, 14.0),
                (16.4, 22.0),
                (23.6, 24.8),
                (28.6, 20.4),
                (27.6, 13.8),
            ],
        ),
        (
            (7.6, 19.2, 7.2),  # apex_scr = (7.6, 16.8)
            [
                (7.4, 12.6),
                (2.4, 16.8),
                (3.4, 22.6),
                (9.8, 25.0),
                (14.0, 20.4),
            ],
        ),
        (
            (16.6, 21.4, 6.2),  # South angular fore-ridge
            [
                (16.2, 15.8),
                (10.6, 20.4),
                (12.6, 26.2),
                (20.0, 26.4),
                (23.0, 21.8),
            ],
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
# 5 & 6. Razor-Sharp Straight-Edged Crystal / Glass Shards (`shards_small` & `shards_large`)
# ==============================================================================
def gen_solid_shards_small() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    # 7 razor-straight polygonal splinters, daggers, and crystal prisms (7-11px long, 1px tips!).
    # Each splits cleanly along a straight spine into flat #FFFFFF/#EEEEEE vs flat #929292/#626262.
    shards = [
        # 1. Upper-left NW->SE long needle dagger (9px long, 1px acute tips)
        ([(4.2, 3.8), (8.2, 5.2), (11.8, 9.8), (6.8, 7.8)], (4.2, 3.8), (11.8, 9.8), "E", "W", "M", "D"),
        # 2. Upper-right steep NE-pointing quartz prism (9px tall)
        ([(22.8, 3.2), (24.4, 6.8), (20.2, 11.4), (19.0, 7.6)], (22.8, 3.2), (20.2, 11.4), "E", "W", "N", "D"),
        # 3. Mid-left acute triangular glass wedge (10px span)
        ([(13.8, 11.4), (11.2, 15.8), (4.6, 15.6)], (4.6, 15.6), (12.8, 13.4), "W", "W", "M", "D"),
        # 4. Mid-right elongated rhomboid crystal blade (10px diagonal)
        ([(16.6, 12.6), (22.2, 13.8), (26.8, 17.8), (20.4, 16.4)], (16.6, 12.6), (26.8, 17.8), "E", "W", "M", "D"),
        # 5. Lower-left steep acute splinter
        ([(8.6, 18.8), (9.8, 22.0), (5.4, 26.6), (4.8, 23.0)], (8.6, 18.8), (5.4, 26.6), "E", "W", "N", "D"),
        # 6. Lower-center sharp lance shard (9px long)
        ([(12.4, 19.6), (16.8, 21.4), (19.8, 26.2), (14.6, 24.0)], (12.4, 19.6), (19.8, 26.2), "E", "W", "M", "D"),
        # 7. Lower-right crisp triangular ice/glass chip
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
    # Asymmetric shattered crystal/glass fracture field (avoids starburst symmetry!):
    # 3 large crossed/angled cleavage blades + 7 distinct acute daggers and triangular splinters.
    shards = [
        # 1. Upper-left sharp diagonal crystal dagger (10px long, separate from center)
        ([(2.4, 3.6), (7.4, 5.2), (11.2, 10.2), (5.6, 8.2)], (2.4, 3.6), (11.2, 10.2), "E", "W", "M", "D"),
        # 2. Upper-mid-right steep NNE quartz prism (11px tall)
        ([(18.8, 2.2), (20.8, 7.4), (16.4, 12.8), (15.0, 7.6)], (18.8, 2.2), (16.4, 12.8), "E", "W", "N", "D"),
        # 3. Upper-far-right acute triangular glass splinter (8px)
        ([(29.4, 5.4), (27.6, 10.2), (22.2, 9.6)], (29.4, 5.4), (22.2, 9.6), "W", "W", "M", "D"),
        # 4. Large central-left broad angled cleavage blade (13px span, WSW->ENE)
        ([(17.4, 11.4), (14.8, 16.4), (3.0, 17.6), (8.8, 12.4)], (3.0, 17.6), (17.4, 11.4), "E", "W", "M", "D"),
        # 5. Overlapping central-right razor crystal spear (13px NW->SE, casts 1px #1D1D1D cut!)
        ([(12.6, 10.8), (19.6, 13.0), (26.4, 18.6), (18.2, 16.4)], (12.6, 10.8), (26.4, 18.6), "E", "W", "N", "D"),
        # 6. Far-right sharp needle splinter
        ([(25.2, 12.2), (30.2, 13.6), (27.4, 16.4)], (30.2, 13.6), (25.2, 12.2), "W", "W", "M", "D"),
        # 7. Lower-left steep dagger shard (separate cluster)
        ([(8.4, 19.6), (9.8, 23.2), (4.2, 28.2), (3.8, 24.0)], (8.4, 19.6), (4.2, 28.2), "E", "W", "N", "D"),
        # 8. Lower-center broad acute triangular glass wedge (11px)
        ([(11.2, 19.8), (20.6, 22.8), (14.4, 27.6)], (11.2, 19.8), (20.2, 23.2), "E", "W", "M", "D"),
        # 9. Lower-right sharp rhomboid splinter
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
# 7 & 8. Fine Cohesive Powder / Flour Dustings (4-Layer Feathered Halo `[48, 104, 172, 255]`)
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
    elif val >= 0.59:
        return "E"
    elif val >= 0.46:
        return "L"
    elif val >= 0.33:
        return "C"
    elif val >= 0.20:
        return "A"
    else:
        return "N"


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
            best = -99.0
            wob = 1.05 * periodic_wave(x, y, seed=5)
            for cx, cy, rx, ry in lobes:
                d = (1.0 - math.hypot((x - cx) / rx, (y - cy) / ry)) * 10.0 + wob
                if d > best:
                    best = d

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


def gen_solid_dusting_flour_smooth() -> list[dict[str, Any]]:
    fringe = make_grid(160, 32)
    halo = make_grid(160, 32)
    apron = make_grid(160, 32)
    core = make_grid(160, 32)

    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                sdf, v, h, u, w = quadrant_sdf(block, x, y, margin=1.8, corner_radius=5.4)
                ns_w = border_ns_weight(block, u, w, margin=1.8, corner_radius=5.4)
                is_ns = ns_w >= 0.70
                wob = 1.15 * periodic_wave(x, y, seed=5)
                d = sdf + wob

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
# 9 & 10. Jagged Fractured Tunnel Rubble (`debris_jagged_single` & `debris_jagged_smooth`)
# ==============================================================================
# Each rock seed uses ONLY 4 sharp asymmetric half-plane normals (quadrilaterals/wedges,
# NEVER 7-gons/circles!) and each slab has ONE CONSTANT FLAT PLANAR FACE TONE!
_QUAD_ANGLES: list[tuple[float, float, float, float]] = [
    (0.18, 1.62, 3.38, 4.88),
    (0.52, 2.15, 3.72, 5.24),
    (0.08, 1.88, 3.12, 4.65),
    (0.36, 1.54, 3.55, 5.05),
]

_RUBBLE_SEEDS: list[tuple[float, float, float, str]] = [
    # (sx, sy, weight_scale, flat_face_token)
    # Mixed-scale angular rock slabs & wedges across the 32x32 torus with balanced
    # neutral tones ("L":#D9D9D9, "C":#C4C4C4, "A":#AAAAAA, "N":#929292) and zero
    # repeating dark stippled craters!
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
    dx = periodic_delta(x, sx, 32.0)
    dy = periodic_delta(y, sy, 32.0)
    angs = _QUAD_ANGLES[idx % len(_QUAD_ANGLES)]
    best = 0.0
    for k, a in enumerate(angs):
        stretch = 1.18 if (k + idx) % 2 == 0 else 0.88
        proj = (dx * math.cos(a) + dy * math.sin(a)) * stretch
        if proj > best:
            best = proj
    return best / scale


def rubble_cell_info(x: int, y: int) -> tuple[int, float]:
    d1, d2 = 999.0, 999.0
    id1 = 0
    for idx, (sx, sy, sc, _) in enumerate(_RUBBLE_SEEDS):
        d = quad_dist_periodic(x + 0.5, y + 0.5, sx, sy, sc, idx)
        if d < d1:
            d2 = d1
            d1 = d
            id1 = idx
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

    # Narrow 1px #262626 angular fracture crack between quadrilateral stone slabs
    if crack < 0.48:
        return "O" if (crack < 0.20 and (cid + x + y) % 4 == 0) else "D"

    # Crisp 1px #EEEEEE NW fracture bevel along north/west edge of flat slab
    if cid_n != cid or crack_n < 0.48:
        return "E" if flat_tok in ("L", "C") else "L"
    if cid_w != cid or crack_w < 0.48:
        return "E" if flat_tok == "L" else "C"

    # Crisp 1px #626262/#444444 SE slab thickness bevel along south/east edge
    if cid_s != cid or crack_s < 0.48:
        return "M" if flat_tok in ("L", "C") else "S"
    if cid_e != cid or crack_e < 0.48:
        return "N" if flat_tok == "L" else "M"

    # 100% CONSTANT FLAT PLANAR TOP FACE (zero radial cobble dome!)
    return flat_tok


def gen_solid_debris_jagged_single() -> list[dict[str, Any]]:
    master = make_grid(32, 32)
    # Sharp straight-edged polygonal patch boundary (6 asymmetric half-planes, NOT an ellipse!)
    patch_verts = [
        (6.5, 4.5),
        (18.5, 3.5),
        (27.5, 8.5),
        (28.0, 20.5),
        (20.5, 26.5),
        (7.5, 25.5),
        (3.5, 16.5),
    ]

    def tri_ang(t: float) -> float:
        p = t % 1.0
        return 1.0 - 4.0 * abs(p - 0.5)

    for y in range(32):
        for x in range(32):
            # Perturb polygon test with sharp piecewise-linear sawtooth fracture notches
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

    # Sharp angular spalled rock splinters scattered around perimeter
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


def gen_solid_debris_jagged_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)

    def tri_32(t: float, freq: int, phase: float) -> float:
        p = (t * freq / 32.0 + phase) % 1.0
        return 1.0 - 4.0 * abs(p - 0.5)

    for block in range(5):
        ox = block * 32
        sub = make_grid(32, 32)
        for y in range(32):
            for x in range(32):
                # Sharp corner_radius=0.8 so outer block corners look fractured, not rounded!
                sdf, v, h, u, w = quadrant_sdf(block, x, y, margin=3.8, corner_radius=0.8)
                ns_w = border_ns_weight(block, u, w, margin=3.8, corner_radius=0.8)
                is_ns = ns_w >= 0.70
                jagged = (
                    1.35 * tri_32(x + y, 4, 0.10)
                    + 0.85 * tri_32(2 * x - y, 3, 0.35)
                    + 0.45 * tri_32(x - 2 * y, 2, 0.62)
                )
                d = sdf + jagged
                if d >= 0.0:
                    if d < 1.05:
                        if is_ns and y < 16:
                            sub[y][x] = "E" if (x % 4 != 0) else "L"
                        elif is_ns and y >= 16:
                            sub[y][x] = "O"
                        else:
                            sub[y][x] = "D" if x >= 16 else "S"
                    elif d < 2.05 and is_ns and y >= 16:
                        sub[y][x] = "M"
                    else:
                        sub[y][x] = rubble_interior_token(x, y)

        # Safe-margin sharp angular rock splinters along exposed borders
        if block in (0, 2):
            stamp_template(sub, 5, 1, ["WE.", ".MD"])
            stamp_template(sub, 21, 1, [".EL", "CMD"])
            stamp_template(sub, 8, 29, ["LC.", ".DO"])
            stamp_template(sub, 22, 29, [".CA", "MDO"])
        if block in (0, 1):
            stamp_template(sub, 1, 6, ["EL", "MD"])
            stamp_template(sub, 1, 21, ["CA", "DO"])
            stamp_template(sub, 29, 8, ["WE", "MD"])
            stamp_template(sub, 29, 22, ["LC", "DO"])

        for y in range(32):
            for x in range(32):
                master[y][ox + x] = sub[y][x]

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
# 11, 12, 13. Soil-Esque Farm Plot Coverings (Preserved Clean Intact from v1!)
# ==============================================================================
_SOIL_CLODS: list[tuple[float, float, float, float, float]] = []
for _i in range(52):
    _cx = ((_i * 0.7548776662) % 1.0) * 32.0
    _cy = ((_i * 0.5698402910) % 1.0) * 32.0
    _rx = 2.05 + (_i % 5) * 0.34
    _ry = 1.90 + ((_i * 3) % 4) * 0.30
    _lift = ((_i * 7) % 5 - 2) * 0.08
    _SOIL_CLODS.append((_cx, _cy, _rx, _ry, _lift))

_SOIL_SPECKS: set[tuple[int, int]] = {
    (5, 4), (6, 4),
    (21, 3), (22, 3),
    (14, 6), (15, 6),
    (12, 9), (13, 9),
    (27, 8), (28, 8),
    (4, 15), (5, 15),
    (18, 16), (19, 16),
    (10, 23), (11, 23),
}


def soil_clod_token(x: int, y: int) -> str:
    best_z = -9.0
    best_ny = 0.0
    best_lift = 0.0
    px, py = x + 0.5, y + 0.5
    for cx, cy, rx, ry, lift in _SOIL_CLODS:
        dx = periodic_delta(px, cx, 32.0) / rx
        dy = periodic_delta(py, cy, 32.0) / ry
        r2 = dx * dx + dy * dy
        if r2 < 1.32:
            z = math.sqrt(max(0.0, 1.32 - r2)) + lift
            if z > best_z:
                best_z = z
                best_ny = dy
                best_lift = lift

    if best_z < 0.34:
        return "S" if (x * 3 + y * 5) % 4 == 0 else "M"

    if (x % 32, y % 32) in _SOIL_SPECKS and best_z > 0.55:
        return "W" if best_ny <= 0.0 else "E"

    illum = 0.53 - 0.33 * best_ny + 0.22 * (best_z - 0.58) + 0.55 * best_lift
    if illum >= 0.80:
        return "E"
    elif illum >= 0.64:
        return "L"
    elif illum >= 0.48:
        return "C"
    elif illum >= 0.32:
        return "A"
    elif illum >= 0.17:
        return "N"
    else:
        return "M"


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
            best = -99.0
            wob = 0.85 * periodic_wave(x, y, seed=9)
            for cx, cy, rx, ry in lobes:
                d = (1.0 - math.hypot((x - cx) / rx, (y - cy) / ry)) * 10.0 + wob
                if d > best:
                    best = d
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


def gen_solid_soil_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)
    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                sdf, v, h, u, w = quadrant_sdf(block, x, y, margin=3.4, corner_radius=4.6)
                ns_w = border_ns_weight(block, u, w, margin=3.4, corner_radius=4.6)
                is_ns = ns_w >= 0.70
                wob = 0.65 * periodic_wave(x, y, seed=9)
                d = sdf + wob
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
    row_idx = y // 8
    ry_i = y % 8
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
    elif lum >= 0.65:
        return "L"
    elif lum >= 0.50:
        return "C"
    elif lum >= 0.35:
        return "A"
    elif lum >= 0.22:
        return "N"
    elif lum >= 0.12:
        return "M"
    else:
        return "S"


def gen_solid_soil_tilled_smooth() -> list[dict[str, Any]]:
    master = make_grid(160, 32)
    for block in range(5):
        ox = block * 32
        for y in range(32):
            for x in range(32):
                sdf, v, h, u, w = quadrant_sdf(block, x, y, margin=3.25, corner_radius=4.0)
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
                        if y < 16:
                            master[y][ox + x] = "L" if (x % 4 != 0) else "C"
                        else:
                            master[y][ox + x] = "M" if (x % 4 != 0) else "S"
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


# ==============================================================================
# Exported `SPRITES` Specification List (13 Required Solid Assets)
# ==============================================================================
SPRITES: list[dict[str, Any]] = [
    {
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
            {"name": "Saltpetre", "label": "Saltpetre", "hex": "#60A584"},
            {"name": "Table Salt / Sugar", "label": "Table Salt / Sugar", "hex": "#FFFFFF"},
            {"name": "Sulfur Grains", "label": "Sulfur Grains", "hex": "#BF8C00"},
            {"name": "Black Powder", "label": "Black Powder", "hex": "#515151"},
        ],
        "description": "25 crisp micro-cubes, 3x2 rhomboids, and 2px glinting crystal specks with hard #FFFFFF/#EEEEEE facets and 1px #2B2B2B SE contact pixels.",
        "physics_notes": "Low-volume discrete particulate (1-5 mL): individual cleaved crystals rest independently with sharp specular corners.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_sprinkles()}],
    },
    {
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
    {
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
    {
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
    {
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
    {
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
    {
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
    {
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
    {
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
    {
        "id": "solid_debris_jagged_smooth",
        "title": "Jagged Tunnel Rubble Carpeting (47-State Smooth)",
        "element": "solid",
        "category": "solid_debris",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "ase_relpath": "assets/originals/art/matter/solids/solid_debris_jagged_smooth.aseprite",
        "tag": "idle",
        "default_tint": "#968471",
        "sample_tints": [
            {"name": "Concrete / Sandstone", "label": "Concrete / Sandstone", "hex": "#968471"},
            {"name": "Mined Basalt Scree", "label": "Mined Basalt Scree", "hex": "#565A63"},
            {"name": "Martian Breccia", "label": "Martian Breccia", "hex": "#A8694A"},
            {"name": "Hull Breach Rubble", "label": "Hull Breach Rubble", "hex": "#777B83"},
        ],
        "description": "160x32 5-block bitmask strip of flat-topped 4-sided fracture slabs, 1px NW/SE bevels, #1D1D1D/#262626 cracks, and splintered borders.",
        "physics_notes": "Continuous mined-tunnel or breach debris bed: flat planar quadrilateral slabs and sharp scree splinters tile seamlessly across neighbors.",
        "frames": [{"duration_ms": 200, "layers": gen_solid_debris_jagged_smooth()}],
    },
    {
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
    {
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
    {
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
]
