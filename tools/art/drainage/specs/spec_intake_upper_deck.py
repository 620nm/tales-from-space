"""Upper-level (`z`) mechanical intake head & top-down vault sequence (`intake_upper_deck.aseprite`).

32x32 RGBA, 12 frames at 100 ms each. Tags: depressed (1), opening (2..6), elevated (7), closing (8..12).
Layers, bottom to top: topdown_vault_and_cover (animated), isolated_intake_head (animated).
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


def _verify_zero_shared_boundary_hexes(
    head_grid: list[list[str | None]],
    vault_f4_grid: list[list[str | None]],
) -> None:
    """Ensure zero boundary pixels between `intake_head` at `dy=0` and `intake_vault` `f4` share identical colors."""
    collisions: list[tuple[int, int, int, int, str]] = []
    for y in range(32):
        for x in range(32):
            hx = head_grid[y][x]
            if hx is None:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 32 and 0 <= ny < 32 and head_grid[ny][nx] is None:
                        vhx = vault_f4_grid[ny][nx]
                        if vhx == hx:
                            collisions.append((x, y, nx, ny, hx))
    if collisions:
        raise AssertionError(
            f"intake_upper_deck f7 boundary collision between intake_head (dy=0) and intake_vault f4: {collisions[:8]}"
        )


def _build_spec() -> dict[str, Any]:
    vault_spec = spec_intake_vault.SPEC
    head_spec = spec_intake_head.SPEC

    vault_grids = [_composite_palette_grid(vault_spec, vi) for vi in range(4)]
    head_grid = _composite_palette_grid(head_spec, 0)

    _verify_zero_shared_boundary_hexes(head_grid, vault_grids[3])

    all_cols: list[str] = []
    for g in (*vault_grids, head_grid):
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

    # 12-frame upper-deck mechanical choreography: (vault_frame_idx, head_dy_or_None)
    choreography: list[tuple[int, int | None]] = [
        (0, None),  # f1:  depressed — bisected top-down cover closed & locked (horizontal cam-bar)
        (1, None),  # f2:  opening 1 — cam-bar rotates 90° vertical & center seam cracks open (dx = 2)
        (2, None),  # f3:  opening 2 — cover leaves slide halfway into side pockets (dx = 7)
        (3, 13),    # f4:  opening 3 — cover fully open (dx = 12); 3/4th head cap emerges (dy = +13)
        (3, 7),     # f5:  opening 4 — 3/4th head rises through open vault shaft (dy = +7)
        (3, 2),     # f6:  opening 5 — 3/4th head settling into raised lock (dy = +2)
        (3, 0),     # f7:  elevated  — dry 3/4th head fully raised above open top-down vault (dy = 0)
        (3, 5),     # f8:  closing 1 — head begins receding (dy = +5, cover stays wide open)
        (3, 11),    # f9:  closing 2 — head cap sinks into open hexagonal shaft (dy = +11)
        (3, None),  # f10: closing 3 — head fully receded below deck (dy = None, open dark shaft)
        (2, None),  # f11: closing 4 — bisected cover slides half-closed (dx = 7)
        (1, None),  # f12: closing 5 — cover meets at center & cam twists shut (dx = 2 -> f1)
    ]

    vault_layer_frames = [encode_grid(vault_grids[v_idx]) for v_idx, _ in choreography]
    head_layer_frames = [make_shifted_clipped_head(dy) for _, dy in choreography]

    def layer_legend(frames: list[list[str]]) -> dict[str, str]:
        used = {ch for rows in frames for row in rows for ch in row if ch != "."}
        return {k: v for k, v in legend.items() if k in used}

    return {
        "name": "intake_upper_deck",
        "kind": "intake_upper_deck",
        "title": "Intake Head — Upper Deck (z)",
        "width": 32,
        "height": 32,
        "blurb": (
            "Full 32×32 upper-deck composition combining the top-down orthographic vault & bisected cover "
            "with the rising/receding 3/4th hexagonal intake head."
        ),
        "design_notes": (
            "Non-colliding two-stage choreography: f1 depressed flush cover (walkable); f2 90° cam-latch unlock; "
            "f3 cover retracts while head remains recessed; f4..f6 3/4th head rises through open throat (dy=+13, +7, +2); "
            "f7 elevated head (dy=0, 0 shared boundary hexes with open vault); f8..f9 head recedes (dy=+5, +11); "
            "f10..f12 cover slides closed."
        ),
        "frame_count": 12,
        "frame_durations_ms": [100] * 12,
        "tags": [
            {"name": "depressed", "from": 1, "to": 1},
            {"name": "opening", "from": 2, "to": 6},
            {"name": "elevated", "from": 7, "to": 7},
            {"name": "closing", "from": 8, "to": 12},
        ],
        "layers": [
            {
                "name": "topdown_vault_and_cover",
                "animated": True,
                "legend": layer_legend(vault_layer_frames),
                "frames": vault_layer_frames,
            },
            {
                "name": "isolated_intake_head",
                "animated": True,
                "legend": layer_legend(head_layer_frames),
                "frames": head_layer_frames,
            },
        ],
    }


SPEC = _build_spec()
