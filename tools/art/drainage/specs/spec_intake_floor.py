"""The intake seen from above, in the floor it sits in (`intake_floor.aseprite`).

32x32 RGBA, 12 frames at 100 ms each, frame-locked with `intake_ceiling`. Tags name the
head's position: lowered (1), raising (2..6), raised (7), lowering (8..12).
Layers, bottom to top: hatch_frame (static), hatch_cover (animated), head (animated).
Pixels come from the `spec_intake_vault` (hatch) and `spec_intake_head` libraries.
"""

from __future__ import annotations

from pathlib import Path
import sys
from typing import Any

_SPECS_DIR = str(Path(__file__).resolve().parent)
if _SPECS_DIR not in sys.path:
    sys.path.insert(0, _SPECS_DIR)

import spec_intake_head  # noqa: E402
import spec_intake_vault  # noqa: E402


def _palette_grid(layers: list[dict[str, Any]], frame_idx: int) -> list[list[str | None]]:
    grid: list[list[str | None]] = [[None for _ in range(32)] for _ in range(32)]
    for layer in layers:
        leg = layer["legend"]
        rows = layer["frames"][frame_idx] if "frames" in layer else layer["rows"]
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    grid[y][x] = leg[ch]
    return grid


def _build_spec() -> dict[str, Any]:
    frame_layer, cover_layer = spec_intake_vault.SPEC["layers"]
    head_grid = _palette_grid(spec_intake_head.SPEC["layers"], 0)

    frame_grid = _palette_grid([frame_layer], 0)
    cover_grids = [_palette_grid([cover_layer], ci) for ci in range(4)]

    all_cols: list[str] = []
    for g in (frame_grid, *cover_grids, head_grid):
        for row in g:
            for col in row:
                if col is not None and col not in all_cols:
                    all_cols.append(col)

    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    if len(all_cols) > len(alphabet):
        raise ValueError(f"Too many combined colors: {len(all_cols)}")
    tok_by_col = {col: alphabet[i] for i, col in enumerate(all_cols)}
    legend = {alphabet[i]: col for i, col in enumerate(all_cols)}

    def encode_grid(grid: list[list[str | None]]) -> list[str]:
        return ["".join("." if col is None else tok_by_col[col] for col in row) for row in grid]

    def make_shifted_clipped_head(dy: int | None) -> list[str]:
        out: list[list[str | None]] = [[None for _ in range(32)] for _ in range(32)]
        if dy is None:
            return encode_grid(out)
        for src_y in range(32):
            dst_y = src_y + dy
            if not (0 <= dst_y < 32):
                continue
            for x in range(32):
                col = head_grid[src_y][x]
                if col is None:
                    continue
                max_y = spec_intake_vault.shaft_south_max_y(x)
                if max_y >= 0 and dst_y <= max_y:
                    out[dst_y][x] = col
        return encode_grid(out)

    # 12-frame choreography: (cover_frame_idx, head_dy_or_None)
    choreography: list[tuple[int, int | None]] = [
        (0, None),  # f1:  lowered — bisected cover closed & locked (horizontal cam-bar)
        (1, None),  # f2:  raising 1 — cam-bar rotates 90° vertical & center seam cracks open (dx = 2)
        (2, None),  # f3:  raising 2 — cover leaves slide halfway into side pockets (dx = 7)
        (3, 13),    # f4:  raising 3 — cover fully open (dx = 12); 3/4 head cap emerges (dy = +13)
        (3, 7),     # f5:  raising 4 — 3/4 head rises through the open shaft (dy = +7)
        (3, 2),     # f6:  raising 5 — 3/4 head settling into its raised lock (dy = +2)
        (3, 0),     # f7:  raised — dry 3/4 head fully up above the open hatch (dy = 0)
        (3, 5),     # f8:  lowering 1 — head begins receding (dy = +5, cover stays wide open)
        (3, 11),    # f9:  lowering 2 — head cap sinks into the open hexagonal shaft (dy = +11)
        (3, None),  # f10: lowering 3 — head fully below the floor (dy = None, open dark shaft)
        (2, None),  # f11: lowering 4 — bisected cover slides half-closed (dx = 7)
        (1, None),  # f12: lowering 5 — cover meets at center & cam twists shut (dx = 2 -> f1)
    ]

    frame_rows = encode_grid(frame_grid)
    cover_layer_frames = [encode_grid(cover_grids[c_idx]) for c_idx, _ in choreography]
    head_layer_frames = [make_shifted_clipped_head(dy) for _, dy in choreography]

    def layer_legend(frames: list[list[str]]) -> dict[str, str]:
        used = {ch for rows in frames for row in rows for ch in row if ch != "."}
        return {k: v for k, v in legend.items() if k in used}

    return {
        "name": "intake_floor",
        "kind": "intake_floor",
        "title": "Intake — Floor Face (z)",
        "width": 32,
        "height": 32,
        "blurb": (
            "Full 32×32 floor face: the top-down orthographic hatch & bisected cover "
            "with the rising/receding 3/4 hexagonal intake head."
        ),
        "design_notes": (
            "Non-colliding two-stage choreography: f1 lowered flush cover (walkable); f2 90° cam-latch unlock; "
            "f3 cover retracts while head remains recessed; f4..f6 3/4 head rises through open throat (dy=+13, +7, +2); "
            "f7 raised head (dy=0, 0 shared boundary hexes with the open hatch); f8..f9 head recedes (dy=+5, +11); "
            "f10..f12 cover slides closed."
        ),
        "frame_count": 12,
        "frame_durations_ms": [100] * 12,
        "tags": [
            {"name": "lowered", "from": 1, "to": 1},
            {"name": "raising", "from": 2, "to": 6},
            {"name": "raised", "from": 7, "to": 7},
            {"name": "lowering", "from": 8, "to": 12},
        ],
        "layers": [
            {
                "name": "hatch_frame",
                "animated": False,
                "legend": layer_legend([frame_rows]),
                "rows": frame_rows,
            },
            {
                "name": "hatch_cover",
                "animated": True,
                "legend": layer_legend(cover_layer_frames),
                "frames": cover_layer_frames,
            },
            {
                "name": "head",
                "animated": True,
                "legend": layer_legend(head_layer_frames),
                "frames": head_layer_frames,
            },
        ],
    }


SPEC = _build_spec()
