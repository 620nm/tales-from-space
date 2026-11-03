#!/usr/bin/env python3
r"""
Shared font loader, sRGB multiply-tint helper, 47-junction bitmask slicer, `AssetBank`,
and 4-layer shoreline / planetary diorama compositor (`build_mars_main_scene`,
`build_mars_vignette_1b`..`1d`, `build_earth_main_scene`, `build_earth_vignette_2b`..`2d`)
for Terrestrial Art spotcheck plates.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path
import sys
from typing import Any, Callable

from PIL import Image, ImageFont

PLATES_PKG_DIR = Path(__file__).resolve().parent
TERR_ROOT_DIR = PLATES_PKG_DIR.parent
for _p in (str(PLATES_PKG_DIR), str(TERR_ROOT_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from schema_contract import (  # noqa: E402
    BIOME_TINT_PRESETS,
    DEFAULT_OUT_DIR,
    EAST,
    JUNCTIONS,
    NE,
    NORTH,
    NW,
    SE,
    SOUTH,
    SW,
    WEST,
)

J_INDEX: dict[int, int] = {j: idx for idx, j in enumerate(JUNCTIONS)}


def is_smooth_kind(kind: str) -> bool:
    return kind == "smooth_strip"


def assert_plate_output(path: Path, out_dir: Path) -> Path:
    resolved = path.resolve()
    plates_root = (out_dir.resolve() / "plates").resolve()
    if not resolved.is_relative_to(plates_root):
        raise RuntimeError(f"Refusing plate write outside {plates_root}: {resolved}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def load_font(size: int, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        [
            "/usr/share/fonts/Adwaita/AdwaitaMono-Bold.ttf",
            "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
        ]
        if (mono and bold)
        else [
            "/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf",
            "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        ]
        if mono
        else [
            "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf",
        ]
        if bold
        else [
            "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf",
            "/usr/share/fonts/TTF/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ]
    )
    for cand in candidates:
        if Path(cand).exists():
            return ImageFont.truetype(cand, size)
    return ImageFont.load_default()


def scale_nn(im: Image.Image, factor: int) -> Image.Image:
    return im.resize((im.width * factor, im.height * factor), Image.Resampling.NEAREST)


def sanitize_mask(mask: int) -> int:
    out = mask & (NORTH | SOUTH | EAST | WEST)
    for diag, a, b in ((NW, NORTH, WEST), (NE, NORTH, EAST), (SE, SOUTH, EAST), (SW, SOUTH, WEST)):
        if (mask & diag) and (mask & a) and (mask & b):
            out |= diag
    return out


def compute_junction(
    pred: Callable[[int, int], bool],
    x: int,
    y: int,
    grid_w: int,
    grid_h: int,
    clamp_border: bool = False,
) -> int:
    """Compute canonical 47-junction bitmask with diagonal gating."""

    def ok(nx: int, ny: int) -> bool:
        if 0 <= nx < grid_w and 0 <= ny < grid_h:
            return pred(nx, ny)
        if clamp_border:
            return pred(min(max(nx, 0), grid_w - 1), min(max(ny, 0), grid_h - 1))
        return False

    mask = 0
    for bit, dx, dy in (
        (NORTH, 0, -1), (SOUTH, 0, 1), (EAST, 1, 0), (WEST, -1, 0),
        (NE, 1, -1), (SE, 1, 1), (SW, -1, 1), (NW, -1, -1),
    ):
        if ok(x + dx, y + dy):
            mask |= bit
    return sanitize_mask(mask)


def slice_junction_tile(strip_frame: Image.Image, junction: int) -> Image.Image:
    """Slice one 32x32 junction tile from a 160x32 5-block strip frame."""
    if strip_frame.size != (160, 32):
        raise ValueError(f"Expected 160x32 strip frame, got {strip_frame.size}")
    j = sanitize_mask(junction)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    quads = (
        (0, 0, bool(j & NORTH), bool(j & WEST), bool(j & NW)),
        (16, 0, bool(j & NORTH), bool(j & EAST), bool(j & NE)),
        (0, 16, bool(j & SOUTH), bool(j & WEST), bool(j & SW)),
        (16, 16, bool(j & SOUTH), bool(j & EAST), bool(j & SE)),
    )
    for qx, qy, v, h, d in quads:
        block = 0 if (not v and not h) else 1 if (v and not h) else 2 if (not v and h) else 3 if not d else 4
        out.paste(strip_frame.crop((block * 32 + qx, qy, block * 32 + qx + 16, qy + 16)), (qx, qy))
    return out


def cell_47(atlas: Image.Image, junction: int, frame: int = 0, cell_w: int = 32, cell_h: int = 32) -> Image.Image:
    col = J_INDEX[sanitize_mask(junction)]
    return atlas.crop((col * cell_w, frame * cell_h, (col + 1) * cell_w, (frame + 1) * cell_h))


def parse_hex_rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.strip().lstrip("#")
    if len(h) != 6:
        raise ValueError(f"Expected #RRGGBB hex color, got {hex_color!r}")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def tint_srgb_multiply(
    im: Image.Image,
    tint_hex: str | None = None,
    alpha_scale: float = 1.0,
) -> Image.Image:
    """Exact sRGB byte multiply `((px * tint + 127) // 255)` on RGB preserving alpha."""
    src = im.convert("RGBA")
    if (tint_hex is None or tint_hex.upper() == "#FFFFFF") and abs(alpha_scale - 1.0) < 1e-6:
        return src.copy()

    tr, tg, tb = parse_hex_rgb(tint_hex or "#FFFFFF")
    r_ch, g_ch, b_ch, a_ch = src.split()
    if (tr, tg, tb) != (255, 255, 255):
        r_ch = r_ch.point(lambda p: (p * tr + 127) // 255)
        g_ch = g_ch.point(lambda p: (p * tg + 127) // 255)
        b_ch = b_ch.point(lambda p: (p * tb + 127) // 255)
    if abs(alpha_scale - 1.0) >= 1e-6:
        a_ch = a_ch.point(lambda a: max(0, min(255, int(round(a * alpha_scale)))))
    return Image.merge("RGBA", (r_ch, g_ch, b_ch, a_ch))


class AssetBank:
    """Cached manifest loader & sprite cell slicer for `terrestrial.json` + `existing.json`."""

    def __init__(self, out_dir: Path = DEFAULT_OUT_DIR) -> None:
        self.out_dir = out_dir.resolve()
        manifests_dir = self.out_dir / "manifests"
        terr_path = manifests_dir / "terrestrial.json"
        exist_path = manifests_dir / "existing.json"
        if not terr_path.exists():
            raise FileNotFoundError(f"Missing {terr_path} (run terrestrial_kit.py first)")
        if not exist_path.exists():
            raise FileNotFoundError(f"Missing {exist_path} (run extract_reference_assets.py first)")

        self.terrestrial_records: list[dict[str, Any]] = json.loads(terr_path.read_text(encoding="utf-8"))
        self.existing_records: list[dict[str, Any]] = json.loads(exist_path.read_text(encoding="utf-8"))
        self.records: dict[str, dict[str, Any]] = {}
        for rec in self.terrestrial_records:
            self.records[rec["id"]] = rec
        for rec in self.existing_records:
            self.records[rec["id"]] = rec
        self._images: dict[str, Image.Image] = {}
        self._strips: dict[str, Image.Image] = {}
        self._cell_cache: dict[tuple[str, int, int, str, int], Image.Image] = {}

    def meta(self, asset_id: str) -> dict[str, Any]:
        if asset_id not in self.records:
            raise KeyError(f"Unknown asset_id: {asset_id!r}")
        return self.records[asset_id]

    def atlas(self, asset_id: str) -> Image.Image:
        if asset_id not in self._images:
            rel = self.meta(asset_id)["atlas_png_relpath"]
            self._images[asset_id] = Image.open(self.out_dir / rel).convert("RGBA")
        return self._images[asset_id]

    def strip(self, asset_id: str) -> Image.Image | None:
        rec = self.meta(asset_id)
        rel = rec.get("strip_png_relpath")
        if not rel:
            return None
        if asset_id not in self._strips:
            self._strips[asset_id] = Image.open(self.out_dir / rel).convert("RGBA")
        return self._strips[asset_id]

    def resolve_frame(self, asset_id: str, global_frame: int) -> int:
        rec = self.meta(asset_id)
        fc = int(rec["frame_count"])
        if fc <= 1:
            return 0
        if rec.get("rewind"):
            cycle = list(range(fc)) + list(range(fc - 2, 0, -1))
            return cycle[global_frame % len(cycle)]
        return global_frame % fc

    def get_cell(
        self,
        asset_id: str,
        junction: int = 255,
        global_frame: int = 0,
        tint_hex: str | None = None,
        alpha_scale: float = 1.0,
    ) -> Image.Image:
        rec = self.meta(asset_id)
        f_idx = self.resolve_frame(asset_id, global_frame)
        norm_tint = (tint_hex or "#FFFFFF").upper()
        alpha_key = int(round(alpha_scale * 1000))
        smooth = is_smooth_kind(rec["kind"])
        j_key = sanitize_mask(junction) if smooth else 0
        cache_key = (asset_id, j_key, f_idx, norm_tint, alpha_key)
        if cache_key in self._cell_cache:
            return self._cell_cache[cache_key]

        cw, ch = int(rec["cell_w"]), int(rec["cell_h"])
        sheet = self.atlas(asset_id)
        if smooth:
            col = J_INDEX[j_key]
            raw = sheet.crop((col * cw, f_idx * ch, (col + 1) * cw, (f_idx + 1) * ch))
        else:
            raw = sheet.crop((f_idx * cw, 0, (f_idx + 1) * cw, ch))

        out = tint_srgb_multiply(raw, norm_tint, alpha_scale)
        self._cell_cache[cache_key] = out
        return out


@dataclass
class SmoothLayerSpec:
    asset_id: str
    coords: set[tuple[int, int]]
    tint: str | None = None
    alpha: float = 1.0
    clamp_border: bool = False
    smooth_extra: set[tuple[int, int]] = field(default_factory=set)


@dataclass
class PlacedObject:
    asset_id: str
    x: int
    y: int
    tint: str | None = None
    alpha: float = 1.0
    z_bias: int = 0


@dataclass
class DioramaScene:
    grid_w: int
    grid_h: int
    tints: dict[str, str]
    substrate_asset: str = "terrain_silicate_rough_smooth"
    substrate_tint: str | None = None
    silicate_coords: set[tuple[int, int]] = field(default_factory=set)
    ice_coords: set[tuple[int, int]] = field(default_factory=set)
    ocean_coords: set[tuple[int, int]] = field(default_factory=set)
    cliff_coords: set[tuple[int, int]] = field(default_factory=set)
    silicate_under_ocean: bool = True
    station_decks: dict[tuple[int, int], str] = field(default_factory=dict)
    overwater_smooth_decks: list[SmoothLayerSpec] = field(default_factory=list)
    grass_coords: set[tuple[int, int]] = field(default_factory=set)
    moss_coords: set[tuple[int, int]] = field(default_factory=set)
    extra_terrain_smooth: list[SmoothLayerSpec] = field(default_factory=list)
    explicit_turfs: list[PlacedObject] = field(default_factory=list)
    station_decals: list[PlacedObject] = field(default_factory=list)
    matter_smooth: list[SmoothLayerSpec] = field(default_factory=list)
    matter_singles: list[PlacedObject] = field(default_factory=list)
    smooth_structures: list[SmoothLayerSpec] = field(default_factory=list)
    props_and_flora: list[PlacedObject] = field(default_factory=list)
    campfires: list[PlacedObject] = field(default_factory=list)
    haze_layers: list[SmoothLayerSpec] = field(default_factory=list)


def render_diorama_frame(bank: AssetBank, scene: DioramaScene, frame_idx: int = 3) -> Image.Image:
    """Composite one `grid_w x grid_h` planetary diorama at `frame_idx` across all 12 layers."""
    gw, gh = scene.grid_w, scene.grid_h
    canvas = Image.new("RGBA", (gw * 32, gh * 32), (20, 23, 34, 255))
    tints = scene.tints

    def paste_obj(obj: PlacedObject) -> None:
        rec = bank.meta(obj.asset_id)
        tint = obj.tint if obj.tint is not None else (rec["default_tint"] if rec["colorable"] else None)
        cell = bank.get_cell(obj.asset_id, 255, frame_idx, tint, obj.alpha)
        canvas.alpha_composite(cell, (obj.x * 32 + int(rec["offset_x"]), obj.y * 32 + int(rec["offset_y"])))

    def draw_smooth(spec: SmoothLayerSpec) -> None:
        if not spec.coords:
            return
        rec = bank.meta(spec.asset_id)
        union_set = spec.coords | spec.smooth_extra
        ox, oy = int(rec["offset_x"]), int(rec["offset_y"])
        for gy in range(gh):
            for gx in range(gw):
                if (gx, gy) not in spec.coords:
                    continue
                jv = compute_junction(lambda nx, ny: (nx, ny) in union_set, gx, gy, gw, gh, clamp_border=spec.clamp_border)
                canvas.alpha_composite(bank.get_cell(spec.asset_id, jv, frame_idx, spec.tint, spec.alpha), (gx * 32 + ox, gy * 32 + oy))

    sub_tint = scene.substrate_tint if scene.substrate_tint is not None else tints.get("silicate_low", "#82402A")
    sub_tile = bank.get_cell(scene.substrate_asset, 255, frame_idx, sub_tint)
    sil_255 = bank.get_cell("terrain_silicate_rough_smooth", 255, frame_idx, tints.get("silicate", "#B85C3C"))
    ice_255 = bank.get_cell("terrain_ice_sheet_smooth", 255, frame_idx, tints.get("ice", "#D4EFF7"))

    for gy in range(gh):
        for gx in range(gw):
            canvas.alpha_composite(sub_tile, (gx * 32, gy * 32))
            if (gx, gy) in scene.ocean_coords:
                for qx, qy, dxs, dys in (
                    (0, 0, (-1, 0, -1), (0, -1, -1)),
                    (16, 0, (1, 0, 1), (0, -1, -1)),
                    (0, 16, (-1, 0, -1), (0, 1, 1)),
                    (16, 16, (1, 0, 1), (0, 1, 1)),
                ):
                    nbs = [(gx + dx, gy + dy) for dx, dy in zip(dxs, dys, strict=True) if 0 <= gx + dx < gw and 0 <= gy + dy < gh]
                    if any(nb in scene.ice_coords for nb in nbs):
                        canvas.alpha_composite(ice_255.crop((qx, qy, qx + 16, qy + 16)), (gx * 32 + qx, gy * 32 + qy))
                    elif scene.silicate_under_ocean and any((nb in scene.silicate_coords or nb in scene.station_decks) for nb in nbs):
                        canvas.alpha_composite(sil_255.crop((qx, qy, qx + 16, qy + 16)), (gx * 32 + qx, gy * 32 + qy))

    for tobj in scene.explicit_turfs:
        paste_obj(tobj)

    calving_ice_edges = {
        (ix, iy)
        for (ix, iy) in scene.ice_coords
        if any((ix + dx, iy + dy) in scene.ocean_coords for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx, dy) != (0, 0))
    }
    if scene.ocean_coords:
        draw_smooth(SmoothLayerSpec("ocean_body_smooth", scene.ocean_coords | calving_ice_edges, tint=tints["ocean"], clamp_border=True))

    if scene.silicate_coords:
        sil_extra = scene.ocean_coords if scene.silicate_under_ocean else set()
        draw_smooth(SmoothLayerSpec("terrain_silicate_rough_smooth", scene.silicate_coords, tint=tints["silicate"], clamp_border=True, smooth_extra=sil_extra | scene.ice_coords))

    for ext in scene.extra_terrain_smooth:
        draw_smooth(ext)

    if scene.ice_coords:
        draw_smooth(SmoothLayerSpec("terrain_ice_sheet_smooth", scene.ice_coords, tint=tints["ice"], clamp_border=True))

    plating_tile = bank.get_cell("plating", 255, frame_idx, None)
    for (sx, sy), deck_id in sorted(scene.station_decks.items()):
        if deck_id in ("open_floor", "wall", "reinforced_wall", "airlock_closed", "airlock_glass_closed"):
            canvas.alpha_composite(plating_tile, (sx * 32, sy * 32))
        canvas.alpha_composite(bank.get_cell(deck_id, 255, frame_idx, None), (sx * 32, sy * 32))

    if scene.ocean_coords:
        draw_smooth(SmoothLayerSpec("ocean_backwash_smooth", scene.ocean_coords, tint=tints.get("backwash", "#4A2218"), clamp_border=True))
        draw_smooth(SmoothLayerSpec("ocean_swash_smooth", scene.ocean_coords, tint=tints["swash"], clamp_border=True))
        draw_smooth(SmoothLayerSpec("ocean_foam_lace_smooth", scene.ocean_coords, tint=tints["swash"], clamp_border=True))

    for ow in scene.overwater_smooth_decks:
        draw_smooth(ow)

    ground_grass = scene.grass_coords - scene.cliff_coords
    ground_moss = scene.moss_coords - scene.cliff_coords
    if ground_grass:
        draw_smooth(SmoothLayerSpec("solid_grass_smooth", ground_grass, tint=tints["grass"]))
    if ground_moss:
        draw_smooth(SmoothLayerSpec("solid_moss_smooth", ground_moss, tint=tints["moss"]))

    for dec in scene.station_decals:
        paste_obj(dec)

    if scene.cliff_coords:
        draw_smooth(SmoothLayerSpec("terrain_cliff_stepped_smooth", scene.cliff_coords, tint=tints["cliff"], clamp_border=True))
        if scene.grass_coords & scene.cliff_coords:
            draw_smooth(SmoothLayerSpec("solid_grass_smooth", scene.grass_coords & scene.cliff_coords, tint=tints["grass"], clamp_border=True))
        if scene.moss_coords & scene.cliff_coords:
            draw_smooth(SmoothLayerSpec("solid_moss_smooth", scene.moss_coords & scene.cliff_coords, tint=tints["moss"], clamp_border=True))

    for ms in scene.matter_smooth:
        draw_smooth(ms)
    for mp in scene.matter_singles:
        paste_obj(mp)

    by_row: dict[int, list[PlacedObject]] = {ry: [] for ry in range(gh)}
    for obj in scene.props_and_flora:
        if 0 <= obj.y < gh:
            by_row[obj.y].append(obj)

    hedge_specs_by_row = [
        (
            hs,
            {
                (gx, gy): compute_junction(lambda nx, ny, s=hs: (nx, ny) in (s.coords | s.smooth_extra), gx, gy, gw, gh, clamp_border=hs.clamp_border)
                for (gx, gy) in hs.coords
            },
        )
        for hs in scene.smooth_structures
    ]

    for ry in range(gh):
        for hs, jmap in hedge_specs_by_row:
            rec = bank.meta(hs.asset_id)
            ox, oy = int(rec["offset_x"]), int(rec["offset_y"])
            for gx in range(gw):
                if (gx, ry) in jmap:
                    canvas.alpha_composite(bank.get_cell(hs.asset_id, jmap[(gx, ry)], frame_idx, hs.tint, hs.alpha), (gx * 32 + ox, ry * 32 + oy))
        for obj in sorted(by_row[ry], key=lambda o: (o.z_bias, o.x)):
            paste_obj(obj)

    for cf in scene.campfires:
        paste_obj(cf)
    for hz in scene.haze_layers:
        draw_smooth(hz)
    return canvas


def rect_coords(x0: int, y0: int, x1: int, y1: int) -> set[tuple[int, int]]:
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def build_mars_main_scene() -> DioramaScene:
    """14x9 Mars Main Diorama: Rust-Silicate Cliffs, Calving Ice Sheet, Liquid Ammonia Ocean & Pier."""
    tints = dict(BIOME_TINT_PRESETS["mars_cryo_ammonia"])
    gw, gh = 14, 9
    cliff = rect_coords(0, 0, 4, 1) | rect_coords(0, 2, 3, 2) | rect_coords(0, 3, 1, 3)
    ice = rect_coords(7, 0, 13, 0) | rect_coords(8, 1, 13, 1) | rect_coords(9, 2, 13, 2) | rect_coords(11, 3, 13, 3)
    ocean = {(9, 3), (10, 3)} | rect_coords(7, 4, 13, 5) | rect_coords(5, 6, 13, 8)
    silicate = rect_coords(0, 0, gw - 1, gh - 1) - ocean - ice - {(5, 0), (5, 1), (6, 1), (4, 3)}

    decks: dict[tuple[int, int], str] = {
        (0, 5): "floor", (1, 5): "floor", (2, 5): "floor",
        (0, 6): "floor", (1, 6): "floor", (2, 6): "plating",
        (0, 7): "floor", (1, 7): "floor", (2, 7): "plating",
        (3, 6): "plating", (4, 5): "plating", (4, 6): "plating", (4, 7): "plating",
    }
    wall_coords = [(0, 4), (1, 4), (2, 4), (3, 4), (3, 5), (3, 7), (0, 8), (1, 8), (2, 8), (3, 8)]
    for wc in wall_coords:
        decks[wc] = "plating"

    pier = SmoothLayerSpec("catwalk", {(5, 6), (6, 6), (7, 6)}, smooth_extra={(4, 6)})
    moss = {(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 3), (3, 3)}
    station_decals = [
        PlacedObject("decal_hazard_s", 1, 7), PlacedObject("decal_hazard_s", 2, 7),
        PlacedObject("decal_hazard_s", 4, 5), PlacedObject("decal_hazard_e", 4, 6),
    ]
    matter_smooth = [
        SmoothLayerSpec("solid_dusting_flour_smooth", {(7, 0), (7, 1), (8, 1), (8, 2), (9, 2)}, tint="#E8F4F8", alpha=0.48, clamp_border=True),
        SmoothLayerSpec("liquid_puddle_smooth_shimmer", {(2, 6), (3, 6), (4, 6)}, tint=tints["ocean"], alpha=0.85),
        SmoothLayerSpec("solid_debris_jagged_smooth", {(4, 7), (4, 8)}, tint=tints["silicate"], alpha=0.80),
    ]
    matter_singles = [
        PlacedObject("solid_shards_large", 10, 2, tint=tints["ice"]),
        PlacedObject("solid_shards_large", 12, 3, tint=tints["ice"]),
        PlacedObject("solid_scattering", 2, 7, tint=tints["silicate"]),
    ]
    props: list[PlacedObject] = [
        *[PlacedObject("wall", wx, wy, z_bias=0) for (wx, wy) in wall_coords],
        PlacedObject("apc", 2, 4, z_bias=2),
        PlacedObject("airlock_glass_closed", 3, 6, z_bias=1),
        PlacedObject("canister_ammonia", 1, 5, z_bias=3),
        PlacedObject("canister_ammonia", 4, 5, z_bias=3),
        PlacedObject("crate_steel", 0, 6, z_bias=3),
        PlacedObject("prop_rough_outcrop_1", 1, 1, tint=tints["cliff"], z_bias=4),
        PlacedObject("siderite_growth1", 3, 1, z_bias=5),
        PlacedObject("siderite_growth2", 5, 2, z_bias=5),
        PlacedObject("basalt2", 6, 2, tint=tints["silicate"], z_bias=4),
        PlacedObject("prop_rough_outcrop_1", 5, 3, tint=tints["silicate"], z_bias=4),
        PlacedObject("lavarocks_siderite1", 2, 3, z_bias=4),
        PlacedObject("lavarocks_siderite2", 7, 2, z_bias=4),
        PlacedObject("basalt1", 8, 3, tint=tints["cliff"], z_bias=4),
        PlacedObject("ore_vent_ice", 11, 1, z_bias=5),
        PlacedObject("prop_rough_outcrop_2", 9, 1, tint=tints["ice"], z_bias=4),
        PlacedObject("prop_rough_outcrop_2", 12, 2, tint=tints["ice"], z_bias=4),
        PlacedObject("geyser", 6, 4, tint="#9EA858", z_bias=5),
    ]
    haze = [SmoothLayerSpec("gas_mist_smooth_gentle", rect_coords(7, 4, 10, 5) | rect_coords(8, 6, 11, 6), tint=tints["haze"], alpha=0.45)]
    return DioramaScene(
        grid_w=gw, grid_h=gh, tints=tints, silicate_coords=silicate, ice_coords=ice, ocean_coords=ocean,
        cliff_coords=cliff, silicate_under_ocean=True, station_decks=decks, overwater_smooth_decks=[pier],
        moss_coords=moss, station_decals=station_decals, matter_smooth=matter_smooth,
        matter_singles=matter_singles, props_and_flora=props, haze_layers=haze,
    )


def build_mars_vignette_1b() -> DioramaScene:
    """6x6 Vignette 1B: the pack's own colours (ammonia `color`, iron_oxide `color`, water solid tint)."""
    tints = dict(BIOME_TINT_PRESETS["mars_pack_ammonia"])
    all_t = rect_coords(0, 0, 5, 5)
    cliff = {(0, 0), (1, 0), (0, 1), (1, 1)}
    ice = {(3, 0), (4, 0), (5, 0), (4, 1), (5, 1)}
    ocean = {(3, 2), (4, 2), (5, 2)} | rect_coords(2, 3, 5, 5)
    silicate = all_t - ocean - ice - {(2, 1)}
    decks = {(0, 4): "plating", (1, 4): "plating", (0, 5): "floor", (1, 5): "plating"}
    return DioramaScene(
        grid_w=6, grid_h=6, tints=tints, silicate_coords=silicate, ice_coords=ice, ocean_coords=ocean,
        cliff_coords=cliff, silicate_under_ocean=True, station_decks=decks,
        station_decals=[PlacedObject("decal_hazard_e", 1, 4)],
        matter_singles=[PlacedObject("solid_shards_large", 4, 1, tint=tints["ice"])],
        props_and_flora=[
            PlacedObject("wall", 0, 4), PlacedObject("canister_ammonia", 0, 5, z_bias=3),
            PlacedObject("prop_rough_outcrop_1", 2, 2, tint=tints["silicate"]), PlacedObject("lavarocks_siderite1", 1, 2),
        ],
        haze_layers=[SmoothLayerSpec("gas_mist_smooth_gentle", {(3, 3), (4, 3), (3, 4), (4, 4)}, tint=tints["haze"], alpha=0.45)],
    )


def _shared_morph_masks() -> tuple[set[tuple[int, int]], set[tuple[int, int]], set[tuple[int, int]]]:
    cliff = {(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (0, 2)}
    ocean = rect_coords(3, 2, 5, 3) | rect_coords(2, 4, 5, 5)
    return cliff, ocean, rect_coords(0, 0, 5, 5)


def build_mars_vignette_1c() -> DioramaScene:
    """6x6 Vignette 1C: Glacial Ammonia-Water Brine (#7AC5CD ocean + #C96A4B rust ironsand + #E2F4FA ice)."""
    cliff, ocean, all_t = _shared_morph_masks()
    tints = {
        "silicate": "#C96A4B", "silicate_low": "#8E4630", "ice": "#E2F4FA", "cliff": "#A85238",
        "ocean": "#7AC5CD", "backwash": "#54271A", "swash": "#F0FCFA",
        "grass": "#A8743A", "moss": "#8F9E6B", "haze": "#E6F4F2",
    }
    ice = {(4, 0), (5, 0), (4, 1), (5, 1)}
    return DioramaScene(
        grid_w=6, grid_h=6, tints=tints, silicate_coords=all_t - ocean - ice - {(3, 1)},
        ice_coords=ice, ocean_coords=ocean, cliff_coords=cliff, silicate_under_ocean=True,
        moss_coords={(0, 0), (1, 0)},
        props_and_flora=[
            PlacedObject("prop_rough_outcrop_1", 1, 2, tint=tints["cliff"]),
            PlacedObject("prop_rough_outcrop_2", 4, 1, tint=tints["ice"]),
            PlacedObject("siderite_growth1", 1, 1, z_bias=4),
        ],
    )


def build_mars_vignette_1d() -> DioramaScene:
    """6x6 Vignette 1D: Polar Basalt & Calving Ammonia Polynya (#5E626E basalt + #DCF2FA ice + glass_floor)."""
    tints = dict(BIOME_TINT_PRESETS["mars_polar_ice"])
    all_t = rect_coords(0, 0, 5, 5)
    ocean = {(2, 2), (3, 2), (4, 2), (1, 3), (2, 3), (3, 3), (4, 3), (2, 4), (3, 4), (4, 4)}
    ice = {(2, 0), (3, 0), (4, 0), (5, 0), (3, 1), (4, 1), (5, 1), (5, 2), (5, 3), (5, 4), (4, 5), (5, 5)}
    decks = {(0, 3): "wall", (0, 4): "floor", (0, 5): "wall", (1, 5): "plating", (2, 5): "wall"}
    return DioramaScene(
        grid_w=6, grid_h=6, tints=tints, silicate_coords=all_t - ocean - ice, ice_coords=ice,
        ocean_coords=ocean, cliff_coords={(0, 0), (1, 0), (0, 1)}, silicate_under_ocean=True,
        station_decks=decks, overwater_smooth_decks=[SmoothLayerSpec("glass_floor", {(1, 3), (2, 3), (1, 4), (2, 4)})],
        matter_singles=[PlacedObject("solid_shards_small", 5, 3, tint=tints["ice"])],
        props_and_flora=[
            PlacedObject("wall", 0, 3), PlacedObject("wall", 0, 5), PlacedObject("wall", 2, 5),
            PlacedObject("airlock_glass_closed", 1, 5, z_bias=2), PlacedObject("ore_vent_ice", 4, 1, z_bias=4),
            PlacedObject("basalt1", 1, 2, tint=tints["silicate"]), PlacedObject("prop_rough_outcrop_2", 3, 0, tint=tints["ice"]),
        ],
    )


def build_earth_main_scene() -> DioramaScene:
    """14x9 Earth Main Diorama: Same Smooth Assets + Smooth Nature Decals, TG Flora & Overgrown Outpost."""
    tints = dict(BIOME_TINT_PRESETS["earth_coastal_meadow"])
    gw, gh = 14, 9
    cliff = rect_coords(0, 0, 4, 1) | rect_coords(0, 2, 3, 2) | rect_coords(0, 3, 1, 3) | rect_coords(12, 0, 13, 1)
    ocean = rect_coords(9, 4, 13, 4) | rect_coords(7, 5, 13, 6) | rect_coords(6, 7, 13, 8)
    beach_sand_band = {(9, 3), (10, 3), (11, 3), (12, 3), (13, 3), (7, 4), (8, 4), (6, 5), (6, 6), (5, 7), (5, 8)}
    silicate = rect_coords(0, 0, gw - 1, gh - 1) - ocean - beach_sand_band

    rwall_coords = [(0, 4), (1, 4), (2, 4), (2, 5), (2, 7), (0, 8), (1, 8), (2, 8)]
    decks: dict[tuple[int, int], str] = {
        (0, 5): "floor", (1, 5): "floor", (0, 6): "floor", (1, 6): "floor",
        (0, 7): "floor", (1, 7): "open_floor", (2, 6): "plating",
        (3, 5): "plating", (3, 6): "plating", (3, 7): "plating",
        (4, 6): "plating", (4, 7): "plating", (5, 6): "plating",
    }
    for rw in rwall_coords:
        decks[rw] = "plating"

    grass = rect_coords(4, 0, 11, 2) | {(2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (6, 4), (4, 6), (5, 6), (4, 7)}
    moss = {(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (1, 7), (3, 5), (3, 7), (12, 0), (13, 0)}
    matter_smooth = [
        SmoothLayerSpec("solid_soil_tilled_smooth", {(4, 4), (5, 4), (4, 5), (5, 5)}, tint="#6B4C35"),
        SmoothLayerSpec("liquid_puddle_smooth", {(3, 6), (4, 6)}, tint="#5F9BD5", alpha=0.86),
        SmoothLayerSpec("liquid_puddle_smooth_shimmer", {(3, 6)}, tint="#75B2EB", alpha=0.55),
    ]
    props: list[PlacedObject] = [
        *[PlacedObject("reinforced_wall", wx, wy, z_bias=0) for (wx, wy) in rwall_coords],
        PlacedObject("airlock_closed", 2, 6, z_bias=1),
        PlacedObject("crate_hydro", 0, 5, z_bias=3),
        PlacedObject("canister_blue", 3, 4, z_bias=3),
        PlacedObject("tree1", 4, 2, z_bias=6),
        PlacedObject("tree2", 8, 2, z_bias=6),
        PlacedObject("bush1", 11, 1, z_bias=5),
        PlacedObject("palm1", 11, 3, z_bias=6),
        PlacedObject("ywflowers_1", 6, 1, z_bias=2),
        PlacedObject("ppflowers_1", 6, 2, z_bias=2),
        PlacedObject("ppflowers_1", 10, 1, z_bias=2),
        PlacedObject("brflowers_1", 10, 2, z_bias=2),
        PlacedObject("lavendergrass_1", 7, 1, z_bias=2),
        PlacedObject("lavendergrass_1", 6, 3, z_bias=2),
        PlacedObject("fernybush_1", 5, 1, z_bias=3),
        PlacedObject("fernybush_1", 9, 2, z_bias=3),
        PlacedObject("reedbush_1", 7, 4, z_bias=4),
        PlacedObject("reedbush_2", 6, 6, z_bias=4),
        PlacedObject("prop_rough_outcrop_1", 1, 1, tint=tints["cliff"], z_bias=4),
        PlacedObject("prop_rough_outcrop_2", 3, 2, tint=tints["cliff"], z_bias=4),
        PlacedObject("rock1", 2, 3, z_bias=4),
        PlacedObject("rock3", 8, 3, z_bias=4),
        PlacedObject("rock2", 12, 2, z_bias=4),
        PlacedObject("rocks1", 12, 1, z_bias=5),
    ]
    return DioramaScene(
        grid_w=gw, grid_h=gh, tints=tints, silicate_coords=silicate, ocean_coords=ocean, cliff_coords=cliff,
        silicate_under_ocean=False, station_decks=decks, grass_coords=grass, moss_coords=moss,
        matter_smooth=matter_smooth, matter_singles=[PlacedObject("solid_pile_small", 9, 3, tint="#6B5746")],
        smooth_structures=[SmoothLayerSpec("tg_hedge", {(3, 3), (4, 3), (5, 3)})],
        props_and_flora=props, campfires=[PlacedObject("fire_campfire_steady", 9, 3)],
    )


def build_earth_vignette_2b() -> DioramaScene:
    """6x6 Vignette 2B: Lush Jungle / Highland Basin & Campfire (`tree1`, `rocks1`, `bush1`, campfire)."""
    tints = dict(BIOME_TINT_PRESETS["earth_lush_jungle"])
    all_t = rect_coords(0, 0, 5, 5)
    ocean = {(4, 3), (5, 3)} | rect_coords(3, 4, 5, 5)
    cliff = {(4, 0), (5, 0), (5, 1)}
    return DioramaScene(
        grid_w=6, grid_h=6, tints=tints, silicate_coords=all_t - ocean, ocean_coords=ocean, cliff_coords=cliff,
        silicate_under_ocean=False, grass_coords=all_t - ocean - cliff - {(2, 3)},
        moss_coords={(0, 0), (0, 1), (4, 0), (5, 0), (1, 3), (2, 4)},
        matter_singles=[PlacedObject("solid_pile_small", 2, 3, tint="#5C4D42")],
        props_and_flora=[
            PlacedObject("tree1", 1, 2, z_bias=6),
            PlacedObject("rocks1", 4, 1, z_bias=4),
            PlacedObject("bush1", 1, 4, z_bias=5),
            PlacedObject("reedbush_1", 3, 3, z_bias=3),
            PlacedObject("fernybush_2", 3, 2, z_bias=3),
        ],
        campfires=[PlacedObject("fire_campfire_steady", 2, 3)],
        haze_layers=[SmoothLayerSpec("gas_mist_smooth_gentle", {(3, 4), (4, 4), (5, 4), (4, 5), (5, 5)}, tint=tints["haze"], alpha=0.38)],
    )


def build_earth_vignette_2c() -> DioramaScene:
    """6x6 Vignette 2C: Same-Geometry Morph Proof (exact same cliff/bay layout as Mars Vignette 1C)."""
    cliff, ocean, all_t = _shared_morph_masks()
    tints = dict(BIOME_TINT_PRESETS["earth_coastal_meadow"])
    beach_margin = {(3, 1), (2, 2), (2, 3), (1, 4), (1, 5)}
    return DioramaScene(
        grid_w=6, grid_h=6, tints=tints, silicate_coords=all_t - ocean - beach_margin,
        ocean_coords=ocean, cliff_coords=cliff, silicate_under_ocean=False,
        grass_coords={(3, 0), (4, 0), (5, 0), (2, 1), (4, 1), (5, 1), (1, 2), (0, 3), (1, 3), (0, 4)},
        moss_coords={(0, 0), (1, 0), (0, 1)},
        props_and_flora=[
            PlacedObject("prop_rough_outcrop_1", 1, 2, tint=tints["cliff"]),
            PlacedObject("prop_rough_outcrop_2", 4, 1, tint=tints["cliff"]),
            PlacedObject("ywflowers_1", 3, 0),
            PlacedObject("ppflowers_1", 5, 1),
            PlacedObject("reedbush_2", 2, 3),
        ],
    )


def build_earth_vignette_2d() -> DioramaScene:
    """6x6 Vignette 2D: Upstream `tgstation` Native Reference (`tg_grass_smooth` 50x50 + `beach.dmi` + `palm1`)."""
    tints = dict(BIOME_TINT_PRESETS["earth_coastal_meadow"])
    grid = [
        ["tg_beach_sand", "tg_beach_sand", "tg_beach_sand", "tg_beach_sand", "tg_beach_coast_e", "tg_beach_water"],
        ["tg_beach_sand", "tg_beach_sand", "tg_beach_sand", "tg_beach_corner_s", "tg_beach_coast_se", "tg_beach_water"],
        ["tg_beach_sand", "tg_beach_sand", "tg_beach_corner_s", "tg_beach_coast_se", "tg_beach_water", "tg_beach_deepwater"],
        ["tg_beach_sand", "tg_beach_corner_s", "tg_beach_coast_se", "tg_beach_water", "tg_beach_water", "tg_beach_deepwater"],
        ["tg_beach_coast_s", "tg_beach_coast_se", "tg_beach_water", "tg_beach_water", "tg_beach_deepwater", "tg_beach_deepwater"],
        ["tg_beach_water", "tg_beach_water", "tg_beach_deepwater", "tg_beach_deepwater", "tg_beach_deepwater", "tg_beach_deepwater"],
    ]
    return DioramaScene(
        grid_w=6, grid_h=6, tints=tints, substrate_asset="tg_beach_sand", substrate_tint="#FFFFFF",
        explicit_turfs=[PlacedObject(grid[y][x], x, y) for y in range(6) for x in range(6)],
        extra_terrain_smooth=[SmoothLayerSpec("tg_grass_smooth", {(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (0, 2)}, clamp_border=True)],
        props_and_flora=[PlacedObject("palm1", 2, 1, z_bias=5), PlacedObject("ywflowers_2", 1, 1, z_bias=2), PlacedObject("fernybush_1", 0, 2, z_bias=3)],
    )
