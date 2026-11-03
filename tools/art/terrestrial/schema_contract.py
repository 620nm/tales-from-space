r"""
Shared manifest contract, environment-resolved paths, and palette/biome constants
for Tales from Space Terrestrial & Planetary Art (`tools/art/terrestrial/`).
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import sys
from typing import Any

from pack_tints import PackTint, resolve_presets

# tools/art/terrestrial/schema_contract.py -> pack/worktree root is 3 levels up.
PACK_ROOT = Path(__file__).resolve().parents[3]
TERRESTRIAL_DIR = Path(__file__).resolve().parent
ORIGINALS_DIR = PACK_ROOT / "assets/originals/art/terrestrial"
GPL_PATH = PACK_ROOT / "docs/art-reference/palettes/tales-from-space.gpl"
DEFAULT_OUT_DIR = PACK_ROOT / "target/art/terrestrial"


def aseprite_binary() -> str:
    r"""Return `ASEPRITE_PATH` or `aseprite` on `PATH`, raising `RuntimeError` if missing."""
    found = os.environ.get("ASEPRITE_PATH") or shutil.which("aseprite")
    if not found:
        raise RuntimeError("aseprite not found: set ASEPRITE_PATH or put aseprite on PATH")
    return found


def mcp_python_and_repo() -> tuple[str, str | None]:
    r"""Return the interpreter that runs `aseprite_mcp`, and the checkout for `PYTHONPATH`.

    `ASEPRITE_MCP_REPO` names the checkout; `ASEPRITE_MCP_PYTHON` names the interpreter
    and defaults to the checkout's `.venv/bin/python`, then to `sys.executable`.
    """
    repo = os.environ.get("ASEPRITE_MCP_REPO")
    python = os.environ.get("ASEPRITE_MCP_PYTHON")
    if not python and repo:
        venv = Path(repo) / ".venv" / "bin" / "python"
        python = str(venv) if venv.exists() else None
    return python or sys.executable, repo


def tgstation_root() -> Path:
    r"""Resolve the read-only `tgstation` checkout containing `icons/turf`.

    Checks `LUNATIC_TG`, then `<pack_root>/../tgstation`, then `<pack_root>/../../../tgstation`
    so worktrees under `<main_repo>/.worktrees/<branch>` also resolve `../tgstation`.
    """
    candidates: list[Path] = []
    env_tg = os.environ.get("LUNATIC_TG")
    if env_tg:
        candidates.append(Path(env_tg))
    candidates.append(PACK_ROOT.parent / "tgstation")
    if len(PACK_ROOT.parents) > 2:
        candidates.append(PACK_ROOT.parents[2] / "tgstation")
    for cand in candidates:
        resolved = cand.expanduser().resolve()
        if (resolved / "icons" / "turf").is_dir():
            return resolved
    raise RuntimeError(
        "tgstation checkout containing icons/turf not found: "
        "set LUNATIC_TG or place tgstation beside the main repository checkout"
    )


def rgba_pixels(im: Any) -> Any:
    r"""Return flattened pixel sequence without triggering Pillow 14 `getdata()` deprecation."""
    return im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()


# Canonical 47 diagonal-gated bitmask junctions (N=1, S=2, E=4, W=8, NE=16, SE=32, SW=64, NW=128)
NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
NE, SE, SW, NW = 16, 32, 64, 128
JUNCTIONS: list[int] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    21, 23, 29, 31, 38, 39, 46, 47, 55, 63,
    74, 75, 78, 79, 95, 110, 111, 127,
    137, 139, 141, 143, 157, 159, 175, 191,
    203, 207, 223, 239, 255,
]

# Strictly neutral greyscale swatches (R == G == B) in tales-from-space.gpl
NEUTRAL_GREYS: dict[str, str] = {
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

# Biome multiply tints for plates and the workbench. A `PackTint` role is read from the
# pack's content at import (`pack_tints.py`), so it draws what the pack declares; a
# `#RRGGBB` role is an art-direction proposal the pack does not declare yet.
_SUB = lambda entry, path: PackTint("substance", entry, path)  # noqa: E731
BIOME_TINT_SOURCES: dict[str, dict[str, str | PackTint]] = {
    "mars_cryo_ammonia": {
        "label": "Mars — Cryo-Ammonia Sea & Rust Silicates",
        "silicate": "#B85C3C",
        "silicate_low": "#82402A",
        "ice": _SUB("ammonia", "appearance.solid.tint"),
        "cliff": "#9E482C",
        "ocean": _SUB("ammonia", "appearance.liquid.tint"),
        "backwash": "#4A2218",
        "swash": "#E6F7F5",
        "grass": "#BC8444",
        "moss": "#96A670",
        "haze": _SUB("ammonia", "visible.tint"),
    },
    "mars_pack_ammonia": {
        "label": "Mars — Pack Ammonia Colour & Hematite",
        "silicate": _SUB("iron_oxide", "color"),
        "silicate_low": "#693514",
        "ice": _SUB("water", "appearance.solid.tint"),
        "cliff": "#7A3B18",
        "ocean": _SUB("ammonia", "color"),
        "backwash": "#2E1A0E",
        "swash": _SUB("ammonia", "visible.tint"),
        "grass": "#9C841A",
        "moss": "#6E6646",
        "haze": _SUB("ammonia", "visible.tint"),
    },
    "mars_polar_ice": {
        "label": "Mars — Calving Polar Ice Sheet & Basalt",
        "silicate": _SUB("basalt", "color"),
        "silicate_low": "#42454F",
        "ice": "#DCF2FA",
        "cliff": "#8798A6",
        "ocean": "#4A95AC",
        "backwash": "#232730",
        "swash": "#F0FAFF",
        "grass": "#88D0C2",
        "moss": "#92C0B0",
        "haze": _SUB("water", "visible.tint"),
    },
    "earth_coastal_meadow": {
        "label": "Earth — Coastal Meadow, Granite Cliffs & Sea",
        "silicate": "#947B62",
        "silicate_low": PackTint("terrain", "deep_liquid", "face_tint"),
        "ice": "#D8EEF8",
        "cliff": "#7D7A74",
        "ocean": "#3889C9",
        "backwash": "#594936",
        "swash": "#F4FAFF",
        "grass": "#86C44A",
        "moss": "#5A9842",
        "haze": _SUB("water", "visible.tint"),
    },
    "earth_lush_jungle": {
        "label": "Earth — Lush Jungle Basin & Mossy Crags",
        "silicate": "#6B5746",
        "silicate_low": "#8A7658",
        "ice": "#C4EAF5",
        "cliff": "#5A5D56",
        "ocean": "#2D7D8A",
        "backwash": "#332B22",
        "swash": "#E8F8F5",
        "grass": "#4C9658",
        "moss": "#66A84C",
        "haze": "#D8ECE4",
    },
}

BIOME_TINT_PRESETS: dict[str, dict[str, str]] = resolve_presets(PACK_ROOT / "content", BIOME_TINT_SOURCES)
