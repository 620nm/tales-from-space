r"""
Unified neutral-grayscale sprite roster (`SPRITES`) for Tales from Space Terrestrial Art
(`tools/art/terrestrial/specs/`).
"""
from __future__ import annotations

from pathlib import Path
import sys
from typing import Any

if __package__:
    from .spec_ocean_nature import (
        OCEAN_NATURE_SPRITES,
        gen_solid_grass_smooth,
        gen_solid_moss_smooth,
        gen_ocean_backwash_smooth,
        gen_ocean_body_smooth,
        gen_ocean_foam_lace_smooth,
        gen_ocean_swash_smooth,
    )
    from .spec_terrain import (
        TERRAIN_SPRITES,
        gen_prop_rough_outcrop_1,
        gen_prop_rough_outcrop_2,
        gen_terrain_cliff_stepped_smooth,
        gen_terrain_ice_sheet_smooth,
        gen_terrain_silicate_rough_smooth,
    )
else:
    _TERRESTRIAL_DIR = str(Path(__file__).resolve().parents[1])
    if _TERRESTRIAL_DIR not in sys.path:
        sys.path.insert(0, _TERRESTRIAL_DIR)
    from specs.spec_ocean_nature import (  # type: ignore[import-not-found]
        OCEAN_NATURE_SPRITES,
        gen_solid_grass_smooth,
        gen_solid_moss_smooth,
        gen_ocean_backwash_smooth,
        gen_ocean_body_smooth,
        gen_ocean_foam_lace_smooth,
        gen_ocean_swash_smooth,
    )
    from specs.spec_terrain import (  # type: ignore[import-not-found]
        TERRAIN_SPRITES,
        gen_prop_rough_outcrop_1,
        gen_prop_rough_outcrop_2,
        gen_terrain_cliff_stepped_smooth,
        gen_terrain_ice_sheet_smooth,
        gen_terrain_silicate_rough_smooth,
    )

_SPRITE_ORDER: tuple[str, ...] = (
    "terrain_silicate_rough_smooth",
    "terrain_ice_sheet_smooth",
    "terrain_cliff_stepped_smooth",
    "ocean_body_smooth",
    "ocean_backwash_smooth",
    "ocean_swash_smooth",
    "ocean_foam_lace_smooth",
    "solid_grass_smooth",
    "solid_moss_smooth",
    "prop_rough_outcrop_1",
    "prop_rough_outcrop_2",
    "terrain_silicate_rough_flat_1",
    "terrain_silicate_rough_flat_2",
    "terrain_silicate_rough_flat_3",
    "terrain_ice_sheet_flat_1",
    "terrain_ice_sheet_flat_2",
    "terrain_ice_sheet_flat_3",
    "terrain_cliff_stepped_flat_1",
    "terrain_cliff_stepped_flat_2",
    "terrain_cliff_stepped_flat_3",
)

_BY_ID: dict[str, dict[str, Any]] = {
    sp["id"]: sp for sp in (*TERRAIN_SPRITES, *OCEAN_NATURE_SPRITES)
}

SPRITES: list[dict[str, Any]] = [_BY_ID[sid] for sid in _SPRITE_ORDER]

__all__ = [
    "OCEAN_NATURE_SPRITES",
    "SPRITES",
    "TERRAIN_SPRITES",
    "gen_solid_grass_smooth",
    "gen_solid_moss_smooth",
    "gen_ocean_backwash_smooth",
    "gen_ocean_body_smooth",
    "gen_ocean_foam_lace_smooth",
    "gen_ocean_swash_smooth",
    "gen_prop_rough_outcrop_1",
    "gen_prop_rough_outcrop_2",
    "gen_terrain_cliff_stepped_smooth",
    "gen_terrain_ice_sheet_smooth",
    "gen_terrain_silicate_rough_smooth",
]
