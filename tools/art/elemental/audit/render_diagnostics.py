#!/usr/bin/env python3
"""
Render pixel-exact 3x/4x diagnostic composite plates from exported .aseprite frames
to visually verify true multi-density blending, vertical gas strip seams, and f8->f1 loop wrap snap.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from elemental_kit import (  # noqa: E402
    DEFAULT_OUT_DIR,
    compute_junction,
    slice_junction_tile as slice_junction,
    tint_multiply,
)


def tint_rgb(img: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    return tint_multiply(img, "#%02X%02X%02X" % rgb)


def make_plating_tile() -> Image.Image:
    t = Image.new("RGBA", (32, 32), (52, 55, 64, 255))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 31, 31], outline=(38, 40, 48, 255))
    d.line([(16, 1), (16, 30)], fill=(45, 48, 56, 255))
    d.line([(1, 16), (30, 16)], fill=(45, 48, 56, 255))
    return t


def make_floor_tile() -> Image.Image:
    t = Image.new("RGBA", (32, 32), (112, 115, 122, 255))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 31, 31], outline=(86, 89, 96, 255))
    d.line([(16, 1), (16, 30)], fill=(98, 101, 108, 255))
    d.line([(1, 16), (30, 16)], fill=(98, 101, 108, 255))
    return t


def main():
    parser = argparse.ArgumentParser(description="Render diagnostic plates from the audit's exports")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR))
    args = parser.parse_args()
    AUDIT_DIR = Path(args.out_dir).resolve() / "audit"
    EXP_DIR = AUDIT_DIR / "ase_exports"
    # 1. True 3-Tier Nested Gas Gradient (Mist -> Smoke -> Cloud) + Vertical Corridor Seam Test
    gw, gh = 11, 7
    canvas_gas = Image.new("RGBA", (gw * 32, gh * 32), (0, 0, 0, 255))
    bg_p = make_plating_tile()
    for y in range(gh):
        for x in range(gw):
            canvas_gas.paste(bg_p, (x * 32, y * 32))

    # Left side (x=0..7): Nested circular/organic mist -> smoke -> cloud shells
    # Right side (x=9, y=1..5): 1-tile-wide vertical corridor of gas_cloud_smooth_gentle (exposes Block 1 -> Block 1 VJoin!)
    moles = [[0.0 for _ in range(gw)] for _ in range(gh)]
    cx, cy = 3.5, 3.0
    for y in range(gh):
        for x in range(8):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist <= 1.45:
                moles[y][x] = 20.0  # cloud + smoke + mist
            elif dist <= 2.45:
                moles[y][x] = 6.0   # smoke + mist
            elif dist <= 3.35:
                moles[y][x] = 1.2   # mist

    for y in range(1, 6):
        moles[y][9] = 20.0  # 1-wide vertical column -> j=1 (top), j=3 (mid x3, Block 1 -> Block 1!), j=2 (bot)

    mist_s = tint_rgb(Image.open(EXP_DIR / "gas_mist_smooth_gentle_f1.png").convert("RGBA"), (220, 238, 255))
    smoke_s = tint_rgb(Image.open(EXP_DIR / "gas_smoke_smooth_gentle_f1.png").convert("RGBA"), (220, 238, 255))
    cloud_s = tint_rgb(Image.open(EXP_DIR / "gas_cloud_smooth_gentle_f8.png").convert("RGBA"), (220, 238, 255))

    for y in range(gh):
        for x in range(gw):
            m = moles[y][x]
            if m >= 0.35:
                jm = compute_junction(lambda nx, ny: moles[ny][nx] >= 0.35, x, y, gw, gh)
                canvas_gas.alpha_composite(slice_junction(mist_s, jm), (x * 32, y * 32))
            if m >= 3.5:
                js = compute_junction(lambda nx, ny: moles[ny][nx] >= 3.5, x, y, gw, gh)
                canvas_gas.alpha_composite(slice_junction(smoke_s, js), (x * 32, y * 32))
            if m >= 12.0:
                jc = compute_junction(lambda nx, ny: moles[ny][nx] >= 12.0, x, y, gw, gh)
                canvas_gas.alpha_composite(slice_junction(cloud_s, jc), (x * 32, y * 32))

    canvas_gas.resize((gw * 96, gh * 96), Image.NEAREST).save(AUDIT_DIR / "diag_true_gas_gradient_and_vseam.png")

    # 2. True 3-Tier Nested Liquid Gradient (Splatter -> Splash -> Spill_1/2 -> Puddle -> Pool)
    lw, lh = 10, 7
    canvas_liq = Image.new("RGBA", (lw * 32, lh * 32), (0, 0, 0, 255))
    bg_f = make_floor_tile()
    for y in range(lh):
        for x in range(lw):
            canvas_liq.paste(bg_f, (x * 32, y * 32))

    vol = [[0 for _ in range(lw)] for _ in range(lh)]
    lcx, lcy = 4.5, 3.0
    for y in range(lh):
        for x in range(lw):
            dist = ((x - lcx) ** 2 + (y - lcy) ** 2) ** 0.5
            if dist <= 1.65:
                vol[y][x] = 3500  # pool + puddle
            elif dist <= 2.75:
                vol[y][x] = 900   # puddle
            elif dist <= 3.45:
                vol[y][x] = 190   # spill_1 / spill_2
            elif dist <= 4.15:
                vol[y][x] = 95    # splash_1 / splash_2
            elif dist <= 4.65:
                vol[y][x] = 35    # splatter_1 / splatter_2

    water_rgb = (75, 163, 227)
    puddle_s = tint_rgb(Image.open(EXP_DIR / "liquid_puddle_smooth_shimmer_f1.png").convert("RGBA"), water_rgb)
    pool_s = tint_rgb(Image.open(EXP_DIR / "liquid_pool_smooth_ripple_f1.png").convert("RGBA"), water_rgb)
    spill_1 = tint_rgb(Image.open(EXP_DIR / "liquid_spill_1_f1.png").convert("RGBA"), water_rgb)
    spill_2 = tint_rgb(Image.open(EXP_DIR / "liquid_spill_2_f1.png").convert("RGBA"), water_rgb)
    splash_1 = tint_rgb(Image.open(EXP_DIR / "liquid_splash_1_f1.png").convert("RGBA"), water_rgb)
    splash_2 = tint_rgb(Image.open(EXP_DIR / "liquid_splash_2_f1.png").convert("RGBA"), water_rgb)
    splat_1 = tint_rgb(Image.open(EXP_DIR / "liquid_splatter_1_f1.png").convert("RGBA"), water_rgb)
    splat_2 = tint_rgb(Image.open(EXP_DIR / "liquid_splatter_2_f1.png").convert("RGBA"), water_rgb)

    for y in range(lh):
        for x in range(lw):
            v = vol[y][x]
            odd = (x * 3 + y * 5) & 1
            if v >= 260:
                jp = compute_junction(lambda nx, ny: vol[ny][nx] >= 260, x, y, lw, lh)
                canvas_liq.alpha_composite(slice_junction(puddle_s, jp), (x * 32, y * 32))
                if v >= 2600:
                    jpool = compute_junction(lambda nx, ny: vol[ny][nx] >= 2600, x, y, lw, lh)
                    canvas_liq.alpha_composite(slice_junction(pool_s, jpool), (x * 32, y * 32))
            elif v >= 140:
                canvas_liq.alpha_composite(spill_2 if odd else spill_1, (x * 32, y * 32))
            elif v >= 65:
                canvas_liq.alpha_composite(splash_2 if odd else splash_1, (x * 32, y * 32))
            elif v >= 10:
                canvas_liq.alpha_composite(splat_2 if odd else splat_1, (x * 32, y * 32))

    canvas_liq.resize((lw * 96, lh * 96), Image.NEAREST).save(AUDIT_DIR / "diag_true_liquid_gradient_pool_puddle_spill.png")

    # 3. Animation Loop Wrap Strip (f1..f8 -> f1) for liquid_pool_smooth_ripple (j=255) & liquid_puddle_smooth_shimmer (j=255)
    strip_out = Image.new("RGBA", (9 * 36 + 8, 2 * 44 + 12), (22, 24, 34, 255))
    for row_idx, sp_name in enumerate(["liquid_pool_smooth_ripple", "liquid_puddle_smooth_shimmer"]):
        seq = [1, 2, 3, 4, 5, 6, 7, 8, 1]
        for col_idx, f_num in enumerate(seq):
            s_img = tint_rgb(Image.open(EXP_DIR / f"{sp_name}_f{f_num}.png").convert("RGBA"), water_rgb)
            t255 = slice_junction(s_img, 255)
            cell = make_floor_tile()
            cell.alpha_composite(t255, (0, 0))
            ox = 8 + col_idx * 36
            oy = 8 + row_idx * 44
            strip_out.paste(cell, (ox, oy))
            if col_idx == 7:
                # Highlight the f8 -> f1 wrap boundary
                d = ImageDraw.Draw(strip_out)
                d.line([(ox + 33, oy), (ox + 33, oy + 31)], fill=(255, 80, 80, 255))

    strip_out.resize((strip_out.width * 3, strip_out.height * 3), Image.NEAREST).save(
        AUDIT_DIR / "diag_liquid_loop_wrap_f1_to_f8_to_f1.png"
    )
    print("Diagnostic plates saved successfully.")


if __name__ == "__main__":
    main()
