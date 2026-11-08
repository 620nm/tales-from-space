"""Load a domain's `SPRITES` specs: seam patches and `first_frame_of` stills resolved.

Split from `elemental_kit.py`; needs only the standard library.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from typing import Any

ELEMENTAL_DIR = Path(__file__).resolve().parent


def bake_tag(spec: dict[str, Any]) -> str:
    """The tag the roster reads: a strip is cut by `Slice`, which asks for `<state>-s`."""
    state = spec.get("tag", "idle")
    return f"{state}-s" if spec["kind"] == "smooth_strip" else state


SEAM_PATCHES_PATH = ELEMENTAL_DIR / "specs/seam_patches.json"


def load_sprites(spec_path: Path) -> list[dict[str, Any]]:
    mod_spec = importlib.util.spec_from_file_location("domain_sprites", str(spec_path))
    if mod_spec is None or mod_spec.loader is None:
        raise RuntimeError(f"Cannot load spec module: {spec_path}")
    mod = importlib.util.module_from_spec(mod_spec)
    mod_spec.loader.exec_module(mod)
    sprites = getattr(mod, "SPRITES", None)
    if not isinstance(sprites, list) or not sprites:
        raise ValueError(f"{spec_path}: must define non-empty SPRITES = [...]")
    apply_seam_patches(sprites)
    resolve_first_frame_sources(sprites)
    return sprites


def _flat_frame(frame: dict[str, Any]) -> list[tuple[Any, ...]]:
    """A frame as (layer, opacity, blend, per-pixel hex rows), independent of legend letters."""
    return [
        (
            lay["name"],
            int(lay.get("opacity", 255)),
            str(lay.get("blend_mode", "normal")),
            tuple(
                tuple(None if ch == "." else lay["legend"][ch].upper() for ch in row)
                for row in lay["rows"]
            ),
        )
        for lay in frame["layers"]
    ]


def resolve_first_frame_sources(sprites: list[dict[str, Any]]) -> None:
    """Point each `first_frame_of` still at its owner's source after checking they agree.

    The roster reads such a still as the first frame of the owner's tag (`Ase`/`Sprite`),
    so the still's one frame must equal the owner's frame 1 layer for layer and pixel for
    pixel, on the same canvas and tag.
    """
    by_id = {sp["id"]: sp for sp in sprites}
    for sp in sprites:
        owner_id = sp.get("first_frame_of")
        if not owner_id:
            continue
        owner = by_id.get(owner_id)
        if owner is None or owner.get("first_frame_of"):
            raise ValueError(f"{sp['id']}: first_frame_of={owner_id!r} names no drawn sprite in this domain")
        if len(sp["frames"]) != 1:
            raise ValueError(f"{sp['id']}: first_frame_of needs a one-frame still")
        if (sp["kind"], bake_tag(sp)) != (owner["kind"], bake_tag(owner)):
            raise ValueError(f"{sp['id']}: kind/tag differ from {owner_id}")
        if _flat_frame(sp["frames"][0]) != _flat_frame(owner["frames"][0]):
            raise ValueError(f"{sp['id']}: frame differs from frame 1 of {owner_id}; give it its own source")
        sp["ase_relpath"] = owner["ase_relpath"]


def _patch_char(layer: dict[str, Any], hex_color: str) -> str:
    for ch, hx in layer["legend"].items():
        if hx.upper() == hex_color:
            return ch
    ch = next(c for c in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" if c not in layer["legend"])
    layer["legend"][ch] = hex_color
    return ch


def _patch_pixel(layer: dict[str, Any], x: int, y: int, ch: str) -> None:
    row = layer["rows"][y]
    layer["rows"][y] = row[:x] + ch + row[x + 1 :]


def apply_seam_patches(sprites: list[dict[str, Any]]) -> None:
    """Set the pixels `specs/seam_patches.json` lists on top of the procedural spec.

    A patch names one flattened pixel (frame, x, y) and its final color and alpha. An
    opaque patch recolors the topmost layer that draws the pixel; a partial-alpha patch
    moves it into the layer of that opacity and clears the others (tiers are disjoint).
    The same list is written into the sources, so a rebuild reproduces them.
    """
    patches = json.loads(SEAM_PATCHES_PATH.read_text(encoding="utf-8"))
    for sp in sprites:
        for p in patches.get(sp["id"], []):
            layers = sp["frames"][p["frame"] - 1]["layers"]
            x, y, alpha = p["x"], p["y"], p["alpha"]
            drawn = [lay for lay in layers if lay["rows"][y][x] != "."]
            if alpha == 255:
                target = drawn[-1]
            else:
                target = next(lay for lay in layers if lay["opacity"] == alpha)
                for lay in drawn:
                    if lay is not target:
                        _patch_pixel(lay, x, y, ".")
            _patch_pixel(target, x, y, _patch_char(target, p["hex"].upper()))
