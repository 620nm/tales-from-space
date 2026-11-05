"""Lower-level (`z - 1`) undertile ceiling-suspended intake head (`intake_ceiling_below.aseprite`).

32x32 RGBA, 12 frames at 100 ms each. Tags: submerged (1), ascending (2..6), retracted (7), descending (8..12).
Layers, bottom to top: throat_and_floor_shadow, suspended_intake_head, ceiling_collar_and_ram.
"""

from __future__ import annotations

from pathlib import Path
import sys
from typing import Any

_SPECS_DIR = str(Path(__file__).resolve().parent)
if _SPECS_DIR not in sys.path:
    sys.path.insert(0, _SPECS_DIR)

import spec_intake_head  # noqa: E402


def _composite_palette_grid(spec: dict[str, Any], frame_idx: int) -> list[list[str | None]]:
    grid: list[list[str | None]] = [[None for _ in range(32)] for _ in range(32)]
    for layer in spec["layers"]:
        leg = layer["legend"]
        rows = layer["frames"][frame_idx] if "frames" in layer else layer["rows"]
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    grid[y][x] = leg[ch]
    return grid


def _build_spec() -> dict[str, Any]:
    head_spec = spec_intake_head.SPEC
    head_grid = _composite_palette_grid(head_spec, 0)

    c_s1, c_s2, c_s3, c_s4, c_s5, c_s6 = "S1", "S2", "S3", "S4", "S5", "S6"
    c_m1, c_m2, c_blk = "M1", "M2", "BLK"
    c_ck1, c_ck2, c_ck3, c_ey1 = "CK1", "CK2", "CK3", "EY1"

    def build_shadow_and_throat_grid(dy: int) -> list[list[str | None]]:
        """Background layer: 24px (`x = 4..27`) recessed ceiling throat liner (`y = 0..1`) +
        hexagonal floor drop-shadow (`y = 30..31`) beneath clear hover space (`y = 29`).
        """
        g: list[list[str | None]] = [[None for _ in range(32)] for _ in range(32)]

        # 1. Recessed 24px (`x = 4..27`) ceiling shaft throat behind the moving head (`y = 0..1`)
        if dy > -20:
            for x in range(4, 28):
                if x in (4, 27):
                    g[0][x] = c_s2
                    g[1][x] = c_s1
                elif x in (5, 6, 25, 26):
                    g[0][x] = c_m2
                    g[1][x] = c_m1
                elif x in (7, 8, 23, 24):
                    g[0][x] = c_m1
                    g[1][x] = c_m1
                else:
                    g[0][x] = c_blk
                    g[1][x] = c_blk
        else:
            # At `f7` (`dy = -22`), fill `x = 4, 27` seal corners cleanly at `y = 0..1`
            g[0][4] = c_s3
            g[0][27] = c_s3
            g[1][4] = c_s2
            g[1][27] = c_s2
            g[1][5] = c_s2
            g[1][26] = c_s2

        # 2. Shrinking hexagonal cast drop-shadow on the `z - 1` floor (`y = 30..31`)
        if dy >= 0:
            spans = {30: (8, 23), 31: (10, 21)}
        elif dy >= -6:
            spans = {30: (10, 21), 31: (12, 19)}
        elif dy >= -12:
            spans = {30: (12, 19), 31: (13, 18)}
        elif dy >= -17:
            spans = {31: (13, 18)}
        else:
            spans = {}

        for y, (x0, x1) in spans.items():
            for x in range(x0, x1 + 1):
                is_rim = x in (x0, x1) or (y == 31 and x in (x0 + 1, x1 - 1))
                g[y][x] = c_m2 if is_rim else c_m1
        return g

    def build_suspended_head_grid(dy: int) -> list[list[str | None]]:
        """Exact isolated `intake_head` (`x = 4..27, src_y = 3..26`) shifted by `dy` (`dst_y = 0..31`)."""
        out: list[list[str | None]] = [[None for _ in range(32)] for _ in range(32)]
        for src_y in range(32):
            dst_y = src_y + dy
            if 0 <= dst_y < 32:
                for x in range(32):
                    col = head_grid[src_y][x]
                    if col is not None:
                        out[dst_y][x] = col
        return out

    def build_collar_and_ram_grid(dy: int) -> list[list[str | None]]:
        """Foreground stationary bolted collar cheeks (`x = 2..3, 28..29` at `y = 0..2`) +
        central `CK3/CK2/CK1` brass gland & solid `6px` (`x = 13..18`) `S6/S5/S4/S3/S2` hydraulic piston.
        """
        g: list[list[str | None]] = [[None for _ in range(32)] for _ in range(32)]

        # 1. Stationary bolted outer ceiling collar cheeks at x = 2..3 and x = 28..29
        g[0][2], g[0][3] = c_s2, c_ck3
        g[0][28], g[0][29] = c_ck3, c_s2
        g[1][2], g[1][3] = c_s3, c_ck2
        g[1][28], g[1][29] = c_ck2, c_s3
        g[2][3], g[2][28] = c_ck1, c_ck1

        # 2. Central stout 6px cylindrical hydraulic piston (`x = 13..18`) seating into center brass boss (`7 + dy`)
        boss_seat_y = 7 + dy
        if boss_seat_y >= 1:
            gland0 = [c_s2, c_ck3, c_ck2, c_ck2, c_ck1, c_ey1, c_ck1, c_s2]
            for i, col in enumerate(gland0):
                g[0][12 + i] = col

        if boss_seat_y >= 2:
            gland1 = [c_s2, c_ck2, c_ck3, c_ck1, c_ey1, c_ey1, c_s3, c_s2]
            for i, col in enumerate(gland1):
                g[1][12 + i] = col

            shaft_cols = [c_s2, c_s5, c_s6, c_s4, c_s3, c_s2]
            for y in range(2, boss_seat_y):
                for i, col in enumerate(shaft_cols):
                    g[y][13 + i] = col

            base_cols = [c_s4, c_s6, c_s3, c_s2]
            for i, col in enumerate(base_cols):
                g[boss_seat_y][14 + i] = col

        return g

    # Smooth 12-frame loop (`+2, +1, 0, -5, -11, -17, -22, -16, -9, -3, 0, +1`):
    choreography: list[int] = [
        +2,   # f1:  submerged — z cover closed; 3/4th head hovers at y=5..28 over y=30..31 shadow
        +1,   # f2:  z cover cam twists & cracks open; hydraulic ram pre-lifts (+1px to y=4..27)
        0,    # f3:  z cover half-retracted; head rises to y=3..26 just below ceiling throat
        -5,   # f4:  z cover open; head enters 24px (x=4..27) ceiling penetration throat
        -11,  # f5:  head halfway inside 24px ceiling throat; floor shadow shrinks
        -17,  # f6:  grille tucked in; tapered concrete cone entering ceiling collar
        -22,  # f7:  retracted — lower concrete skirt (`src_y=22..26`) seated flush at `y=0..4`
        -16,  # f8:  z head receding; lower skirt & grille emerge from 24px ceiling throat
        -9,   # f9:  z head sinking; cage halfway out on central hydraulic piston
        -3,   # f10: head clears ceiling throat onto z-1 as z shaft opens
        0,    # f11: z bisected cover half-closed; head settling at y=3..26
        +1,   # f12: z bisected cover latching shut; head eases down to y=4..27 (-> f1 y=5..28)
    ]

    bg_grids = [build_shadow_and_throat_grid(dy) for dy in choreography]
    sus_grids = [build_suspended_head_grid(dy) for dy in choreography]
    collar_grids = [build_collar_and_ram_grid(dy) for dy in choreography]

    all_cols: list[str] = []
    for g in (*bg_grids, *sus_grids, *collar_grids):
        for row in g:
            for col in row:
                if col is not None and col not in all_cols:
                    all_cols.append(col)

    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    tok_by_col = {col: alphabet[i] for i, col in enumerate(all_cols)}
    legend = {alphabet[i]: col for i, col in enumerate(all_cols)}

    def encode_grid(grid: list[list[str | None]]) -> list[str]:
        return ["".join("." if col is None else tok_by_col[col] for col in row) for row in grid]

    bg_frames = [encode_grid(g) for g in bg_grids]
    sus_frames = [encode_grid(g) for g in sus_grids]
    collar_frames = [encode_grid(g) for g in collar_grids]

    def layer_legend(frames: list[list[str]]) -> dict[str, str]:
        used = {ch for rows in frames for row in rows for ch in row if ch != "."}
        return {k: v for k, v in legend.items() if k in used}

    return {
        "name": "intake_ceiling_below",
        "kind": "intake_ceiling_below",
        "title": "Intake Head — Undertile Rig (z-1)",
        "width": 32,
        "height": 32,
        "blurb": (
            "Independent 3/4th-perspective undertile view on level z-1 showing the intake head suspended "
            "from a recessed 24px ceiling shaft throat and central 6px hydraulic piston."
        ),
        "design_notes": (
            "Zero dangling chains. Heavy bolted ceiling shaft collar (x=2..29, y=0..4) with 24px recessed throat "
            "(x=4..27), central 6px polished steel/brass hydraulic cylinder (x=13..18), suspended intake head "
            "(dy=+2 submerged down to dy=-22 retracted), and shrinking floor drop-shadow (y=30..31)."
        ),
        "frame_count": 12,
        "frame_durations_ms": [100] * 12,
        "tags": [
            {"name": "submerged", "from": 1, "to": 1},
            {"name": "ascending", "from": 2, "to": 6},
            {"name": "retracted", "from": 7, "to": 7},
            {"name": "descending", "from": 8, "to": 12},
        ],
        "layers": [
            {
                "name": "throat_and_floor_shadow",
                "animated": True,
                "legend": layer_legend(bg_frames),
                "frames": bg_frames,
            },
            {
                "name": "suspended_intake_head",
                "animated": True,
                "legend": layer_legend(sus_frames),
                "frames": sus_frames,
            },
            {
                "name": "ceiling_collar_and_ram",
                "animated": True,
                "legend": layer_legend(collar_frames),
                "frames": collar_frames,
            },
        ],
    }


SPEC = _build_spec()
