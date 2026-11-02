"""The floor drain: a flush steel collar round a recessed tarnished-brass grate.

32x32 RGBA, 5 frames at [100, 200, 200, 200, 200] ms. Tags: idle (1), draining (2..5).
Layers, bottom to top: collar_and_sump (static), drain_flow (animated), grille_bars
(static). The rules are docs/art-reference/drainage-asset-guide.md.
"""

from __future__ import annotations

from typing import Any

EMPTY_32: list[str] = ["." * 32 for _ in range(32)]


def pad_to_32(rows: list[str], x0: int, y0: int) -> list[str]:
    h = len(rows)
    assert h > 0, "Empty block"
    w = len(rows[0])
    for idx, r in enumerate(rows):
        if len(r) != w:
            raise ValueError(f"Row {idx} length {len(r)} != {w}: {r!r}")
    assert x0 >= 0 and y0 >= 0 and x0 + w <= 32 and y0 + h <= 32
    top = ["." * 32 for _ in range(y0)]
    mid = [("." * x0) + r + ("." * (32 - x0 - w)) for r in rows]
    bot = ["." * 32 for _ in range(32 - y0 - h)]
    out = top + mid + bot
    assert len(out) == 32 and all(len(line) == 32 for line in out)
    return out


# Subdued dark water palette inside BLK/M1 apertures:
#   d = M2  (#212330, Y=35.5 — dark slate wake)
#   b = MB1 (#1a3a48, Y=52.2 — subdued deep blue-teal water body)
#   g = G1  (#4a687b, Y=99.0 — sparse upper-slot meniscus glint)
FLOW_LEGEND: dict[str, str] = {
    "d": "M2",
    "b": "MB1",
    "g": "G1",
}

FRAME_DURATIONS: list[int] = [100, 200, 200, 200, 200]
TAGS: list[dict[str, Any]] = [
    {"name": "idle", "from": 1, "to": 1},
    {"name": "draining", "from": 2, "to": 5},
]



COLLAR = pad_to_32(
    [
        "......2222222......",  # r0  (7)  crisp S2 straight north edge
        "....33555555533....",  # r1  (11) S3 diag bevel + calm flat S5 ring
        "...3555555555553...",  # r2  (13)
        "..3554eeeeeee4553..",  # r3  (15) EY1 recessed dark tarnished-brass seat
        ".3554eMMMMMMMe4553.",  # r4  (17) M1 top aperture shadow (c6..12)
        ".3554eKKKKKKKe4553.",  # r5  (17) (c6..12)
        "255eKKKKKKKKKKKe552",  # r6  (19) full 11px sump span (c4..14)
        "255eMMKKKKKKKMMe552",  # r7  (19)
        "254eKKKKKKKKKKKe452",  # r8  (19)
        "233eKKKKKKKKKKKe332",  # r9  (19) paired 2px E/W flush seating keyways
        "244eKKKKKKKKKKKe442",  # r10 (19)
        "245eKKKKKKKKKKKe542",  # r11 (19)
        "245eKKKKKKKKKKKe542",  # r12 (19)
        ".3454eKKKKKKKe4543.",  # r13 (17) (c6..12)
        ".3444eKKKKKKKe4443.",  # r14 (17) (c6..12)
        "..3444eeeeeee4443..",  # r15 (15) EY1 lower brass seat crease
        "...3445555555443...",  # r16 (13) flat S5/S4 lower steel face
        "....33444444433....",  # r17 (11) S3 diag bevel
        "......2222222......",  # r18 (7)  crisp S2 straight south edge
    ],
    x0=6,
    y0=6,
)

# Tarnished-brass 3x3 orthogonal cross-grid:
#   c = CK2 (#8c855f, Y=131.7 — flat tarnished khaki-brass top face)
#   w = WD4 (#a07c59, Y=128.9 — warm brushed bronze-brass mid face)
#   k = CK1 (#635c3f, Y=91.4  — muted olive-brass bevel)
#   u = WD2 (#70533b, Y=87.6  — shaded bronze-brass bar ends)
GRILLE = pad_to_32(
    [
        "...................",  # r0
        "...................",  # r1
        "...................",  # r2
        "...................",  # r3
        "......w..c..w......",  # r4
        "......w..c..w......",  # r5
        "....kwcccccccwk....",  # r6  horizontal brass bar 1 (flat CK2/WD4)
        "......w..c..w......",  # r7
        "......w..w..w......",  # r8
        "....kwwwwcwwwwk....",  # r9  horizontal brass bar 2 (warm WD4/CK2)
        "......k..w..k......",  # r10
        "......k..k..k......",  # r11
        "....ukkkkkkkkku....",  # r12 horizontal brass bar 3 (subdued CK1/WD2)
        "......k..k..k......",  # r13
        "......u..k..u......",  # r14
        "...................",  # r15
        "...................",  # r16
        "...................",  # r17
        "...................",  # r18
    ],
    x0=6,
    y0=6,
)

# Phase-shifted coherent 2x1 horizontal water cascade (32 animated px)
FLOW_FRAMES = [
    EMPTY_32,
    # Frame 2 (16 px)
    pad_to_32(
        [
            "...................",
            "...................",
            "...................",
            "...................",
            "...................",  # r4
            ".......db.bd.......",  # r5:  top cells wake
            "...................",  # r6:  bar
            ".......bg.gb.......",  # r7:  emerged at top of central upper-mid cells
            "....dd.......dd....",  # r8:  outer wake
            "...................",  # r9:  bar
            "....db.bb.bb.bd....",  # r10: emerged across lower-mid cells
            "...................",  # r11
            "...................",  # r12: bar
            "...................",  # r13
            "...................",  # r14
            "...................",
            "...................",
            "...................",
            "...................",
        ],
        x0=6,
        y0=6,
    ),
    # Frame 3 (16 px)
    pad_to_32(
        [
            "...................",
            "...................",
            "...................",
            "...................",
            "...................",  # r4
            "...................",  # r5
            "...................",  # r6:  bar
            ".......db.bd.......",  # r7:  wake in central upper-mid cells
            ".......bg.gb.......",  # r8:  stepped to bottom of central upper-mid cells
            "...................",  # r9:  bar
            "....dd.......dd....",  # r10: outer wake
            ".......bb.bb.......",  # r11: stepped to bottom of central lower-mid cells
            "...................",  # r12: bar
            ".......db.bd.......",  # r13: emerged at top of bottom cells
            "...................",  # r14
            "...................",
            "...................",
            "...................",
            "...................",
        ],
        x0=6,
        y0=6,
    ),
    # Frame 4 (16 px)
    pad_to_32(
        [
            "...................",
            "...................",
            "...................",
            "...................",
            "...................",  # r4
            ".......db.bd.......",  # r5:  fresh intake at top cells
            "...................",  # r6:  bar
            ".......dd.dd.......",  # r7:  intake in central upper-mid cells
            "....db.bb.bb.bd....",  # r8:  rebuilding across upper-mid row
            "...................",  # r9:  bar
            ".......bd.db.......",  # r10: central lower-mid wake
            "...................",  # r11
            "...................",  # r12: bar
            ".......bb.bb.......",  # r13: bottom cells draining out
            "...................",  # r14
            "...................",
            "...................",
            "...................",
            "...................",
        ],
        x0=6,
        y0=6,
    ),
    # Frame 5 (16 px)
    pad_to_32(
        [
            "...................",
            "...................",
            "...................",
            "...................",
            "...................",  # r4
            ".......bg.gb.......",  # r5:  top cells meniscus
            "...................",  # r6:  bar
            "...................",  # r7
            "....db.bb.bb.bd....",  # r8:  upper-mid cells
            "...................",  # r9:  bar
            "...................",  # r10
            ".......db.bd.......",  # r11: lower-mid central cells
            "...................",  # r12: bar
            ".......dd.dd.......",  # r13: bottom cells wake
            "...................",  # r14
            "...................",
            "...................",
            "...................",
            "...................",
        ],
        x0=6,
        y0=6,
    ),
]


SPEC: dict[str, Any] = {
    "name": "floor_drain",
    "title": "Floor Drain",
    "kind": "floor_drain",
    "width": 32,
    "height": 32,
    "blurb": "19x19 flat Structure Steel flush collar framing a recessed matte tarnished-brass 3x3 orthogonal cross-grid (CK1/CK2/WD4/WD2) over 12 crisp 2x2 sump apertures.",
    "design_notes": "A 2x2 waffle grid in weathered tarnished brass inside a calm S2..S5 steel deck collar.",
    "frame_count": 5,
    "frame_durations_ms": FRAME_DURATIONS,
    "tags": TAGS,
    "layers": [
        {
            "name": "collar_and_sump",
            "animated": False,
            "legend": {
                "2": "S2",
                "3": "S3",
                "4": "S4",
                "5": "S5",
                "e": "EY1",
                "M": "M1",
                "K": "BLK",
            },
            "rows": COLLAR,
        },
        {
            "name": "drain_flow",
            "animated": True,
            "legend": FLOW_LEGEND,
            "frames": FLOW_FRAMES,
        },
        {
            "name": "grille_bars",
            "animated": False,
            "legend": {
                "c": "CK2",
                "w": "WD4",
                "k": "CK1",
                "u": "WD2",
            },
            "rows": GRILLE,
        },
    ],
}


def _assert_flow_invariants() -> None:
    """Verify zero collar bleed, zero isolated 1px water dots, and clean flow counts."""
    for sp in (SPEC,):
        collar = sp["layers"][0]["rows"]
        flow_frames = sp["layers"][1]["frames"]
        grille = sp["layers"][2]["rows"]
        assert flow_frames[0] == EMPTY_32, f"{sp['name']}: f1 idle flow must be empty"
        changed_visible: set[tuple[int, int]] = set()
        for fi in range(1, 5):
            vis_pts: set[tuple[int, int]] = set()
            for y in range(32):
                for x in range(32):
                    ch = flow_frames[fi][y][x]
                    if ch != ".":
                        if collar[y][x] not in ("K", "M"):
                            raise AssertionError(
                                f"{sp['name']} f{fi+1} ({x},{y}): flow pixel {ch!r} hit collar {collar[y][x]!r}!"
                            )
                        if grille[y][x] != ".":
                            raise AssertionError(
                                f"{sp['name']} f{fi+1} ({x},{y}): flow pixel {ch!r} hidden under grille {grille[y][x]!r}!"
                            )
                        vis_pts.add((x, y))
                    if grille[y][x] == "." and fi > 1:
                        if flow_frames[fi][y][x] != flow_frames[1][y][x]:
                            changed_visible.add((x, y))
            for x, y in vis_pts:
                has_ortho_nb = any(
                    (x + dx, y + dy) in vis_pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                if not has_ortho_nb:
                    raise AssertionError(
                        f"{sp['name']} f{fi+1} ({x},{y}): isolated 1px water speckle without orthogonal neighbor!"
                    )
            if not (10 <= len(vis_pts) <= 32):
                raise AssertionError(
                    f"{sp['name']} f{fi+1}: visible water pixels {len(vis_pts)} outside [10, 32]"
                )
        if not (12 <= len(changed_visible) <= 44):
            raise AssertionError(
                f"{sp['name']}: animated_px {len(changed_visible)} outside [12, 44]"
            )


_assert_flow_invariants()
