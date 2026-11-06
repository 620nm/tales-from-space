#!/usr/bin/env python3
r"""
Procedural pixel-art specification entrypoint for Tales from Space — Solid Matter & Soil (`solids`).
Assembles the 13 neutral-grayscale solid sprites (`SPRITES`) from `solids_discrete` and
`solids_surfaces` in canonical manifest order.
"""
from __future__ import annotations

from pathlib import Path
import sys
from typing import Any

if __package__:
    from .solids_discrete import DISCRETE_SOLID_SPRITES
    from .solids_surfaces import SURFACE_SOLID_SPRITES
else:
    _SPECS_DIR = str(Path(__file__).resolve().parent)
    if _SPECS_DIR not in sys.path:
        sys.path.insert(0, _SPECS_DIR)
    from solids_discrete import DISCRETE_SOLID_SPRITES  # type: ignore[import-not-found]
    from solids_surfaces import SURFACE_SOLID_SPRITES  # type: ignore[import-not-found]

SPRITES: list[dict[str, Any]] = [
    DISCRETE_SOLID_SPRITES["solid_sprinkles"],
    DISCRETE_SOLID_SPRITES["solid_scattering"],
    DISCRETE_SOLID_SPRITES["solid_pile_small"],
    DISCRETE_SOLID_SPRITES["solid_pile_large"],
    DISCRETE_SOLID_SPRITES["solid_shards_small"],
    DISCRETE_SOLID_SPRITES["solid_shards_large"],
    DISCRETE_SOLID_SPRITES["solid_dusting_flour_single"],
    SURFACE_SOLID_SPRITES["solid_dusting_flour_smooth"],
    DISCRETE_SOLID_SPRITES["solid_debris_jagged_single"],
    SURFACE_SOLID_SPRITES["solid_debris_jagged_smooth"],
    DISCRETE_SOLID_SPRITES["solid_soil_patch_single"],
    SURFACE_SOLID_SPRITES["solid_soil_smooth"],
    SURFACE_SOLID_SPRITES["solid_soil_tilled_smooth"],
]
