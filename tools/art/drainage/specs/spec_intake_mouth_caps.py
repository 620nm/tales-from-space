"""Intake 5x3 pipe mouth collars (`intake_mouth_caps.aseprite`) for all 5 pipe layers (`l1..l5` x `1=N, 2=S, 4=E, 8=W`).

32x32 RGBA, 20 frames at 100 ms each. Tags: l1_1..l5_8 (frames 1..20).
Single layer: collar (animated). Each frame is a 15px (5x3 or 3x5) collar seated on the
stationary 3px outer hatch curb (0..2 / 29..31); all 20 frames are 100% pairwise disjoint.
"""

from __future__ import annotations

from typing import Any


def _build_collar_frame(ch: int, dbit: int) -> list[str]:
    grid = [["." for _ in range(32)] for _ in range(32)]
    shift = (ch - 3) * 5
    xc = 15 + shift
    yc = 15 - shift

    if dbit == 1:
        for dy, pat in enumerate(("25652", "24542", "23432")):
            for dx, tok in enumerate(pat):
                grid[dy][xc - 2 + dx] = tok
    elif dbit == 2:
        for dy, pat in enumerate(("25652", "24542", "23432")):
            for dx, tok in enumerate(pat):
                grid[29 + dy][xc - 2 + dx] = tok
    elif dbit == 4:
        for dy, pat in enumerate(("222", "565", "454", "343", "222")):
            for dx, tok in enumerate(pat):
                grid[yc - 2 + dy][29 + dx] = tok
    elif dbit == 8:
        for dy, pat in enumerate(("222", "565", "454", "343", "222")):
            for dx, tok in enumerate(pat):
                grid[yc - 2 + dy][dx] = tok
    else:
        raise ValueError(f"Unsupported dbit: {dbit}")

    return ["".join(row) for row in grid]


def _build_spec() -> dict[str, Any]:
    frames: list[list[str]] = []
    tags: list[dict[str, Any]] = []
    idx = 0
    for ch in range(1, 6):
        for dbit in (1, 2, 4, 8):
            idx += 1
            frames.append(_build_collar_frame(ch, dbit))
            tags.append({"name": f"l{ch}_{dbit}", "from": idx, "to": idx})

    return {
        "name": "intake_mouth_caps",
        "kind": "intake_mouth_caps",
        "title": "Intake Mouth Caps (l1..l5)",
        "width": 32,
        "height": 32,
        "blurb": (
            "20 pairwise-disjoint 5×3 (15px) pipe mouth collars seated on the stationary 3px outer "
            "hatch curb across all 5 pipe layers (l1..l5 × N/S/E/W)."
        ),
        "design_notes": (
            "Each 5×3 collar sits flush on the stationary 3px outer hatch curb (y=0..2 on N, y=29..31 on S, "
            "x=29..31 on E, x=0..2 on W) at channel center 15 ± (ch-3)*5, with S2..S6 cylindrical shading and "
            "zero overlap across all 20 simultaneous ports."
        ),
        "frame_count": 20,
        "frame_durations_ms": [100] * 20,
        "tags": tags,
        "layers": [
            {
                "name": "collar",
                "animated": True,
                "legend": {
                    "2": "S2",
                    "3": "S3",
                    "4": "S4",
                    "5": "S5",
                    "6": "S6",
                },
                "frames": frames,
            },
        ],
    }


SPEC = _build_spec()
