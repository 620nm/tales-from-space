#!/usr/bin/env python3
"""Pipe stubs, caps, riser sleeves and tg wallmount references for the drainage gallery.

Everything reads the pack's plumbing sources and the tgstation checkout; every fixture
here is unary, one mouth on one pipe. `render_pipe_connections_board` draws the static
sheet of the same compositing stack.
"""

from __future__ import annotations

import base64
import io
import json
import subprocess
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from drainage_kit import (
    OUT_ROOT,
    PACK_ROOT,
    aseprite_binary,
    hex_to_rgb,
    load_context_tiles,
    load_dmi_tile,
    load_ui_font,
    make_water_overlay,
    resolve_hex,
)

# BYOND / Lunatic direction bits: 1=North, 2=South, 4=East, 8=West
DIR_BITS = {"N": 1, "S": 2, "E": 4, "W": 8}
DMI_DIR_IDX = {1: 1, 2: 0, 4: 2, 8: 3}  # DMI order: 0=S, 1=N, 2=E, 3=W


def img_to_data_uri(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def tint_rgba(im: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    tr, tg, tb = rgb
    px_in = im.load()
    px_out = out.load()
    assert px_in is not None and px_out is not None
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px_in[x, y]
            if a > 0:
                px_out[x, y] = ((r * tr) // 255, (g * tg) // 255, (b * tb) // 255, a)
    return out


def extract_all_aseprite_tags(ase_rel: str) -> dict[str, Image.Image]:
    """Export an .aseprite spritesheet once with --list-tags and slice all tagged frames."""
    src = PACK_ROOT / ase_rel
    out_dir = OUT_ROOT
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet_png = out_dir / f"_sheet_{src.stem}.png"
    sheet_json = out_dir / f"_sheet_{src.stem}.json"
    subprocess.run(
        [
            aseprite_binary(),
            "-b",
            str(src),
            "--list-tags",
            "--sheet",
            str(sheet_png),
            "--data",
            str(sheet_json),
            "--format",
            "json-array",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    meta = json.loads(sheet_json.read_text(encoding="utf-8"))
    atlas = Image.open(sheet_png).convert("RGBA")
    sheet_png.unlink(missing_ok=True)
    sheet_json.unlink(missing_ok=True)

    frames = meta["frames"]
    result: dict[str, Image.Image] = {}
    for tg in meta["meta"].get("frameTags", []):
        f_idx = int(tg["from"])
        rect = frames[f_idx]["frame"]
        x, y, w, h = int(rect["x"]), int(rect["y"]), int(rect["w"]), int(rect["h"])
        result[tg["name"]] = atlas.crop((x, y, x + w, y + h))
    return result


# Pipe bitmask helper matching 50-pipes-and-cable.ron:30-109
PIPE_MASK_TO_TAG_PREFIX: dict[int, int] = {
    0: 48,
    1: 33,
    2: 18,
    3: 3,
    4: 132,
    5: 5,
    6: 6,
    7: 7,
    8: 72,
    9: 9,
    10: 10,
    11: 11,
    12: 12,
    13: 13,
    14: 14,
    15: 15,
}


def make_scupper_riser_sprites() -> dict[str, Image.Image]:
    """Build tales-from-space.gpl subfloor riser sleeves for the scupper across l1..l5.

    Drawn strictly on the central floor tile (0..31, 0..31) on the 'pipe' infrastructure layer
    (hidden when floor cover is intact, exposed on plating / open_grid). For channel ch_idx (1..5),
    shift = (ch_idx - 3) * 5 places the union box at (ux, uy) = (15 + shift, 15 - shift), matching
    every intact/exposed/half underlay stub on l1..l5 with 0px gap and 0px wall bleed.
    """
    c_s2 = hex_to_rgb(resolve_hex("S2"))
    c_s3 = hex_to_rgb(resolve_hex("S3"))
    c_s4 = hex_to_rgb(resolve_hex("S4"))
    c_s5 = hex_to_rgb(resolve_hex("S5"))
    c_ck1 = hex_to_rgb(resolve_hex("CK1"))
    c_ck2 = hex_to_rgb(resolve_hex("CK2"))

    def put(im: Image.Image, x: int, y: int, rgb: tuple[int, int, int]) -> None:
        if 0 <= x < 32 and 0 <= y < 32:
            im.putpixel((x, y), (*rgb, 255))

    def build_for_wall(wdir: str, ch_idx: int = 3, include_center_union: bool = True) -> Image.Image:
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        shift = (ch_idx - 3) * 5
        ux = 15 + shift
        uy = 15 - shift

        if wdir in ("N", "S"):
            ys = (range(0, uy + 1) if wdir == "N" else range(uy, 32)) if include_center_union else (
                range(0, 6) if wdir == "N" else range(26, 32)
            )
            for y in ys:
                put(im, ux - 3, y, c_s2)
                put(im, ux - 2, y, c_s3)
                put(im, ux - 1, y, c_s5)
                put(im, ux, y, c_s5)
                put(im, ux + 1, y, c_s4)
                put(im, ux + 2, y, c_s3)
                put(im, ux + 3, y, c_s2)
            flange_ys = [0, 1, 2] if wdir == "N" else [29, 30, 31]
            for fy in flange_ys:
                for fx in range(ux - 4, ux + 5):
                    dx_f = fx - ux
                    if dx_f in (-4, 4):
                        put(im, fx, fy, c_s2)
                    elif fy == flange_ys[1] and -2 <= dx_f <= 2:
                        put(im, fx, fy, c_ck2 if dx_f in (-1, 0) else c_ck1)
                    else:
                        put(im, fx, fy, c_s5 if fy == flange_ys[0] else c_s3)
        else:
            xs = (range(ux, 32) if wdir == "E" else range(0, ux + 1)) if include_center_union else (
                range(26, 32) if wdir == "E" else range(0, 6)
            )
            for x in xs:
                put(im, x, uy - 3, c_s2)
                put(im, x, uy - 2, c_s5)
                put(im, x, uy - 1, c_s5)
                put(im, x, uy, c_s4)
                put(im, x, uy + 1, c_s4)
                put(im, x, uy + 2, c_s3)
                put(im, x, uy + 3, c_s2)
            flange_xs = [29, 30, 31] if wdir == "E" else [0, 1, 2]
            for fx in flange_xs:
                for fy in range(uy - 4, uy + 5):
                    dy_f = fy - uy
                    if dy_f in (-4, 4):
                        put(im, fx, fy, c_s2)
                    elif fx == flange_xs[1] and -2 <= dy_f <= 2:
                        put(im, fx, fy, c_ck2 if dy_f in (-2, -1) else c_ck1)
                    else:
                        put(im, fx, fy, c_s5 if dy_f <= -1 else c_s3)

        if include_center_union:
            for dy_u in range(-4, 5):
                for dx_u in range(-4, 5):
                    if abs(dx_u) == 4 and abs(dy_u) == 4:
                        continue  # chamfered corners
                    x, y = ux + dx_u, uy + dy_u
                    if abs(dx_u) == 4 or abs(dy_u) == 4:
                        put(im, x, y, c_s2 if dy_u >= 3 else c_s3)
                    elif -1 <= dx_u <= 1 and -1 <= dy_u <= 1:
                        put(im, x, y, c_ck2 if dy_u == -1 else c_ck1)
                    elif dy_u == -3:
                        put(im, x, y, c_s5)
                    elif dy_u >= 2:
                        put(im, x, y, c_s3)
                    else:
                        put(im, x, y, c_s4)
        return im

    out: dict[str, Image.Image] = {}
    for wd in ("N", "S", "E", "W"):
        for ch_idx in range(1, 6):
            r_im = build_for_wall(wd, ch_idx=ch_idx, include_center_union=True)
            b_im = build_for_wall(wd, ch_idx=ch_idx, include_center_union=False)
            out[f"riser_{wd}_l{ch_idx}"] = r_im
            out[f"bulkhead_collar_{wd}_l{ch_idx}"] = b_im
            if ch_idx == 3:
                out[f"riser_{wd}"] = r_im
                out[f"bulkhead_collar_{wd}"] = b_im
    return out


def collect_pipe_workbench_bundle() -> dict[str, Any]:
    """Collect all subfloor pipe, stub, cap, riser, and 4-dir tgstation benchmark sprites."""
    underlays = extract_all_aseprite_tags("assets/originals/art/subfloor/plumbing/pipe_underlays.aseprite")
    pipes_bm = extract_all_aseprite_tags("assets/originals/art/subfloor/plumbing/pipes_bitmask.aseprite")
    half_bm = extract_all_aseprite_tags("assets/originals/art/subfloor/plumbing/layer_manifold_underlays.aseprite")

    stubs_intact: dict[str, str] = {}
    stubs_exposed: dict[str, str] = {}
    stubs_half: dict[str, str] = {}
    for ch_idx in range(1, 6):
        for dbit in (1, 2, 4, 8):
            stubs_intact[f"l{ch_idx}_{dbit}"] = img_to_data_uri(underlays[f"intact_{dbit}_{ch_idx}-s"])
            stubs_exposed[f"l{ch_idx}_{dbit}"] = img_to_data_uri(underlays[f"exposed_{dbit}_{ch_idx}-s"])
            stubs_half[f"l{ch_idx}_{dbit}"] = img_to_data_uri(half_bm[f"intact_{dbit}_{ch_idx}-s"])

    pipe_runs: dict[str, str] = {}
    for ch_idx in range(1, 6):
        for mask, prefix in PIPE_MASK_TO_TAG_PREFIX.items():
            pipe_runs[f"l{ch_idx}_{mask}"] = img_to_data_uri(pipes_bm[f"{prefix}_{ch_idx}-s"])

    # Mouth caps (22-atmos-mouth-caps.ron)
    caps: dict[str, str] = {}
    for fam, dmi_path, st_name in [
        ("scrub", "obj/machines/atmospherics/unary_devices.dmi", "scrub_cap"),
        ("vent", "obj/machines/atmospherics/unary_devices.dmi", "vent_cap"),
        ("inje", "obj/machines/atmospherics/unary_devices.dmi", "inje_cap"),
    ]:
        for dbit, dmi_dir in DMI_DIR_IDX.items():
            im = load_dmi_tile(dmi_path, st_name, dir_idx=dmi_dir, frame_idx=0)
            uri = img_to_data_uri(im)
            for ch_idx in range(1, 6):
                caps[f"{fam}_l{ch_idx}_{dbit}"] = uri

    intake_caps = extract_all_aseprite_tags("assets/originals/art/machines/drainage/intake_mouth_caps.aseprite")
    for ch_idx in range(1, 6):
        for dbit in (1, 2, 4, 8):
            caps[f"intake_l{ch_idx}_{dbit}"] = img_to_data_uri(intake_caps[f"l{ch_idx}_{dbit}"])

    risers_im = make_scupper_riser_sprites()
    risers = {k: img_to_data_uri(v) for k, v in risers_im.items()}


    # 4-dir tgstation wallmount benchmarks (wall_mounted.dm:60-72: dir points TOWARD supporting wall -> DMI order N=1, S=0, E=2, W=3)
    wall_dmi_dirs = [1, 0, 2, 3]  # [North wall, South wall, East wall, West wall]
    tg_4dir_mounts = [
        {
            "id": "tg_fire0",
            "title": "tg Fire Alarm (`fire0`, dirs=4)",
            "subtitle": "machines/wallmounts.dmi · shift=±26 · 8×14 N/S, 14×8 E/W",
            "note": "Canonical tg 4-dir machine wallmount: horizontal slot on N & S walls, rotated 90° to vertical slot on E & W walls.",
            "shifts": [[0, -26], [0, 26], [26, 0], [-26, 0]],
            "dirs": [
                img_to_data_uri(load_dmi_tile("obj/machines/wallmounts.dmi", "fire0", dir_idx=d, frame_idx=0))
                for d in wall_dmi_dirs
            ],
        },
        {
            "id": "tg_telescreen",
            "title": "tg Telescreen (`telescreen`, dirs=4)",
            "subtitle": "wallmounts.dmi · shift=±32 · 21×17 N/S, 17×21 E/W",
            "note": "Canonical tg 4-dir bulkhead overlay: wall-parallel louver/indicator strip runs horizontally on N & S, vertically on E & W.",
            "shifts": [[0, -32], [0, 32], [32, 0], [-32, 0]],
            "dirs": [
                img_to_data_uri(load_dmi_tile("obj/wallmounts.dmi", "telescreen", dir_idx=d, frame_idx=0))
                for d in wall_dmi_dirs
            ],
        },
        {
            "id": "tg_urinal",
            "title": "tg Urinal (`urinal`, dirs=4)",
            "subtitle": "watercloset.dmi · shift=±32 · strict oblique roof",
            "note": "Strict 3/4 oblique plumbing fixture: front basin visible on N/S, profile side view on E/W.",
            "shifts": [[0, -32], [0, 32], [32, 0], [-32, 0]],
            "dirs": [
                img_to_data_uri(load_dmi_tile("obj/watercloset.dmi", "urinal", dir_idx=d, frame_idx=0))
                for d in wall_dmi_dirs
            ],
        },
    ]

    return {
        "stubs_intact": stubs_intact,
        "stubs_exposed": stubs_exposed,
        "stubs_half": stubs_half,
        "pipe_runs": pipe_runs,
        "caps": caps,
        "risers": risers,
        "tg_4dir_mounts": tg_4dir_mounts,
    }


def render_pipe_connections_board(out_path: Path) -> None:
    """Render the static sheet of each fixture on its pipe, l1..l5."""
    ctx = load_context_tiles()
    underlays = extract_all_aseprite_tags("assets/originals/art/subfloor/plumbing/pipe_underlays.aseprite")
    pipes_bm = extract_all_aseprite_tags("assets/originals/art/subfloor/plumbing/pipes_bitmask.aseprite")
    half_bm = extract_all_aseprite_tags("assets/originals/art/subfloor/plumbing/layer_manifold_underlays.aseprite")
    risers = make_scupper_riser_sprites()

    scrub_caps = {db: load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "scrub_cap", DMI_DIR_IDX[db], 0) for db in (1, 2, 4, 8)}
    vent_caps = {db: load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_cap", DMI_DIR_IDX[db], 0) for db in (1, 2, 4, 8)}

    def frame(name: str, number: int) -> Image.Image:
        return Image.open(OUT_ROOT / "png_1x" / f"{name}_f{number}.png").convert("RGBA")

    drain = frame("floor_drain", 2)
    scupper_n = frame("scupper", 5)
    scupper_e = frame("scupper", 13)
    sump_ew = frame("sump_pump", 2)
    sump_ns = frame("sump_pump", 8)
    intake_lowered = frame("intake_floor", 1)
    intake_raised = frame("intake_floor", 7)
    intake_caps_im = extract_all_aseprite_tags("assets/originals/art/machines/drainage/intake_mouth_caps.aseprite")

    puddle = make_water_overlay(full_flood=False)
    waste_rgb = (240, 65, 55)
    blue_rgb = (84, 145, 232)

    def compose_3x3_floor_case(
        body_im: Image.Image,
        mouths: int,
        cap_dict: dict[int, Image.Image],
        ch_idx: int = 3,
        paint_rgb: tuple[int, int, int] = waste_rgb,
        exposed_unjoined: bool = False,
        covered: bool = False,
    ) -> Image.Image:
        rm = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
        base_tile = ctx["floor"] if covered else ctx["plating"]
        for gy in range(3):
            for gx in range(3):
                rm.paste(base_tile, (gx * 32, gy * 32))

        shift = (ch_idx - 3) * 5
        dx = shift if (mouths & 3) else 0
        dy = -shift if (mouths & 12) else 0

        if not covered:
            # Draw neighbor trunk pipes on surrounding tiles when joined
            if not exposed_unjoined:
                if mouths & 1:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"3_{ch_idx}-s"], paint_rgb), (32, 0))
                if mouths & 2:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"3_{ch_idx}-s"], paint_rgb), (32, 64))
                if mouths & 4:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"12_{ch_idx}-s"], paint_rgb), (64, 32))
                if mouths & 8:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"12_{ch_idx}-s"], paint_rgb), (0, 32))
            # Draw central tile underlay stubs
            for db in (1, 2, 4, 8):
                if mouths & db:
                    if exposed_unjoined:
                        st_im = underlays[f"exposed_{db}_{ch_idx}-s"]
                    else:
                        st_im = tint_rgba(underlays[f"intact_{db}_{ch_idx}-s"], paint_rgb)
                    rm.alpha_composite(st_im, (32, 32))

        rm.alpha_composite(puddle, (32, 32))
        bx = 32 + (0 if covered else dx)
        by = 32 + (0 if covered else dy)
        rm.alpha_composite(body_im, (bx, by))
        if not covered:
            for db in (1, 2, 4, 8):
                if mouths & db:
                    rm.alpha_composite(cap_dict[db], (bx, by))
        return rm.crop((16, 16, 80, 80))  # 64x64 crisp centered view!

    def compose_scupper_case(
        wdir: str,
        mouths: int,
        in_wall_only: bool = False,
        ch_idx: int = 3,
        covered: bool = False,
    ) -> Image.Image:
        rm = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
        base_tile = ctx["floor"] if covered else ctx["plating"]
        for gy in range(3):
            for gx in range(3):
                is_wall = (gy == 0 if wdir == "N" else (gx == 2))
                rm.paste(ctx["wall"] if is_wall else base_tile, (gx * 32, gy * 32))

        shift = (ch_idx - 3) * 5
        dx_wall = shift if wdir in ("N", "S") else 0
        dy_wall = -shift if wdir in ("E", "W") else 0

        if not covered:
            if in_wall_only:
                dbit_wall = {"N": 1, "S": 2, "E": 4, "W": 8}[wdir]
                rm.alpha_composite(tint_rgba(half_bm[f"intact_{dbit_wall}_{ch_idx}-s"], waste_rgb), (32, 32))
                rm.alpha_composite(risers[f"bulkhead_collar_{wdir}_l{ch_idx}"], (32, 32))
            else:
                if mouths & 2:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"3_{ch_idx}-s"], waste_rgb), (32, 64))
                if mouths & 1 and wdir == "E":
                    rm.alpha_composite(tint_rgba(pipes_bm[f"3_{ch_idx}-s"], waste_rgb), (32, 0))
                if mouths & 4 and wdir == "N":
                    rm.alpha_composite(tint_rgba(pipes_bm[f"12_{ch_idx}-s"], waste_rgb), (64, 32))
                if mouths & 8:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"12_{ch_idx}-s"], waste_rgb), (0, 32))
                for db in (1, 2, 4, 8):
                    if mouths & db:
                        rm.alpha_composite(tint_rgba(underlays[f"intact_{db}_{ch_idx}-s"], waste_rgb), (32, 32))
                rm.alpha_composite(risers[f"riser_{wdir}_l{ch_idx}"], (32, 32))

        rm.alpha_composite(puddle, (32, 32))
        if wdir == "N":
            rm.alpha_composite(scupper_n, (32 + (0 if covered else dx_wall), 0))
            return rm.crop((16, 8, 80, 72))
        rm.alpha_composite(scupper_e, (64, 32 + (0 if covered else dy_wall)))
        return rm.crop((24, 16, 88, 80))

    def compose_intake_case(
        body_im: Image.Image,
        channels_mouths: list[tuple[int, int, tuple[int, int, int]]],
        covered: bool = False,
    ) -> Image.Image:
        rm = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
        base_tile = ctx["floor"] if covered else ctx["plating"]
        for gy in range(3):
            for gx in range(3):
                rm.paste(base_tile, (gx * 32, gy * 32))

        if not covered:
            for ch_idx, mouths, paint_rgb in channels_mouths:
                if mouths & 1:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"3_{ch_idx}-s"], paint_rgb), (32, 0))
                if mouths & 2:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"3_{ch_idx}-s"], paint_rgb), (32, 64))
                if mouths & 4:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"12_{ch_idx}-s"], paint_rgb), (64, 32))
                if mouths & 8:
                    rm.alpha_composite(tint_rgba(pipes_bm[f"12_{ch_idx}-s"], paint_rgb), (0, 32))
                for db in (1, 2, 4, 8):
                    if mouths & db:
                        rm.alpha_composite(tint_rgba(underlays[f"intact_{db}_{ch_idx}-s"], paint_rgb), (32, 32))

        rm.alpha_composite(puddle, (32, 32))
        rm.alpha_composite(body_im, (32, 32))
        if not covered:
            for ch_idx, mouths, _paint_rgb in channels_mouths:
                for db in (1, 2, 4, 8):
                    if mouths & db:
                        rm.alpha_composite(intake_caps_im[f"l{ch_idx}_{db}"], (32, 32))
        return rm.crop((16, 16, 80, 80))

    font_h1 = load_ui_font(15)
    font_h2 = load_ui_font(12)
    font_s = load_ui_font(10)

    cols = 6
    cell_px = 192  # 64 * 3x
    col_w = cell_px + 18
    row_h = cell_px + 54
    W = cols * col_w + 30
    H = 4 * row_h + 74
    board = Image.new("RGBA", (W, H), (15, 18, 26, 255))
    draw = ImageDraw.Draw(board)

    draw.text(
        (20, 14),
        "Drainage fixtures: pipe connections",
        font=font_h1,
        fill=(245, 224, 74, 255),
    )
    draw.text(
        (20, 36),
        "Bare bodies + pipe_intact/pipe_exposed stubs + mouth_cap ('scrub'/'vent'/'intake') + l1..l5 tracks; hidden under covered floor.",
        font=font_s,
        fill=(148, 151, 171, 255),
    )

    rows_data = [
        (
            'Floor drain (mouth_cap = "scrub"): 4-fold symmetric, one picture on every facing',
            [
                ("North (l3 joined)", compose_3x3_floor_case(drain, 1, scrub_caps, 3, waste_rgb)),
                ("Unjoined (exposed)", compose_3x3_floor_case(drain, 1, scrub_caps, 3, waste_rgb, exposed_unjoined=True)),
                ("East (l3 joined)", compose_3x3_floor_case(drain, 4, scrub_caps, 3, blue_rgb)),
                ("Layer l1 (-10,+10)", compose_3x3_floor_case(drain, 1, scrub_caps, 1, waste_rgb)),
                ("Covered floor (hides stubs)", compose_3x3_floor_case(drain, 1, scrub_caps, 1, waste_rgb, covered=True)),
            ],
        ),
        (
            "Scupper: centered on pixel 15, reached through the room tile or an in-wall drop",
            [
                ("N wall, in-wall drop", compose_scupper_case("N", 0, in_wall_only=True)),
                ("N wall, riser (south)", compose_scupper_case("N", 2)),
                ("E wall, riser (west)", compose_scupper_case("E", 8)),
                ("Covered floor (clean wall)", compose_scupper_case("N", 2, covered=True)),
            ],
        ),
        (
            'Sump pump (mouth_cap = "vent"): the manifold spine turns with the facing',
            [
                ("North (N-S spine)", compose_3x3_floor_case(sump_ns, 1, vent_caps, 3, waste_rgb)),
                ("South (N-S spine)", compose_3x3_floor_case(sump_ns, 2, vent_caps, 3, blue_rgb)),
                ("East (E-W spine)", compose_3x3_floor_case(sump_ew, 4, vent_caps, 3, waste_rgb)),
                ("West (E-W spine)", compose_3x3_floor_case(sump_ew, 8, vent_caps, 3, blue_rgb)),
                ("Layer l5 (+10px)", compose_3x3_floor_case(sump_ns, 1, vent_caps, 5, waste_rgb)),
            ],
        ),
        (
            'Intake (mouth_cap = "intake"): full 32×32 curb seats 5×3 collars on l1..l5',
            [
                ("North l3 (lowered)", compose_intake_case(intake_lowered, [(3, 1, waste_rgb)])),
                ("Layer l1 (-10px track)", compose_intake_case(intake_lowered, [(1, 1, waste_rgb)])),
                ("East l5 (raised)", compose_intake_case(intake_raised, [(5, 4, blue_rgb)])),
                ("All 5 layers (N+E)", compose_intake_case(intake_raised, [(ch, 5, blue_rgb if ch % 2 == 0 else waste_rgb) for ch in range(1, 6)])),
                ("Covered floor (hides stubs)", compose_intake_case(intake_lowered, [(3, 1, waste_rgb)], covered=True)),
            ],
        ),
    ]

    for ri, (row_title, cells) in enumerate(rows_data):
        ry = 66 + ri * row_h
        draw.text((20, ry), row_title, font=font_h2, fill=(124, 196, 182, 255))
        for ci, (lbl, cim) in enumerate(cells):
            cx = 20 + ci * col_w
            cy = ry + 20
            board.paste(cim.resize((cell_px, cell_px), Image.NEAREST), (cx, cy))
            draw.rectangle([cx - 1, cy - 1, cx + cell_px, cy + cell_px], outline=(55, 58, 75, 255))
            draw.text((cx + 2, cy + cell_px + 4), lbl, font=font_s, fill=(210, 214, 226, 255))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(out_path)
