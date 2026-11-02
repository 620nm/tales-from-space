#!/usr/bin/env python3
"""Validator and Aseprite MCP exporter for the drainage fixture sprites.

Each spec in `specs/` is one source under `assets/originals/art/machines/drainage/`. An
existing source is exported and validated as it stands; a missing one is drawn from its
spec, and `--rebuild-sources` redraws them all. Generated files land in the pack's
gitignored `target/art/drainage/`; the rules are
docs/art-reference/drainage-asset-guide.md.
"""

from __future__ import annotations

import argparse
import asyncio
from collections import deque
from contextlib import asynccontextmanager
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys
from typing import Any

from PIL import Image, ImageFont

# tools/art/drainage/drainage_kit.py -> the pack root is three levels up.
PACK_ROOT = Path(__file__).resolve().parents[3]
DRAINAGE_DIR = Path(__file__).resolve().parent
OUT_ROOT = PACK_ROOT / "target/art/drainage"
SOURCE_DIR = PACK_ROOT / "assets/originals/art/machines/drainage"
GPL_PATH = PACK_ROOT / "docs/art-reference/palettes/tales-from-space.gpl"
TTF_FONT_PATH = os.environ.get("DRAINAGE_FONT", "/usr/share/fonts/noto/NotoSansMono-Regular.ttf")
FIXTURES: tuple[str, ...] = ("floor_drain", "scupper", "sump_pump")


def aseprite_binary() -> str:
    """`ASEPRITE_PATH`, else `aseprite` on PATH."""
    found = os.environ.get("ASEPRITE_PATH") or shutil.which("aseprite")
    if not found:
        raise RuntimeError("aseprite not found: set ASEPRITE_PATH or put aseprite on PATH")
    return found


def mcp_python_and_repo() -> tuple[str, str | None]:
    """The interpreter that runs `aseprite_mcp`, and the checkout to put on its PYTHONPATH."""
    repo = os.environ.get("ASEPRITE_MCP_REPO")
    python = os.environ.get("ASEPRITE_MCP_PYTHON")
    if not python and repo:
        venv = Path(repo) / ".venv" / "bin" / "python"
        python = str(venv) if venv.exists() else None
    return python or sys.executable, repo


def tg_root() -> Path:
    """The tgstation checkout: `LUNATIC_TG`, else a `tgstation` sibling of the pack."""
    candidates = [Path(os.environ["LUNATIC_TG"])] if os.environ.get("LUNATIC_TG") else []
    candidates.append(PACK_ROOT.parent / "tgstation")
    candidates.append(PACK_ROOT.parents[2] / "tgstation")
    for cand in candidates:
        if (cand / "icons").is_dir():
            return cand
    raise RuntimeError("no tgstation checkout: set LUNATIC_TG")


def load_ui_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    if os.path.exists(TTF_FONT_PATH):
        return ImageFont.truetype(TTF_FONT_PATH, size=size)
    return ImageFont.load_default(size=size)


def load_tfs_gpl(path: Path = GPL_PATH) -> tuple[dict[str, str], dict[str, str]]:
    by_name: dict[str, str] = {}
    by_hex: dict[str, str] = {}
    with path.open(encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith(("GIMP Palette", "Name:", "Columns:", "#")):
                continue
            m = re.match(r"^(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(#[0-9a-fA-F]{6})$", line)
            if not m:
                raise ValueError(f"Unparsed .gpl line: {raw!r}")
            r, g, b, sw_name, hx = m.groups()
            hx_low = hx.lower()
            calc = f"#{int(r):02x}{int(g):02x}{int(b):02x}"
            if calc != hx_low:
                raise ValueError(f"RGB mismatch on {sw_name}: {calc} != {hx_low}")
            by_name[sw_name] = hx_low
            by_hex[hx_low] = sw_name
    return by_name, by_hex


SWATCH_BY_NAME, NAME_BY_HEX = load_tfs_gpl()

P: dict[str, str] = {
    # Set 1 - Structure steel (8)
    "S1": "#26262c", "S2": "#353841", "S3": "#474851", "S4": "#565a63",
    "S5": "#777b83", "S6": "#a2a9b1", "S7": "#c6cdd3", "S8": "#e1e7ea",
    # Set 2 - Machine steel, navy-tinted (8)
    "M1": "#151824", "M2": "#212330", "M3": "#373a4b", "M4": "#474a5b",
    "M5": "#606375", "M6": "#9497ab", "M7": "#c5c7d4", "M8": "#d5d7e0",
    # Set 3 - Neutral steel (8)
    "N1": "#1d1d1d", "N2": "#2b2b2b", "N3": "#444444", "N4": "#626262",
    "N5": "#929292", "N6": "#aaaaaa", "N7": "#c4c4c4", "N8": "#d9d9d9",
    # Set 4 - Industrial copper/brass (5) & dark rubber/polymer (3)
    "CU1": "#3b1d11", "CU2": "#6e371e", "CU3": "#a45729", "CU4": "#d4803d", "CU5": "#f0b06e",
    "RB1": "#201d26", "RB2": "#35313e", "RB3": "#4f4a5a",
    # Set 5 - Panel glass (3), black, whites & paper (5)
    "G1": "#4a687b", "G2": "#7498ad", "G3": "#a4bac6",
    "BLK": "#0a0a0d", "NW": "#eeeeee", "W": "#ffffff",
    "PPR": "#f1ead4", "INK": "#202c2d",
    # Set 6 - Wood (4) & ceramic beige (3)
    "WD1": "#3a2314", "WD2": "#70533b", "WD3": "#805f44", "WD4": "#a07c59",
    "CE1": "#6b5d4d", "CE2": "#968471", "CE3": "#bfb09c",
    # Set 7 - Safety paint (8)
    "SD1": "#1b1b1b", "SD2": "#262626",
    "CP1": "#b5b92b", "CP2": "#d2d53d",
    "FR1": "#4f011c", "FR2": "#8c0522", "FR3": "#ad2931", "FR4": "#c61326",
    # Set 8 - Signals & emissives (11)
    "SIG_G": "#50ff31", "SIG_C": "#ffd60e", "SIG_L": "#ffff33", "SIG_F": "#ff441b",
    "SCR_C": "#00ccff", "SCR_L": "#8cd6fd", "SCR_G": "#80ffff",
    "PG1": "#c93cff", "PG2": "#f08cff",
    "BG1": "#2667d1", "BG2": "#65b4ff",
    # Set 9 - Leadership gold (subdued steps 1..3 for tarnished bronze/brass)
    "GL1": "#5c3b14", "GL2": "#8c5a1c", "GL3": "#ba7d30",
    # Set 10 - Command blue (5)
    "CB1": "#172a40", "CB2": "#1f4670", "CB3": "#1b67a5", "CB4": "#3d8bcb", "CB5": "#82bde6",
    # Set 13 - Medical blue (5) & sterile white (3)
    "MB1": "#1a3a48", "MB2": "#2d6f8c", "MB3": "#4ea3c4", "MB4": "#85cbe3", "MB5": "#c4eaf5",
    "MW1": "#a5a9b6", "MW2": "#cbcdd1", "MW3": "#f2f4f7",
    # Set 15 - Engineering yellow (5), safety orange (3), atmos teal (3)
    "EY1": "#3e3510", "EY2": "#8c7614", "EY3": "#d9c21a", "EY4": "#f5e04a", "EY5": "#fff3a6",
    "EO1": "#a63a16", "EO2": "#d15b1b", "EO3": "#f08a45",
    "AT1": "#2a6b62", "AT2": "#469085", "AT3": "#7cc4b6",
    # Set 16 - Service linen (1, matte pale brass edge)
    "SL1": "#b5a685",
    # Set 17 - Cargo russet & khaki
    "CR1": "#2e1810", "CR2": "#57301f", "CR3": "#824b32", "CR4": "#a8694a", "CR5": "#cf9c80",
    "CK1": "#635c3f", "CK2": "#8c855f", "CK3": "#b8b28e",
}

HARD_DARK_OUTER_SWATCHES: set[str] = {
    sw for sw in NAME_BY_HEX.values()
    if sw.endswith("-1-outline") or sw in ("black", "paper-ink", "stripe-dark-1", "stripe-dark-2")
}

# The "flatter and subdued, like air vents" ceiling: ban specular chrome, whites, neon signals, and loud orange/gold
BANNED_SHINY_OR_LOUD_SWATCHES: set[str] = {
    "structure-6", "structure-7", "structure-8-highlight",
    "machine-6", "machine-7", "machine-8-highlight",
    "neutral-6", "neutral-7", "neutral-8-highlight",
    "near-white", "white-glint", "paper", "ceramic-3-light",
    "medical-white-1", "medical-white-2", "medical-white-3",
    "copper-4", "copper-5-highlight",
    "engineering-orange-1", "engineering-orange-2", "engineering-orange-3",
    "engineering-yellow-3", "engineering-yellow-4", "engineering-yellow-5-highlight",
    "caution-paint-1", "caution-paint-2",
    "gold-4", "gold-5-glint", "cargo-khaki-3", "cargo-brown-5-highlight",
    "signal-open-green", "signal-caution", "signal-lamp", "signal-denied-fault",
    "screen-cyan", "screen-cyan-light", "screen-glow",
    "plasma-glow-1", "plasma-glow-2", "bluespace-glow-1", "bluespace-glow-2",
    "glass-3", "medical-blue-4", "medical-blue-5-highlight",
    "command-blue-4", "command-blue-5-highlight",
}

SUBDUED_ACTIVE_LED_SWATCHES: set[str] = {
    "atmos-teal-2", "atmos-teal-3",
}

SUBDUED_FAULT_LED_SWATCHES: set[str] = {
    "fire-red-2", "fire-red-3", "fire-red-4-light",
}

SUBDUED_LED_SWATCHES: set[str] = SUBDUED_ACTIVE_LED_SWATCHES | SUBDUED_FAULT_LED_SWATCHES


def resolve_hex(val: str) -> str:
    hx = P.get(val, val).lower()
    if hx not in NAME_BY_HEX:
        raise ValueError(f"Color {val!r} ({hx}) is NOT in tales-from-space.gpl")
    if "reserved" in NAME_BY_HEX[hx]:
        raise ValueError(f"Color {val!r} ({NAME_BY_HEX[hx]}) is antagonist-reserved")
    return hx


def hex_to_rgb(hx: str) -> tuple[int, int, int]:
    h = hx.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rec709_luma(hx: str) -> float:
    r, g, b = hex_to_rgb(hx)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def to_rec709_greyscale_rgba(im: Image.Image) -> Image.Image:
    """Convert RGBA image to Rec.709 greyscale (docs/ART.md:45), preserving alpha."""
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            if a > 0:
                lum = int(round(0.2126 * r + 0.7152 * g + 0.0722 * b))
                lum = max(0, min(255, lum))
                out.putpixel((x, y), (lum, lum, lum, a))
    return out


def composite_frame(spec: dict[str, Any], frame_idx: int = 0, static_only: bool = False) -> list[list[str | None]]:
    w = spec.get("width", 32)
    h = spec.get("height", 32)
    grid: list[list[str | None]] = [[None for _ in range(w)] for _ in range(h)]
    for layer in spec["layers"]:
        if static_only and layer.get("animated", False):
            continue
        legend = {ch: resolve_hex(col) for ch, col in layer["legend"].items()}
        rows = layer["frames"][frame_idx] if "frames" in layer else layer["rows"]
        if len(rows) != h:
            raise ValueError(f"{spec['name']}/{layer['name']} f{frame_idx}: expected {h} rows, got {len(rows)}")
        for y, row in enumerate(rows):
            if len(row) != w:
                raise ValueError(
                    f"{spec['name']}/{layer['name']} f{frame_idx} row {y}: len={len(row)} != {w} ({row!r})"
                )
            for x, ch in enumerate(row):
                if ch == ".":
                    continue
                if ch not in legend:
                    raise ValueError(f"{spec['name']}/{layer['name']} f{frame_idx} ({x},{y}): {ch!r} not in legend")
                grid[y][x] = legend[ch]
    return grid


def analyze_grid(grid: list[list[str | None]]) -> dict[str, Any]:
    h, w = len(grid), len(grid[0])
    pts = [(x, y, grid[y][x]) for y in range(h) for x in range(w) if grid[y][x] is not None]
    if not pts:
        raise ValueError("Empty sprite grid")

    occupied = {(x, y) for x, y, _ in pts}
    visited: set[tuple[int, int]] = set()
    pieces: list[list[tuple[int, int]]] = []
    for start in occupied:
        if start in visited:
            continue
        comp: list[tuple[int, int]] = []
        q = deque([start])
        visited.add(start)
        while q:
            cx, cy = q.popleft()
            comp.append((cx, cy))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nb = (cx + dx, cy + dy)
                    if nb in occupied and nb not in visited:
                        visited.add(nb)
                        q.append(nb)
        pieces.append(comp)

    lone = sum(1 for c in pieces if len(c) == 1)

    boundary_swatches: list[tuple[int, int, str]] = []
    banned_used: set[str] = set()
    led_pixels = 0
    active_led_pixels = 0
    fault_led_pixels = 0
    linen_pixels = 0
    housing_lumas: list[float] = []
    for x, y, hx in pts:
        assert hx is not None
        sw = NAME_BY_HEX[hx]
        lum = rec709_luma(hx)
        if sw in BANNED_SHINY_OR_LOUD_SWATCHES:
            banned_used.add(sw)
        if sw in SUBDUED_LED_SWATCHES:
            led_pixels += 1
            if sw in SUBDUED_ACTIVE_LED_SWATCHES:
                active_led_pixels += 1
            if sw in SUBDUED_FAULT_LED_SWATCHES:
                fault_led_pixels += 1
        elif sw == "service-linen-1":
            linen_pixels += 1
        elif lum >= 36.0:
            housing_lumas.append(lum)
        touches_transparent = any(
            0 <= x + dx < w and 0 <= y + dy < h and grid[y + dy][x + dx] is None
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
        )
        if touches_transparent:
            boundary_swatches.append((x, y, sw))

    xs = [x for x, _, _ in pts]
    ys = [y for _, y, _ in pts]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    span_y = max(1, max_y - min_y + 1)
    span_x = max(1, max_x - min_x + 1)
    top_cut = min_y + span_y / 3.0
    bot_cut = max_y - span_y / 3.0
    left_cut = min_x + span_x / 3.0
    right_cut = max_x - span_x / 3.0

    l_all = [rec709_luma(c) for _, _, c in pts if c is not None]
    l_top = [rec709_luma(c) for _, y, c in pts if c is not None and y <= top_cut]
    l_bot = [rec709_luma(c) for _, y, c in pts if c is not None and y >= bot_cut]
    l_mid = [rec709_luma(c) for _, y, c in pts if c is not None and top_cut < y < bot_cut]
    l_left = [rec709_luma(c) for x, _, c in pts if c is not None and x <= left_cut]
    l_right = [rec709_luma(c) for x, _, c in pts if c is not None and x >= right_cut]
    avg = lambda a: round(sum(a) / max(1, len(a)), 1)

    return {
        "opaque_pixels": len(pts),
        "unique_colors": len({c for _, _, c in pts}),
        "pieces": len(pieces),
        "lone_pixels": lone,
        "led_pixels": led_pixels,
        "active_led_pixels": active_led_pixels,
        "fault_led_pixels": fault_led_pixels,
        "linen_pixels": linen_pixels,
        "banned_swatches": sorted(banned_used),
        "housing_mean_luma": avg(housing_lumas),
        "housing_max_luma": round(max(housing_lumas), 1) if housing_lumas else 0.0,
        "boundary_swatches": boundary_swatches,
        "bbox": [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1],
        "luma_top": avg(l_top),
        "luma_mid": avg(l_mid),
        "luma_bottom": avg(l_bot),
        "luma_left": avg(l_left),
        "luma_right": avg(l_right),
        "luma_overall": avg(l_all),
    }


def _wall_dir_for_frame(spec: dict[str, Any], f_zero: int) -> str:
    """The wall a scupper frame faces, from its `<state>-<dir>` tag."""
    f1 = f_zero + 1
    words = {"n": "north", "s": "south", "e": "east", "w": "west"}
    for tg in spec["tags"]:
        if tg["from"] <= f1 <= tg["to"]:
            return words[tg["name"].rsplit("-", 1)[1]]
    raise ValueError(f"{spec['name']} f{f1}: unable to determine wall direction from tags")


def validate_spec(spec: dict[str, Any]) -> dict[str, Any]:
    """Validate a drainage fixture spec against docs/ART.md rules."""
    kind = spec["kind"]
    name = spec["name"]
    n_frames = int(spec["frame_count"])
    tags = spec["tags"]
    durations = spec["frame_durations_ms"]
    if len(durations) != n_frames:
        raise AssertionError(f"{name}: frame_durations_ms len {len(durations)} != {n_frames}")
    for d in durations:
        if d < 100 or d % 100 != 0:
            raise AssertionError(f"{name}: duration {d}ms violates 100ms (1 ds) rule")

    # Ensure zero unused legend tokens in any layer
    for layer in spec["layers"]:
        rows_list = layer["frames"] if "frames" in layer else [layer["rows"]]
        used_tokens = {ch for rows in rows_list for row in rows for ch in row if ch != "."}
        unused = set(layer["legend"].keys()) - used_tokens
        if unused:
            raise AssertionError(f"{name}/{layer['name']}: unused legend keys {sorted(unused)}")

    per_frame_stats: list[dict[str, Any]] = []
    for f in range(n_frames):
        full = composite_frame(spec, f, static_only=False)
        st = analyze_grid(full)
        if st["pieces"] != 1:
            raise AssertionError(f"{name} f{f+1}: pieces={st['pieces']} != 1 (detached floating pixels)")
        if st["lone_pixels"] != 0:
            raise AssertionError(f"{name} f{f+1}: lone_pixels={st['lone_pixels']} != 0")
        if st["banned_swatches"]:
            raise AssertionError(
                f"{name} f{f+1}: uses shiny/loud swatches banned by the vent-flat contract: {st['banned_swatches']}"
            )
        if st["linen_pixels"] > 8:
            raise AssertionError(
                f"{name} f{f+1}: service-linen-1 (#b5a685) must stay <= 8 sparse rim pixels, got {st['linen_pixels']}"
            )
        max_cols = 14 if f == 0 or (kind == "scupper" and f < 4) else 18
        if not (5 <= st["unique_colors"] <= max_cols):
            raise AssertionError(
                f"{name} f{f+1}: unique_colors={st['unique_colors']} outside [5, {max_cols}] (keep flat & subdued like vents: 8-13 cols)"
            )
        if not (68.0 <= st["housing_mean_luma"] <= 118.0):
            raise AssertionError(
                f"{name} f{f+1}: housing_mean_luma={st['housing_mean_luma']} outside subdued vent range [68.0, 118.0]"
            )
        if st["housing_max_luma"] > 148.0:
            raise AssertionError(
                f"{name} f{f+1}: housing_max_luma={st['housing_max_luma']} > 148.0 (neutral-5 #929292 Y=146 ceiling)"
            )
        hard_outer = [
            (x, y, sw) for x, y, sw in st["boundary_swatches"]
            if sw in HARD_DARK_OUTER_SWATCHES
        ]
        if hard_outer:
            raise AssertionError(
                f"{name} f{f+1}: outer perimeter must use soft step-2/3 vent bevels (no black or *-1-outline on outer boundary); got {hard_outer[:6]}"
            )

        bx, by, bw, bh = st["bbox"]
        if kind == "floor_drain":
            luma_diff = st["luma_top"] - st["luma_bottom"]
            if not (2.5 <= luma_diff <= 38.0):
                raise AssertionError(
                    f"{name} f{f+1}: luma_top-luma_bottom={luma_diff:.1f} ({st['luma_top']} vs {st['luma_bottom']}) outside flat-vent range [2.5, 38.0]"
                )
            if f == 0 and abs(st["luma_left"] - st["luma_right"]) > 3.5:
                raise AssertionError(f"{name} f1: left/right luma bias ({st['luma_left']} vs {st['luma_right']})")
            if st["led_pixels"] > 0:
                raise AssertionError(f"{name} f{f+1}: passive floor drain must have 0 LED pixels")
            if bx < 5 or by < 5 or bx + bw > 27 or by + bh > 27:
                raise AssertionError(f"{name} f{f+1}: bbox {st['bbox']} outside centered floor margin 5..26")
            if not (16 <= bw <= 20 and 16 <= bh <= 20):
                raise AssertionError(f"{name} f{f+1}: floor drain span {bw}x{bh} outside 16..20")

        elif kind == "sump_pump":
            axis_f = f % 6
            luma_diff = st["luma_top"] - st["luma_bottom"]
            if not (2.5 <= luma_diff <= 38.0):
                raise AssertionError(
                    f"{name} f{f+1}: luma_top-luma_bottom={luma_diff:.1f} ({st['luma_top']} vs {st['luma_bottom']}) outside flat-vent range [2.5, 38.0]"
                )
            if axis_f == 0 and abs(st["luma_left"] - st["luma_right"]) > 3.5:
                raise AssertionError(f"{name} f{f+1}: left/right luma bias ({st['luma_left']} vs {st['luma_right']})")
            if axis_f == 0 and st["led_pixels"] > 0:
                raise AssertionError(f"{name} f{f+1} (off): off state must have 0 lit LED px (use M5 #606375 unlit)")
            if 1 <= axis_f <= 4 and not (1 <= st["active_led_pixels"] <= 4 and st["fault_led_pixels"] == 0):
                raise AssertionError(
                    f"{name} f{f+1} (pumping): expected 1..4 subdued teal LED px (AT2/AT3, docs/ART.md:94-95) and 0 fault px; got active={st['active_led_pixels']} fault={st['fault_led_pixels']}"
                )
            if axis_f == 5 and not (1 <= st["fault_led_pixels"] <= 4):
                raise AssertionError(
                    f"{name} f{f+1} (fault): expected 1..4 subdued red LED px (FR2/FR3/FR4, docs/ART.md:94-95); got {st['fault_led_pixels']}"
                )
            # Require by >= 6 so north mouth cap at y=5 peeks cleanly above the housing!
            if bx < 5 or by < 6 or bx + bw > 27 or by + bh > 27:
                raise AssertionError(f"{name} f{f+1}: bbox {st['bbox']} must satisfy bx>=5, by>=6 (for pipe mouth cap), <=26")
            if not (18 <= bw <= 21 and 18 <= bh <= 20):
                raise AssertionError(f"{name} f{f+1}: sump pump span {bw}x{bh} outside 18..21 x 18..20")

        elif kind == "scupper":
            if st["led_pixels"] > 0:
                raise AssertionError(f"{name} f{f+1}: passive wall scupper must have 0 LED pixels, got {st['led_pixels']}")
            wdir = _wall_dir_for_frame(spec, f)
            if wdir == "north":
                # Overlays lower/room-facing half of North wall-0 (like APC y=16..29 & Fire Alarm y=18..31)
                if not (5 <= bx <= 9 and 14 <= bw <= 22 and 14 <= by <= 19 and 30 <= by + bh <= 32 and 13 <= bh <= 17):
                    raise AssertionError(
                        f"{name} north f{f+1}: expected wall-overlay bbox bx=5..9, bw=14..22, by=14..19, by+bh=30..32, bh=13..17; got {st['bbox']}"
                    )
                if abs((bx + bw / 2.0) - 16.0) > 1.0:
                    raise AssertionError(f"{name} north f{f+1}: horizontally off-center bbox {st['bbox']}")
                if abs(st["luma_left"] - st["luma_right"]) > 3.5:
                    raise AssertionError(f"{name} north f{f+1}: L/R luma bias ({st['luma_left']} vs {st['luma_right']})")
                if not (2.0 <= st["luma_top"] - st["luma_bottom"] <= 42.0):
                    raise AssertionError(
                        f"{name} north f{f+1}: luma_top-luma_bottom={st['luma_top']-st['luma_bottom']:.1f} outside [2.0, 42.0]"
                    )
                dark_ys = [y for y in range(by, by + bh) for x in range(bx, bx + bw) if full[y][x] and rec709_luma(full[y][x]) < 36.0]
                if not dark_ys or max(dark_ys) < by + bh - 6:
                    raise AssertionError(f"{name} north f{f+1}: dark scupper intake throat must sit near bottom/room edge of North wall")
            elif wdir == "south":
                # Overlays upper/room-facing roof/lip of South wall-0 (like APC y=2..15 & lighting.dmi south bracket)
                if not (5 <= bx <= 9 and 14 <= bw <= 22 and 0 <= by <= 2 and 10 <= by + bh <= 17 and 10 <= bh <= 16):
                    raise AssertionError(
                        f"{name} south f{f+1}: expected wall-overlay bbox bx=5..9, bw=14..22, by=0..2, by+bh=10..17, bh=10..16; got {st['bbox']}"
                    )
                if abs((bx + bw / 2.0) - 16.0) > 1.0:
                    raise AssertionError(f"{name} south f{f+1}: horizontally off-center bbox {st['bbox']}")
                if abs(st["luma_left"] - st["luma_right"]) > 3.5:
                    raise AssertionError(f"{name} south f{f+1}: L/R luma bias ({st['luma_left']} vs {st['luma_right']})")
                if not (2.0 <= st["luma_top"] - st["luma_bottom"] <= 42.0):
                    raise AssertionError(
                        f"{name} south f{f+1}: luma_top-luma_bottom={st['luma_top']-st['luma_bottom']:.1f} ({st['luma_top']} vs {st['luma_bottom']}) outside [2.0, 42.0] — South scupper roof housing must stay top-lit!"
                    )
                dark_ys = [y for y in range(by, by + bh) for x in range(bx, bx + bw) if full[y][x] and rec709_luma(full[y][x]) < 36.0]
                if not dark_ys or min(dark_ys) > by + 5:
                    raise AssertionError(f"{name} south f{f+1}: dark scupper intake throat must sit near top/room edge (y<=by+5) of South wall")
            elif wdir == "east":
                # Overlays left/room-facing half of East wall-0 (like APC x=1..17 & Fire Alarm x=0..13)
                if not (0 <= bx <= 2 and 12 <= bx + bw <= 17 and 12 <= bw <= 16 and 5 <= by <= 9 and 14 <= bh <= 22):
                    raise AssertionError(
                        f"{name} east f{f+1}: expected wall-overlay bbox bx=0..2, bw=12..16, by=5..9, bh=14..22; got {st['bbox']}"
                    )
                if abs((by + bh / 2.0) - 16.0) > 1.0:
                    raise AssertionError(f"{name} east f{f+1}: vertically off-center bbox {st['bbox']}")
                if not (2.0 <= st["luma_top"] - st["luma_bottom"] <= 38.0):
                    raise AssertionError(
                        f"{name} east f{f+1}: luma_top-luma_bottom={st['luma_top']-st['luma_bottom']:.1f} outside [2.0, 38.0]"
                    )
                dark_xs = [x for y in range(by, by + bh) for x in range(bx, bx + bw) if full[y][x] and rec709_luma(full[y][x]) < 36.0]
                if not dark_xs or min(dark_xs) > bx + 6:
                    raise AssertionError(f"{name} east f{f+1}: dark scupper intake throat must sit near left/room edge (x<=bx+6) of East wall")
            elif wdir == "west":
                # Overlays right/room-facing half of West wall-0 (like APC x=15..31 & Fire Alarm x=18..31)
                if not (15 <= bx <= 20 and 30 <= bx + bw <= 32 and 12 <= bw <= 16 and 5 <= by <= 9 and 14 <= bh <= 22):
                    raise AssertionError(
                        f"{name} west f{f+1}: expected wall-overlay bbox bx=15..20, bx+bw=30..32, bw=12..16, by=5..9, bh=14..22; got {st['bbox']}"
                    )
                if abs((by + bh / 2.0) - 16.0) > 1.0:
                    raise AssertionError(f"{name} west f{f+1}: vertically off-center bbox {st['bbox']}")
                if not (2.0 <= st["luma_top"] - st["luma_bottom"] <= 38.0):
                    raise AssertionError(
                        f"{name} west f{f+1}: luma_top-luma_bottom={st['luma_top']-st['luma_bottom']:.1f} outside [2.0, 38.0]"
                    )
                dark_xs = [x for y in range(by, by + bh) for x in range(bx, bx + bw) if full[y][x] and rec709_luma(full[y][x]) < 36.0]
                if not dark_xs or max(dark_xs) < bx + bw - 7:
                    raise AssertionError(f"{name} west f{f+1}: dark scupper intake throat must sit near right/room edge of West wall")
        else:
            raise ValueError(f"Unknown kind: {kind}")

        clean_st = {k: v for k, v in st.items() if k != "boundary_swatches"}
        per_frame_stats.append(clean_st)

    # Enforce strict static housing invariant (docs/ART.md:84-86): animated layers must NEVER overwrite solid metal/brass sills!
    if kind in ("floor_drain", "scupper"):
        lyr0, lyr1, lyr2 = spec["layers"]
        f0_list = lyr0["frames"] if "frames" in lyr0 else [lyr0["rows"]] * n_frames
        f1_list = lyr1["frames"] if "frames" in lyr1 else [lyr1["rows"]] * n_frames
        f2_list = lyr2["frames"] if "frames" in lyr2 else [lyr2["rows"]] * n_frames
        leg0 = {ch: resolve_hex(col) for ch, col in lyr0["legend"].items()}
        for fi in range(n_frames):
            for y in range(32):
                for x in range(32):
                    if f1_list[fi][y][x] != ".":
                        base_ch = f0_list[fi][y][x]
                        if base_ch == "." or rec709_luma(leg0[base_ch]) >= 36.0:
                            raise AssertionError(
                                f"{name} f{fi+1} ({x},{y}): drain_flow overwrites solid housing/sill or transparent space ({base_ch!r}) — must stay inside dark <36 luma throat!"
                            )
                        if f2_list[fi][y][x] != ".":
                            raise AssertionError(
                                f"{name} f{fi+1} ({x},{y}): drain_flow pixel hidden underneath static {lyr2['name']} bar!"
                            )

    animated_px = 0
    for tg in tags:
        f_start = tg["from"] - 1
        f_end = tg["to"] - 1
        if f_end > f_start:
            base_static = composite_frame(spec, f_start, static_only=True)
            changed: set[tuple[int, int]] = set()
            prev_full = None
            for fi in range(f_start, f_end + 1):
                cur_static = composite_frame(spec, fi, static_only=True)
                if cur_static != base_static:
                    raise AssertionError(
                        f"{name} tag {tg['name']!r}: static housing mutated between f{f_start+1} and f{fi+1}!"
                    )
                cur_full = composite_frame(spec, fi, static_only=False)
                if prev_full is not None and cur_full == prev_full:
                    raise AssertionError(f"{name} tag {tg['name']!r}: adjacent frames f{fi} and f{fi+1} are identical!")
                prev_full = cur_full
                if fi > f_start:
                    ref_full = composite_frame(spec, f_start, static_only=False)
                    for y in range(32):
                        for x in range(32):
                            if cur_full[y][x] != ref_full[y][x]:
                                changed.add((x, y))
            if animated_px == 0:
                animated_px = len(changed)
            if not (6 <= len(changed) <= 65):
                raise AssertionError(
                    f"{name} tag {tg['name']!r}: animated pixel count {len(changed)} outside [6, 65]"
                )

    if kind == "scupper":
        g_n = composite_frame(spec, 0)
        g_s = composite_frame(spec, 1)
        rot180_n = [[g_n[31 - y][31 - x] for x in range(32)] for y in range(32)]
        if rot180_n == g_s:
            raise AssertionError(f"{name}: south is a raw 180° rotation of north!")
        rot90_n = [[g_n[31 - x][y] for x in range(32)] for y in range(32)]
        g_e = composite_frame(spec, 2)
        if rot90_n == g_e:
            raise AssertionError(f"{name}: east is a raw 90° rotation of north!")

    return {
        "frame_stats": per_frame_stats,
        "animated_px": animated_px,
    }


def load_dmi_tile(dmi_rel: str, state_name: str, dir_idx: int = 0, frame_idx: int = 0) -> Image.Image:
    path = tg_root() / "icons" / dmi_rel
    im = Image.open(path)
    info = im.info.get("Description", "")
    w = h = 32
    states: list[dict[str, Any]] = []
    cur: dict[str, Any] | None = None
    for line in info.splitlines():
        s = line.strip()
        if s.startswith("width ="):
            w = int(s.split("=")[1])
        elif s.startswith("height ="):
            h = int(s.split("=")[1])
        elif s.startswith("state ="):
            if cur:
                states.append(cur)
            cur = {"name": s.split("=", 1)[1].strip().strip('"'), "dirs": 1, "frames": 1}
        elif cur and s.startswith("dirs ="):
            cur["dirs"] = int(s.split("=")[1])
        elif cur and s.startswith("frames ="):
            cur["frames"] = int(s.split("=")[1])
    if cur:
        states.append(cur)
    cols = im.width // w
    idx = 0
    im_rgba = im.convert("RGBA")
    for st in states:
        n_cells = st["frames"] * st["dirs"]
        if st["name"] == state_name:
            target = idx + frame_idx * st["dirs"] + dir_idx
            cx = (target % cols) * w
            cy = (target // cols) * h
            return im_rgba.crop((cx, cy, cx + w, cy + h))
        idx += n_cells
    raise KeyError(f"State {state_name!r} not found in {path}")


def load_context_tiles() -> dict[str, Image.Image]:
    return {
        "floor": load_dmi_tile("turf/floors.dmi", "floor"),
        "plating": load_dmi_tile("turf/floors.dmi", "plating"),
        "reinforced_floor": load_dmi_tile("turf/floors.dmi", "engine"),
        "white_floor": load_dmi_tile("turf/floors.dmi", "white"),
        "dark_floor": load_dmi_tile("turf/floors.dmi", "dark"),
        "wall": load_dmi_tile("turf/walls/wall.dmi", "wall-0"),
        "reinforced_wall": load_dmi_tile("turf/walls/reinforced_wall.dmi", "reinforced_wall-0"),
    }


def make_water_overlay(full_flood: bool = False) -> Image.Image:
    ov = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in range(32):
            if full_flood:
                edge = (x in (0, 31) or y in (0, 31))
                hi = ((x + y * 3) % 17 == 0)
                if hi:
                    ov.putpixel((x, y), (200, 224, 238, 120))
                elif edge:
                    ov.putpixel((x, y), (92, 132, 156, 110))
                else:
                    ov.putpixel((x, y), (116, 158, 182, 96))
            else:
                dx = (x - 15.5) / 13.5
                dy = (y - 15.5) / 12.5
                d2 = dx * dx + dy * dy
                if d2 <= 1.0:
                    if d2 > 0.82:
                        ov.putpixel((x, y), (164, 196, 214, 128))
                    elif (x * 5 + y * 7) % 23 == 0:
                        ov.putpixel((x, y), (210, 232, 244, 130))
                    else:
                        ov.putpixel((x, y), (116, 158, 182, 92))
    return ov


@asynccontextmanager
async def open_aseprite_mcp():
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    python, repo = mcp_python_and_repo()
    env = {**os.environ, "ASEPRITE_PATH": aseprite_binary()}
    if repo:
        env["PYTHONPATH"] = repo
    params = StdioServerParameters(command=python, args=["-m", "aseprite_mcp"], env=env)
    with open(os.devnull, "w") as devnull:
        async with stdio_client(params, errlog=devnull) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                yield session


async def call_tool(session: Any, name: str, args: dict[str, Any]) -> str:
    res = await session.call_tool(name, args)
    texts = [c.text for c in res.content if hasattr(c, "text")]
    out = "\n".join(texts).strip()
    if getattr(res, "isError", False) or out.startswith(("Command failed", "Failed")):
        raise RuntimeError(f"Aseprite MCP {name} failed: {out}")
    return out


def render_layer_png(layer: dict[str, Any], out_path: Path, frame_idx: int = 0) -> None:
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    legend = {ch: resolve_hex(col) for ch, col in layer["legend"].items()}
    rows = layer["frames"][frame_idx] if "frames" in layer else layer["rows"]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                r, g, b = hex_to_rgb(legend[ch])
                im.putpixel((x, y), (r, g, b, 255))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path)


async def draw_source(session: Any, spec: dict[str, Any], ase_path: Path) -> None:
    """Replace `ase_path` with the spec's layers, frames and tags."""
    n_frames = int(spec["frame_count"])
    ase_path.parent.mkdir(parents=True, exist_ok=True)
    if ase_path.exists():
        ase_path.unlink()

    used_hexes: list[str] = []
    resolved_layers: list[dict[str, Any]] = []
    for layer in spec["layers"]:
        leg = {ch: resolve_hex(col).upper() for ch, col in layer["legend"].items()}
        for hx in leg.values():
            if hx not in used_hexes:
                used_hexes.append(hx)
        resolved_layers.append({
            "name": layer["name"],
            "legend": leg,
            "frames": layer["frames"] if "frames" in layer else [layer["rows"]] * n_frames,
        })

    await call_tool(session, "create_canvas", {"width": 32, "height": 32, "filename": str(ase_path)})
    await call_tool(session, "set_palette", {"filename": str(ase_path), "colors": used_hexes})

    for idx, lyr in enumerate(resolved_layers):
        if idx == 0:
            await call_tool(
                session, "rename_layer",
                {"filename": str(ase_path), "layer_name": "Layer 1", "new_name": lyr["name"]},
            )
        else:
            await call_tool(session, "add_layer", {"filename": str(ase_path), "layer_name": lyr["name"]})

    for _ in range(n_frames - 1):
        await call_tool(session, "add_frame", {"filename": str(ase_path)})

    for f_idx, dur in enumerate(spec["frame_durations_ms"], start=1):
        await call_tool(
            session, "set_frame_duration",
            {"filename": str(ase_path), "frame_index": f_idx, "duration_ms": int(dur)},
        )

    for lyr in resolved_layers:
        for f_zero in range(n_frames):
            await call_tool(
                session, "draw_rows",
                {
                    "filename": str(ase_path),
                    "layer_name": lyr["name"],
                    "frame_index": f_zero + 1,
                    "x": 0,
                    "y": 0,
                    "rows": lyr["frames"][f_zero],
                    "legend": lyr["legend"],
                },
            )

    for tg in spec["tags"]:
        await call_tool(
            session, "set_tag",
            {
                "filename": str(ase_path),
                "name": tg["name"],
                "from_frame": int(tg["from"]),
                "to_frame": int(tg["to"]),
                "direction": "forward",
            },
        )


async def export_source(session: Any, spec: dict[str, Any], ase_path: Path, val: dict[str, Any]) -> dict[str, Any]:
    """Export every frame and layer of one source and return its manifest."""
    name = spec["name"]
    n_frames = int(spec["frame_count"])
    png_1x_dir = OUT_ROOT / "png_1x"
    png_8x_dir = OUT_ROOT / "png_8x"
    layers_dir = OUT_ROOT / "layers"
    for d in (png_1x_dir, png_8x_dir, layers_dir):
        d.mkdir(parents=True, exist_ok=True)

    frame_pngs_1x: list[str] = []
    frame_pngs_8x: list[str] = []
    for f_idx in range(1, n_frames + 1):
        fp1 = (png_1x_dir / f"{name}_f{f_idx}.png").resolve()
        fp8 = (png_8x_dir / f"{name}_f{f_idx}_8x.png").resolve()
        await call_tool(
            session, "export_frame",
            {"filename": str(ase_path), "output_filename": str(fp1), "frame_index": f_idx, "scale": 1},
        )
        await call_tool(
            session, "export_frame",
            {"filename": str(ase_path), "output_filename": str(fp8), "frame_index": f_idx, "scale": 8},
        )
        lint_raw = await call_tool(session, "lint_sprite", {"filename": str(ase_path), "frame_index": f_idx})
        lint_obj = json.loads(lint_raw)
        if lint_obj.get("lone_pixel_count", 0) != 0:
            raise AssertionError(f"MCP lint_sprite {name} f{f_idx}: lone_pixel_count={lint_obj['lone_pixel_count']}")
        frame_pngs_1x.append(str(fp1))
        frame_pngs_8x.append(str(fp8))

    first_anim_f = next((tg["from"] - 1 for tg in spec["tags"] if tg["to"] > tg["from"]), 0)
    layer_pngs: list[dict[str, Any]] = []
    for idx, orig_layer in enumerate(spec["layers"]):
        lp = (layers_dir / f"{name}_L{idx+1}_{orig_layer['name']}.png").resolve()
        use_f = first_anim_f if orig_layer.get("animated", False) else 0
        render_layer_png(orig_layer, lp, frame_idx=use_f)
        layer_pngs.append({
            "name": orig_layer["name"],
            "animated": bool(orig_layer.get("animated", False)),
            "png": str(lp),
        })

    used = {
        resolve_hex(col).lower()
        for layer in spec["layers"]
        for col in layer["legend"].values()
    }
    return {
        "name": name,
        "title": spec["title"],
        "kind": spec["kind"],
        "blurb": spec["blurb"],
        "design_notes": spec.get("design_notes", ""),
        "aseprite": str(ase_path.relative_to(PACK_ROOT)),
        "frame_count": n_frames,
        "frame_durations_ms": spec["frame_durations_ms"],
        "tags": spec["tags"],
        "frame_pngs_1x": frame_pngs_1x,
        "frame_pngs_8x": frame_pngs_8x,
        "layer_pngs": layer_pngs,
        "swatches": [{"hex": hx, "name": NAME_BY_HEX[hx]} for hx in sorted(used)],
        "frame_stats": val["frame_stats"],
        "animated_px": val["animated_px"],
    }


def load_spec(fixture: str) -> dict[str, Any]:
    spec_file = DRAINAGE_DIR / "specs" / f"spec_{fixture}.py"
    mod_name = f"spec_{fixture}"
    spec_obj = importlib.util.spec_from_file_location(mod_name, spec_file)
    assert spec_obj and spec_obj.loader
    mod = importlib.util.module_from_spec(spec_obj)
    spec_obj.loader.exec_module(mod)
    return mod.SPEC


async def run_fixture(session: Any, spec: dict[str, Any], rebuild: bool) -> None:
    val = validate_spec(spec)
    ase_path = SOURCE_DIR / f"{spec['name']}.aseprite"
    if rebuild or not ase_path.exists():
        await draw_source(session, spec, ase_path)
    manifest = await export_source(session, spec, ase_path, val)
    manifest_path = OUT_ROOT / "manifests" / f"{spec['name']}.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"built {spec['name']}: {manifest['frame_count']} frames, anim={manifest['animated_px']}px")


async def run_all(specs: list[dict[str, Any]], rebuild: bool) -> None:
    async with open_aseprite_mcp() as session:
        for spec in specs:
            await run_fixture(session, spec, rebuild)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture", choices=[*FIXTURES, "all"], default="all")
    ap.add_argument("--check-specs", action="store_true", help="validate the specs; no Aseprite or MCP")
    ap.add_argument("--rebuild-sources", action="store_true", help="redraw the sources, discarding hand edits")
    args = ap.parse_args()

    names = FIXTURES if args.fixture == "all" else (args.fixture,)
    specs = [load_spec(name) for name in names]
    for spec in specs:
        validate_spec(spec)
    print(f"specs ok: {', '.join(names)}")
    if not args.check_specs:
        asyncio.run(run_all(specs, args.rebuild_sources))


if __name__ == "__main__":
    main()
