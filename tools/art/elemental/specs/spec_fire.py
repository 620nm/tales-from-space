#!/usr/bin/env python3
"""
Oxidized Hydrocarbon & Chemical/Blackbody Fire pixel-art specification (`element: "fire"`).
Pass 5 — Continuous Braided Sweeping Flame Curtains & 8-Frame Rolling Plumes:
  1. Zero Voronoi cobbles AND zero discrete triangle stamps: `fire_gas_*` and `fire_grease_*`
     use continuous, braided, S-sheared multi-harmonic flame curtains (`evaluate_braided_flame_curtains`)
     where broad undulating incandescent sheets erupt into irregular jagged upward-licking tongues.
  2. Soft feathered outer blending rim (`opacity 92..96` outer glow + `138..148` ragged licking fringe)
     on `Blocks 0, 1, 2, 3` of `fire_gas_smooth_*` and `fire_grease_smooth` (and single twins).
  3. Smooth non-strobing 8-frame continuous rolling flame animation (`dy = -(f * 4) % 32` ->
     exact 32px wrap over 8 frames; `8f @ 100ms` for roaring/violent/tintable, `8f @ 200ms` for
     steady campfire & grease pool fires).
"""
from __future__ import annotations

import math
from typing import Any

# ---------------------------------------------------------------------------
# Strict `tales-from-space.gpl` Palette Tables (NO `-reserved` swatches)
# ---------------------------------------------------------------------------

HYDRO_LEGEND: dict[str, str] = {
    # Soot / Char / Smoke Tips
    "K": "#0A0A0D",  # black
    "1": "#1D1D1D",  # neutral-1-outline
    "2": "#2B2B2B",  # neutral-2
    "3": "#444444",  # neutral-3-wall-face
    "4": "#626262",  # neutral-4
    # Deep Ember & Outer Flame Red
    "c": "#3B1D11",  # copper-1-outline
    "r": "#4F011C",  # fire-red-1-outline
    "R": "#8C0522",  # fire-red-2
    "m": "#AD2931",  # fire-red-3
    "M": "#C61326",  # fire-red-4-light
    "F": "#FF441B",  # signal-denied-fault
    # Orange Oxidation Body
    "d": "#6E371E",  # copper-2
    "o": "#A63A16",  # engineering-orange-1
    "p": "#A45729",  # copper-3
    "O": "#D15B1B",  # engineering-orange-2
    "P": "#D4803D",  # copper-4
    "N": "#F08A45",  # engineering-orange-3
    "H": "#F0B06E",  # copper-5-highlight
    "G": "#F2B050",  # gold-4
    # Yellow & White Incandescent Core
    "y": "#D9C21A",  # engineering-yellow-3
    "Y": "#FFD60E",  # signal-caution
    "e": "#F5E04A",  # engineering-yellow-4
    "L": "#FFFF33",  # signal-lamp
    "U": "#FFF3A6",  # engineering-yellow-5-highlight
    "g": "#FFF0C0",  # gold-5-glint
    "E": "#EEEEEE",  # near-white
    "W": "#FFFFFF",  # white-glint
}

# Strictly neutral greyscale (`R == G == B`) for `colorable: True`
TINT_LEGEND: dict[str, str] = {
    "a": "#1B1B1B",  # stripe-dark-1
    "b": "#1D1D1D",  # neutral-1-outline
    "c": "#262626",  # stripe-dark-2
    "d": "#2B2B2B",  # neutral-2
    "e": "#444444",  # neutral-3-wall-face
    "f": "#626262",  # neutral-4
    "g": "#929292",  # neutral-5
    "h": "#AAAAAA",  # neutral-6
    "i": "#C4C4C4",  # neutral-7
    "j": "#D9D9D9",  # neutral-8-highlight
    "k": "#EEEEEE",  # near-white
    "W": "#FFFFFF",  # white-glint
}

TAU_32 = 2.0 * math.pi / 32.0


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


def smoothstep(e0: float, e1: float, x: float) -> float:
    if e1 <= e0:
        return 1.0 if x >= e1 else 0.0
    t = clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def smax(a: float, b: float, k: float = 0.12) -> float:
    """Smooth maximum for braiding continuous flame sheets while keeping sharp tongue clefts."""
    h = clamp(0.5 + 0.5 * (b - a) / max(1e-5, k), 0.0, 1.0)
    return a * (1.0 - h) + b * h + k * h * (1.0 - h)


class LayeredFrameBuilder:
    """
    Partitioned multi-layer grid where each `(x, y)` belongs to at most ONE semantic layer.
    Prevents inter-layer alpha-composite RGB drift so 100% of exported pixels retain exact
    `tales-from-space.gpl` swatches and controlled opacity tiers.
    """

    def __init__(
        self,
        width: int,
        height: int,
        layer_defs: list[tuple[str, int]],
        master_legend: dict[str, str],
    ) -> None:
        self.width = width
        self.height = height
        self.layer_defs = layer_defs
        self.layer_names = {name for name, _ in layer_defs}
        self.master_legend = master_legend
        self.cells: list[list[tuple[str, str] | None]] = [
            [None for _ in range(width)] for _ in range(height)
        ]

    def set_px(self, x: int, y: int, layer: str, token: str) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            assert layer in self.layer_names, f"Unknown layer {layer}"
            assert token in self.master_legend, f"Unknown token {token}"
            self.cells[y][x] = (layer, token)

    def clean_lone_pixels_single(self) -> None:
        """Remove any accidental 1px orphan specks (zero 8-neighbors) on a 32x32 single canvas."""
        assert self.width == 32 and self.height == 32
        changed = True
        while changed:
            changed = False
            for y in range(self.height):
                for x in range(self.width):
                    if self.cells[y][x] is None:
                        continue
                    n8 = 0
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if dx == 0 and dy == 0:
                                continue
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < self.width and 0 <= ny < self.height:
                                if self.cells[ny][nx] is not None:
                                    n8 += 1
                    if n8 == 0:
                        self.cells[y][x] = None
                        changed = True

    def clean_lone_pixels_strip_safe(self) -> None:
        """Clean any isolated 1px specks using exact block wrap topology (`x%32` on B2/3/4, `y%32` on B1/3/4)."""
        assert self.width == 160 and self.height == 32
        changed = True
        while changed:
            changed = False
            for block in range(5):
                bx0 = block * 32
                wrap_x = block in (2, 3, 4)
                wrap_y = block in (1, 3, 4)
                for ly in range(32):
                    for lx in range(32):
                        x = bx0 + lx
                        if self.cells[ly][x] is None:
                            continue
                        n8 = 0
                        for dy in (-1, 0, 1):
                            for dx in (-1, 0, 1):
                                if dx == 0 and dy == 0:
                                    continue
                                nlx = (lx + dx) % 32 if wrap_x else (lx + dx)
                                nly = (ly + dy) % 32 if wrap_y else (ly + dy)
                                if 0 <= nlx < 32 and 0 <= nly < 32:
                                    if self.cells[nly][bx0 + nlx] is not None:
                                        n8 += 1
                        if n8 == 0:
                            self.cells[ly][x] = None
                            changed = True

    def to_frame_dict(self, duration_ms: int) -> dict[str, Any]:
        fallback_tok = next(iter(self.master_legend.keys()))
        layers_out: list[dict[str, Any]] = []
        for lname, opacity in self.layer_defs:
            rows: list[str] = []
            used_tokens: set[str] = set()
            for y in range(self.height):
                chars: list[str] = []
                for x in range(self.width):
                    cell = self.cells[y][x]
                    if cell is not None and cell[0] == lname:
                        chars.append(cell[1])
                        used_tokens.add(cell[1])
                    else:
                        chars.append(".")
                row_s = "".join(chars)
                assert len(row_s) == self.width
                rows.append(row_s)
            if not used_tokens:
                used_tokens.add(fallback_tok)
            legend = {tok: self.master_legend[tok] for tok in sorted(used_tokens)}
            layers_out.append(
                {
                    "name": lname,
                    "ZA_UNUSED": None,
                }
            )
            layers_out[-1] = {
                "name": lname,
                "opacity": opacity,
                "blend_mode": "normal",
                "rows": rows,
                "legend": legend,
            }
        return {"duration_ms": duration_ms, "layers": layers_out}


# ---------------------------------------------------------------------------
# 5-Block 160x32 Quadrant Distance & Inward-Normal Field (`C1`-Seamless)
# ---------------------------------------------------------------------------

def smooth_quad_boundary(block: int, lx: int, ly: int, r_round: float = 14.5) -> tuple[float, float, float]:
    """
    Compute `(D, nx, ny)` for pixel `(lx, ly)` in `0..31 x 0..31` inside `block` (`0..4`).
      block 0 = convex (!v and !h)
      block 1 = vertical (v and !h)
      block 2 = horizontal (!v and h)
      block 3 = concave (v and h and !d)
      block 4 = flat interior (v and h and d)
    """
    is_east = lx >= 16
    is_south = ly >= 16
    du = (31.5 - lx) if is_east else (lx + 0.5)
    dv = (31.5 - ly) if is_south else (ly + 0.5)
    sx = -1.0 if is_east else 1.0
    sy = -1.0 if is_south else 1.0

    if block == 0:
        cx = max(0.0, r_round - du)
        cy = max(0.0, r_round - dv)
        rad = math.hypot(cx, cy)
        d = r_round - rad
        if rad > 1e-6:
            return d, sx * (cx / rad), sy * (cy / rad)
        return d, 0.0, 0.0
    if block == 1:
        return du, sx, 0.0
    if block == 2:
        return dv, 0.0, sy
    if block == 3:
        rad = math.hypot(du, dv)
        return rad, sx * (du / rad), sy * (dv / rad)
    return 16.0, 0.0, 0.0


# ---------------------------------------------------------------------------
# Organic 2D Toroidal Upward-Licking Flame-Tongue Generator (Zero Stripes, Zero Voronoi!)
# ---------------------------------------------------------------------------

def evaluate_braided_flame_curtains(
    px: float,
    py: float,
    frame_idx: int,
    n_frames: int = 8,
    tongue_reach: float = 15.5,
) -> tuple[float, float, float]:
    """
    Synthesize continuous, organic room-scale upward-licking flame tongues & billowing plasma
    fronts across the 32x32 torus (`C^inf` periodic, zero Voronoi cobbles, zero vertical stripes):
      - `py_roll = (py + 4.0 * frame_idx) % 32.0` rolls continuously UPWARD (`-y`) by `4 px/frame`
        (`8 * 4 = 32 px == 0 mod 32` -> seamless 8-frame upward flame surge!).
      - Low-frequency 2D toroidal modes `(kx=1, ky=1)` and `(kx=1, ky=-2)` with strictly integer
        temporal harmonics (`+ph`, `-ph`) warp lateral lean, vertical billow height, and core
        brightness across `(x, y)` so flames form organic, asymmetric wandering tongues across
        `3x3` / `5x5` pools instead of parallel vertical herringbone columns!
      - Circle diffeomorphism `theta = phi - asym * cos(phi)` gives each billow a compact rounded
        underside (`+y`) and a drawn-out upward-tapering pointed flame tongue (`-y`) with bounded
        lateral gradients so inter-tile & intra-tile boundary joins stay effortlessly smooth.
    """
    ph = 2.0 * math.pi * (frame_idx / n_frames)
    py_roll = (py + 4.0 * frame_idx) % 32.0
    reach_scale = clamp(tongue_reach / 16.0, 0.80, 1.12)

    u = TAU_32 * (px - 15.5)
    v = TAU_32 * (py_roll - 15.5)

    # Low-frequency 2D toroidal modes (kx=1, ky=1), (kx=1, ky=-2), and (kx=1, ky=-1)
    m_diag = math.sin(u + v + 0.35 + ph)
    m_skew = math.cos(u - 2.0 * v - 0.65 - ph)
    m_anti = math.cos(u - v + 1.10 - ph)

    # 2D lateral lean/displacement breaks all parallel vertical column alignment across 32x32
    # while keeping |dx_warped/dx| <= 1.55 so boundary gradients stay smooth!
    xa = px + 2.8 * m_diag + 1.9 * m_skew + 1.4 * math.sin(v + 0.4)
    xb = px - 2.7 * m_anti + 2.0 * math.sin(u - 2.0 * v + 0.9 + ph) - 1.4 * math.cos(v - 0.7)

    # Stream A: 2 wandering uneven tongues per 32px modulated in brightness by (1,1) & (1,-2)
    ra_raw = 0.52 + 0.48 * math.cos(TAU_32 * 2.0 * (xa - 15.0) + 0.35 * m_skew)
    amp_a = clamp(0.80 + 0.22 * math.cos(u + v - 0.4 + ph) + 0.16 * math.sin(u - 2.0 * v + 0.8 - ph), 0.46, 1.10)

    # Stream B: 1 broad dominant plume + oblique (2, -1) fork, counter-modulated across the tile
    rb_raw = (
        0.52
        + 0.34 * math.cos(TAU_32 * 1.0 * (xb - 16.5) - 0.35 * m_diag)
        + 0.15 * math.sin(TAU_32 * (2.0 * xb - py_roll) + ph)
    )
    amp_b = clamp(0.80 - 0.20 * math.sin(u + v + 0.9 - ph) + 0.17 * math.cos(u - 2.0 * v - 0.3 + ph), 0.46, 1.10)

    # Stagger vertical billow heights organically across 2D via (kx=1, ky=1) and (kx=1, ky=-2)
    phi_a = v - 0.55 + 1.15 * m_diag + 0.75 * m_skew
    phi_b = v + 2.35 - 1.10 * m_anti + 0.70 * math.sin(u + 2.0 * v - ph)

    best_heat = -1.0
    dom_tip = 0.0
    dom_h = -9.0
    asym = clamp(0.48 * reach_scale, 0.40, 0.54)

    for r_raw, amp, phi in ((ra_raw, amp_a, phi_a), (rb_raw, amp_b, phi_b)):
        theta = phi - asym * math.cos(phi)
        v_env = 0.5 + 0.5 * math.cos(theta)
        is_upward = clamp(0.5 - 0.60 * math.sin(theta), 0.0, 1.0)

        # Bounded taper exponent (0.62..1.32) sculpts upward tips without steep 1px seam cliffs
        taper_exp = 0.62 + 0.70 * ((1.0 - v_env) ** 0.85) * (0.45 + 0.55 * is_upward)
        spire = (clamp(r_raw, 0.0, 1.0) ** taper_exp) * amp

        h_val = (v_env ** 0.74) * (0.18 + 0.86 * spire)
        tip_val = clamp((1.0 - v_env) * 1.25, 0.0, 1.0) * is_upward

        if h_val > dom_h:
            dom_h = h_val
            dom_tip = tip_val
        best_heat = smax(best_heat, h_val, 0.16)

    # Smooth low-wavenumber (k <= 2) upward flame-lick serration (zero high-k cliff steps)
    lick_serr = 0.55 * math.sin(2.0 * u + v + ph) + 0.45 * math.cos(u - 2.0 * v - ph + 0.6)
    best_heat += 0.038 * lick_serr
    return best_heat, dom_tip, lick_serr


# ---------------------------------------------------------------------------
# 1. `fire_scorch_mark` — Charred Radial Soot & Ash Scorch Decal (1f @ 200ms)
# ---------------------------------------------------------------------------

def build_fire_scorch_mark() -> dict[str, Any]:
    layer_defs = [
        ("ash_halo", 88),
        ("soot_skirt", 148),
        ("char_ring", 208),
        ("vitreous_core", 246),
    ]
    fb = LayeredFrameBuilder(32, 32, layer_defs, HYDRO_LEGEND)

    cx, cy = 15.5, 17.2
    rx, ry = 12.2, 9.8
    for y in range(32):
        for x in range(32):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            rays = (
                0.11 * math.cos(7.0 * ang + 0.4)
                + 0.08 * math.sin(11.0 * ang - 0.9)
                + 0.05 * math.cos(4.0 * ang + 1.7)
            )
            grain = 0.05 * math.sin((x * 0.9) + (y * 1.1)) + 0.04 * math.cos((x * 1.4) - (y * 0.8))
            rn = r + rays + grain

            if rn > 1.02:
                continue
            if rn > 0.81:
                tok = "4" if (rn > 0.91 or grain > 0.02) else "3"
                fb.set_px(x, y, "ash_halo", tok)
            elif rn > 0.57:
                tok = "3" if (rn > 0.69 and rays > -0.02) else "2"
                fb.set_px(x, y, "soot_skirt", tok)
            elif rn > 0.32:
                tok = "2" if (rn > 0.44 or grain > 0.03) else "1"
                fb.set_px(x, y, "char_ring", tok)
            else:
                tok = "2" if (rn > 0.24 and grain > 0.025) else ("1" if rn > 0.16 or grain > 0.01 else "K")
                fb.set_px(x, y, "vitreous_core", tok)

    fb.clean_lone_pixels_single()
    return {
        "id": "fire_scorch_mark",
        "title": "Charred Soot & Ash Scorch Decal",
        "element": "fire",
        "category": "fire_campfire",
        "kind": "single",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Carbon Soot & Ash", "label": "Carbon Soot & Ash", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_scorch_mark.aseprite",
        "tag": "idle",
        "description": (
            "Oblique radial carbonized char scar with 4 feathered opacity rings (alpha 88..246) "
            "and radiating soot draft streaks; leaves tile corners clear for underlying floor plating."
        ),
        "physics_notes": (
            "Incomplete pyrolysis deposits a dense vitreous carbon center (#0A0A0D/#1D1D1D) "
            "surrounded by radially entrained soot fingers (#2B2B2B) and light fly-ash (#444444/#626262)."
        ),
        "frames": [fb.to_frame_dict(200)],
    }


# ---------------------------------------------------------------------------
# 2. `fire_campfire_embers` — Pulsing Glowing Coal/Ember Bed (8f @ 200ms)
# ---------------------------------------------------------------------------

def build_fire_campfire_embers() -> dict[str, Any]:
    layer_defs = [
        ("ash_skirt", 170),
        ("coal_crust", 242),
        ("lazy_wisps", 198),
        ("glowing_coals", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8
    coal_lumps = [
        (9.6, 22.8, 4.3, 2.8),
        (15.5, 23.5, 5.8, 3.2),
        (21.4, 22.7, 4.4, 2.8),
        (12.2, 20.4, 4.3, 2.6),
        (18.8, 20.5, 4.3, 2.6),
        (15.5, 19.2, 3.8, 2.2),
    ]

    for f in range(n_frames):
        fb = LayeredFrameBuilder(32, 32, layer_defs, HYDRO_LEGEND)
        ph = 2.0 * math.pi * (f / float(n_frames))
        breath = 0.5 + 0.5 * math.sin(ph)

        for y in range(14, 29):
            for x in range(4, 28):
                px, py = x + 0.5, y + 0.5
                mound = -10.0
                second_lump = -10.0
                for lx0, ly0, rx, ry in coal_lumps:
                    d = 1.0 - math.hypot((px - lx0) / rx, (py - ly0) / ry)
                    if d > second_lump:
                        if d > mound:
                            second_lump = mound
                            mound = d
                        else:
                            second_lump = d

                if mound < -0.08:
                    continue
                if mound < 0.0:
                    if py >= 21.0:
                        fb.set_px(x, y, "ash_skirt", "2" if mound < -0.04 else "c")
                    continue

                crevice = clamp(1.0 - abs(mound - second_lump) / 0.26, 0.0, 1.0) if second_lump > -0.1 else 0.0
                draft_wave = 0.5 + 0.5 * math.sin(px * 0.65 - py * 0.55 + ph)
                core_prox = clamp(1.0 - math.hypot((px - 15.5) / 8.0, (py - 22.0) / 4.2), 0.0, 1.0)

                heat = (
                    0.30 * mound
                    + 0.38 * crevice
                    + 0.30 * core_prox
                    + 0.16 * draft_wave
                    + 0.10 * breath
                    - 0.22 * smoothstep(24.0, 26.8, py)
                )

                if mound < 0.13:
                    tok = "K" if py >= 24.5 else ("1" if heat < 0.34 else "c")
                    fb.set_px(x, y, "coal_crust", tok)
                elif heat < 0.38:
                    tok = "1" if heat < 0.26 else ("2" if crevice < 0.15 else "c")
                    fb.set_px(x, y, "coal_crust", tok)
                elif heat < 0.50:
                    tok = "r" if heat < 0.44 else "R"
                    fb.set_px(x, y, "coal_crust", tok)
                elif heat < 0.62:
                    tok = "o" if heat < 0.56 else "O"
                    fb.set_px(x, y, "glowing_coals", tok)
                elif heat < 0.72:
                    tok = "N" if heat < 0.67 else "G"
                    fb.set_px(x, y, "glowing_coals", tok)
                elif heat < 0.81:
                    tok = "Y" if heat < 0.76 else "g"
                    fb.set_px(x, y, "glowing_coals", tok)
                else:
                    fb.set_px(x, y, "glowing_coals", "W")

        wisp_specs = [
            (12.6, 18.8, f),
            (18.6, 19.0, (f + 4) % 8),
        ]
        for wx0, wy0, wf in wisp_specs:
            heights = [4, 5, 6, 7, 6, 5, 4, 3][wf]
            wph = 2.0 * math.pi * (wf / 8.0)
            for step in range(heights):
                wy = int(round(wy0 - step))
                sway = round(1.15 * math.sin(step * 0.72 - wph))
                wx = int(round(wx0 + sway))
                if step <= 1:
                    fb.set_px(wx, wy, "glowing_coals", "Y" if step == 0 else "O")
                    fb.set_px(wx + 1, wy, "lazy_wisps", "O" if step == 0 else "R")
                elif step < heights - 1:
                    fb.set_px(wx, wy, "lazy_wisps", "M" if step == 2 else "R")
                    fb.set_px(wx - 1, wy, "lazy_wisps", "r")
                else:
                    fb.set_px(wx, wy, "lazy_wisps", "r")

        fb.clean_lone_pixels_single()
        frames.append(fb.to_frame_dict(200))

    return {
        "id": "fire_campfire_embers",
        "title": "Glowing Campfire Coal & Ember Bed",
        "element": "fire",
        "category": "fire_campfire",
        "kind": "single",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Glowing Hardwood Coals", "label": "Glowing Hardwood Coals", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_campfire_embers.aseprite",
        "tag": "idle",
        "description": (
            "8-frame breathing 6-chunk charred coal mound (`8f @ 200ms`, `x=5..26, y=14..27`) with "
            "incandescent inter-coal crevices and lazy curling wisps; composites cleanly over `solid_pile_small`."
        ),
        "physics_notes": (
            "Late-stage heterogeneous char oxidation: surface carbon reacts directly with diffusing O2 "
            "at 900-1300 K inside inter-coal crevices while volatile flaming subsides to lazy wisps."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# Campfire Plume Sculptor (8-Frame Smooth Rolling Upward Advection!)
# ---------------------------------------------------------------------------

def evaluate_curved_tongue(
    px: float,
    py: float,
    bx: float,
    by: float,
    top_y: float,
    half_w_base: float,
    inward_pull: float,
    sway_amp: float,
    phase: float,
    freq: float = 1.0,
) -> float:
    if py > by + 2.6 or py < top_y - 1.0:
        return -1.0
    h_span = max(1.0, by - top_y)
    t = (by - py) / h_span
    if t < 0.0:
        under = (py - by) / 2.5
        if under >= 1.0:
            return -1.0
        hw = half_w_base * math.sqrt(max(0.0, 1.0 - under * under))
        if hw < 0.25:
            return -1.0
        dx = abs(px - bx) / hw
        return (1.0 - dx) * (1.0 - 0.62 * under)

    neck_pull = inward_pull * math.sin(min(1.0, t) * math.pi * 0.75)
    sway = sway_amp * (t ** 1.25) * math.sin(phase - freq * t * 3.4)
    cx = bx + neck_pull + sway

    hw = half_w_base * ((1.0 - clamp(t, 0.0, 1.0)) ** 0.86)
    if hw < 0.32:
        return -1.0
    dx = abs(px - cx) / hw
    axial_cool = 1.0 - 0.50 * (t ** 1.22)
    return axial_cool - 0.85 * (dx ** 1.12)


def ember_cup_rim_cooling(px: float, py: float, center_y: float, rx: float, ry: float) -> float:
    if py <= center_y:
        return 0.0
    r_bot = math.hypot((px - 15.5) / rx, (py - center_y) / ry)
    return 0.44 * smoothstep(0.55, 1.05, r_bot)


# ---------------------------------------------------------------------------
# 3. `fire_campfire_steady` — 8-Frame Rolling Steady Campfire (8f @ 200ms)
# ---------------------------------------------------------------------------

def build_fire_campfire_steady() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 112),
        ("outer_crimson", 218),
        ("flame_body", 246),
        ("incandescent_core", 255),
        ("rising_sparks", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(32, 32, layer_defs, HYDRO_LEGEND)
        ph = 2.0 * math.pi * (f / n_frames)
        py_roll = (4.0 * f) % 32.0

        tongues = [
            (15.5, 23.4, 5.2 + 0.9 * math.sin(ph), 4.6, 0.0, 1.95, ph),
            (10.8, 22.8, 9.6 + 1.1 * math.cos(ph), 3.3, 1.3, 1.60, ph + 2.0),
            (20.2, 22.8, 10.0 - 1.1 * math.cos(ph), 3.3, -1.3, 1.60, ph - 1.8),
            (13.2, 23.2, 7.8 - 0.8 * math.sin(ph), 2.7, 0.6, 1.30, ph + 1.1),
            (17.8, 23.2, 8.2 + 0.8 * math.sin(ph), 2.7, -0.6, 1.30, ph - 1.0),
        ]

        for y in range(2, 27):
            for x in range(5, 27):
                px, py = x + 0.5, y + 0.5
                h_val = -1.0
                for bx, by, ty, hw, pull, sw, poff in tongues:
                    tv = evaluate_curved_tongue(px, py, bx, by, ty, hw, pull, sw, poff)
                    h_val = smax(h_val, tv, 0.10)

                cradle = 0.68 - math.hypot((px - 15.5) / 7.2, (py - 22.6) / 3.1) * 0.68
                h_val = smax(h_val, cradle, 0.12)
                h_val += 0.065 * math.sin(TAU_32 * (py + py_roll) * 2.0 + 0.5 * math.cos(px * 0.6))

                if h_val < -0.03:
                    continue
                if h_val < 0.035:
                    fb.set_px(x, y, "outer_glow", "c" if py >= 23.0 else "r")
                    continue

                h_col = h_val - ember_cup_rim_cooling(px, py, 22.0, 7.2, 3.6)

                if h_col < 0.14:
                    if py <= 7.5 and h_val < 0.09:
                        tok = "1"
                    elif py >= 23.6 and h_col < 0.06:
                        tok = "c"
                    elif h_col < 0.08:
                        tok = "r"
                    else:
                        tok = "R"
                    fb.set_px(x, y, "outer_crimson", tok)
                elif h_col < 0.26:
                    tok = "M" if py < 21.0 else "o"
                    fb.set_px(x, y, "outer_crimson", tok)
                elif h_col < 0.43:
                    tok = "O" if h_col < 0.35 else "P"
                    fb.set_px(x, y, "flame_body", tok)
                elif h_col < 0.59:
                    tok = "N" if h_col < 0.51 else "G"
                    fb.set_px(x, y, "flame_body", tok)
                elif h_col < 0.74:
                    tok = "Y" if h_col < 0.67 else "L"
                    fb.set_px(x, y, "incandescent_core", tok)
                elif h_col < 0.86:
                    tok = "U" if h_col < 0.80 else "g"
                    fb.set_px(x, y, "incandescent_core", tok)
                else:
                    fb.set_px(x, y, "incandescent_core", "W")

        left_spark = [(10, 10), (9, 9), (9, 8), (10, 7), (10, 6), (9, 5), (9, 4), (10, 3)][f]
        right_spark = [(21, 6), (22, 5), (22, 4), (21, 3), (21, 10), (20, 9), (21, 8), (21, 7)][f]
        for idx_s, (sx, sy) in enumerate((left_spark, right_spark)):
            age = f if idx_s == 0 else (f + 4) % 8
            fb.set_px(sx, sy, "rising_sparks", "g" if age < 4 else "Y")
            fb.set_px(sx, sy + 1, "rising_sparks", "Y" if age < 3 else ("F" if age < 6 else "M"))

        fb.clean_lone_pixels_single()
        frames.append(fb.to_frame_dict(200))

    return {
        "id": "fire_campfire_steady",
        "title": "Steady Campfire Diffusion Flame",
        "element": "fire",
        "category": "fire_campfire",
        "kind": "single",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Natural Wood/Solid Oxidation", "label": "Natural Wood/Solid Oxidation", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_campfire_steady.aseprite",
        "tag": "idle",
        "description": (
            "8-frame smooth rolling buoyant diffusion campfire (`8f @ 200ms`) with rounded ember cradle, "
            "feathered outer crimson glow, white-yellow pyrolysis core, and rising 2px sparks."
        ),
        "physics_notes": (
            "Buoyancy-driven solid-fuel diffusion flame with continuous upward wave advection and "
            "vena-contracta necking above glowing hardwood char."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# 4. `fire_campfire_roaring` — 8-Frame Roaring Bonfire & Shower (8f @ 100ms)
# ---------------------------------------------------------------------------

def build_fire_campfire_roaring() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 112),
        ("outer_crimson", 220),
        ("flame_body", 248),
        ("incandescent_core", 255),
        ("ember_shower", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(32, 32, layer_defs, HYDRO_LEGEND)
        ph = 2.0 * math.pi * (f / n_frames)
        py_roll = (4.0 * f) % 32.0

        tongues = [
            (15.5, 24.0, 2.0 + 0.8 * math.sin(ph), 5.8, 0.0, 2.35, ph),
            (9.8, 23.4, 5.8 + 1.2 * math.cos(ph), 4.1, 2.2, 1.95, ph + 1.9),
            (21.2, 23.4, 6.2 - 1.2 * math.cos(ph), 4.1, -2.2, 1.95, ph - 1.8),
            (7.4, 22.8, 11.4 + 1.0 * math.sin(ph + 1.1), 3.0, 1.8, 1.45, ph + 2.9),
            (23.6, 22.8, 11.8 - 1.0 * math.sin(ph + 1.1), 3.0, -1.8, 1.45, ph - 2.7),
            (13.0, 23.8, 4.2 - 0.9 * math.cos(ph), 3.7, 0.9, 1.75, ph + 0.8),
            (18.0, 23.8, 4.6 + 0.9 * math.cos(ph), 3.7, -0.9, 1.75, ph - 0.7),
        ]

        bolus_t = f / float(n_frames)
        bolus_y = 8.8 - 6.4 * bolus_t
        bolus_x = 15.5 + 1.8 * math.sin(ph + 0.5)
        bolus_r = 2.6 - 1.2 * bolus_t

        for y in range(1, 28):
            for x in range(3, 29):
                px, py = x + 0.5, y + 0.5
                h_val = -1.0
                for bx, by, ty, hw, pull, sw, poff in tongues:
                    tv = evaluate_curved_tongue(px, py, bx, by, ty, hw, pull, sw, poff, freq=1.15)
                    h_val = smax(h_val, tv, 0.12)

                bolus = (1.0 - math.hypot((px - bolus_x) / bolus_r, (py - bolus_y) / (bolus_r * 1.15))) * 0.46
                h_val = smax(h_val, bolus, 0.10)

                cradle = 0.74 - math.hypot((px - 15.5) / 9.4, (py - 23.0) / 3.6) * 0.74
                h_val = smax(h_val, cradle, 0.14)
                h_val += 0.075 * math.sin(TAU_32 * (py + py_roll) * 2.0 + 0.7 * math.sin(px * 0.5))

                if h_val < -0.03:
                    continue
                if h_val < 0.035:
                    fb.set_px(x, y, "outer_glow", "c" if py >= 23.5 else "r")
                    continue

                h_col = h_val - ember_cup_rim_cooling(px, py, 22.2, 9.4, 4.1)

                if h_col < 0.14:
                    if py <= 6.2 and h_val < 0.085:
                        tok = "1" if py <= 4.2 else "2"
                    elif py >= 24.2 and h_col < 0.05:
                        tok = "c"
                    elif h_col < 0.08:
                        tok = "r"
                    else:
                        tok = "R"
                    fb.set_px(x, y, "outer_crimson", tok)
                elif h_col < 0.27:
                    tok = "M" if h_col < 0.21 else "F"
                    fb.set_px(x, y, "outer_crimson", tok)
                elif h_col < 0.44:
                    tok = "O" if h_col < 0.36 else "N"
                    fb.set_px(x, y, "flame_body", tok)
                elif h_col < 0.58:
                    tok = "G" if h_col < 0.51 else "Y"
                    fb.set_px(x, y, "flame_body", tok)
                elif h_col < 0.73:
                    tok = "L" if h_col < 0.66 else "U"
                    fb.set_px(x, y, "incandescent_core", tok)
                elif h_col < 0.85:
                    tok = "g" if h_col < 0.79 else "E"
                    fb.set_px(x, y, "incandescent_core", tok)
                else:
                    fb.set_px(x, y, "incandescent_core", "W")

        base_track_l1 = [(6, 12), (6, 10), (5, 9), (5, 7), (6, 6), (6, 4), (5, 3), (5, 2)]
        base_track_l2 = [(8, 11), (8, 9), (7, 8), (7, 6), (8, 5), (8, 3), (7, 2), (8, 13)]
        base_track_r1 = [(25, 11), (25, 9), (26, 8), (26, 6), (25, 5), (25, 3), (26, 2), (24, 12)]
        base_track_r2 = [(23, 10), (24, 8), (23, 7), (23, 5), (24, 4), (23, 2), (23, 12), (24, 11)]
        tracks = [
            base_track_l1[f],
            base_track_l2[(f + 4) % 8],
            base_track_r1[(f + 2) % 8],
            base_track_r2[(f + 6) % 8],
        ]
        for s_i, (sx, sy) in enumerate(tracks):
            age = (f + s_i * 2) % 8
            fb.set_px(sx, sy, "ember_shower", "W" if age < 2 else ("g" if age < 5 else "Y"))
            fb.set_px(sx, sy + 1, "ember_shower", "Y" if age < 4 else ("F" if age < 6 else "M"))

        fb.clean_lone_pixels_single()
        frames.append(fb.to_frame_dict(100))

    return {
        "id": "fire_campfire_roaring",
        "title": "Roaring Bonfire Plume & Ember Shower",
        "element": "fire",
        "category": "fire_campfire",
        "kind": "single",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Roaring Hydrocarbon Bonfire", "label": "Roaring Hydrocarbon Bonfire", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_campfire_roaring.aseprite",
        "tag": "idle",
        "description": (
            "8-frame vigorous roaring bonfire (`8f @ 100ms`) with rounded ember cradle, sweeping "
            "vena-contracta tongues, continuous rising bolus, feathered crimson halo, and 4-stream ember shower."
        ),
        "physics_notes": (
            "High-Froude turbulent buoyant plume: radial air entrainment necks the lower plume inward "
            "before shedding rising toroidal flame pockets and lofting glowing char sparks."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# 5. `fire_campfire_tintable` — 8-Frame Neutral Greyscale Flame (8f @ 100ms)
# ---------------------------------------------------------------------------

def build_fire_campfire_tintable() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 110),
        ("outer_sheath", 214),
        ("mid_plume", 244),
        ("spectral_core", 255),
        ("ionic_sparks", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(32, 32, layer_defs, TINT_LEGEND)
        ph = 2.0 * math.pi * (f / n_frames)
        py_roll = (4.0 * f) % 32.0

        tongues = [
            (15.5, 23.4, 5.0 + 0.9 * math.sin(ph), 4.5, 0.0, 1.90, ph),
            (10.9, 22.8, 9.4 + 1.1 * math.cos(ph), 3.2, 1.25, 1.55, ph + 2.0),
            (20.1, 22.8, 9.8 - 1.1 * math.cos(ph), 3.2, -1.25, 1.55, ph - 1.8),
            (13.3, 23.2, 7.6 - 0.8 * math.sin(ph), 2.6, 0.55, 1.25, ph + 1.0),
            (17.7, 23.2, 8.0 + 0.8 * math.sin(ph), 2.6, -0.55, 1.25, ph - 0.9),
        ]

        for y in range(2, 27):
            for x in range(5, 27):
                px, py = x + 0.5, y + 0.5
                h_val = -1.0
                for bx, by, ty, hw, pull, sw, poff in tongues:
                    tv = evaluate_curved_tongue(px, py, bx, by, ty, hw, pull, sw, poff)
                    h_val = smax(h_val, tv, 0.10)

                cradle = 0.68 - math.hypot((px - 15.5) / 7.1, (py - 22.6) / 3.1) * 0.68
                h_val = smax(h_val, cradle, 0.12)
                h_val += 0.06 * math.sin(TAU_32 * (py + py_roll) * 2.0 + 0.45 * math.cos(px * 0.65))

                if h_val < -0.03:
                    continue
                if h_val < 0.035:
                    fb.set_px(x, y, "outer_glow", "b" if py >= 23.0 else "c")
                    continue

                h_col = h_val - ember_cup_rim_cooling(px, py, 22.0, 7.1, 3.6)

                if h_col < 0.08:
                    fb.set_px(x, y, "outer_sheath", "a" if py >= 23.0 else "b")
                elif h_col < 0.16:
                    fb.set_px(x, y, "outer_sheath", "c" if h_col < 0.12 else "d")
                elif h_col < 0.27:
                    fb.set_px(x, y, "outer_sheath", "e" if h_col < 0.22 else "f")
                elif h_col < 0.42:
                    fb.set_px(x, y, "mid_plume", "g")
                elif h_col < 0.55:
                    fb.set_px(x, y, "mid_plume", "h")
                elif h_col < 0.68:
                    fb.set_px(x, y, "spectral_core", "i")
                elif h_col < 0.79:
                    fb.set_px(x, y, "spectral_core", "j")
                elif h_col < 0.88:
                    fb.set_px(x, y, "spectral_core", "k")
                else:
                    fb.set_px(x, y, "spectral_core", "W")

        left_s = [(10, 10), (9, 9), (9, 8), (10, 7), (10, 6), (9, 5), (9, 4), (10, 3)][f]
        right_s = [(21, 6), (22, 5), (22, 4), (21, 3), (21, 10), (20, 9), (21, 8), (21, 7)][f]
        for s_i, (sx, sy) in enumerate((left_s, right_s)):
            age = f if s_i == 0 else (f + 4) % 8
            fb.set_px(sx, sy, "ionic_sparks", "W" if age < 4 else "j")
            fb.set_px(sx, sy + 1, "ionic_sparks", "i" if age < 4 else "f")

        fb.clean_lone_pixels_single()
        frames.append(fb.to_frame_dict(100))

    return {
        "id": "fire_campfire_tintable",
        "title": "Tintable Chemical-Salt Campfire Flame",
        "element": "fire",
        "category": "fire_campfire",
        "kind": "single",
        "colorable": True,
        "require_top_light": False,
        "default_tint": "#38E570",
        "sample_tints": [
            {"name": "Copper(II) Emerald (#38E570)", "label": "Copper(II) Emerald", "hex": "#38E570"},
            {"name": "Lithium Crimson (#FF3366)", "label": "Lithium Crimson", "hex": "#FF3366"},
            {"name": "Potassium Lilac (#C96DBF)", "label": "Potassium Lilac", "hex": "#C96DBF"},
            {"name": "Sodium D-Line Amber (#FFB833)", "label": "Sodium Amber", "hex": "#FFB833"},
            {"name": "Barium Apple-Green (#8CE64C)", "label": "Barium Green", "hex": "#8CE64C"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_campfire_tintable.aseprite",
        "tag": "idle",
        "description": (
            "8-frame strictly neutral greyscale (`R==G==B`, 12 steps `#1B1B1B..#FFFFFF`) rolling flame "
            "with feathered outer glow and rounded ember cradle for metallic-salt sRGB multiply tinting."
        ),
        "physics_notes": (
            "Atomic emission spectroscopy in flames: thermally excited metal ions emit narrow-band "
            "photons (CuCl+ 515nm green, Li 671nm red, K 404/766nm violet) with minimal continuum soot."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# Grease Pool Fire Shared Physics Evaluator (Braided Flame Curtains + Feather Rim)
# ---------------------------------------------------------------------------

def paint_grease_pixel(
    fb: LayeredFrameBuilder,
    x: int,
    y: int,
    lx: int,
    ly: int,
    d_raw: float,
    nx: float,
    ny: float,
    frame_idx: int,
    n_frames: int = 8,
) -> None:
    """
    Evaporative liquid hydrocarbon pool fire (8-frame braided flame curtains + feathered rim):
      - `dp < 1.45`: open margin so glossy dark liquid puddle meniscus peeks out underneath.
      - `dp in 1.45..2.80`: soft feathered `outer_glow` (`opacity: 96`) blending into oil slick.
      - `dp in 2.80..3.95`: ragged `perimeter_fringe` (`opacity: 146`) with upward North licks.
      - `dp in 3.95..7.20`: bright yellow-white O2-fed stoichiometric reaction lip (`opacity: 255`).
      - `dp >= 7.20`: continuous braided orange-red interior flame curtains (`opacity: 176`),
        dark `#1D1D1D`/`#2B2B2B` soot crests (`opacity: 210`) curling along ragged upper (`-y`)
        curtain lips, and dark boiling-oil troughs (`opacity: 112` + interior peek gaps).
    """
    px, py = lx + 0.5, ly + 0.5
    heat_c, tip_t, lick_serr = evaluate_braided_flame_curtains(
        px, py, frame_idx, n_frames=n_frames, tongue_reach=13.5
    )

    edge_w = 1.0 - smoothstep(3.2, 13.0, d_raw)
    north_lick = max(0.0, ny) * (0.85 + 1.00 * clamp(heat_c, 0.0, 0.9))
    side_lick = abs(nx) * 0.40 * lick_serr
    south_tuck = max(0.0, -ny) * 0.40
    dp = d_raw + edge_w * (0.55 * lick_serr + north_lick + side_lick - south_tuck)

    if dp < 1.45:
        return

    # 1. Soft Feathered Outer Glow / Smoke Blend (`opacity: 96`) on Blocks 0, 1, 2, 3
    if dp < 2.80:
        if ny > 0.35 and tip_t > 0.50:
            tok = "1" if dp < 2.10 else "2"
        else:
            tok = "c" if dp < 2.10 else "r"
        fb.set_px(x, y, "outer_glow", tok)
        return

    # 2. Ragged Licking Perimeter Fringe (`opacity: 148`)
    if dp < 3.95:
        if ny > 0.40 and dp < 3.30 and lick_serr > 0.25:
            tok = "2"
        elif dp < 3.35:
            tok = "R"
        else:
            tok = "M" if lick_serr < 0.15 else "O"
        fb.set_px(x, y, "perimeter_fringe", tok)
        return

    # 3. Bright Oxygen-Fed Stoichiometric Perimeter Rim (`dp = 3.95..7.20`, `opacity: 255`)
    if dp < 7.20:
        rim_t = 1.0 - abs(dp - 5.35) / 1.85 + 0.15 * lick_serr + 0.12 * clamp(heat_c - 0.3, -0.2, 0.5)
        if rim_t > 0.92:
            tok = "W" if lick_serr > 0.10 else "g"
        elif rim_t > 0.72:
            tok = "U" if rim_t > 0.82 else "L"
        elif rim_t > 0.48:
            tok = "Y" if rim_t > 0.60 else "G"
        elif rim_t > 0.24:
            tok = "N" if dp < 5.5 else "P"
        else:
            tok = "O"
        fb.set_px(x, y, "oxygen_rim", tok)
        return

    # 4. Organic Wandering Interior Hydrocarbon Flame Tongues + Continuous Soot Crests (`dp >= 7.20`)
    # Smoothly cool upper (`-y`) flame crests via pyrolysis (`tip_t`) so orange grades through
    # crimson into dark carbonized soot (#2B2B2B/#1D1D1D/#0A0A0D) without boolean step cliffs!
    soot_cool = 0.28 * smoothstep(0.32, 0.78, tip_t) * (1.0 - smoothstep(0.48, 0.78, heat_c))
    h_int = heat_c - soot_cool

    if h_int < 0.13:
        fb.set_px(x, y, "outer_glow", "K" if h_int < 0.08 else "1")
        return
    if h_int < 0.22:
        fb.set_px(x, y, "oil_vapor_gaps", "1" if h_int < 0.17 else ("2" if tip_t > 0.45 else "c"))
        return
    if h_int < 0.31:
        if tip_t > 0.46:
            fb.set_px(x, y, "soot_crests", "2" if h_int < 0.26 else "r")
        else:
            fb.set_px(x, y, "interior_sheets", "r" if h_int < 0.26 else "R")
        return

    # Organic orange-red grease flame tongues (`opacity: 176`)
    if h_int < 0.44:
        tok = "R" if h_int < 0.37 else "M"
    elif h_int < 0.57:
        tok = "o" if h_int < 0.50 else "O"
    elif h_int < 0.70:
        tok = "F" if h_int < 0.63 else "N"
    elif h_int < 0.82:
        tok = "G" if h_int < 0.76 else "Y"
    else:
        tok = "L" if h_int < 0.90 else "U"
    fb.set_px(x, y, "interior_sheets", tok)


# ---------------------------------------------------------------------------
# 6. `fire_grease_single` — 8-Frame Oil/Grease Spill Fire (8f @ 200ms)
# ---------------------------------------------------------------------------

def build_fire_grease_single() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 96),
        ("oil_vapor_gaps", 128),
        ("perimeter_fringe", 148),
        ("interior_sheets", 176),
        ("soot_crests", 198),
        ("oxygen_rim", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(32, 32, layer_defs, HYDRO_LEGEND)
        for y in range(32):
            for x in range(32):
                px, py = x + 0.5, y + 0.5
                dx = (px - 15.6) / 13.4
                dy = (py - 16.5) / 11.8
                ang = math.atan2(dy, dx)
                lobe = 0.09 * math.cos(3.0 * ang - 0.5) + 0.06 * math.sin(2.0 * ang + 1.1)
                r_norm = math.hypot(dx, dy) - lobe
                d_raw = (1.08 - r_norm) * 12.2
                rad = max(1e-5, math.hypot(dx, dy))
                nx, ny = -dx / rad, -dy / rad
                paint_grease_pixel(fb, x, y, x, y, d_raw, nx, ny, f, n_frames=n_frames)

        fb.clean_lone_pixels_single()
        frames.append(fb.to_frame_dict(200))

    return {
        "id": "fire_grease_single",
        "title": "Single-Tile Oil & Grease Spill Fire",
        "element": "fire",
        "category": "fire_grease",
        "kind": "single",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Heavy Hydrocarbon Pool Fire", "label": "Heavy Hydrocarbon Pool Fire", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_grease_single.aseprite",
        "tag": "idle",
        "description": (
            "8-frame rolling spilled-oil pool fire (`8f @ 200ms`) with feathered `opacity 96..146` outer "
            "blend, bright O2-fed reaction rim, sweeping orange interior sheets, and `#1D1D1D` soot crests."
        ),
        "physics_notes": (
            "Evaporative pool combustion: perimeter air entrainment sustains a bright yellow-white lip "
            "while interior hydrocarbon flame curtains roll upward and pyrolyze into dark soot crests."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# 7. `fire_grease_smooth` — 47-Junction 8-Frame Smooth Pool Fire (8f @ 200ms)
# ---------------------------------------------------------------------------

def build_fire_grease_smooth() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 96),
        ("oil_vapor_gaps", 128),
        ("perimeter_fringe", 148),
        ("interior_sheets", 176),
        ("soot_crests", 198),
        ("oxygen_rim", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(160, 32, layer_defs, HYDRO_LEGEND)
        for block in range(5):
            bx0 = block * 32
            for ly in range(32):
                for lx in range(32):
                    d_raw, nx, ny = smooth_quad_boundary(block, lx, ly, r_round=14.4)
                    paint_grease_pixel(fb, bx0 + lx, ly, lx, ly, d_raw, nx, ny, f, n_frames=n_frames)

        fb.clean_lone_pixels_strip_safe()
        frames.append(fb.to_frame_dict(200))

    return {
        "id": "fire_grease_smooth",
        "title": "Smoothed Multi-Tile Oil & Grease Pool Fire",
        "element": "fire",
        "category": "fire_grease",
        "kind": "smooth_strip",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Heavy Hydrocarbon Pool Fire", "label": "Heavy Hydrocarbon Pool Fire", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_grease_smooth.aseprite",
        "tag": "idle",
        "description": (
            "5-block (`160x32`) 47-junction smooth pool fire (`8f @ 200ms`): feathered `opacity 96..146` "
            "outer glow on Blocks 0-3, bright O2-fed perimeter lip, and braided rolling soot-crested interior curtains."
        ),
        "physics_notes": (
            "Multi-tile pool fire scale effect: soft outer thermal halo blends into the oil meniscus around "
            "a stoichiometric yellow-white rim and sweeping fuel-rich soot-crested interior flame sheets."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# Combustible Gas Cloud Braided Sweeping Flame Curtains (`fire_gas_*`)
# ---------------------------------------------------------------------------

def paint_gas_smooth_pixel(
    fb: LayeredFrameBuilder,
    x: int,
    y: int,
    lx: int,
    ly: int,
    d_raw: float,
    nx: float,
    ny: float,
    frame_idx: int,
    colorable: bool,
    n_frames: int = 8,
) -> None:
    """
    Continuous braided sweeping flame curtains for multi-tile gas firestorms:
      - `dp < 1.25`: open outer margin for surrounding `gas_cloud_smooth_stirred`.
      - `dp in 1.25..2.75`: soft feathered `outer_glow` (`opacity: 92`) on Blocks 0-3!
      - `dp in 2.75..4.15`: ragged upward-licking `licking_fringe` (`opacity: 138`)!
      - `dp >= 4.15`: continuous sweeping S-curved flame curtains (`flame_curtain` @ 196,
        `roaring_tongues` @ 236, `incandescent_core` @ 255) with ragged concave `licking_fringe`
        (`opacity: 138`) valleys between billowing sheets so gas haze breathes through!
    """
    px, py = lx + 0.5, ly + 0.5
    heat_c, tip_t, lick_serr = evaluate_braided_flame_curtains(
        px, py, frame_idx, n_frames=n_frames, tongue_reach=17.0
    )

    edge_w = 1.0 - smoothstep(2.8, 13.2, d_raw)
    tongue_jut = 1.65 * clamp(heat_c - 0.18, -0.25, 0.85) + 0.45 * lick_serr
    north_boost = max(0.0, ny) * (0.95 + 0.80 * clamp(heat_c, 0.0, 0.9))
    south_round = max(0.0, -ny) * 0.35
    dp = d_raw + edge_w * (tongue_jut + north_boost - south_round - 0.70)

    if dp < 1.25:
        return

    # 1. Soft Feathered Outer Glow (`opacity: 96`) on Blocks 0, 1, 2, 3
    if dp < 2.75:
        if colorable:
            tok = "b" if dp < 1.85 else ("c" if dp < 2.30 else "d")
        else:
            tok = "r" if dp < 1.85 else ("R" if dp < 2.30 else "M")
        fb.set_px(x, y, "outer_glow", tok)
        return

    # 2. Ragged Outer Licking Flame Fringe (`opacity: 140`)
    if dp < 4.15:
        if colorable:
            tok = "d" if dp < 3.15 else ("e" if dp < 3.65 else "f")
        else:
            tok = "R" if dp < 3.15 else ("M" if dp < 3.65 else "F")
        fb.set_px(x, y, "licking_fringe", tok)
        return

    rim_atten = smoothstep(3.8, 8.2, dp)
    eff_heat = heat_c * (0.58 + 0.42 * rim_atten) - 0.12 * (1.0 - rim_atten)

    # 3. Ragged Concave Valleys between organic flame billows (`opacity: 140` so gas cloud breathes through!)
    if colorable:
        # 14-step monotonic premultiplied-luma ladder (max step <= 21.7 luma, bridges #626262 -> #929292 gap!)
        if eff_heat < 0.10:
            fb.set_px(x, y, "licking_fringe", "d")
        elif eff_heat < 0.17:
            fb.set_px(x, y, "licking_fringe", "e")
        elif eff_heat < 0.24:
            fb.set_px(x, y, "licking_fringe", "f")
        elif eff_heat < 0.31:
            fb.set_px(x, y, "flame_curtain", "f")
        elif eff_heat < 0.38:
            fb.set_px(x, y, "roaring_tongues", "f")
        elif eff_heat < 0.45:
            fb.set_px(x, y, "flame_curtain", "g")
        elif eff_heat < 0.52:
            fb.set_px(x, y, "roaring_tongues", "g")
        elif eff_heat < 0.59:
            fb.set_px(x, y, "roaring_tongues", "h")
        elif eff_heat < 0.66:
            fb.set_px(x, y, "roaring_tongues", "i")
        elif eff_heat < 0.72:
            fb.set_px(x, y, "roaring_tongues", "j")
        elif eff_heat < 0.78:
            fb.set_px(x, y, "incandescent_core", "i")
        elif eff_heat < 0.84:
            fb.set_px(x, y, "incandescent_core", "j")
        elif eff_heat < 0.90:
            fb.set_px(x, y, "incandescent_core", "k")
        else:
            fb.set_px(x, y, "incandescent_core", "W")
        return

    if eff_heat < 0.26:
        tok = "r" if eff_heat < 0.12 else ("R" if eff_heat < 0.19 else "M")
        fb.set_px(x, y, "licking_fringe", tok)
        return

    # 4. Monotonic Rec.709 Luma Ramp Across Curtains (182), Tongues (220) & Cores (255)
    if eff_heat < 0.44:
        if eff_heat < 0.32:
            tok = "o"
        elif tip_t > 0.52 or eff_heat < 0.38:
            tok = "F"
        else:
            tok = "O"
        fb.set_px(x, y, "flame_curtain", tok)
    elif eff_heat < 0.68:
        if eff_heat < 0.50:
            tok = "P"
        elif eff_heat < 0.56:
            tok = "N"
        elif eff_heat < 0.62:
            tok = "G"
        else:
            tok = "Y"
        fb.set_px(x, y, "roaring_tongues", tok)
    elif eff_heat < 0.78:
        fb.set_px(x, y, "incandescent_core", "L")
    elif eff_heat < 0.88:
        fb.set_px(x, y, "incandescent_core", "g")
    else:
        fb.set_px(x, y, "incandescent_core", "W")


# ---------------------------------------------------------------------------
# 8. `fire_gas_single_violent` — Dedicated 8-Frame Roaring Gas Fireball Plume
# ---------------------------------------------------------------------------

def build_fire_gas_single_violent() -> dict[str, Any]:
    """
    Sculpted single-tile erupting gas fireball (`8f @ 100ms`):
      - Billowing turbulent fireball belly (`y=11..28, x=4..27`) seamlessly fused with
        5 sweeping upward-licking crown & flank flame tongues (`y=1..18`) + continuous
        8-frame upward rolling internal flame curtains and soft `opacity 92..138` feathered halo!
    """
    layer_defs = [
        ("outer_glow", 92),
        ("licking_fringe", 138),
        ("flame_curtain", 196),
        ("roaring_tongues", 236),
        ("incandescent_core", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(32, 32, layer_defs, HYDRO_LEGEND)
        ph = 2.0 * math.pi * (f / n_frames)

        # Sweeping crown & flank tongues erupting out of the billowing gas fireball belly
        plume_tongues = [
            (15.5, 22.5, 1.8 + 0.9 * math.sin(ph), 6.8, 0.0, 2.35, ph),
            (10.0, 21.8, 4.8 + 1.3 * math.cos(ph), 5.0, 1.6, 2.05, ph + 1.8),
            (21.0, 21.8, 5.2 - 1.3 * math.cos(ph), 5.0, -1.6, 2.05, ph - 1.7),
            (6.8, 20.5, 9.8 + 1.1 * math.sin(ph + 1.2), 3.9, 1.2, 1.65, ph + 2.9),
            (24.2, 20.5, 10.2 - 1.1 * math.sin(ph + 1.2), 3.9, -1.2, 1.65, ph - 2.7),
            (13.0, 23.0, 3.6 - 1.0 * math.cos(ph), 4.6, 0.8, 1.90, ph + 0.9),
            (18.0, 23.0, 4.0 + 1.0 * math.cos(ph), 4.6, -0.8, 1.90, ph - 0.8),
        ]

        for y in range(32):
            for x in range(32):
                px, py = x + 0.5, y + 0.5
                h_tongues = -1.0
                for bx, by, ty, hw, pull, sw, poff in plume_tongues:
                    tv = evaluate_curved_tongue(px, py, bx, by, ty, hw, pull, sw, poff, freq=1.2)
                    h_tongues = smax(h_tongues, tv, 0.14)

                # Volumetric billowing fireball belly (`cx=15.5, cy=18.8`)
                ang = math.atan2(py - 18.8, px - 15.5)
                belly_lobes = 0.09 * math.cos(3.0 * ang - ph) + 0.06 * math.sin(5.0 * ang + ph)
                belly = 0.82 - (math.hypot((px - 15.5) / 11.4, (py - 19.2) / 8.8) - belly_lobes) * 0.82
                env = smax(h_tongues, belly, 0.16)

                # Modulate interior with continuous 8-frame rolling braided flame curtains!
                heat_c, _, lick_serr = evaluate_braided_flame_curtains(
                    px, py, f, n_frames=n_frames, tongue_reach=15.0
                )
                h_val = env * (0.64 + 0.46 * clamp(heat_c, 0.0, 1.0)) + 0.055 * lick_serr

                if h_val < -0.05:
                    continue
                if h_val < 0.03:
                    fb.set_px(x, y, "outer_glow", "r" if h_val < -0.01 else "R")
                    continue
                if h_val < 0.13:
                    fb.set_px(x, y, "licking_fringe", "R" if h_val < 0.08 else "M")
                    continue
                if h_val < 0.25:
                    fb.set_px(x, y, "flame_curtain", "F" if h_val < 0.19 else "O")
                    continue
                if h_val < 0.42:
                    fb.set_px(x, y, "roaring_tongues", "O" if h_val < 0.33 else "N")
                    continue
                if h_val < 0.58:
                    fb.set_px(x, y, "roaring_tongues", "G" if h_val < 0.50 else "Y")
                    continue
                if h_val < 0.72:
                    fb.set_px(x, y, "incandescent_core", "L" if h_val < 0.65 else "U")
                    continue
                if h_val < 0.82:
                    fb.set_px(x, y, "incandescent_core", "g" if h_val < 0.77 else "E")
                    continue
                fb.set_px(x, y, "incandescent_core", "W")

        fb.clean_lone_pixels_single()
        frames.append(fb.to_frame_dict(100))

    return {
        "id": "fire_gas_single_violent",
        "title": "Single-Tile Roaring Gas Fireball Plume",
        "element": "fire",
        "category": "fire_gas",
        "kind": "single",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Premixed Hydrocarbon Fireball", "label": "Premixed Hydrocarbon Fireball", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_gas_single_violent.aseprite",
        "tag": "idle",
        "description": (
            "8-frame roaring gas-pocket fireball (`8f @ 100ms`) with billowing flame belly, sweeping "
            "upward-licking crown tongues, incandescent `#FFFFFF`/`#FFF0C0` core curtains, and `opacity 92..138` feathered halo."
        ),
        "physics_notes": (
            "Turbulent gas-pocket deflagration: buoyant flame sheets surge rapidly upward (`-4px/frame`) "
            "into ragged multi-tongue spires while radiant outer glow blends into the gas pocket."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# 9. `fire_gas_smooth_violent` — 47-Junction 8-Frame Gas Firestorm (8f @ 100ms)
# ---------------------------------------------------------------------------

def build_fire_gas_smooth_violent() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 96),
        ("licking_fringe", 140),
        ("flame_curtain", 182),
        ("roaring_tongues", 220),
        ("incandescent_core", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(160, 32, layer_defs, HYDRO_LEGEND)
        for block in range(5):
            bx0 = block * 32
            for ly in range(32):
                for lx in range(32):
                    d_raw, nx, ny = smooth_quad_boundary(block, lx, ly, r_round=14.6)
                    paint_gas_smooth_pixel(
                        fb, bx0 + lx, ly, lx, ly, d_raw, nx, ny, f, colorable=False, n_frames=n_frames
                    )

        fb.clean_lone_pixels_strip_safe()
        frames.append(fb.to_frame_dict(100))

    return {
        "id": "fire_gas_smooth_violent",
        "title": "Smoothed Multi-Tile Violent Gas Firestorm",
        "element": "fire",
        "category": "fire_gas",
        "kind": "smooth_strip",
        "colorable": False,
        "require_top_light": False,
        "default_tint": "#FFFFFF",
        "sample_tints": [
            {"name": "Atmospheric Firestorm", "label": "Atmospheric Firestorm", "hex": "#FFFFFF"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_gas_smooth_violent.aseprite",
        "tag": "idle",
        "description": (
            "5-block (`160x32`) 47-junction smooth gas firestorm (`8f @ 100ms`): braided sweeping "
            "upward-licking flame curtains, `opacity 92..138` feathered outer rim on Blocks 0-3, and zero-seam 32x32 roll."
        ),
        "physics_notes": (
            "Room-scale turbulent gas firestorm (`LINDA_fire.dm` hotspot regime): continuous billowing "
            "flame curtains surge upward (`-4px/frame`) while ragged outer tips feather into surrounding gas haze."
        ),
        "frames": frames,
    }


# ---------------------------------------------------------------------------
# 10. `fire_gas_smooth_tintable` — 47-Junction 8-Frame Tintable Plasma Firestorm
# ---------------------------------------------------------------------------

def build_fire_gas_smooth_tintable() -> dict[str, Any]:
    layer_defs = [
        ("outer_glow", 96),
        ("licking_fringe", 140),
        ("flame_curtain", 182),
        ("roaring_tongues", 220),
        ("incandescent_core", 255),
    ]
    frames: list[dict[str, Any]] = []
    n_frames = 8

    for f in range(n_frames):
        fb = LayeredFrameBuilder(160, 32, layer_defs, TINT_LEGEND)
        for block in range(5):
            bx0 = block * 32
            for ly in range(32):
                for lx in range(32):
                    d_raw, nx, ny = smooth_quad_boundary(block, lx, ly, r_round=14.6)
                    paint_gas_smooth_pixel(
                        fb, bx0 + lx, ly, lx, ly, d_raw, nx, ny, f, colorable=True, n_frames=n_frames
                    )

        fb.clean_lone_pixels_strip_safe()
        frames.append(fb.to_frame_dict(100))

    return {
        "id": "fire_gas_smooth_tintable",
        "title": "Smoothed Tintable Plasma & Blackbody Gas Firestorm",
        "element": "fire",
        "category": "fire_gas",
        "kind": "smooth_strip",
        "colorable": True,
        "require_top_light": False,
        "default_tint": "#E052FF",
        "sample_tints": [
            {"name": "Plasma Firestorm (#E052FF)", "label": "Plasma Firestorm", "hex": "#E052FF"},
            {"name": "Hydrogen/Methane Blue (#55B8FF)", "label": "Hydrogen/Methane Blue", "hex": "#55B8FF"},
            {"name": "Blackbody 1800K Orange (#FF7A24)", "label": "Blackbody 1800K", "hex": "#FF7A24"},
            {"name": "Blackbody 9000K Arc (#B8DCFF)", "label": "Blackbody 9000K Arc", "hex": "#B8DCFF"},
            {"name": "Freon Cold Burn (#40F0E0)", "label": "Freon Cold Burn", "hex": "#40F0E0"},
        ],
        "ase_relpath": "assets/originals/art/fx/fire/fire_gas_smooth_tintable.aseprite",
        "tag": "idle",
        "description": (
            "5-block (`160x32`) 47-junction neutral greyscale (`R==G==B`) 8-frame rolling plasma/gas "
            "firestorm with continuous braided flame curtains and `opacity 92..138` feathered outer rim."
        ),
        "physics_notes": (
            "Covers non-sooting premixed chemiluminescence (CH*/OH* blue bands), billowing plasma firestorms "
            "(`>40,000 K` violet emission in `LINDA_fire.dm:244`), and Planckian blackbody color ramps."
        ),
        "frames": frames,
    }


SPRITES: list[dict[str, Any]] = [
    build_fire_scorch_mark(),
    build_fire_campfire_embers(),
    build_fire_campfire_steady(),
    build_fire_campfire_roaring(),
    build_fire_campfire_tintable(),
    build_fire_grease_single(),
    build_fire_grease_smooth(),
    build_fire_gas_single_violent(),
    build_fire_gas_smooth_violent(),
    build_fire_gas_smooth_tintable(),
]
