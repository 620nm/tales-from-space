#!/usr/bin/env python3
r"""
Render the 4 Planetary & Terrestrial Biome Spotcheck Plates & Animated GIFs into `<out-dir>/plates/`:
  - `03_mars_ammonia_spotcheck.png`
  - `04_earth_nature_spotcheck.png`
  - `05_mars_shoreline_anim.gif`
  - `06_earth_shoreline_anim.gif`
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from PIL import Image, ImageDraw

PLATES_PKG_DIR = Path(__file__).resolve().parent
TERR_ROOT_DIR = PLATES_PKG_DIR.parent
for _p in (str(PLATES_PKG_DIR), str(TERR_ROOT_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from scene_compositor import (  # noqa: E402
    AssetBank,
    DioramaScene,
    assert_plate_output,
    build_earth_main_scene,
    build_earth_vignette_2b,
    build_earth_vignette_2c,
    build_earth_vignette_2d,
    build_mars_main_scene,
    build_mars_vignette_1b,
    build_mars_vignette_1c,
    build_mars_vignette_1d,
    load_font,
    render_diorama_frame,
    scale_nn,
)
from schema_contract import BIOME_TINT_PRESETS, DEFAULT_OUT_DIR  # noqa: E402


def render_spotcheck_board(
    out_path: Path,
    out_dir: Path,
    *,
    plate_title: str,
    plate_subtitle: str,
    main_title: str,
    main_caption: str,
    main_im_1x: Image.Image,
    legend_swatches: list[tuple[str, str, str]],
    layer_notes: list[str],
    vignettes: list[tuple[str, str, Image.Image, list[tuple[str, str]], list[str]]],
) -> Path:
    W, H = 1920, 1560
    BG = (20, 23, 34, 255)
    CARD_BG = (27, 32, 46, 255)
    INSET_BG = (15, 18, 27, 255)
    CARD_BD = (52, 62, 88, 255)
    ACCENT = (114, 202, 238, 255)
    TXT_HI = (238, 242, 252, 255)
    TXT_MD = (182, 194, 218, 255)
    TXT_LO = (132, 146, 178, 255)

    f_h1 = load_font(22, bold=True)
    f_sub = load_font(13)
    f_sec = load_font(16, bold=True)
    f_lbl = load_font(13, bold=True)
    f_mono = load_font(11, mono=True)
    f_tiny = load_font(10, mono=True)

    board = Image.new("RGBA", (W, H), BG)
    draw = ImageDraw.Draw(board)

    draw.text((28, 18), plate_title, font=f_h1, fill=TXT_HI)
    draw.text((28, 48), plate_subtitle, font=f_sub, fill=TXT_MD)

    my0, mh = 78, 956
    draw.rounded_rectangle((24, my0, W - 24, my0 + mh), radius=8, fill=CARD_BG, outline=CARD_BD, width=1)
    draw.text((42, my0 + 12), main_title, font=f_sec, fill=ACCENT)
    draw.text((42, my0 + 34), main_caption, font=f_mono, fill=TXT_LO)
    draw.line((42, my0 + 54, W - 42, my0 + 54), fill=CARD_BD, width=1)

    dx0, dy0 = 42, my0 + 68
    main_3x = scale_nn(main_im_1x, 3)
    draw.rectangle((dx0 - 2, dy0 - 2, dx0 + main_3x.width + 1, dy0 + main_3x.height + 1), outline=(88, 104, 142, 255), width=2)
    board.alpha_composite(main_3x, (dx0, dy0))
    draw.text(
        (dx0, dy0 + main_3x.height + 6),
        "3x Nearest-Neighbor View (1344x864 px • 14x9 tiles @ 32px • Frame 5/12 Smooth Turnaround Surf, Foam Lace & Wet Backwash)",
        font=f_tiny,
        fill=TXT_LO,
    )

    for tx in range(14):
        draw.text((dx0 + tx * 96 + 42, dy0 - 13), str(tx), font=f_tiny, fill=(104, 118, 148, 255))
    for ty in range(9):
        draw.text((dx0 - 15, dy0 + ty * 96 + 42), str(ty), font=f_tiny, fill=(104, 118, 148, 255))

    sx0, sy0 = 1408, dy0
    draw.text((sx0, sy0 - 2), "1x True-Scale Game Zoom Inset (448x288 px):", font=f_lbl, fill=TXT_HI)
    ibox_y = sy0 + 18
    draw.rounded_rectangle((sx0, ibox_y, sx0 + 468, ibox_y + 308), radius=6, fill=INSET_BG, outline=CARD_BD, width=1)
    ix = sx0 + (468 - main_im_1x.width) // 2
    iy = ibox_y + (308 - main_im_1x.height) // 2
    draw.rectangle((ix - 1, iy - 1, ix + main_im_1x.width, iy + main_im_1x.height), outline=(74, 86, 116, 255), width=1)
    board.alpha_composite(main_im_1x, (ix, iy))

    ly = ibox_y + 322
    draw.text((sx0, ly), "sRGB Multiply Tints ((px * tint + 127) // 255):", font=f_lbl, fill=ACCENT)
    ly += 22
    for sw_hex, sw_role, sw_detail in legend_swatches:
        draw.rectangle((sx0, ly + 2, sx0 + 16, ly + 16), fill=sw_hex, outline=(210, 220, 240, 180), width=1)
        draw.text((sx0 + 24, ly + 1), f"{sw_hex}  {sw_role}", font=f_mono, fill=TXT_HI)
        draw.text((sx0 + 216, ly + 2), sw_detail, font=f_tiny, fill=TXT_LO)
        ly += 20

    ly += 10
    draw.line((sx0, ly, sx0 + 468, ly), fill=CARD_BD, width=1)
    ly += 10
    draw.text((sx0, ly), "Layer Order & Source Citations:", font=f_lbl, fill=ACCENT)
    ly += 20
    for note_line in layer_notes:
        draw.text((sx0, ly), note_line, font=f_tiny, fill=TXT_MD)
        ly += 16

    vy0, vh, card_w, gap = 1050, 486, 604, 18
    for idx, (v_title, v_sub, v_im_1x, v_swatches, v_bullets) in enumerate(vignettes):
        vx0 = 24 + idx * (card_w + gap)
        draw.rounded_rectangle((vx0, vy0, vx0 + card_w, vy0 + vh), radius=8, fill=CARD_BG, outline=CARD_BD, width=1)
        draw.text((vx0 + 16, vy0 + 12), v_title, font=f_lbl, fill=ACCENT)
        draw.text((vx0 + 16, vy0 + 31), v_sub, font=f_tiny, fill=TXT_LO)
        draw.line((vx0 + 16, vy0 + 48, vx0 + card_w - 16, vy0 + 48), fill=CARD_BD, width=1)

        v2x = scale_nn(v_im_1x, 2)
        v_img_x, v_img_y = vx0 + 16, vy0 + 60
        draw.rectangle((v_img_x - 1, v_img_y - 1, v_img_x + 384, v_img_y + 384), outline=(80, 94, 128, 255), width=1)
        board.alpha_composite(v2x, (v_img_x, v_img_y))
        draw.text((v_img_x, v_img_y + 390), "6x6 tiles @ 2x (384x384 px)", font=f_tiny, fill=TXT_LO)

        tx, ty = v_img_x + 398, v_img_y
        draw.text((tx, ty), "Palette / Tints:", font=f_mono, fill=TXT_HI)
        ty += 18
        for shx, slbl in v_swatches:
            draw.rectangle((tx, ty + 2, tx + 12, ty + 14), fill=shx, outline=(195, 205, 225, 160), width=1)
            draw.text((tx + 17, ty + 1), f"{shx} {slbl}", font=f_tiny, fill=TXT_MD)
            ty += 17
        ty += 10
        draw.line((tx, ty, vx0 + card_w - 14, ty), fill=CARD_BD, width=1)
        ty += 8
        draw.text((tx, ty), "Spotcheck Notes:", font=f_mono, fill=TXT_HI)
        ty += 18
        for bul in v_bullets:
            draw.text((tx, ty), bul, font=f_tiny, fill=TXT_LO)
            ty += 15

    safe_out = assert_plate_output(out_path, out_dir)
    board.save(safe_out, format="PNG", optimize=True)
    return safe_out


def save_seamless_shoreline_gif(
    bank: AssetBank,
    scene: DioramaScene,
    out_path: Path,
    out_dir: Path,
    scale_factor: int = 3,
) -> tuple[Path, int, int, int, int]:
    """Render shoreline loop at `scale_factor`x with one shared 256-color palette (zero dither crawl)."""
    swash_rec = bank.meta("ocean_swash_smooth")
    n_frames = int(swash_rec["frame_count"])
    frame_ms = int(swash_rec["durations_ms"][0]) if swash_rec.get("durations_ms") else 200

    rgb_frames = [
        scale_nn(render_diorama_frame(bank, scene, frame_idx=f), scale_factor).convert("RGB")
        for f in range(n_frames)
    ]
    fw, fh = rgb_frames[0].size
    strip = Image.new("RGB", (fw, fh * n_frames))
    for i, fr in enumerate(rgb_frames):
        strip.paste(fr, (0, i * fh))
    master_pal = strip.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    quantized = [fr.quantize(palette=master_pal, dither=Image.Dither.NONE) for fr in rgb_frames]

    safe_out = assert_plate_output(out_path, out_dir)
    quantized[0].save(
        safe_out,
        format="GIF",
        save_all=True,
        append_images=quantized[1:],
        duration=frame_ms,
        loop=0,
        optimize=False,
    )
    return safe_out, fw, fh, n_frames, frame_ms


def main() -> None:
    parser = argparse.ArgumentParser(description="Render Mars & Earth planetary biome spotcheck plates and animated GIFs.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="output root containing manifests/ and receiving plates/")
    args = parser.parse_args()

    out_dir = Path(args.out_dir).resolve()
    plates_dir = out_dir / "plates"
    bank = AssetBank(out_dir)

    # Plate 03: Mars Ammonia Spotcheck
    mars_cryo = BIOME_TINT_PRESETS["mars_cryo_ammonia"]
    mars_pack = BIOME_TINT_PRESETS["mars_pack_ammonia"]
    mars_polar = BIOME_TINT_PRESETS["mars_polar_ice"]
    mars_main = build_mars_main_scene()
    mars_1b = build_mars_vignette_1b()
    mars_1c = build_mars_vignette_1c()
    mars_1d = build_mars_vignette_1d()

    mars_main_im = render_diorama_frame(bank, mars_main, frame_idx=4)
    mars_1b_im = render_diorama_frame(bank, mars_1b, frame_idx=4)
    mars_1c_im = render_diorama_frame(bank, mars_1c, frame_idx=4)
    mars_1d_im = render_diorama_frame(bank, mars_1d, frame_idx=4)

    p03 = render_spotcheck_board(
        plates_dir / "03_mars_ammonia_spotcheck.png",
        out_dir,
        plate_title="PLATE 03 — MARS PLANETARY DIORAMA: RUST-SILICATE CLIFFS, CALVING ICE, LIQUID AMMONIA SEA & PIER",
        plate_subtitle="Neutral-greyscale 47-junction terrestrial kit + inherited TfS elemental matter/station turfs + curated tgstation planetary spires & vents",
        main_title="1A. MARS CRYO-AMMONIA COAST, STEPPED MESA, CALVING POLAR ICE & RESEARCH PIER (14x9)",
        main_caption=(
            f"Silicate {mars_cryo['silicate']}/{mars_cryo['silicate_low']} • Mesa {mars_cryo['cliff']} • "
            f"Ice {mars_cryo['ice']} • NH3 Sea {mars_cryo['ocean']} + 4-Layer Surf "
            f"{mars_cryo['swash']}/{mars_cryo['backwash']} (F5/12) • Mist {mars_cryo['haze']} @ 0.45a"
        ),
        main_im_1x=mars_main_im,
        legend_swatches=[
            (mars_cryo["silicate"], "Silicate Shelf", "terrain_silicate_rough_smooth"),
            (mars_cryo["backwash"], "Wet Backwash", "ocean_backwash_smooth (12f)"),
            (mars_cryo["cliff"], "Stepped Cliff", "terrain_cliff_stepped_smooth"),
            (mars_cryo["ice"], "Calving Ice", "terrain_ice_sheet_smooth + shards"),
            (mars_cryo["ocean"], "NH3 Ocean", "ocean_body_smooth (bubble-free)"),
            (mars_cryo["swash"], "NH3 Surf+Lace", "ocean_swash + foam_lace (F5/12)"),
            (mars_cryo["haze"], "NH3 Mist", "gas_mist_smooth_gentle (0.45a)"),
            (mars_cryo["moss"], "Martian Lichen", "solid_moss_smooth"),
            ("#9EA858", "NH3 Fumarole", "tg geyser (geyser.dm:7)"),
        ],
        layer_notes=[
            "• 4-Layer 12f Surf: ocean_body + ocean_backwash",
            f"  ({mars_cryo['backwash']} soak) + ocean_swash + ocean_foam_lace.",
            "• Basalt-Style Cracks: 4-connected open-ended",
            "  stepped stone seams (ref: floors.dmi:basalt).",
            "• Calving Seafront: ocean_body extends beneath",
            "  coastal ice rim so @160 skirt refracts over NH3.",
            "• Catwalk Pier (x=5..7,y=6): draws OVER surf so",
            "  ammonia swash surges visibly under steel grating.",
            "• TfS Matter: solid_debris_jagged_smooth, frost",
            "  drift, shimmering NH3 puddle, ice shards.",
            "• TG Geology: basalt1/2, siderite_growth1/2,",
            "  lavarocks, ore_vent_ice & matte outcrops.",
        ],
        vignettes=[
            (
                f"1B. PACK-LITERAL AMMONIA ({mars_pack['ocean']})",
                "ammonia.luau:66 + iron_oxide.luau:30 + water.luau:65",
                mars_1b_im,
                [
                    (mars_pack["ocean"], "NH3 color"),
                    (mars_pack["haze"], "NH3 visible"),
                    (mars_pack["silicate"], "iron_oxide"),
                    (mars_pack["ice"], "water ice"),
                ],
                [
                    "Honest audit of exact",
                    "current substance hexes:",
                    f"• {mars_pack['ocean']} reads as dark",
                    "  reagent olive sludge.",
                    f"• {mars_pack['silicate']} hematite &",
                    f"  {mars_pack['haze']} mist hold up,",
                    "  motivating a dedicated",
                    "  cryo-liquid tint field",
                    "  like water's #5F9BD5.",
                ],
            ),
            (
                "1C. GLACIAL AMMONIA-WATER BRINE",
                f"Shared geometry w/ Earth 2C ({mars_1c.tints['ocean']} + {mars_1c.tints['silicate']})",
                mars_1c_im,
                [
                    (mars_1c.tints["ocean"], "Brine sea"),
                    (mars_1c.tints["swash"], "Brine foam"),
                    (mars_1c.tints["silicate"], "Ironsand"),
                    (mars_1c.tints["cliff"], "Mesa crag"),
                    (mars_1c.tints["ice"], "Glacier"),
                ],
                [
                    "Bright cryo-brine coast",
                    "sharing the EXACT 6x6",
                    "cliff, bay & outcrop",
                    "mask as Plate 04 (2C):",
                    "• NW stepped cliff",
                    "• NE ice headland",
                    "• Siderite spire +",
                    "  polyhedral outcrops.",
                ],
            ),
            (
                "1D. POLAR BASALT & POLYNYA",
                f"Basalt {mars_polar['silicate']} + Ice {mars_polar['ice']} + glass_floor window",
                mars_1d_im,
                [
                    (mars_polar["silicate"], "Basalt"),
                    (mars_polar["silicate_low"], "Low basalt"),
                    (mars_polar["ice"], "Polar ice"),
                    (mars_polar["ocean"], "Polynya"),
                ],
                [
                    "High-latitude volcanic",
                    "basalt & sea-ice lead:",
                    "• 2x2 TfS glass_floor",
                    "  outpost deck (x=1..2,",
                    "  y=3..4) overhangs the",
                    "  calving polynya edge,",
                    "  revealing dark NH3",
                    "  sea through the glass!",
                ],
            ),
        ],
    )
    print(f"Wrote {p03} ({mars_main_im.size} 1x)")

    # Plate 04: Earth Nature Spotcheck
    earth_meadow = BIOME_TINT_PRESETS["earth_coastal_meadow"]
    earth_jungle = BIOME_TINT_PRESETS["earth_lush_jungle"]
    earth_main = build_earth_main_scene()
    earth_2b = build_earth_vignette_2b()
    earth_2c = build_earth_vignette_2c()
    earth_2d = build_earth_vignette_2d()

    earth_main_im = render_diorama_frame(bank, earth_main, frame_idx=4)
    earth_2b_im = render_diorama_frame(bank, earth_2b, frame_idx=4)
    earth_2c_im = render_diorama_frame(bank, earth_2c, frame_idx=4)
    earth_2d_im = render_diorama_frame(bank, earth_2d, frame_idx=1)

    p04 = render_spotcheck_board(
        plates_dir / "04_earth_nature_spotcheck.png",
        out_dir,
        plate_title="PLATE 04 — TERRESTRIAL EARTH DIORAMA: SAME SMOOTH KIT + NATURE DECALS, TG FLORA & BOTANY OUTPOST",
        plate_subtitle="Zero new terrain geometry: identical smooth cliff/silicate/ocean/swash terrestrial strips re-tinted + smooth grass/moss decals + tgstation flora",
        main_title="2A. COASTAL MEADOW, GRANITE CRAGS, LEAFY CANOPY, SANDY SURF & OVERGROWN BOTANY OUTPOST (14x9)",
        main_caption=(
            f"Soil {earth_meadow['silicate']} over Sand {earth_meadow['silicate_low']} • "
            f"Wet Sand {earth_meadow['backwash']} • Sea {earth_meadow['ocean']} + 4-Layer Surf "
            f"{earth_meadow['swash']} (F5/12) • Grass {earth_meadow['grass']} • Moss {earth_meadow['moss']}"
        ),
        main_im_1x=earth_main_im,
        legend_swatches=[
            (earth_meadow["silicate"], "Warm Soil", "terrain_silicate_rough_smooth"),
            (earth_meadow["silicate_low"], "Coastal Sand", "substrate + beach foreshore"),
            (earth_meadow["backwash"], "Wet Sand Glaze", "ocean_backwash_smooth (12f)"),
            (earth_meadow["cliff"], "Granite Crag", "terrain_cliff_stepped_smooth"),
            (earth_meadow["ocean"], "Coastal Sea", "ocean_body_smooth (bubble-free)"),
            (earth_meadow["swash"], "Surf + Lace", "ocean_swash + foam_lace (F5/12)"),
            (earth_meadow["grass"], "Meadow Grass", "solid_grass_smooth"),
            (earth_meadow["moss"], "Creeping Moss", "solid_moss_smooth"),
            ("#6B4C35", "Tilled Plot", "solid_soil_tilled_smooth"),
        ],
        layer_notes=[
            "• Same 32x32 Smooth Kit: granite crag, soil, sea &",
            "  4-layer surf use the EXACT same strips as Mars!",
            "• Low-Contrast Nature Decals: flat 4-tone botanical",
            "  blade/moss weave (zero melted-wax drop shadows).",
            "• TG Rocks & Flora: rock1..3, rocks1 (64x64),",
            "  tree1/2 (96x96), bush1, palm1, tg_hedge & reeds.",
            "• Botany Outpost: reinforced_wall, airlock_closed,",
            "  crate_hydro, canister_blue & 2x2 tilled garden.",
        ],
        vignettes=[
            (
                "2B. LUSH JUNGLE BASIN & CAMPFIRE",
                "jungletreesmall.dmi + largejungleflora.dmi + campfire",
                earth_2b_im,
                [
                    (earth_jungle["grass"], "Jungle turf"),
                    (earth_jungle["moss"], "Canopy moss"),
                    (earth_jungle["ocean"], "Lagoon"),
                    (earth_jungle["haze"], "Morning mist"),
                ],
                [
                    "Deep rainforest mood:",
                    "• tree1 (96x96, -32,-64)",
                    "  anchored at (1,2) w/",
                    "  zero edge clipping.",
                    "• rocks1 & bush1 (64x64)",
                    "• TfS fire_campfire_steady",
                    "  over solid_pile_small +",
                    "  gentle lagoon mist.",
                ],
            ),
            (
                "2C. SAME-GEOMETRY MORPH PROOF",
                "Identical 6x6 cliff/bay/outcrop mask as Mars 1C!",
                earth_2c_im,
                [
                    (earth_meadow["cliff"], "Granite"),
                    (earth_meadow["silicate"], "Loam soil"),
                    (earth_meadow["silicate_low"], "Beach sand"),
                    (earth_meadow["grass"], "Grass decal"),
                    (earth_meadow["ocean"], "Ocean"),
                ],
                [
                    "1:1 proof of planetary",
                    "reuse vs Plate 03 (1C):",
                    "• Identical NW cliff,",
                    "  SE bay & outcrop",
                    "  coordinates.",
                    "• Swapping multiply hex",
                    "  + grass/moss decals",
                    "  yields Earth coast!",
                ],
            ),
            (
                "2D. UPSTREAM TG NATIVE REFERENCE",
                "tg_grass_smooth (50x50) + beach.dmi + palm1",
                earth_2d_im,
                [
                    ("#FFFFFF", "Baked RGB"),
                    ("#E8D29C", "tg_beach_sand"),
                    ("#4F9E46", "tg_grass 50px"),
                    ("#3985C6", "tg_beach_water"),
                ],
                [
                    "Read-only tgstation",
                    "comparison baseline:",
                    "• 50x50 (-9,-9) grass",
                    "  bleeds 9px over sand",
                    "  (baked green RGB).",
                    "• beach.dmi uses fixed",
                    "  cardinal states vs",
                    "  47-junction smooth!",
                ],
            ),
        ],
    )
    print(f"Wrote {p04} ({earth_main_im.size} 1x)")

    # Plates 05 & 06: 12-Frame 3x Seamless Shoreline Animated GIFs
    p05, mw, mh, mf, mms = save_seamless_shoreline_gif(bank, mars_main, plates_dir / "05_mars_shoreline_anim.gif", out_dir, scale_factor=3)
    print(f"Wrote {p05} ({mw}x{mh}, {mf} frames @ {mms}ms)")

    p06, ew, eh, ef, ems = save_seamless_shoreline_gif(bank, earth_main, plates_dir / "06_earth_shoreline_anim.gif", out_dir, scale_factor=3)
    print(f"Wrote {p06} ({ew}x{eh}, {ef} frames @ {ems}ms)")


if __name__ == "__main__":
    main()
