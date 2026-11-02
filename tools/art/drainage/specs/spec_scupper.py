"""The scupper: a louvered steel wall outlet over a brass weir, drawn four ways.

32x32 RGBA, 20 frames. Each face is drawn on the wall tile itself, at the edge beside
the room, so its sprite row displaces it one whole tile (+-32 px). Tags: idle-<dir>
(1 frame) and draining-<dir> (4 frames), dir n/s/e/w. Layers, bottom to top:
scupper_housing (static), drain_flow (animated), bars_and_trim (static).
"""

from __future__ import annotations

from typing import Any

EMPTY_FRAME: list[str] = ["." * 32 for _ in range(32)]

TAGS: list[dict[str, Any]] = [
    {"name": "idle-n", "from": 1, "to": 1},
    {"name": "idle-s", "from": 2, "to": 2},
    {"name": "idle-e", "from": 3, "to": 3},
    {"name": "idle-w", "from": 4, "to": 4},
    {"name": "draining-n", "from": 5, "to": 8},
    {"name": "draining-s", "from": 9, "to": 12},
    {"name": "draining-e", "from": 13, "to": 16},
    {"name": "draining-w", "from": 17, "to": 20},
]

DURATIONS: list[int] = [100, 100, 100, 100] + [200] * 16

# Subdued dark water palette (strictly inside recessed <36-luma open throat slots)
WATER_MASTER_LEGEND: dict[str, str] = {
    "z": "M2",   # #212330 deep dark wet ripple (Y=35.0)
    "m": "MB1",  # #1a3a48 dark bilge water (Y=51.3)
    "t": "AT1",  # #2a6b62 subdued murky teal water (Y=91.5)
    "a": "G1",   # #4a687b muted slate water meniscus (Y=99.8)
}


def place(x0: int, y0: int, sub_rows: list[str]) -> list[str]:
    """Paste a rectangular character grid at (x0, y0) onto a 32x32 '.' canvas."""
    if not sub_rows:
        return list(EMPTY_FRAME)
    h = len(sub_rows)
    w = len(sub_rows[0])
    for idx, r in enumerate(sub_rows):
        if len(r) != w:
            raise ValueError(f"Row {idx} width {len(r)} != expected {w}: {r!r}")
    if not (0 <= x0 and x0 + w <= 32 and 0 <= y0 and y0 + h <= 32):
        raise ValueError(f"Sub-grid {w}x{h} at ({x0},{y0}) overflows 32x32 canvas")
    canvas = [["." for _ in range(32)] for _ in range(32)]
    for dy, r in enumerate(sub_rows):
        for dx, ch in enumerate(r):
            if ch != ".":
                canvas[y0 + dy][x0 + dx] = ch
    return ["".join(row) for row in canvas]


def mirror_x(frame_rows: list[str]) -> list[str]:
    """Mirror a 32x32 frame across X (preserving Y top-down north lighting)."""
    return [r[::-1] for r in frame_rows]


def static_20_frames(
    f_north: list[str],
    f_south: list[str],
    f_east: list[str],
    f_west: list[str],
) -> list[list[str]]:
    """Assemble 20 frames for static layers: N, S, E, W + 4 verbatim repeats per draining tag."""
    return (
        [f_north, f_south, f_east, f_west]
        + [f_north] * 4
        + [f_south] * 4
        + [f_east] * 4
        + [f_west] * 4
    )


def anim_20_frames(
    n_flow: list[list[str]],
    s_flow: list[list[str]],
    e_flow: list[list[str]],
    w_flow: list[list[str]] | None = None,
) -> list[list[str]]:
    """Assemble 20 frames for drain_flow: empty on f1..f4, then N, S, E, W 4-frame active loops."""
    if len(n_flow) != 4 or len(s_flow) != 4 or len(e_flow) != 4:
        raise ValueError("Each directional draining loop must have exactly 4 frames")
    wf = w_flow if w_flow is not None else [mirror_x(fr) for fr in e_flow]
    if len(wf) != 4:
        raise ValueError("west_draining loop must have 4 frames")
    return [EMPTY_FRAME] * 4 + n_flow + s_flow + e_flow + wf


def make_layer(name: str, animated: bool, master_legend: dict[str, str], frames: list[list[str]]) -> dict[str, Any]:
    """Build a layer dict with its legend pruned strictly to tokens present in frames."""
    used = sorted({ch for fr in frames for row in fr for ch in row if ch != "."})
    missing = [ch for ch in used if ch not in master_legend]
    if missing:
        raise KeyError(f"Layer {name!r} uses undefined legend keys: {missing}")
    return {
        "name": name,
        "animated": animated,
        "legend": {ch: master_legend[ch] for ch in used},
        "frames": frames,
    }


# ==============================================================================
# Louvered wall outlet and brass sill, wall-parallel on all four faces.
#     19px span (6..24, odd pipe center 15) on all 4 directions:
#       - North (f1): 19x15 at (6, 17); two 11px horizontal M1 slits at x=10..20, y=19 & y=21
#       - South (f2): 19x14 at (6,  0); two 11px horizontal M1 slits at x=10..20, y=7  & y=9
#       - East  (f3): 14x19 at (0,  6); two 11px vertical   M1 slits at y=10..20, x=8  & x=10
#       - West  (f4): 14x19 at (18, 6); two 11px vertical   M1 slits at y=10..20, x=21 & x=23
#     Unified 19px 4-slot brass weir (2+2+2+2+3+2+2+2+2):
#       cheeks=6..7,23..24 | open slots=8..9,12..13,17..18,21..22 | bars=10..11, 14..16(center 15), 19..20
# ==============================================================================
LEGEND = {
    "2": "S2", "3": "S3", "4": "S4", "5": "S5",
    "M": "M1", "K": "BLK",
    "d": "WD2", "c": "CK1", "k": "CK2",
}

N_HOUSING = place(6, 17, [
    ".45555555555555554.",
    "3444444444444444443",
    "3444MMMMMMMMMMM4443",
    "3444555555555554443",
    "3444MMMMMMMMMMM4443",
    "3444555555555554443",
    "3444444444444444443",
    "cckkkkkkkkkkkkkkkcc",
    "cdMMMMMMMMMMMMMMMdc",
    "cdKKKKKKKKKKKKKKKdc",
    "cdKKKKKKKKKKKKKKKdc",
    "cdKKKKKKKKKKKKKKKdc",
    "cdMMMMMMMMMMMMMMMdc",
    "2ccdddddddddddddcc2",
    ".22222222222222222.",
])

S_HOUSING = place(6, 0, [
    ".cckkkkkkkkkkkkkcc.",
    "ccdcccccccccccccdcc",
    "cdKKKKKKKKKKKKKKKdc",
    "cdMMMMMMMMMMMMMMMdc",
    "ccdcccccccccccccdcc",
    "4555555555555555554",
    "3455555555555555543",
    "3444MMMMMMMMMMM4443",
    "3444555555555554443",
    "3344MMMMMMMMMMM4433",
    "3344444444444444433",
    "3344444444444444433",
    "2333333333333333332",
    ".22222222222222222.",
])

E_HOUSING = place(0, 6, [
    ".cckkk5555554.",
    "ckkcc555555554",
    "ckKKM544444444",
    "ckKKM544444443",
    "ccKKM444M5M543",
    "ccKKM444M5M543",
    "ccKKM444M5M543",
    "ccKKM444M5M543",
    "ccKKM444M5M543",
    "ccKKM444M5M543",
    "cdKKM444M4M443",
    "cdKKM444M4M443",
    "cdKKM444M4M443",
    "cdKKM433M4M433",
    "ddKKM433M4M433",
    "ddKKM333333332",
    "ddKKM333333322",
    "2dddc233333322",
    ".222222222222.",
])
W_HOUSING = mirror_x(E_HOUSING)

N_TRIM = place(6, 17, [
    "...................",
    "..22...........22..",
    "...................",
    "...................",
    "...................",
    "...................",
    "..22...........22..",
    "...................",
    "....kk..kkk..kk....",
    "....kk..kkk..kk....",
    "....cc..ccc..cc....",
    "....cc..ccc..cc....",
    "....dd..ddd..dd....",
    "...................",
    "...................",
])

S_TRIM = place(6, 0, [
    "...................",
    "...................",
    "....kk..kkk..kk....",
    "....cc..ccc..cc....",
    "...................",
    "...................",
    "..22...........22..",
    "...................",
    "...................",
    "...................",
    "...................",
    "..22...........22..",
    "...................",
    "...................",
])

E_TRIM = place(0, 6, [
    "..............",
    "..............",
    ".......2...2..",
    "..............",
    "..kkk.........",
    "..kcc.........",
    "..............",
    "..............",
    "..kkk.........",
    "..ccc.........",
    "..ddd.........",
    "..............",
    "..............",
    "..ccc.........",
    "..ddd.........",
    ".......2...2..",
    "..............",
    "..............",
    "..............",
])
W_TRIM = mirror_x(E_TRIM)

# Strictly inside the 4 open 2px vertical throat slots: dx in {2..3, 6..7, 11..12, 15..16} (x=8..9, 12..13, 17..18, 21..22), dy=9..12
N_FLOW = [
    place(6, 17, [
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "..mm...........mm..",
        "..tt..mm...mm..tt..",
        "..aa..tt...tt..aa..",
        "..zz..aa...aa..zz..",
        "...................",
        "...................",
    ]),
    place(6, 17, [
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "......mm...mm......",
        "..mm..tt...tt..mm..",
        "..tt..aa...aa..tt..",
        "..aa..zz...zz..aa..",
        "...................",
        "...................",
    ]),
    place(6, 17, [
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "..zm...........mz..",
        "..aa..zm...mz..aa..",
        "..tt..aa...aa..tt..",
        "..mm..tt...tt..mm..",
        "...................",
        "...................",
    ]),
    place(6, 17, [
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "......zm...mz......",
        "..zz..aa...aa..zz..",
        "..mm..tt...tt..mm..",
        "..tt..mm...mm..tt..",
        "...................",
        "...................",
    ]),
]

# Strictly inside the 4 open 2px vertical throat slots on South: dx in {2..3, 6..7, 11..12, 15..16}, dy=2..3
S_FLOW = [
    place(6, 0, [
        "...................",
        "...................",
        "..aa..zz...zz..aa..",
        "..tt..mm...mm..tt..",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
    ]),
    place(6, 0, [
        "...................",
        "...................",
        "..zz..aa...aa..zz..",
        "..mm..tt...tt..mm..",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
    ]),
    place(6, 0, [
        "...................",
        "...................",
        "..tt..mm...mm..tt..",
        "..zm...........mz..",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
    ]),
    place(6, 0, [
        "...................",
        "...................",
        "..mm..tt...tt..mm..",
        "......zm...mz......",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
        "...................",
    ]),
]

# Strictly inside the 4 open 3x2 horizontal throat slots: dx=2..4, dy in {2..3, 6..7, 11..12, 15..16} (y=8..9, 12..13, 17..18, 21..22)
E_FLOW = [
    place(0, 6, [
        "..............",
        "..............",
        "..atm.........",
        "..tzm.........",
        "..............",
        "..............",
        "...mm.........",
        "..atm.........",
        "..............",
        "..............",
        "..............",
        "..tzm.........",
        "...zm.........",
        "..............",
        "..............",
        "..atm.........",
        "..............",
        "..............",
        "..............",
    ]),
    place(0, 6, [
        "..............",
        "..............",
        "...zm.........",
        "..atm.........",
        "..............",
        "..............",
        "..atm.........",
        "..tzm.........",
        "..............",
        "..............",
        "..............",
        "...mm.........",
        "..atm.........",
        "..............",
        "..............",
        "..tzm.........",
        "...mm.........",
        "..............",
        "..............",
    ]),
    place(0, 6, [
        "..............",
        "..............",
        "..tzm.........",
        "...mm.........",
        "..............",
        "..............",
        "..tzm.........",
        "...zm.........",
        "..............",
        "..............",
        "..............",
        "..atm.........",
        "..tzm.........",
        "..............",
        "..............",
        "...zm.........",
        "..atm.........",
        "..............",
        "..............",
    ]),
    place(0, 6, [
        "..............",
        "..............",
        "..............",
        "..tzm.........",
        "..............",
        "..............",
        "...zm.........",
        "..atm.........",
        "..............",
        "..............",
        "..............",
        "..tzm.........",
        "...mm.........",
        "..............",
        "..............",
        "..atm.........",
        "..tzm.........",
        "..............",
        "..............",
    ]),
]

SPEC: dict[str, Any] = {
    "name": "scupper",
    "title": "Scupper",
    "kind": "scupper",
    "blurb": "Pipe-centered (x/y=15) Structure Steel wall outlet with 2x11px wall-parallel louvers (horizontal on N/S, vertical on E/W) over a 4-slot brass weir.",
    "design_notes": "19x15 N, 19x14 S, 14x19 E/W centered on pixel 15. Two 11px M1 slits run parallel to the wall on all four faces, as tg's 4-dir wallmounts do.",
    "width": 32,
    "height": 32,
    "frame_count": 20,
    "frame_durations_ms": DURATIONS,
    "tags": TAGS,
    "layers": [
        make_layer(
            "scupper_housing",
            False,
            LEGEND,
            static_20_frames(N_HOUSING, S_HOUSING, E_HOUSING, W_HOUSING),
        ),
        make_layer(
            "drain_flow",
            True,
            WATER_MASTER_LEGEND,
            anim_20_frames(N_FLOW, S_FLOW, E_FLOW),
        ),
        make_layer(
            "bars_and_trim",
            False,
            LEGEND,
            static_20_frames(N_TRIM, S_TRIM, E_TRIM, W_TRIM),
        ),
    ],
}
