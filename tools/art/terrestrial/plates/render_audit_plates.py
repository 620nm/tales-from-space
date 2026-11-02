#!/usr/bin/env python3
r"""
Render the 4 Terrestrial Art audit & reference spotcheck plates into `<out-dir>/plates/`:
  - `01_tg_outdoor_gems.png` (curated `tgstation` outdoor, planetary, cliff & shoreline reference)
  - `02_terrestrial_strips_audit.png` (raw greyscale strips, Mars/Earth tints, 12f surf & props)
  - `08_feedback_fixes_spotcheck.png` (12f 4-layer surf, silky ocean, flat decals, outcrops & seams)
  - `09_anti_repetition_spotcheck.png` (4x4 tiling anti-repetition at 2x pixel & 1x game scale)
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path
import sys

from PIL import Image, ImageDraw

PLATES_PKG_DIR = Path(__file__).resolve().parent
TERR_ROOT_DIR = PLATES_PKG_DIR.parent
for _p in (str(PLATES_PKG_DIR), str(TERR_ROOT_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from scene_compositor import (  # noqa: E402
    J_INDEX, AssetBank, assert_plate_output, cell_47, compute_junction,
    is_smooth_kind, load_font, scale_nn, tint_srgb_multiply,
)
from schema_contract import BIOME_TINT_PRESETS, DEFAULT_OUT_DIR  # noqa: E402


# ---------------------------------------------------------------------------
# Plate 01: Curated `tgstation` Outdoor, Planetary, Cliff & Shoreline Gems
# ---------------------------------------------------------------------------
def _render_smooth_island(
    bank: AssetBank, base_id: str, smooth_id: str, mask_coords: set[tuple[int, int]],
    grid_w: int = 5, grid_h: int = 5, base_tint: str | None = None,
    smooth_tint: str | None = None, split_smooth_tint_right: str | None = None,
    center_fill_id: str | None = None,
) -> Image.Image:
    canvas = Image.new("RGBA", (grid_w * 32, grid_h * 32), (0, 0, 0, 255))
    base_im = tint_srgb_multiply(bank.atlas(base_id).crop((0, 0, 32, 32)), base_tint)
    for gy in range(grid_h):
        for gx in range(grid_w):
            canvas.alpha_composite(base_im, (gx * 32, gy * 32))
    if center_fill_id:
        canvas.alpha_composite(bank.atlas(center_fill_id).crop((0, 0, 32, 32)), (64, 64))

    sm_rec, sm_atlas = bank.meta(smooth_id), bank.atlas(smooth_id)
    cw, ch, ox, oy = int(sm_rec["cell_w"]), int(sm_rec["cell_h"]), int(sm_rec["offset_x"]), int(sm_rec["offset_y"])
    for gy in range(grid_h):
        for gx in range(grid_w):
            if (gx, gy) not in mask_coords:
                continue
            col = J_INDEX[compute_junction(lambda nx, ny: (nx, ny) in mask_coords, gx, gy, grid_w, grid_h)]
            cell = sm_atlas.crop((col * cw, 0, (col + 1) * cw, ch))
            tint = split_smooth_tint_right if (split_smooth_tint_right and gx >= grid_w // 2) else smooth_tint
            canvas.alpha_composite(tint_srgb_multiply(cell, tint), (gx * 32 + ox, gy * 32 + oy))
    return canvas


def _render_mineral_pool(
    bank: AssetBank, land_id: str, outline_id: str, land_is_smooth: bool = True,
    land_tint: str | None = None, outline_tint: str | None = None, water_tint: str | None = None,
) -> Image.Image:
    grid_w = grid_h = 5
    pool = {(x, y) for y in range(1, 4) for x in range(1, 4)}
    canvas = Image.new("RGBA", (160, 160), (0, 0, 0, 255))
    land_rec, land_atlas = bank.meta(land_id), bank.atlas(land_id)
    if land_is_smooth:
        cw, ch, ox, oy = int(land_rec["cell_w"]), int(land_rec["cell_h"]), int(land_rec["offset_x"]), int(land_rec["offset_y"])
        land_cell = tint_srgb_multiply(land_atlas.crop((J_INDEX[255] * cw, 0, (J_INDEX[255] + 1) * cw, ch)), land_tint)
    else:
        ox = oy = 0
        land_cell = tint_srgb_multiply(land_atlas.crop((0, 0, 32, 32)), land_tint)
    for gy in range(grid_h):
        for gx in range(grid_w):
            if (gx, gy) not in pool:
                canvas.alpha_composite(land_cell, (gx * 32 + ox, gy * 32 + oy))

    wat_255 = tint_srgb_multiply(cell_47(bank.atlas("tg_water_lavaland"), 255, 0), water_tint)
    out_atlas = bank.atlas(outline_id)
    for gy in range(1, 4):
        for gx in range(1, 4):
            canvas.alpha_composite(wat_255, (gx * 32, gy * 32))
            pj = compute_junction(lambda nx, ny: (nx, ny) in pool, gx, gy, grid_w, grid_h)
            if pj != 255:
                canvas.alpha_composite(tint_srgb_multiply(cell_47(out_atlas, pj, 0), outline_tint), (gx * 32, gy * 32))
    return canvas


def _render_beach_bay(bank: AssetBank) -> Image.Image:
    canvas = Image.new("RGBA", (160, 160), (0, 0, 0, 255))
    grid = [
        ["tg_beach_sand", "tg_beach_sand", "tg_beach_sand", "tg_beach_coast_e", "tg_beach_water"],
        ["tg_beach_sand", "tg_beach_sand", "tg_beach_corner_s", "tg_beach_coast_se", "tg_beach_water"],
        ["tg_beach_sand", "tg_beach_corner_s", "tg_beach_coast_se", "tg_beach_water", "tg_beach_deepwater"],
        ["tg_beach_coast_s", "tg_beach_coast_se", "tg_beach_water", "tg_beach_water", "tg_beach_deepwater"],
        ["tg_beach_water", "tg_beach_water", "tg_beach_deepwater", "tg_beach_deepwater", "tg_beach_deepwater"],
    ]
    for gy, row in enumerate(grid):
        for gx, tid in enumerate(row):
            fr = 1 if ("coast" in tid or "corner" in tid) else 0
            canvas.alpha_composite(bank.atlas(tid).crop((fr * 32, 0, (fr + 1) * 32, 32)), (gx * 32, gy * 32))
    canvas.alpha_composite(bank.atlas("palm1"), (0, 0))
    return canvas


def render_plate_01(bank: AssetBank, out_dir: Path) -> Path:
    W, H = 1960, 84 + 444 + 556 + 464 + 452 + 24
    BG, CARD_BG, CARD_BD, SWATCH_BG = (20, 23, 34, 255), (28, 33, 48, 255), (48, 57, 82, 255), (35, 42, 60, 255)
    TXT_HI, TXT_MD, TXT_LO, ACCENT = (236, 241, 252, 255), (176, 188, 214, 255), (126, 140, 172, 255), (110, 196, 232, 255)
    f_h1, f_sub, f_band = load_font(24, bold=True), load_font(14), load_font(17, bold=True)
    f_lbl, f_cit, f_tiny = load_font(13, bold=True), load_font(11, mono=True), load_font(10, mono=True)

    plate = Image.new("RGBA", (W, H), BG)
    draw = ImageDraw.Draw(plate)
    draw.text((32, 20), "PLATE 01 — CURATED TGSTATION OUTDOOR, PLANETARY, CLIFF & SHORELINE GEMS", font=f_h1, fill=TXT_HI)
    draw.text((32, 52), "Read-only reference extraction from tgstation/icons/ • Nearest-neighbor 2x pixel scaling • Overhang offsets & inverse shoreline masks preserved", font=f_sub, fill=TXT_MD)

    def draw_band_box(y0: int, h: int, title: str, subtitle: str) -> int:
        draw.rounded_rectangle((24, y0, W - 24, y0 + h), radius=8, fill=CARD_BG, outline=CARD_BD, width=1)
        draw.text((40, y0 + 12), title, font=f_band, fill=ACCENT)
        draw.text((40 + draw.textlength(title, font=f_band) + 16, y0 + 15), subtitle, font=f_cit, fill=TXT_LO)
        draw.line((40, y0 + 38, W - 40, y0 + 38), fill=CARD_BD, width=1)
        return y0 + 48

    island_3x3 = {(x, y) for y in range(1, 4) for x in range(1, 4)}
    hedge_ring = island_3x3 - {(2, 2)}

    # Band 1: Smooth Nature & Grass Turfs
    y_cur = 84
    cy = draw_band_box(y_cur, 430, "1. SMOOTH NATURE & GRASS TURFS (2x)", "5x5 turf swatches with 3x3 smoothed islands demonstrating native 50x50 (-9,-9) overhang bleed & 32x32 enclosures")
    b1_cards = [
        (_render_smooth_island(bank, "tg_sand", "tg_grass_smooth", island_3x3), "tg_grass_smooth (50x50, -9,-9)", "over tg_sand • grass.dmi (grass.dm:1-22)"),
        (_render_smooth_island(bank, "tg_dirt", "tg_junglegrass_smooth", island_3x3), "tg_junglegrass_smooth (50x50, -9,-9)", "over tg_dirt • junglegrass.dmi (planet.dm:68-77)"),
        (_render_smooth_island(bank, "tg_greenerdirt", "tg_grass_damaged_smooth", island_3x3), "tg_grass_damaged_smooth (50x50)", "over greenerdirt • grass_damaged.dmi (grass.dm:20-26)"),
        (_render_smooth_island(bank, "tg_dirt", "tg_hedge", hedge_ring, center_fill_id="tg_fairygrass"), "tg_hedge (32x32) + tg_fairygrass", "hedge.dmi (hedges.dm:35) • fancy_floor.dm:192"),
        (_render_smooth_island(bank, "rock_floor", "tg_ice_turf", island_3x3), "tg_ice_turf over rock_floor", "ice_turf.dmi (ice.dm:75) • floors.dmi:\"asteroid\""),
    ]
    for i, (im5, lbl, cit) in enumerate(b1_cards):
        cx = 42 + i * 376
        draw.rectangle((cx - 1, cy - 1, cx + 320, cy + 320), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(im5, 2), (cx, cy))
        draw.text((cx, cy + 326), lbl, font=f_lbl, fill=TXT_HI)
        draw.text((cx, cy + 344), cit, font=f_cit, fill=TXT_LO)

    # Band 2: Flora, Ferns, Reeds, Bushes & Oversized Trees
    y_cur += 444
    cy = draw_band_box(y_cur, 542, "2. WILDFLOWERS, FERNS, REEDS, BUSHES & OVERSIZED TREES (2x)", "ausflora.dmi (flora.dm:684-902) • jungleflora.dmi (flora.dm:616-1160) • ash_flora.dmi (ash_flora.dm:101-227) • Oversized trees & boulders w/ anchors")
    meadow_bg, jungle_bg, basalt_bg = scale_nn(bank.atlas("tg_dirt"), 2), scale_nn(bank.atlas("tg_greenerdirt"), 2), scale_nn(bank.atlas("tg_basalt"), 2)
    flora_rows = (
        ["ywflowers_1", "ywflowers_2", "ppflowers_1", "ppflowers_2", "brflowers_1", "lavendergrass_1", "lavendergrass_2", "sunnybush_1", "sparsegrass_1", "fullgrass_1"],
        ["fernybush_1", "fernybush_2", "reedbush_1", "reedbush_2", "leafybush_1", "grassybush_1", "busha1", "bushb1", "bushc1", "grassa1"],
        ["grassb1", "rock1", "rock2", "rock3", "glowgrowth1", "chilly_pepper1", "fireblossom1", "seraka_mushroom1", "cactus1"],
    )
    draw.text((42, cy - 2), "ausflora.dmi + jungleflora.dmi + ash_flora.dmi (64x64 @ 2x over dirt / greenerdirt / basalt):", font=f_lbl, fill=TXT_MD)
    ash_ids = {"glowgrowth1", "chilly_pepper1", "fireblossom1", "seraka_mushroom1", "cactus1"}
    jung_ids = {"busha1", "bushb1", "bushc1", "grassa1", "grassb1", "rock1", "rock2", "rock3"}
    for r_idx, row_ids in enumerate(flora_rows):
        ry = cy + 20 + r_idx * 144
        for c_idx, fid in enumerate(row_ids):
            fx = 42 + c_idx * 93
            bg_tile = basalt_bg if fid in ash_ids else (jungle_bg if fid in jung_ids else meadow_bg)
            draw.rectangle((fx - 1, ry - 1, fx + 64, ry + 64), outline=CARD_BD, width=1)
            plate.alpha_composite(bg_tile, (fx, ry))
            plate.alpha_composite(scale_nn(bank.atlas(fid), 2), (fx, ry))
            short = fid.replace("lavendergrass_", "lav_").replace("seraka_mushroom", "seraka_m").replace("chilly_pepper", "chilly_p")
            draw.text((fx, ry + 68), short, font=f_tiny, fill=TXT_HI)
            draw.text((fx, ry + 82), "ash_flora" if fid in ash_ids else ("jungleflora" if fid in jung_ids else "ausflora"), font=f_tiny, fill=TXT_LO)

    tx0 = 984
    draw.text((tx0, cy - 2), "Oversized Trees & Boulders (2x, orange box = 32x32 anchor tile):", font=f_lbl, fill=TXT_MD)
    oy_top, oy_bot = cy + 20, cy + 252
    oversized_cards = [
        (tx0, oy_top, 3, 3, "ground", "pine_1", 1, 2, "pine_1 (64x96, -16,-64)", "pinetrees.dmi (flora.dm:451)"),
        (tx0 + 232, oy_top, 3, 3, "tg_dirt", "pine_2", 1, 2, "pine_2 (64x96, -16,-64)", "pinetrees.dmi (flora.dm:460)"),
        (tx0 + 464, oy_top, 3, 3, "tg_greenerdirt", "tree1", 1, 2, "tree1 (96x96, -32,-64)", "jungletreesmall.dmi (flora.dm:418)"),
        (tx0 + 696, oy_top, 3, 3, "tg_greenerdirt", "tree2", 1, 2, "tree2 (96x96, -32,-64)", "jungletreesmall.dmi (flora.dm:427)"),
        (tx0, oy_bot, 3, 2, "tg_dirt", "tree_1", 1, 1, "tree_1 (64x64, -16,-32)", "deadtrees.dmi (flora.dm:360)"),
        (tx0 + 208, oy_bot, 3, 2, "tg_sand", "tree_4", 1, 1, "tree_4 (64x64, -16,-32)", "deadtrees.dmi (flora.dm:374)"),
        (tx0 + 416, oy_bot, 1, 2, "tg_beach_sand", "palm1", 0, 1, "palm1 (32x64)", "flora.dm:537-543"),
        (tx0 + 528, oy_bot, 3, 3, "tg_greenerdirt", "bush1", 1, 1, "bush1 (64x64, -16,-20)", "flora.dm:981-986"),
        (tx0 + 736, oy_bot, 3, 3, "tg_greenerdirt", "rocks1", 1, 1, "rocks1 (64x64, -16,-16)", "flora.dm:1173-1179"),
    ]
    for x, y, gw, gh, base_tid, obj_id, ax, ay, label, cit in oversized_cards:
        ped = Image.new("RGBA", (gw * 32, gh * 32), (0, 0, 0, 255))
        bt = bank.atlas(base_tid).crop((0, 0, 32, 32))
        for py in range(gh):
            for px in range(gw):
                ped.alpha_composite(bt, (px * 32, py * 32))
        rec = bank.meta(obj_id)
        ped.alpha_composite(bank.atlas(obj_id), (ax * 32 + int(rec["offset_x"]), ay * 32 + int(rec["offset_y"])))
        scaled = scale_nn(ped, 2)
        draw.rectangle((x - 1, y - 1, x + scaled.width, y + scaled.height), outline=CARD_BD, width=1)
        plate.alpha_composite(scaled, (x, y))
        draw.rectangle((x + ax * 64, y + ay * 64, x + ax * 64 + 63, y + ay * 64 + 63), outline=(235, 168, 72, 180), width=1)
        draw.text((x, y + scaled.height + 5), label, font=f_tiny, fill=TXT_HI)
        draw.text((x, y + scaled.height + 18), cit, font=f_tiny, fill=TXT_LO)

    # Band 3: Planetary Rock, Martian Siderite / Ironsand, Ice & Cliffs
    y_cur += 556
    cy = draw_band_box(y_cur, 450, "3. PLANETARY ROCK, MARTIAN SIDERITE / IRONSAND, ICE & CLIFFS (2x)", "40x40 & 48x48 cliff ridges • greyscale colorable mountain_wall & moon • siderite/shale • 32x64 vents & spires")
    b3_islands = [
        (_render_smooth_island(bank, "ground", "tg_icerock_cliff", island_3x3), "tg_icerock_cliff (40x40, -4,-4)", "over snow • icerock_cliff.dmi (cliff.dm:123)"),
        (_render_smooth_island(bank, "tg_moon", "tg_mountain_wall", island_3x3, base_tint="#B85C3C", split_smooth_tint_right="#9E482C"), "tg_mountain_wall (Grey vs Mars #9E482C)", "over tinted moon • minerals.dm:669-674 (colorable)"),
        (_render_smooth_island(bank, "tg_ironsand_1", "tg_red_rock_wall", island_3x3), "tg_red_rock_wall (48x48, -8,-8)", "over ironsand1 • red_rock.dmi (minerals.dm:612)"),
        (_render_smooth_island(bank, "tg_basalt", "tg_siderite_smooth", island_3x3), "tg_siderite_smooth (48x48, -8,-8)", "over tg_basalt • siderite.dmi (asteroid.dm:368)"),
    ]
    for i, (im5, lbl, cit) in enumerate(b3_islands):
        cx = 42 + i * 344
        draw.rectangle((cx - 1, cy - 1, cx + 320, cy + 320), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(im5, 2), (cx, cy))
        draw.text((cx, cy + 326), lbl, font=f_lbl, fill=TXT_HI)
        draw.text((cx, cy + 344), cit, font=f_cit, fill=TXT_LO)

    rx0 = 1424
    draw.text((rx0, cy - 2), "32x64 Spires & Vents (terrain.dmi):", font=f_lbl, fill=TXT_MD)
    tall_props = [
        ("siderite_growth1", None, "tg_ironsand_5", "siderite_1", "flora.dm:1110"),
        ("siderite_growth2", None, "tg_ironsand_9", "siderite_2", "flora.dm:1110"),
        ("ore_vent_ice", None, "ground", "ore_vent_ice", "ore_vent.dm:709"),
        ("geyser", None, "tg_basalt", "geyser (grey)", "geyser.dm:7"),
        ("geyser", "#9EA858", "tg_moon", "geyser (NH3)", "tinted #9EA858"),
    ]
    for idx, (pid, ptint, btid, plbl, pcit) in enumerate(tall_props):
        px, py = rx0 + idx * 98, cy + 20
        col_im = Image.new("RGBA", (32, 64), (0, 0, 0, 255))
        bt = tint_srgb_multiply(bank.atlas(btid).crop((0, 0, 32, 32)), "#B85C3C" if btid == "tg_moon" else None)
        col_im.alpha_composite(bt, (0, 0))
        col_im.alpha_composite(bt, (0, 32))
        col_im.alpha_composite(tint_srgb_multiply(bank.atlas(pid), ptint), (0, 0))
        draw.rectangle((px - 1, py - 1, px + 64, py + 128), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(col_im, 2), (px, py))
        draw.text((px, py + 132), plbl, font=f_tiny, fill=TXT_HI)
        draw.text((px, py + 145), pcit, font=f_tiny, fill=TXT_LO)

    draw.text((rx0, cy + 190), "rocks.dmi (flora.dm:1027) & Tintable Turfs:", font=f_lbl, fill=TXT_MD)
    rock_swatches = [
        ("basalt1", None, "tg_basalt", "basalt1"), ("basalt2", "#B85C3C", "tg_ironsand_1", "basalt2 (Mars)"),
        ("lavarocks_siderite1", None, "tg_ironsand_5", "siderite_r1"), ("lavarocks_siderite2", None, "tg_ironsand_9", "siderite_r2"),
        ("lavarocks_shale1", None, "tg_basalt", "shale_r1"),
    ]
    for idx, (rid, rtint, btid, rlbl) in enumerate(rock_swatches):
        px, py = rx0 + idx * 98, cy + 212
        tile = bank.atlas(btid).crop((0, 0, 32, 32)).copy()
        tile.alpha_composite(tint_srgb_multiply(bank.atlas(rid), rtint), (0, 0))
        draw.rectangle((px - 1, py - 1, px + 64, py + 64), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(tile, 2), (px, py))
        draw.text((px, py + 68), rlbl, font=f_tiny, fill=TXT_HI)

    moon_variants = [
        ("tg_moon", "#FFFFFF", "moon (grey)"), ("tg_moon", "#B85C3C", "moon (#B85C3C)"),
        ("tg_moon", "#8798A6", "moon (#8798A6)"), ("tg_ironsand_1", None, "ironsand1"), ("tg_ironsand_9", None, "ironsand9"),
    ]
    for idx, (mid, mtint, mlbl) in enumerate(moon_variants):
        px, py = rx0 + idx * 98, cy + 300
        tile = tint_srgb_multiply(bank.atlas(mid).crop((0, 0, 32, 32)), mtint)
        draw.rectangle((px - 1, py - 1, px + 64, py + 64), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(tile, 2), (px, py))
        draw.text((px, py + 68), mlbl, font=f_tiny, fill=TXT_LO)

    # Band 4: Ocean, Water & Shorelines
    y_cur += 464
    cy = draw_band_box(y_cur, 442, "4. OCEAN, WATER & SHORELINES (2x)", "beach.dmi coast + corner + 4f loop water (sand.dm:50-89, water.dm:106-131) vs water_lavaland.dmi + inverse *_outline.dmi 3x3 pools (water.dm:141-196)")
    b4_pools = [
        (_render_beach_bay(bank), "Coastal Bay & Cape (beach.dmi + sand.dmi)", "coast_s/e/se + beach_corner_s + palm1 (sand.dm:50-89)"),
        (_render_mineral_pool(bank, "tg_siderite_smooth", "tg_siderite_outline", land_is_smooth=True), "Siderite Mineral Pool (3x3 Inverse Mask)", "water_lavaland + siderite_outline (water.dm:193)"),
        (_render_mineral_pool(bank, "tg_moon", "tg_basalt_outline", land_is_smooth=False, land_tint="#5E626E", outline_tint="#8798A6", water_tint="#89D4E8"), "Cryo-Basalt Pool (basalt_outline tinted)", "water_lavaland + basalt_outline.dmi (water.dm:191)"),
    ]
    for i, (im5, lbl, cit) in enumerate(b4_pools):
        cx = 42 + i * 356
        draw.rectangle((cx - 1, cy - 1, cx + 320, cy + 320), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(im5, 2), (cx, cy))
        draw.text((cx, cy + 326), lbl, font=f_lbl, fill=TXT_HI)
        draw.text((cx, cy + 344), cit, font=f_cit, fill=TXT_LO)

    wx0 = 1120
    draw.text((wx0, cy - 2), "Animated Water Loops & Swash Directions (2x):", font=f_lbl, fill=TXT_MD)
    water_strips = [
        (wx0, cy + 20, "tg_beach_water", "tg_beach_water (f0..f3 @ 300ms)", 4),
        (wx0 + 276, cy + 20, "tg_beach_deepwater", "tg_beach_deepwater (f0..f3)", 4),
        (wx0 + 552, cy + 20, "tg_tizira_water", "tg_tizira_water (water.dm:204)", 3),
        (wx0, cy + 114, "tg_beach_coast_s", "tg_beach_coast_s swash (f0..f3 of 8)", 4),
        (wx0 + 276, cy + 114, "tg_riverwater_motion", "tg_riverwater_motion (water.dm:6)", 4),
        (wx0 + 552, cy + 114, "tg_deep_riverwater_motion", "deep_riverwater (water.dm:93)", 3),
    ]
    for x, y, tid, label, n_show in water_strips:
        sc = scale_nn(bank.atlas(tid).crop((0, 0, 32 * n_show, 32)), 2)
        draw.rectangle((x - 1, y - 1, x + sc.width, y + sc.height), outline=CARD_BD, width=1)
        plate.alpha_composite(sc, (x, y))
        draw.text((x, y + 68), label, font=f_tiny, fill=TXT_HI)

    draw.text((wx0, cy + 208), "Directional Coastline Tiles (beach.dmi frame 0, sand.dm:64-89):", font=f_lbl, fill=TXT_MD)
    coast_dirs = [
        ("tg_beach_coast_s", "coast_s (d0)"), ("tg_beach_coast_n", "coast_n (d1)"),
        ("tg_beach_coast_e", "coast_e (d2)"), ("tg_beach_coast_w", "coast_w (d3)"),
        ("tg_beach_coast_se", "coast_se (d4)"), ("tg_beach_corner_s", "corner_s (d0)"),
        ("tg_shale_outline", "shale_out-38"), ("tg_siderite_outline", "siderite_out-38"),
    ]
    for idx, (cid, clbl) in enumerate(coast_dirs):
        px, py = wx0 + idx * 96, cy + 232
        im = bank.atlas(cid)
        if cid.endswith("_outline"):
            cell = Image.new("RGBA", (32, 32), SWATCH_BG)
            cell.alpha_composite(cell_47(im, 38, 0), (0, 0))
        else:
            cell = im.crop((0, 0, 32, 32))
        draw.rectangle((px - 1, py - 1, px + 64, py + 64), outline=CARD_BD, width=1)
        plate.alpha_composite(scale_nn(cell, 2), (px, py))
        draw.text((px, py + 68), clbl, font=f_tiny, fill=TXT_HI)

    out_path = assert_plate_output(out_dir / "plates" / "01_tg_outdoor_gems.png", out_dir)
    plate.save(out_path, format="PNG", optimize=True)
    return out_path


# ---------------------------------------------------------------------------
# Plate 02: Terrestrial Smooth Strips, 12f Shoreline Turnaround & Single Props
# ---------------------------------------------------------------------------
def _render_smooth_patch(
    atlas_47: Image.Image, mask_grid: list[list[int]], tint_hex: str,
    frame_idx: int = 0, bg_tile: Image.Image | None = None,
    flat_bg_rgba: tuple[int, int, int, int] = (28, 31, 42, 255),
) -> Image.Image:
    gh, gw = len(mask_grid), len(mask_grid[0])
    canvas = Image.new("RGBA", (gw * 32, gh * 32), flat_bg_rgba)
    if bg_tile is not None:
        for gy in range(gh):
            for gx in range(gw):
                canvas.alpha_composite(bg_tile, (gx * 32, gy * 32))
    for gy in range(gh):
        for gx in range(gw):
            if mask_grid[gy][gx]:
                jv = compute_junction(lambda nx, ny: bool(mask_grid[ny][nx]), gx, gy, gw, gh)
                canvas.alpha_composite(tint_srgb_multiply(cell_47(atlas_47, jv, frame_idx), tint_hex), (gx * 32, gy * 32))
    return canvas


def render_plate_02(bank: AssetBank, out_dir: Path) -> Path:
    mars, earth = BIOME_TINT_PRESETS["mars_cryo_ammonia"], BIOME_TINT_PRESETS["earth_coastal_meadow"]
    sil_atlas, ice_atlas, cliff_atlas = bank.atlas("terrain_silicate_rough_smooth"), bank.atlas("terrain_ice_sheet_smooth"), bank.atlas("terrain_cliff_stepped_smooth")
    ocean_atlas, backwash_atlas = bank.atlas("ocean_body_smooth"), bank.atlas("ocean_backwash_smooth")
    swash_atlas, lace_atlas, grass_atlas = bank.atlas("ocean_swash_smooth"), bank.atlas("ocean_foam_lace_smooth"), bank.atlas("solid_grass_smooth")

    sil_j255_raw = cell_47(sil_atlas, 255, 0)
    mars_ground_low = tint_srgb_multiply(sil_j255_raw, mars["silicate_low"])
    mars_ground_mid = tint_srgb_multiply(sil_j255_raw, mars["silicate"])
    earth_sand = tint_srgb_multiply(sil_j255_raw, earth["silicate_low"])
    earth_rock = tint_srgb_multiply(sil_j255_raw, earth["silicate"])

    mask_island = [[1, 1, 1], [1, 1, 1], [1, 1, 1]]
    mask_concave_bay = [[1, 0, 1], [1, 1, 1], [1, 1, 0]]
    preset_smooth_cfg = {
        "terrain_silicate_rough_smooth": (mars["silicate"], earth["silicate"], mars_ground_low, earth_sand),
        "terrain_ice_sheet_smooth": (mars["ice"], earth["ice"], mars_ground_low, earth_rock),
        "terrain_cliff_stepped_smooth": (mars["cliff"], earth["cliff"], mars_ground_mid, earth_sand),
        "ocean_body_smooth": (mars["ocean"], earth["ocean"], mars_ground_mid, earth_sand),
        "ocean_backwash_smooth": (mars["backwash"], earth["backwash"], mars_ground_mid, earth_sand),
        "ocean_swash_smooth": (mars["swash"], earth["swash"], mars_ground_mid, earth_sand),
        "ocean_foam_lace_smooth": (mars["swash"], earth["swash"], mars_ground_mid, earth_sand),
        "solid_grass_smooth": (mars["grass"], earth["grass"], mars_ground_mid, earth_rock),
        "solid_moss_smooth": (mars["moss"], earth["moss"], mars_ground_mid, earth_rock),
    }

    smooth_records = [r for r in bank.terrestrial_records if is_smooth_kind(r["kind"])]
    single_records = [r for r in bank.terrestrial_records if not is_smooth_kind(r["kind"])]
    n_ocean_frames = int(bank.meta("ocean_swash_smooth")["frame_count"])
    plate_w, row_h, sec1_y, sec2_h = 1800, 204, 54, 396
    sec2_y = sec1_y + len(smooth_records) * row_h + 16
    sec3_y = sec2_y + sec2_h + 16
    sec3_h = 44 + max(1, math.ceil(len(single_records) / 2)) * 180
    plate = Image.new("RGBA", (plate_w, sec3_y + sec3_h + 20), (14, 17, 24, 255))
    draw = ImageDraw.Draw(plate)
    draw.text((20, 16), f"PLATE 02 — TALES FROM SPACE TERRESTRIAL KIT AUDIT ({len(bank.terrestrial_records)} ASSETS: RAW GREYSCALE STRIPS, BIOME TINTS, 4-LAYER SURF & PROPS)", fill=(242, 236, 218, 255))

    surf_overlay_ids = ("ocean_backwash_smooth", "ocean_swash_smooth", "ocean_foam_lace_smooth")
    for idx, rec in enumerate(smooth_records):
        sid = rec["id"]
        mars_tint, earth_tint, m_bg, e_bg = preset_smooth_cfg.get(sid, (rec.get("default_tint") or mars["silicate"], earth["silicate"], mars_ground_mid, earth_rock))
        atlas_im, strip_im = bank.atlas(sid), bank.strip(sid)
        y0 = sec1_y + idx * row_h
        draw.rectangle([14, y0, plate_w - 14, y0 + row_h - 10], fill=(22, 26, 36, 255), outline=(58, 66, 86, 255))

        tel = rec["telemetry"]
        j0, j255, seams = tel["j0_isolated"], tel["j255_interior"], tel["seams"]
        anim_part = f"  stepMaxMin={tel['anim']['max_min_step_ratio']:.2f}x wrap={tel['anim']['wrap_ratio']:.2f}" if tel.get("anim") else ""
        hdr = (
            f"{sid} [{rec['category']} | {rec['frame_count']}f @ {rec['durations_ms'][0]}ms]  "
            f"swatches={len(tel['used_swatches'])}  j0_luma(T/B)={j0['luma']['top']}/{j0['luma']['bottom']}  "
            f"j255_luma=[{j255['luma']['min']}..{j255['luma']['max']}]  j255_dom={j255['dominant_rgb_share']}  "
            f"alphaMAX={seams['max_alpha_diff']}  seamRatio(q/t)={seams['max_quad_ratio']:.2f}/{seams['max_tile_ratio']:.2f}<=2.75{anim_part}"
        )
        draw.text((24, y0 + 7), hdr, fill=(235, 224, 175, 255))

        f_preview = min(int(rec["frame_count"]) - 1, 4 if sid in surf_overlay_ids else 0)
        if strip_im is not None:
            s_box = Image.new("RGBA", (320, 64), (34, 38, 50, 255))
            s_box.alpha_composite(strip_im.crop((f_preview * 160, 0, (f_preview + 1) * 160, 32)).resize((320, 64), Image.Resampling.NEAREST), (0, 0))
            plate.paste(s_box, (24, y0 + 30))
        for b_i in range(5):
            draw.rectangle([24 + b_i * 64, y0 + 30, 88 + b_i * 64, y0 + 94], outline=(72, 82, 105, 255))
        draw.text((24, y0 + 98), f"Raw Greyscale 2x Strip (f{f_preview+1}) [0:conv | 1:V | 2:H | 3:conc | 4:flat]", fill=(165, 176, 198, 255))

        raw_bay = _render_smooth_patch(atlas_im, mask_concave_bay, "#FFFFFF", frame_idx=f_preview, flat_bg_rgba=(20, 22, 30, 255))
        plate.paste(raw_bay.resize((136, 68), Image.Resampling.NEAREST), (24, y0 + 116))
        draw.rectangle([24, y0 + 116, 160, y0 + 184], outline=(72, 82, 105, 255))
        draw.text((168, y0 + 124), "Raw Grey Bay", fill=(165, 176, 198, 255))
        draw.text((168, y0 + 142), f"chroma={j255['max_chroma']}", fill=(130, 215, 155, 255))

        if sid in surf_overlay_ids:
            mars_isl = _render_smooth_patch(ocean_atlas, mask_island, mars["ocean"], frame_idx=f_preview, bg_tile=m_bg)
            mars_bay = _render_smooth_patch(ocean_atlas, mask_concave_bay, mars["ocean"], frame_idx=f_preview, bg_tile=m_bg)
            mars_isl.alpha_composite(_render_smooth_patch(atlas_im, mask_island, mars_tint, frame_idx=f_preview, flat_bg_rgba=(0, 0, 0, 0)))
            mars_bay.alpha_composite(_render_smooth_patch(atlas_im, mask_concave_bay, mars_tint, frame_idx=f_preview, flat_bg_rgba=(0, 0, 0, 0)))
            earth_isl = _render_smooth_patch(ocean_atlas, mask_island, earth["ocean"], frame_idx=f_preview, bg_tile=e_bg)
            earth_bay = _render_smooth_patch(ocean_atlas, mask_concave_bay, earth["ocean"], frame_idx=f_preview, bg_tile=e_bg)
            earth_isl.alpha_composite(_render_smooth_patch(atlas_im, mask_island, earth_tint, frame_idx=f_preview, flat_bg_rgba=(0, 0, 0, 0)))
            earth_bay.alpha_composite(_render_smooth_patch(atlas_im, mask_concave_bay, earth_tint, frame_idx=f_preview, flat_bg_rgba=(0, 0, 0, 0)))
        else:
            mars_isl = _render_smooth_patch(atlas_im, mask_island, mars_tint, frame_idx=0, bg_tile=m_bg)
            mars_bay = _render_smooth_patch(atlas_im, mask_concave_bay, mars_tint, frame_idx=0, bg_tile=m_bg)
            earth_isl = _render_smooth_patch(atlas_im, mask_island, earth_tint, frame_idx=0, bg_tile=e_bg)
            earth_bay = _render_smooth_patch(atlas_im, mask_concave_bay, earth_tint, frame_idx=0, bg_tile=e_bg)

        for bx, patch, border_col, txt_col, cap in (
            (368, mars_isl, (140, 82, 64, 255), (228, 175, 152, 255), f"Mars {mars_tint} 3x3"),
            (528, mars_bay, (140, 82, 64, 255), (228, 175, 152, 255), "Mars Concave Bay"),
            (702, earth_isl, (76, 128, 92, 255), (172, 224, 182, 255), f"Earth {earth_tint} 3x3"),
            (862, earth_bay, (76, 128, 92, 255), (172, 224, 182, 255), "Earth Concave Bay"),
        ):
            plate.paste(patch.resize((144, 144), Image.Resampling.NEAREST), (bx, y0 + 28))
            draw.rectangle([bx, y0 + 28, bx + 144, y0 + 172], outline=border_col)
            draw.text((bx, y0 + 175), cap, fill=txt_col)

        cx0 = 1036
        j_zoom_val = (
            2 if sid in ("terrain_cliff_stepped_smooth", "terrain_ice_sheet_smooth")
            else 110 if sid in surf_overlay_ids
            else 255 if sid in ("terrain_silicate_rough_smooth", "ocean_body_smooth")
            else 0
        )
        z_bg = (e_bg if sid.startswith("solid_") else m_bg).copy()
        z_bg.alpha_composite(tint_srgb_multiply(cell_47(atlas_im, j_zoom_val, f_preview), earth_tint if sid.startswith("solid_") else mars_tint))
        plate.paste(z_bg.resize((144, 144), Image.Resampling.NEAREST), (cx0, y0 + 28))
        draw.rectangle([cx0, y0 + 28, cx0 + 144, y0 + 172], outline=(110, 120, 148, 255))
        draw.text((cx0, y0 + 175), f"4.5x Detail (j={j_zoom_val})", fill=(185, 196, 218, 255))

        sx_text = cx0 + 162
        ref_tel = j0 if j255["active_px"] == 0 else j255
        draw.text((sx_text, y0 + 32), "Swatches:", fill=(205, 214, 232, 255))
        for s_i, (hx, sh) in enumerate(list(ref_tel["swatch_shares"].items())[:7]):
            sy_t = y0 + 50 + s_i * 16
            draw.rectangle([sx_text, sy_t + 2, sx_text + 10, sy_t + 12], fill=hx, outline=(90, 96, 112, 255))
            draw.text((sx_text + 15, sy_t), f"{hx}: {int(round(sh * 100))}%", fill=(178, 188, 208, 255))

    # Section 2: 4-Layer Shoreline Composite Audit
    swash_anim = bank.meta("ocean_swash_smooth")["telemetry"]["anim"]
    body_anim = bank.meta("ocean_body_smooth")["telemetry"]["anim"]
    draw.rectangle([14, sec2_y, plate_w - 14, sec2_y + sec2_h - 6], fill=(20, 25, 36, 255), outline=(66, 98, 122, 255))
    draw.text(
        (24, sec2_y + 8),
        f"{n_ocean_frames}-FRAME 4-LAYER SHORELINE TURNAROUND AUDIT (body + backwash + swash + foam_lace @ 200ms | "
        f"ocean stepMaxMin={body_anim['max_min_step_ratio']:.2f}x | swash stepMaxMin={swash_anim['max_min_step_ratio']:.2f}x wrap={swash_anim['wrap_ratio']:.2f})",
        fill=(180, 236, 245, 255),
    )
    shore_mask = [[0, 0, 1], [0, 1, 1], [1, 1, 1]]
    cell_px, step_x = 140, 146
    for f in range(n_ocean_frames):
        fx = 24 + f * step_x
        for ry_off, bg_t, oc_t, bw_t, sw_t, bd_col, tx_col, prefix in (
            (34, mars_ground_mid, mars["ocean"], mars["backwash"], mars["swash"], (145, 92, 74, 255), (232, 188, 168, 255), "Mars"),
            (206, earth_sand, earth["ocean"], earth["backwash"], earth["swash"], (78, 134, 168, 255), (176, 222, 245, 255), "Earth"),
        ):
            sh = _render_smooth_patch(ocean_atlas, shore_mask, oc_t, frame_idx=f, bg_tile=bg_t)
            for ov_atlas, ov_tint in ((backwash_atlas, bw_t), (swash_atlas, sw_t), (lace_atlas, sw_t)):
                sh.alpha_composite(_render_smooth_patch(ov_atlas, shore_mask, ov_tint, frame_idx=f, flat_bg_rgba=(0, 0, 0, 0)))
            plate.paste(sh.resize((cell_px, cell_px), Image.Resampling.NEAREST), (fx, sec2_y + ry_off))
            draw.rectangle([fx, sec2_y + ry_off, fx + cell_px, sec2_y + ry_off + cell_px], outline=bd_col)
            draw.text((fx + 4, sec2_y + ry_off + 4 + cell_px), f"{prefix} F{f+1}", fill=tx_col)

    # Section 3: Matte Outcrop / Single Props
    draw.rectangle([14, sec3_y, plate_w - 14, sec3_y + sec3_h - 6], fill=(22, 26, 36, 255), outline=(72, 82, 105, 255))
    draw.text((24, sec3_y + 8), "MATTE FIELDSTONE & BOULDER OUTCROP PROPS (32x32 single, binary alpha 255, modeled on tg rock1..3 & basalt2)", fill=(242, 226, 178, 255))
    mars_ice_bg = tint_srgb_multiply(cell_47(ice_atlas, 255, 0), mars["ice"])
    earth_grass_bg = earth_rock.copy()
    earth_grass_bg.alpha_composite(tint_srgb_multiply(cell_47(grass_atlas, 255, 0), earth["grass"]))
    earth_cliff_bg = tint_srgb_multiply(cell_47(cliff_atlas, 255, 0), earth["cliff"])
    prop_cfg_map = {
        "prop_rough_outcrop_1": (mars["silicate"], earth["cliff"], mars_ground_mid, earth_grass_bg),
        "prop_rough_outcrop_2": (mars["cliff"], "#7D7A74", mars_ground_mid, earth_cliff_bg),
    }
    for p_i, prec in enumerate(single_records):
        pid = prec["id"]
        m_tint, e_tint, p_mbg, p_ebg = prop_cfg_map.get(pid, (prec.get("default_tint") or mars["silicate"], earth["cliff"], mars_ground_mid, earth_grass_bg))
        p_im = bank.atlas(pid).crop((0, 0, 32, 32))
        ptel = prec["telemetry"]["frame1"]
        px0, py0 = 24 + (p_i % 2) * 860, sec3_y + 32 + (p_i // 2) * 180
        draw.text((px0, py0), f"{pid}: px={ptel['active_px']} pieces={prec['telemetry']['lint_f1']['pieces']} luma(T/B)={ptel['luma']['top']}/{ptel['luma']['bottom']} domRGB={ptel['dominant_rgb_share']}", fill=(218, 226, 242, 255))
        boxes = [
            ("4x Dark", Image.new("RGBA", (32, 32), (21, 24, 36, 255)), p_im),
            ("4x Light", Image.new("RGBA", (32, 32), (241, 234, 212, 255)), p_im),
            (f"Mars {m_tint}", p_mbg.copy(), tint_srgb_multiply(p_im, m_tint)),
            (f"Earth {e_tint}", p_ebg.copy(), tint_srgb_multiply(p_im, e_tint)),
            ("Polar Ice #C8E6F2", mars_ice_bg.copy(), tint_srgb_multiply(p_im, "#C8E6F2")),
        ]
        for b_k, (lbl, bg32, fg32) in enumerate(boxes):
            comp = bg32.copy()
            comp.alpha_composite(fg32)
            bx, by = px0 + b_k * 150, py0 + 22
            plate.paste(comp.resize((128, 128), Image.Resampling.NEAREST), (bx, by))
            draw.rectangle([bx, by, bx + 128, by + 128], outline=(84, 94, 118, 255))
            draw.text((bx, by + 132), lbl, fill=(175, 186, 206, 255))

    out_path = assert_plate_output(out_dir / "plates" / "02_terrestrial_strips_audit.png", out_dir)
    plate.save(out_path, format="PNG", optimize=True)
    return out_path


# ---------------------------------------------------------------------------
# Plate 08: Focused 5-Point Feedback Resolution Spotcheck Board
# ---------------------------------------------------------------------------
def _render_bay_3x3(
    sil: Image.Image, low: Image.Image, body: Image.Image,
    backwash: Image.Image, swash: Image.Image, lace: Image.Image,
    f: int, sandy: bool,
) -> Image.Image:
    ocean_mask = [[False, False, True], [False, True, True], [True, True, True]]
    patch = Image.new("RGBA", (96, 96))
    low_255, sil_255 = cell_47(low, 255, 0), cell_47(sil, 255, 0)
    for gy in range(3):
        for gx in range(3):
            patch.paste(low_255 if sandy else sil_255, (gx * 32, gy * 32))
            if ocean_mask[gy][gx]:
                jv = compute_junction(lambda nx, ny: ocean_mask[ny][nx], gx, gy, 3, 3, clamp_border=True)
                patch.alpha_composite(cell_47(body, jv, f), (gx * 32, gy * 32))
            elif not sandy:
                patch.alpha_composite(sil_255, (gx * 32, gy * 32))
            else:
                jv = compute_junction(lambda nx, ny: not ocean_mask[ny][nx], gx, gy, 3, 3, clamp_border=True)
                patch.alpha_composite(cell_47(sil, jv, 0), (gx * 32, gy * 32))
    for gy in range(3):
        for gx in range(3):
            if ocean_mask[gy][gx]:
                jv = compute_junction(lambda nx, ny: ocean_mask[ny][nx], gx, gy, 3, 3, clamp_border=True)
                if jv != 255:
                    for ov in (backwash, swash, lace):
                        patch.alpha_composite(cell_47(ov, jv, f), (gx * 32, gy * 32))
    return patch


def render_plate_08(bank: AssetBank, out_dir: Path) -> Path:
    def load_tinted(asset_id: str, tint: str | None = None) -> Image.Image:
        return tint_srgb_multiply(bank.atlas(asset_id), tint)

    f_title, f_sec, f_lbl = load_font(17, bold=True, mono=True), load_font(13, bold=True, mono=True), load_font(11, mono=True)
    W, H = 1796, 916
    board = Image.new("RGBA", (W, H), (18, 22, 31, 255))
    draw = ImageDraw.Draw(board)
    draw.text((24, 18), "PLATE 08 — 5-POINT VISUAL SPOTCHECK FIXES: 12F 4-LAYER SURF, SILKY OCEAN, FLAT BOTANICAL DECALS, TG ROCKS & BASALT CRACKS", font=f_title, fill=(236, 242, 252, 255))

    y0 = 56
    draw.rounded_rectangle((20, y0, W - 20, y0 + 258), radius=8, fill=(25, 30, 42, 255), outline=(52, 62, 84, 255))
    draw.text((34, y0 + 10), "(1) & (2) 12-FRAME 4-LAYER SURF TURNAROUND (F3 -> F9 @ 2x) & BUBBLE-FREE BRAIDED OCEAN BODY (ocean_body + backwash + swash + foam_lace)", font=f_sec, fill=(132, 210, 246, 255))
    e_sil, e_sand = load_tinted("terrain_silicate_rough_smooth", "#947B62"), load_tinted("terrain_silicate_rough_smooth", "#CBB68C")
    e_body, e_bw = load_tinted("ocean_body_smooth", "#3889C9"), load_tinted("ocean_backwash_smooth", "#594936")
    e_sw, e_lc = load_tinted("ocean_swash_smooth", "#F4FAFF"), load_tinted("ocean_foam_lace_smooth", "#F4FAFF")

    frames_show = [
        (2, "F3: Surge High"), (3, "F4: Crest In"), (4, "F5: Peak Turn!"), (5, "F6: Wet Hover!"),
        (6, "F7: Gentle Ebb"), (7, "F8: Soak Sheet"), (8, "F9: Roller In"),
    ]
    for idx, (fi, caption) in enumerate(frames_show):
        bx, by = 38 + idx * 246, y0 + 36
        bay = _render_bay_3x3(e_sil, e_sand, e_body, e_bw, e_sw, e_lc, fi, sandy=True)
        board.paste(bay.resize((192, 192), Image.Resampling.NEAREST), (bx, by))
        draw.rectangle((bx, by, bx + 192, by + 192), outline=(72, 86, 114, 255))
        draw.text((bx + 4, by + 197), caption, font=f_lbl, fill=(214, 224, 240, 255))

    y1 = y0 + 272
    draw.rounded_rectangle((20, y1, 748, y1 + 258), radius=8, fill=(25, 30, 42, 255), outline=(52, 62, 84, 255))
    draw.text((34, y1 + 10), "(3) FLAT BOTANICAL NATURE DECALS (4-TONE N..L WEAVE, ZERO MELTED-WAX DROP SHADOWS)", font=f_sec, fill=(146, 224, 132, 255))
    grass_e, moss_e = load_tinted("solid_grass_smooth", "#86C44A"), load_tinted("solid_moss_smooth", "#5A9842")
    moss_m, m_sil = load_tinted("solid_moss_smooth", "#96A670"), load_tinted("terrain_silicate_rough_smooth", "#B85C3C")

    decal_mask = [[True, True, False], [True, True, True], [False, True, True]]
    for idx, (lbl, base_at, dec_at) in enumerate([
        ("Earth Meadow Grass (2x 3x3)", e_sil, grass_e),
        ("Earth Creeping Moss (2x 3x3)", e_sil, moss_e),
        ("Martian Lichen Mat (2x 3x3)", m_sil, moss_m),
    ]):
        bx, by = 34 + idx * 234, y1 + 36
        p = Image.new("RGBA", (96, 96))
        b255 = cell_47(base_at, 255, 0)
        for gy in range(3):
            for gx in range(3):
                p.paste(b255, (gx * 32, gy * 32))
                if decal_mask[gy][gx]:
                    jv = compute_junction(lambda nx, ny: decal_mask[ny][nx], gx, gy, 3, 3)
                    p.alpha_composite(cell_47(dec_at, jv, 0), (gx * 32, gy * 32))
        board.paste(p.resize((192, 192), Image.Resampling.NEAREST), (bx, by))
        draw.rectangle((bx, by, bx + 192, by + 192), outline=(72, 86, 114, 255))
        draw.text((bx + 2, by + 197), lbl, font=f_lbl, fill=(214, 224, 240, 255))

    draw.rounded_rectangle((764, y1, W - 20, y1 + 258), radius=8, fill=(25, 30, 42, 255), outline=(52, 62, 84, 255))
    draw.text((778, y1 + 10), "(4) TG ROCK1..3, ROCKS1 & BASALT2 + REDRAWN MATTE OUTCROPS (4x / 2x)", font=f_sec, fill=(242, 198, 122, 255))
    grass_tile, mars_tile = Image.alpha_composite(cell_47(e_sil, 255, 0), cell_47(grass_e, 255, 0)), cell_47(m_sil, 255, 0)

    def card_32_at_4x(sp: Image.Image, bg_t: Image.Image) -> Image.Image:
        c = bg_t.copy()
        c.alpha_composite(sp.crop((0, 0, 32, 32)))
        return scale_nn(c, 4)

    rocks1_ped = Image.new("RGBA", (64, 64))
    for gy in (0, 32):
        for gx in (0, 32):
            rocks1_ped.paste(grass_tile, (gx, gy))
    rocks1_ped.alpha_composite(load_tinted("rocks1").crop((0, 0, 64, 64)))

    rock_cards = [
        ("tg rock1 (4x)", card_32_at_4x(load_tinted("rock1"), grass_tile)),
        ("tg rock2 (4x)", card_32_at_4x(load_tinted("rock2"), grass_tile)),
        ("tg rock3 (4x)", card_32_at_4x(load_tinted("rock3"), grass_tile)),
        ("tg rocks1 (2x)", scale_nn(rocks1_ped, 2)),
        ("tg basalt2 (4x)", card_32_at_4x(load_tinted("basalt2"), grass_tile)),
        ("outcrop_1 (4x)", card_32_at_4x(load_tinted("prop_rough_outcrop_1", "#8E8A84"), grass_tile)),
        ("outcrop_2 (4x)", card_32_at_4x(load_tinted("prop_rough_outcrop_2", "#B85C3C"), mars_tile)),
    ]
    for idx, (lbl, card_im) in enumerate(rock_cards):
        bx, by = 778 + idx * 140, y1 + 48
        board.paste(card_im, (bx, by))
        draw.rectangle((bx, by, bx + 128, by + 128), outline=(72, 86, 114, 255))
        draw.text((bx + 2, by + 134), lbl, font=f_lbl, fill=(214, 224, 240, 255))

    y2 = y1 + 272
    draw.rounded_rectangle((20, y2, W - 20, H - 20), radius=8, fill=(25, 30, 42, 255), outline=(52, 62, 84, 255))
    draw.text((34, y2 + 10), "(5) 4-CONNECTED TG_BASALT STEPPED ROCK SEAMS & PACK JAGGED DEBRIS (6x PIXEL DETAIL, j=255)", font=f_sec, fill=(246, 156, 132, 255))

    def on_dark(sp: Image.Image, hex_bg: tuple[int, int, int]) -> Image.Image:
        c = Image.new("RGBA", (32, 32), (*hex_bg, 255))
        c.alpha_composite(sp)
        return c

    tg_bas = load_tinted("tg_basalt").crop((0, 0, 32, 32))
    cliff_m = cell_47(load_tinted("terrain_cliff_stepped_smooth", "#9E482C"), 255, 0)
    jag_g = cell_47(load_tinted("solid_debris_jagged_smooth", "#8E8A84"), 255, 0)
    jag_m = cell_47(load_tinted("solid_debris_jagged_smooth", "#B85C3C"), 255, 0)

    crack_cards = [
        ("tg_basalt (Ref)", tg_bas, (140, 220, 150, 255)),
        ("cliff_stepped (Mars)", cliff_m, (140, 220, 150, 255)),
        ("jagged_smooth (#8E8A84)", on_dark(jag_g, (42, 40, 38)), (140, 220, 150, 255)),
        ("jagged_smooth (Mars)", on_dark(jag_m, (58, 28, 20)), (140, 220, 150, 255)),
        ("silicate_rough (Mars)", cell_47(m_sil, 255, 0), (140, 220, 150, 255)),
        ("silicate_rough (Earth)", cell_47(e_sil, 255, 0), (140, 220, 150, 255)),
        ("ice_sheet (#D4EFF7)", cell_47(load_tinted("terrain_ice_sheet_smooth", "#D4EFF7"), 255, 0), (140, 220, 150, 255)),
    ]
    for idx, (lbl, tile32, col) in enumerate(crack_cards):
        bx, by = 38 + idx * 246, y2 + 42
        board.paste(tile32.resize((192, 192), Image.Resampling.NEAREST), (bx, by))
        draw.rectangle((bx, by, bx + 192, by + 192), outline=col, width=2)
        draw.text((bx + 2, by + 199), lbl, font=f_lbl, fill=col)

    draw.text((34, y2 + 264), "Seam anatomy: 6-8 multi-scale asymmetric Voronoi slabs + domain warp + open-ended crack tapering + 2x2 diagonal elbow completion (zero missing-pixel stairsteps).", font=f_lbl, fill=(188, 198, 218, 255))
    out_path = assert_plate_output(out_dir / "plates" / "08_feedback_fixes_spotcheck.png", out_dir)
    board.save(out_path, format="PNG", optimize=True)
    return out_path


# ---------------------------------------------------------------------------
# Plate 09: 4x4 Tiling Anti-Repetition & Anti-Goosepimple Spotcheck Board
# ---------------------------------------------------------------------------
def _tile_4x4(cell32: Image.Image, bg32: Image.Image | None = None) -> Image.Image:
    out = Image.new("RGBA", (128, 128), (22, 26, 36, 255))
    for gy in range(4):
        for gx in range(4):
            if bg32 is not None:
                out.paste(bg32, (gx * 32, gy * 32))
            out.alpha_composite(cell32, (gx * 32, gy * 32))
    return out


def _render_partial_4x4(atlas_tinted: Image.Image, bg32: Image.Image) -> Image.Image:
    mask = [[False, True, True, False], [True, True, True, True], [True, True, True, False], [False, True, False, False]]
    out = Image.new("RGBA", (128, 128))
    for gy in range(4):
        for gx in range(4):
            out.paste(bg32, (gx * 32, gy * 32))
            if mask[gy][gx]:
                jv = compute_junction(lambda nx, ny: mask[ny][nx], gx, gy, 4, 4)
                out.alpha_composite(cell_47(atlas_tinted, jv, 0), (gx * 32, gy * 32))
    return out


def render_plate_09(bank: AssetBank, out_dir: Path) -> Path:
    def load_tinted(asset_id: str, tint: str | None = None) -> Image.Image:
        return tint_srgb_multiply(bank.atlas(asset_id), tint)

    def get_ex_32(asset_id: str) -> Image.Image:
        r, im = bank.meta(asset_id), bank.atlas(asset_id)
        cw, ch = int(r["cell_w"]), int(r["cell_h"])
        c = im.crop((46 * cw, 0, 47 * cw, ch)) if is_smooth_kind(r["kind"]) else im.crop((0, 0, cw, ch))
        if cw > 32 or ch > 32:
            ox, oy = -int(r["offset_x"]), -int(r["offset_y"])
            c = c.crop((ox, oy, ox + 32, oy + 32))
        return c

    soil_e = cell_47(load_tinted("terrain_silicate_rough_smooth", "#947B62"), 255, 0)
    soil_m = cell_47(load_tinted("terrain_silicate_rough_smooth", "#B85C3C"), 255, 0)
    oc_earth, oc_mars = load_tinted("ocean_body_smooth", "#3889C9"), load_tinted("ocean_body_smooth", "#5EB5C4")
    gr_earth = load_tinted("solid_grass_smooth", "#86C44A")
    mo_earth, mo_mars = load_tinted("solid_moss_smooth", "#5A9842"), load_tinted("solid_moss_smooth", "#96A670")
    grass_on_soil = Image.alpha_composite(soil_e, cell_47(gr_earth, 255, 0))

    panels = [
        ("REF: tg_riverwater_motion (4x4)", _tile_4x4(get_ex_32("tg_riverwater_motion")), (168, 206, 238, 255)),
        ("REF: tg_beach_water (4x4)", _tile_4x4(get_ex_32("tg_beach_water")), (168, 206, 238, 255)),
        ("NEW: ocean_body Earth #3889C9 (F1)", _tile_4x4(cell_47(oc_earth, 255, 0)), (134, 234, 172, 255)),
        ("NEW: ocean_body Mars #5EB5C4 (F5)", _tile_4x4(cell_47(oc_mars, 255, 4)), (134, 234, 172, 255)),
        ("REF: tg_grass_smooth (4x4)", _tile_4x4(get_ex_32("tg_grass_smooth")), (168, 206, 238, 255)),
        ("NEW: nature_grass #86C44A (4x4)", _tile_4x4(cell_47(gr_earth, 255, 0), soil_e), (134, 234, 172, 255)),
        ("NEW: nature_grass smoothed (4x4)", _render_partial_4x4(gr_earth, soil_e), (134, 234, 172, 255)),
        ("NEW: nature_moss #5A9842 (4x4)", _tile_4x4(cell_47(mo_earth, 255, 0), soil_e), (134, 234, 172, 255)),
        ("NEW: nature_moss Earth edges (4x4)", _render_partial_4x4(mo_earth, soil_e), (134, 234, 172, 255)),
        ("NEW: nature_moss Mars #96A670 (4x4)", _render_partial_4x4(mo_mars, soil_m), (134, 234, 172, 255)),
        ("NEW: moss over grass mix (4x4)", _render_partial_4x4(mo_earth, grass_on_soil), (134, 234, 172, 255)),
        ("REF: tg_grass_damaged (4x4)", _tile_4x4(get_ex_32("tg_grass_damaged_smooth")), (168, 206, 238, 255)),
    ]

    f_title, f_sub = load_font(16, bold=True, mono=True), load_font(12, mono=True)
    f_lbl, f_small = load_font(12, bold=True, mono=True), load_font(11, mono=True)
    W, H = 1664, 1068
    board = Image.new("RGBA", (W, H), (16, 20, 28, 255))
    draw = ImageDraw.Draw(board)
    draw.text((24, 16), "PLATE 09 — 4x4 TILING ANTI-REPETITION & ANTI-GOOSEPIMPLE AUDIT (2x PIXEL + 1x NATIVE GAME SCALE)", font=f_title, fill=(238, 244, 252, 255))
    draw.text((24, 40), "k=1,2 macro-grid suppressed (<0.03) + non-crystalline broadband k=3..8 spectra matching tgstation water, grass & moss", font=f_sub, fill=(166, 182, 208, 255))

    for i, (lbl, p128, col_rgb) in enumerate(panels):
        bx, by = 22 + (i % 4) * 408, 72 + (i // 4) * 326
        draw.rounded_rectangle((bx - 6, by - 6, bx + 400, by + 306), radius=7, fill=(24, 29, 40, 255), outline=(50, 60, 82, 255))
        draw.text((bx + 2, by), lbl, font=f_lbl, fill=col_rgb)
        board.paste(p128.resize((256, 256), Image.Resampling.NEAREST), (bx + 2, by + 24))
        draw.rectangle((bx + 2, by + 24, bx + 258, by + 280), outline=(68, 82, 108, 255))
        draw.text((bx + 4, by + 284), "2x (4x4 = 128x128)", font=f_small, fill=(176, 190, 214, 255))
        board.paste(p128, (bx + 266, by + 24))
        draw.rectangle((bx + 266, by + 24, bx + 394, by + 152), outline=(68, 82, 108, 255))
        draw.text((bx + 268, by + 158), "1x game scale", font=f_small, fill=(176, 190, 214, 255))

    out_path = assert_plate_output(out_dir / "plates" / "09_anti_repetition_spotcheck.png", out_dir)
    board.save(out_path, format="PNG", optimize=True)
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Render Terrestrial Art audit & reference spotcheck plates (01, 02, 08, 09).")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="output root containing manifests/ and receiving plates/")
    args = parser.parse_args()
    out_dir = Path(args.out_dir).resolve()
    bank = AssetBank(out_dir)
    for fn in (render_plate_01, render_plate_02, render_plate_08, render_plate_09):
        print(f"Wrote {fn(bank, out_dir)}")


if __name__ == "__main__":
    main()
