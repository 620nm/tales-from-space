"""Pixel library: the intake's top-down cast-concrete & brushed-brass hatch and cover.

Not a shipped source: `spec_intake_floor` draws these pixels into its `hatch_frame` and
`hatch_cover` layers; the kit validates this spec but exports nothing for it.
32x32 RGBA, 4 cover frames: closed (1), opening (2..3), open (4).
Layers, bottom to top: vault_frame_and_shaft (static), bisected_cover (animated).
"""

from __future__ import annotations

from typing import Any

WIDTH = 32
HEIGHT = 32

# Shared Open Hexagonal Shaft Aperture Contract.
SHAFT_X_SPAN: dict[int, tuple[int, int]] = {
    4: (9, 22),
    5: (8, 23),
    6: (7, 24),
    7: (6, 25),
    8: (5, 26),
    **{y: (4, 27) for y in range(9, 23)},
    23: (5, 26),
    24: (6, 25),
    25: (7, 24),
    26: (8, 23),
    27: (9, 22),
}


def shaft_south_max_y(x: int) -> int:
    """Maximum y coordinate visible inside the open hexagonal shaft at column `x` (4..27)."""
    ys = [y for y, (x0, x1) in SHAFT_X_SPAN.items() if x0 <= x <= x1]
    return max(ys) if ys else -1


# Coffer + West/East Pocket Clip Mask (`x = 3` and `x = 28` inner pocket tracks on `y = 8..23`,
# keeping the outer 3px perimeter `x = 0..2`, `x = 29..31`, `y = 0..2`, `y = 29..31` 100% stationary!).
COFFER_POCKET_SPAN: dict[int, tuple[int, int]] = {
    4: (9, 22),
    5: (8, 23),
    6: (7, 24),
    7: (6, 25),
    **{y: (3, 28) for y in range(8, 24)},
    24: (6, 25),
    25: (7, 24),
    26: (8, 23),
    27: (9, 22),
}

# True 6-sided regular point-West / point-East concrete hexagon span (`y = 4..27`)
# carried on parallel steel pocket slide shoes across `SHAFT_X_SPAN`.
HEX_SLAB_SPAN: dict[int, tuple[int, int]] = {
    4: (9, 22),
    5: (8, 23),
    6: (8, 23),
    7: (7, 24),
    8: (7, 24),
    9: (6, 25),
    10: (6, 25),
    11: (5, 26),
    12: (5, 26),
    13: (5, 26),
    14: (4, 27),
    15: (4, 27),
    16: (4, 27),
    17: (4, 27),
    18: (5, 26),
    19: (5, 26),
    20: (5, 26),
    21: (6, 25),
    22: (6, 25),
    23: (7, 24),
    24: (7, 24),
    25: (8, 23),
    26: (8, 23),
    27: (9, 22),
}

TOKEN_TO_P: dict[str, str] = {
    "K": "BLK",  # #0a0a0d (10.2) deep shaft void center
    "m": "M1",   # #151824 (24.2) lower shaft throat wall
    "d": "M2",   # #212330 (35.5) upper shaft liner step
    "1": "S1",   # #26262c (38.4) pocket recess / bolt socket
    "z": "N2",   # #2b2b2b (43.0) crisp closed interlocking center seam
    "2": "S2",   # #353841 (56.0) steel bevel / outer tile joint / shaft lip
    "3": "S3",   # #474851 (72.4) structural steel vault frame & carrier shoe
    "4": "S4",   # #565a63 (89.8) lit planar steel vault curb & machined nose
    "n": "N3",   # #444444 (68.0) concrete border & expansion groove
    "c": "CE1",  # #6b5d4d (94.8) calm warm cast-concrete coffer & slab base
    "C": "CE2",  # #968471 (134.5) calm warm lit cast-concrete hexagonal slab
    "T": "CE3",  # #bfb09c (176.9) crisp 1px sunlit top bevel highlight
    "6": "N6",   # #aaaaaa (170.0) crisp inner concrete rim & corner bolt highlight
    "e": "EY1",  # #3e3510 (52.2) dark brushed-brass rail groove & keyhole
    "b": "CK1",  # #635c3f (91.4) mid brushed khaki-brass track & bezel
    "H": "CK2",  # #8c855f (131.7) bright brushed khaki-brass cam-lock & runner
    "G": "CK3",  # #b8b28e (176.5) specular brushed khaki-brass glint
}


def _build_vault_frame_and_shaft() -> list[str]:
    grid = [["3" for _ in range(WIDTH)] for _ in range(HEIGHT)]

    # 1. Outer 32x32 tile-seam bevels (x/y = 0, 31) — soft step-2/3 steel curb for seamless tiling.
    seam_notches = {8, 15, 16, 23}
    for x in range(1, 31):
        grid[0][x] = "2" if x in seam_notches else "4"
        grid[31][x] = "2" if x in seam_notches else "3"
    for y in range(1, 31):
        grid[y][0] = "2" if y in seam_notches else "3"
        grid[y][31] = "2" if y in seam_notches else "3"
    for cx, cy in ((0, 0), (31, 0), (0, 31), (31, 31)):
        grid[cy][cx] = "2"

    # 2. Inner steel curb backing along y = 1, 30 and x = 1, 30.
    for x in range(4, 28):
        grid[1][x] = "2" if x in (15, 16) else ("4" if 9 <= x <= 22 else "3")
        grid[30][x] = "2" if x in (15, 16) else ("4" if 9 <= x <= 22 else "3")
    for y in range(4, 28):
        grid[y][1] = "1" if 8 <= y <= 23 else "3"
        grid[y][30] = "1" if 8 <= y <= 23 else "3"

    # 3. Four distinct 3x3 recessed corner gusset blocks with 2x2 steel anchor bolts.
    for bx0 in (1, 28):
        for dy, tok_bolt in ((1, "6"), (2, "1")):
            for dx in range(2):
                x = bx0 + dx if bx0 == 1 else bx0 + 1 + dx
                grid[dy][x] = tok_bolt
        border_x = bx0 + 2 if bx0 == 1 else bx0
        for dy in (1, 2, 3):
            grid[dy][border_x] = "2"
        for dx in range(3):
            grid[3][bx0 + dx] = "2"

        for dy, tok_bolt in ((29, "6"), (30, "1")):
            for dx in range(2):
                x = bx0 + dx if bx0 == 1 else bx0 + 1 + dx
                grid[dy][x] = tok_bolt
        for dy in (28, 29, 30):
            grid[dy][border_x] = "2"
        for dx in range(3):
            grid[28][bx0 + dx] = "2"

    # 4. Symmetrical N/S brushed khaki-brass horizontal slide-rail tracks along y = 2 and y = 29 (x = 4..27),
    # placing CK3/CK2 specular glints at x = 6..8 and x = 23..25 so x = 9..22 uses CK1/EY1 (zero hex collision with intake_head y = 3!).
    for y_rail in (2, 29):
        for x in range(4, 28):
            if x in (4, 5, 15, 16, 26, 27):
                grid[y_rail][x] = "e"
            elif x in (7, 24):
                grid[y_rail][x] = "G"
            elif x in (6, 8, 23, 25):
                grid[y_rail][x] = "H"
            else:
                grid[y_rail][x] = "b"

    # 5. Cast-concrete coffer spandrels & solid 2px-thick hexagonal coffer collar.
    for y in range(4, 28):
        for x in range(2, 30):
            grid[y][x] = "c"

    # Top & bottom horizontal hexagonal coffer lips (y = 3 and y = 28, x = 4..27)
    for x in range(4, 28):
        if x in (7, 24):
            grid[3][x] = "n"
            grid[28][x] = "n"
        elif 8 <= x <= 23:
            grid[3][x] = "2" if x in (15, 16) else "C"
            grid[28][x] = "2" if x in (15, 16) else "C"
        else:
            grid[3][x] = "c"
            grid[28][x] = "c"

    # Solid 2px-wide diagonal coffer bevels (y = 4..7 and y = 24..27)
    for y in list(range(4, 8)) + list(range(24, 28)):
        sx0, sx1 = SHAFT_X_SPAN[y]
        grid[y][sx0 - 1] = "C"
        grid[y][sx0 - 2] = "C"
        grid[y][sx1 + 1] = "C"
        grid[y][sx1 + 2] = "C"
        if sx0 - 3 >= 3:
            grid[y][sx0 - 3] = "n"
            grid[y][sx1 + 3] = "n"
        grid[y][2] = "3" if y in (4, 5, 26, 27) else "2"
        grid[y][29] = "3" if y in (4, 5, 26, 27) else "2"
        if y in (7, 24):
            grid[y][3] = "2"
            grid[y][28] = "2"

    # 6. Stationary West (`x = 2`) / East (`x = 29`) outer curb + inner (`x = 3, 28`) pocket track (`y = 8..23`).
    for y in range(8, 24):
        if y in (8, 23):
            grid[y][2] = "3"
            grid[y][29] = "3"
            grid[y][3] = "b"
            grid[y][28] = "b"
            grid[y][4] = "C"
            grid[y][27] = "C"
        elif y in (15, 16):
            grid[y][2] = "3"
            grid[y][29] = "3"
            grid[y][3] = "e"
            grid[y][28] = "e"
        else:
            grid[y][2] = "3"
            grid[y][29] = "3"
            grid[y][3] = "1"
            grid[y][28] = "1"

    # 7. Deep Hexagonal Shaft Throat inside SHAFT_X_SPAN (`S2/S1 -> M2 -> M1 -> BLK`).
    for y, (sx0, sx1) in SHAFT_X_SPAN.items():
        for x in range(sx0, sx1 + 1):
            d_edge = min(y - 4, 27 - y, x - sx0, sx1 - x)
            if d_edge == 0:
                grid[y][x] = "2" if (y <= 13 or y == 27) else "1"
            elif d_edge == 1:
                grid[y][x] = "2" if (y == 25 and x in (8, 23)) else "d"
            elif d_edge in (2, 3):
                grid[y][x] = "m"
            else:
                grid[y][x] = "K"

    return ["".join(row) for row in grid]


def _build_canonical_cover_grid(separated: bool) -> list[list[str]]:
    """Build unshifted (`dx = 0`) 32x32 cover grid covering `SHAFT_X_SPAN` + pocket guide tongues."""
    g = [["." for _ in range(WIDTH)] for _ in range(HEIGHT)]

    # Step 1: Fill parallel structural-steel pocket carrier shoes across SHAFT_X_SPAN.
    for y, (sx0, sx1) in SHAFT_X_SPAN.items():
        for x in range(sx0, sx1 + 1):
            g[y][x] = "2" if (x == sx0 or x == sx1) else "3"

    # Step 2: Paint the calm 6-Sided Precast Concrete Hexagon (`HEX_SLAB_SPAN`) with broad CE2/CE1 slabs
    # and a crisp 1px sunlit CE3 north bevel highlight at y = 5.
    for y, (hx0, hx1) in HEX_SLAB_SPAN.items():
        for x in range(hx0, hx1 + 1):
            d_top = y - 4
            d_bot = 27 - y
            d_left = x - hx0
            d_right = hx1 - x
            d_hex = min(d_top, d_bot, d_left, d_right)
            if d_hex == 0:
                g[y][x] = "n"
            elif d_hex == 1:
                g[y][x] = "T" if y == 5 else "C"
            elif d_hex == 2:
                g[y][x] = "C"
            else:
                g[y][x] = "C" if 9 <= y <= 22 and x in (hx0 + 3, hx1 - 3) else "c"

    # Preserve calm concrete inner vertical framing along x = 14 and x = 17 so each half-hexagon
    # reads as an intact framed precast concrete leaf when sliding open.
    for y in range(5, 27):
        g[y][14] = "C"
        g[y][17] = "C"

    # Step 3: Calm horizontal center stiffening rib (`y = 15..16`) & N6 (`6`) inner rim framing the central cam boss (`y = 12..19, x = 12..19`).
    for x in range(6, 13):
        g[15][x] = "C"
        g[16][x] = "C"
    for x in range(19, 26):
        g[15][x] = "C"
        g[16][x] = "C"
    for x in range(12, 20):
        g[12][x] = "6"
        g[19][x] = "6"
    for y in range(13, 19):
        g[y][12] = "6"
        g[y][19] = "6"

    # Step 4: Six corner brushed khaki-brass guide lugs (`CK3/CK2/CK1`) at the 6 hexagon vertices.
    # NW (9..10, 4..5), NE (21..22, 4..5), SW (9..10, 26..27), SE (21..22, 26..27)
    g[4][9], g[4][10] = "G", "H"
    g[4][21], g[4][22] = "H", "G"
    g[5][9], g[5][10] = "H", "b"
    g[5][21], g[5][22] = "b", "H"
    g[26][9], g[26][10] = "H", "b"
    g[26][21], g[26][22] = "b", "H"
    g[27][9], g[27][10] = "G", "H"
    g[27][21], g[27][22] = "H", "G"

    # West (3..4, 15..16) & East (27..28, 15..16) apex brass lugs engaging the pocket rails!
    for ly in (15, 16):
        g[ly][3] = "b"
        g[ly][4] = "G" if ly == 15 else "H"
        g[ly][5] = "6"
        g[ly][26] = "6"
        g[ly][27] = "G" if ly == 15 else "H"
        g[ly][28] = "b"

    # Step 5: Crisp vertical interlocking center seam (`x = 15 | 16` using N2/S2/S4)
    # OR machined brass/steel inner nose strips when separated (`f2..f4`).
    for y in range(4, 28):
        if 13 <= y <= 18:
            continue
        if not separated:
            if y in (8, 23):
                g[y][15] = "2"
                g[y][16] = "2"
            elif 9 <= y <= 12 or 19 <= y <= 22:
                g[y][15] = "4"
                g[y][16] = "z"
            else:
                g[y][15] = "z"
                g[y][16] = "4"
        else:
            if 9 <= y <= 12 or 19 <= y <= 22:
                g[y][15] = "b"
                g[y][16] = "b"
            else:
                g[y][15] = "4"
                g[y][16] = "4"

    # Step 6: Central brushed khaki-brass cam-lock straddling x = 13..18, y = 13..18.
    if not separated:
        # f1: Horizontal brass cam-bar locked across x = 13..18, y = 15..16!
        cam_rows_closed = [
            "nHGGHn",  # y = 13: CK3/CK2 top bevel
            "HeebeH",  # y = 14: EY1 keyhole slots above horizontal cam-bar
            "HGHbGH",  # y = 15: horizontal brass cam-bar locked across x=13..18!
            "HbHGHb",  # y = 16: horizontal brass cam-bar locked across x=13..18!
            "bebeeb",  # y = 17: EY1 keyhole slots below horizontal cam-bar
            "nbHHbn",  # y = 18: CK1/CK2 bottom bevel
        ]
        for dy, pat in enumerate(cam_rows_closed):
            y = 13 + dy
            for dx, ch in enumerate(pat):
                g[y][13 + dx] = ch
    else:
        # f2..f4: Central brass cam-bar rotated 90° vertical onto the split cam-boss noses!
        cam_rows_rotated = [
            "nHGGHn",  # y = 13: vertical cam-bar top (CK3 at src_x=15,16)
            "HbGGbH",  # y = 14: vertical cam-bar upper shaft (CK3 at src_x=15,16)
            "beGGeb",  # y = 15: 90-deg vertical cam-bar with EY1 release notch
            "beHHeb",  # y = 16: 90-deg vertical cam-bar with EY1 release notch
            "HbHHbH",  # y = 17: vertical cam-bar lower shaft (CK2 at src_x=15,16)
            "nbHHbn",  # y = 18: vertical cam-bar bottom (CK2 at src_x=15,16)
        ]
        for dy, pat in enumerate(cam_rows_rotated):
            y = 13 + dy
            for dx, ch in enumerate(pat):
                g[y][13 + dx] = ch

    return g


def _shift_and_clip_cover(dx_mag: int) -> list[str]:
    base = _build_canonical_cover_grid(separated=(dx_mag > 0))
    out = [["." for _ in range(WIDTH)] for _ in range(HEIGHT)]

    for y, (clip_x0, clip_x1) in COFFER_POCKET_SPAN.items():
        # West leaf (`x <= 15` in canonical grid) translates Left by `-dx_mag`
        for src_x in range(0, 16):
            ch = base[y][src_x]
            if ch == ".":
                continue
            dst_x = src_x - dx_mag
            if clip_x0 <= dst_x <= clip_x1:
                out[y][dst_x] = ch

        # East leaf (`x >= 16` in canonical grid) translates Right by `+dx_mag`
        for src_x in range(16, WIDTH):
            ch = base[y][src_x]
            if ch == ".":
                continue
            dst_x = src_x + dx_mag
            if clip_x0 <= dst_x <= clip_x1:
                out[y][dst_x] = ch

    return ["".join(row) for row in out]


def _used_legend(rows_list: list[list[str]]) -> dict[str, str]:
    used = {ch for rows in rows_list for row in rows for ch in row if ch != "."}
    return {ch: TOKEN_TO_P[ch] for ch in TOKEN_TO_P if ch in used}


_VAULT_ROWS = _build_vault_frame_and_shaft()
_COVER_FRAMES = [
    _shift_and_clip_cover(0),   # f1: closed (horizontal brass cam-bar locked across x=13..18, y=15..16)
    _shift_and_clip_cover(2),   # f2: cam-bar rotates 90° vertical while center seam cracks open (dx = 2)
    _shift_and_clip_cover(7),   # f3: West/East leaves slide halfway (dx = 7)
    _shift_and_clip_cover(12),  # f4: leaves fully retracted into x=3, 28 pockets (dx = 12)
]

SPEC: dict[str, Any] = {
    "name": "intake_vault",
    "kind": "intake_vault",
    "title": "Intake Hatch & Cover (Top-Down, pixel library)",
    "width": WIDTH,
    "height": HEIGHT,
    "blurb": (
        "Full 32×32 top-down orthographic concrete & brass vault curb with a stationary 3px outer perimeter "
        "and a bisected hexagonal hatch cover that unlocks with a 90° rotary cam-latch twist before retracting."
    ),
    "design_notes": (
        "Stationary 3px outer vault curb (x=0..2, 29..31, y=0..2, 29..31) seats the 5×3 intake_mouth_caps "
        "across all 5 pipe layers (l1..l5). f1: closed flush hatch; f2: 90° rotary brass cam-latch unlock; "
        "f3: half-retracted cover leaves; f4: wide-open 24×24 hexagonal throat with 1px parked cover strips at x=3, 28."
    ),
    "frame_count": 4,
    "frame_durations_ms": [100, 100, 100, 100],
    "tags": [
        {"name": "closed", "from": 1, "to": 1},
        {"name": "opening", "from": 2, "to": 3},
        {"name": "open", "from": 4, "to": 4},
    ],
    "layers": [
        {
            "name": "vault_frame_and_shaft",
            "animated": False,
            "legend": _used_legend([_VAULT_ROWS]),
            "rows": _VAULT_ROWS,
        },
        {
            "name": "bisected_cover",
            "animated": True,
            "legend": _used_legend(_COVER_FRAMES),
            "frames": _COVER_FRAMES,
        },
    ],
}
