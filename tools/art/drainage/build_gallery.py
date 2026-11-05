#!/usr/bin/env python3
"""Bundles the kit's manifests with `gallery/` into `target/art/drainage/gallery/`.

Also draws `overview_board.png` and `pipe_connections_board.png` beside it. Run
`drainage_kit.py` first: the bundle reads the manifests it writes.
"""

from __future__ import annotations

import base64
import io
import json
import shutil
import subprocess
import textwrap
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from drainage_kit import (
    DRAINAGE_DIR,
    FIXTURES,
    NAME_BY_HEX,
    OUT_ROOT,
    PACK_ROOT,
    aseprite_binary,
    composite_frame,
    load_context_tiles,
    load_dmi_tile,
    load_spec,
    load_ui_font,
    make_water_overlay,
    resolve_hex,
)
from pipe_workbench import (
    collect_pipe_workbench_bundle,
    img_to_data_uri,
    render_pipe_connections_board,
    tint_rgba,
)

GALLERY_SOURCE = DRAINAGE_DIR / "gallery"
GALLERY_DIR = OUT_ROOT / "gallery"


def png_file_to_data_uri(path: str | Path) -> str:
    data = Path(path).read_bytes()
    return "data:image/png;base64," + base64.b64encode(data).decode("ascii")


def extract_aseprite_tag_frame(ase_rel: str, tag: str | None = None) -> Image.Image:
    src = PACK_ROOT / ase_rel
    safe_tag = (tag or "f1").replace("/", "_")
    tmp_out = OUT_ROOT / f"_tmp_{src.stem}_{safe_tag}.png"
    tmp_out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [aseprite_binary(), "-b", str(src)]
    if tag is not None:
        cmd += ["--frame-tag", tag]
    else:
        cmd += ["--frame-range", "0,0"]
    cmd += ["--save-as", str(tmp_out)]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    im = Image.open(tmp_out).convert("RGBA")
    tmp_out.unlink(missing_ok=True)
    return im


def collect_reference_assets() -> dict[str, Any]:
    ctx = load_context_tiles()
    open_floor_im = extract_aseprite_tag_frame("assets/originals/art/turf/open_floor.aseprite", "open_floor")

    pipe_stub_n = extract_aseprite_tag_frame("assets/originals/art/subfloor/plumbing/pipe_underlays.aseprite", "intact_1_3-s")
    pipe_stub_e = extract_aseprite_tag_frame("assets/originals/art/subfloor/plumbing/pipe_underlays.aseprite", "intact_4_3-s")
    pipe_stub_waste_n = tint_rgba(pipe_stub_n, (240, 65, 55))
    pipe_stub_supply_n = tint_rgba(pipe_stub_n, (84, 145, 232))
    pipe_stub_supply_e = tint_rgba(pipe_stub_e, (84, 145, 232))

    pipe_ns_full = extract_aseprite_tag_frame("assets/originals/art/subfloor/plumbing/pipes_bitmask.aseprite", "3_3-s")
    pipe_ns_waste = tint_rgba(pipe_ns_full, (240, 65, 55))

    scrub_cap_n = load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "scrub_cap", dir_idx=1, frame_idx=0)
    vent_cap_n = load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_cap", dir_idx=1, frame_idx=0)
    vent_cap_e = load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_cap", dir_idx=2, frame_idx=0)

    turfs = {
        "floor": {"label": "Standard Station Floor (#808080 — Covers Pipe)", "src": img_to_data_uri(ctx["floor"]), "exposes_pipe": False},
        "plating": {"label": "Subfloor Plating (#36373a — Exposes Pipe)", "src": img_to_data_uri(ctx["plating"]), "exposes_pipe": True},
        "open_grid": {"label": "Open Maintenance Grid (Exposes Pipe)", "src": img_to_data_uri(ctx["plating"]), "exposes_pipe": True, "cover_src": img_to_data_uri(open_floor_im)},
        "reinforced_floor": {"label": "Engine Reinforced Deck (#232127)", "src": img_to_data_uri(ctx["reinforced_floor"]), "exposes_pipe": False},
        "white_floor": {"label": "Medbay Cleanroom White (#d9d9d9)", "src": img_to_data_uri(ctx["white_floor"]), "exposes_pipe": False},
        "dark_floor": {"label": "Dark Checker Deck", "src": img_to_data_uri(ctx["dark_floor"]), "exposes_pipe": False},
    }
    walls = {
        "wall": {"label": "Standard Bulkhead Wall (#444444)", "src": img_to_data_uri(ctx["wall"])},
        "reinforced_wall": {"label": "Reinforced Bulkhead Wall", "src": img_to_data_uri(ctx["reinforced_wall"])},
    }
    apc_base = load_dmi_tile("obj/machines/wallmounts.dmi", "apc0", 0, 0)
    apc_lock = load_dmi_tile("obj/machines/wallmounts.dmi", "apcox-0", 0, 0)
    apc_lit = apc_base.copy()
    for ov_state in ("apcox-0", "apco3-2", "apco0-3", "apco1-3", "apco2-3"):
        apc_lit.alpha_composite(load_dmi_tile("obj/machines/wallmounts.dmi", ov_state, 0, 0))
    apc_fault = apc_base.copy()
    for ov_state in ("apcox-0", "apco3-0", "apco0-1", "apco1-1", "apco2-1"):
        apc_fault.alpha_composite(load_dmi_tile("obj/machines/wallmounts.dmi", ov_state, 0, 0))
    apc_idle = apc_base.copy()
    apc_idle.alpha_composite(apc_lock)

    alarm_base = load_dmi_tile("obj/machines/wallmounts.dmi", "alarmp", 0, 0)
    alarm_ok = alarm_base.copy(); alarm_ok.alpha_composite(load_dmi_tile("obj/machines/wallmounts.dmi", "alarm0", 0, 0))
    alarm_haz = alarm_base.copy(); alarm_haz.alpha_composite(load_dmi_tile("obj/machines/wallmounts.dmi", "alarm1", 0, 0))

    overlays = {
        "puddle": img_to_data_uri(make_water_overlay(full_flood=False)),
        "flood": img_to_data_uri(make_water_overlay(full_flood=True)),
        "pipe_stub_steel_n": img_to_data_uri(pipe_stub_n),
        "pipe_stub_waste_n": img_to_data_uri(pipe_stub_waste_n),
        "pipe_stub_supply_n": img_to_data_uri(pipe_stub_supply_n),
        "pipe_stub_supply_e": img_to_data_uri(pipe_stub_supply_e),
        "pipe_ns_waste": img_to_data_uri(pipe_ns_waste),
        "scrub_cap_n": img_to_data_uri(scrub_cap_n),
        "vent_cap_n": img_to_data_uri(vent_cap_n),
        "vent_cap_e": img_to_data_uri(vent_cap_e),
        "intake_cap_n": img_to_data_uri(extract_aseprite_tag_frame("assets/originals/art/machines/drainage/intake_mouth_caps.aseprite", "l3_1")),
        "apc_lit": img_to_data_uri(apc_lit),
        "alarm_ok": img_to_data_uri(alarm_ok),
    }

    refs = [
        {
            "id": "ref_vent",
            "title": "Air Vent (Unary Supply)",
            "subtitle": "unary_devices.dmi · 19×19 · mouth_cap='vent'",
            "note": "Flat subdued steel louver grille (#353535–#989898); cap & stub appear only when subfloor is exposed.",
            "pipe_kind": "supply",
            "mount_shift": 0,
            "idle": img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_off", 0, 0)),
            "active": [
                img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_out", 0, f))
                for f in range(4)
            ],
            "fault": img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_in", 0, 0)),
        },
        {
            "id": "ref_passive_vent",
            "title": "Passive Vent (Unary)",
            "subtitle": "unary_devices.dmi · 19×19 · mouth_cap='vent'",
            "note": "Unpowered flush grille: zero LEDs, soft #353535/#4d4d4d outer bevel, max #989898.",
            "pipe_kind": "supply",
            "mount_shift": 0,
            "idle": img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "passive_vent", 0, 0)),
            "active": [img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "passive_vent", 0, 0))],
            "fault": img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "passive_vent", 0, 0)),
        },
        {
            "id": "ref_scrubber",
            "title": "Air Scrubber (Unary Waste)",
            "subtitle": "unary_devices.dmi · 19×19 · mouth_cap='scrub'",
            "note": "Octagonal 8-spoke radial grille; exact 19×19 collar & scrub_cap silhouette shared with the floor drain.",
            "pipe_kind": "waste",
            "mount_shift": 0,
            "idle": img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "scrub_off", 0, 0)),
            "active": [
                img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "scrub_on", 0, f))
                for f in (0, 6, 12, 18)
            ],
            "fault": img_to_data_uri(load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "scrub_purge", 0, 1)),
        },
        {
            "id": "ref_apc",
            "title": "APC (`apc0`, dirs=1)",
            "subtitle": "machines/wallmounts.dmi · 17×14 · shift=±25",
            "note": "Single front-on sprite (`dirs=1`) shifted onto walls; 127/143 tg wallmount states use dirs=1.",
            "pipe_kind": "none",
            "mount_shift": 25,
            "idle": img_to_data_uri(apc_idle),
            "active": [img_to_data_uri(apc_lit)],
            "fault": img_to_data_uri(apc_fault),
        },
        {
            "id": "ref_air_alarm",
            "title": "Air Alarm (`alarmp`, dirs=1)",
            "subtitle": "machines/wallmounts.dmi · 23×17 · shift=±27",
            "note": "Single front-on sprite (`dirs=1`); compare true `dirs=4` wallmounts (`fire0`, `telescreen`) below!",
            "pipe_kind": "none",
            "mount_shift": 27,
            "idle": img_to_data_uri(alarm_base),
            "active": [img_to_data_uri(alarm_ok)],
            "fault": img_to_data_uri(alarm_haz),
        },
    ]
    return {"turfs": turfs, "walls": walls, "overlays": overlays, "refs": refs}


def _layer_frames_hex_grid(layer: dict[str, Any], n_frames: int) -> list[list[list[str | None]]]:
    leg = {ch: resolve_hex(col) for ch, col in layer["legend"].items()}
    raw_frames = layer["frames"] if "frames" in layer else [layer["rows"]] * n_frames
    out: list[list[list[str | None]]] = []
    for rows in raw_frames:
        out.append([[None if ch == "." else leg[ch] for ch in row] for row in rows])
    return out


def load_fixtures_bundle() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for fixture in FIXTURES:
        sp = load_spec(fixture)
        rep = json.loads((OUT_ROOT / "manifests" / f"{fixture}.json").read_text(encoding="utf-8"))
        n_frames = rep["frame_count"]
        grids = [composite_frame(sp, fi, static_only=False) for fi in range(n_frames)]
        layers_out = []
        for idx, lyr_rep in enumerate(rep["layer_pngs"]):
            layers_out.append({
                "name": lyr_rep["name"],
                "animated": lyr_rep["animated"],
                "frame_grids": _layer_frames_hex_grid(sp["layers"][idx], n_frames),
            })
        items.append({
            "name": rep["name"],
            "title": rep["title"],
            "kind": rep["kind"],
            "blurb": rep["blurb"],
            "design_notes": rep.get("design_notes", ""),
            "aseprite": rep["aseprite"],
            "frame_count": n_frames,
            "durations": rep["frame_durations_ms"],
            "tags": rep["tags"],
            "frames": [png_file_to_data_uri(p) for p in rep["frame_pngs_1x"]],
            "layers": layers_out,
            "swatches": rep["swatches"],
            "frame_stats": rep["frame_stats"],
            "animated_px": rep["animated_px"],
            "grids": grids,
        })
    return items


def render_overview_board(fixtures: list[dict[str, Any]], out_path: Path) -> None:
    """Render the single-image sheet: references, then each fixture in place."""
    ctx = load_context_tiles()
    puddle = make_water_overlay(full_flood=False)
    flood = make_water_overlay(full_flood=True)
    font_h1 = load_ui_font(16)
    font_h2 = load_ui_font(13)
    font_b = load_ui_font(11)
    font_s = load_ui_font(10)

    W = 1360
    H = 1420
    board = Image.new("RGBA", (W, H), (15, 18, 26, 255))
    draw = ImageDraw.Draw(board)

    draw.text((24, 18), "Tales from Space: liquid drainage fixtures", font=font_h1, fill=(245, 224, 74, 255))

    draw.text((24, 68), "REFERENCES (air vents, scrubbers, dirs=4 fire0 & telescreen wallmounts, APC)", font=font_h2, fill=(124, 196, 182, 255))
    apc_lit = load_dmi_tile("obj/machines/wallmounts.dmi", "apc0", 0, 0)
    for ov_state in ("apcox-0", "apco3-2", "apco0-3", "apco1-3", "apco2-3"):
        apc_lit.alpha_composite(load_dmi_tile("obj/machines/wallmounts.dmi", ov_state, 0, 0))

    def make_wall_ref_tile(sp: Image.Image, shift_x: int, shift_y: int) -> Image.Image:
        rm = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
        for gy in range(3):
            for gx in range(3):
                rm.paste(ctx["floor"] if (gx == 1 and gy == 1) else ctx["wall"], (gx * 32, gy * 32))
        rm.alpha_composite(sp, (32 + shift_x, 32 + shift_y))
        if shift_y < 0:
            return rm.crop((32, 6, 64, 38))
        return rm.crop((56, 32, 88, 64))

    ref_defs = [
        ("vent_off", ctx["floor"], load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "vent_off", 0, 0)),
        ("passive_vent", ctx["floor"], load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "passive_vent", 0, 0)),
        ("scrub_off", ctx["floor"], load_dmi_tile("obj/machines/atmospherics/unary_devices.dmi", "scrub_off", 0, 0)),
        ("fire0 (N wall)", make_wall_ref_tile(load_dmi_tile("obj/machines/wallmounts.dmi", "fire0", 1, 0), 0, -26), None),
        ("fire0 (E wall)", make_wall_ref_tile(load_dmi_tile("obj/machines/wallmounts.dmi", "fire0", 2, 0), 26, 0), None),
        ("telescreen (N)", make_wall_ref_tile(load_dmi_tile("obj/wallmounts.dmi", "telescreen", 1, 0), 0, -32), None),
        ("telescreen (E)", make_wall_ref_tile(load_dmi_tile("obj/wallmounts.dmi", "telescreen", 2, 0), 32, 0), None),
        ("apc (dirs=1 N)", make_wall_ref_tile(apc_lit, 0, -25), None),
    ]
    for i, (lbl, bg_im, ov_im) in enumerate(ref_defs):
        rx = 24 + i * 164
        ry = 92
        c = bg_im.copy()
        if ov_im is not None:
            c.alpha_composite(ov_im)
        big = c.resize((104, 104), Image.NEAREST)
        board.paste(big, (rx, ry))
        draw.rectangle([rx - 1, ry - 1, rx + 104, ry + 104], outline=(55, 58, 75, 255))
        board.paste(c, (rx + 112, ry + 72))
        draw.text((rx, ry + 108), lbl, font=font_s, fill=(197, 199, 212, 255))

    def f_img(c: dict[str, Any], idx: int) -> Image.Image:
        raw = base64.b64decode(c["frames"][idx].split(",", 1)[1])
        return Image.open(io.BytesIO(raw)).convert("RGBA")

    def draw_wrapped_blurb(x: int, y: int, text: str) -> None:
        lines = textwrap.wrap(text, width=46)
        if len(lines) > 2:
            lines = [lines[0], lines[1].rstrip(".,; ") + "..."]
        for li, ln in enumerate(lines):
            draw.text((x, y + li * 13), ln, font=font_s, fill=(148, 151, 171, 255))

    # Row 1: Floor Drains
    drains = [c for c in fixtures if c["kind"] == "floor_drain"]
    draw.text((24, 232), "FLOOR DRAIN", font=font_h2, fill=(124, 196, 182, 255))
    for i, c in enumerate(drains):
        cx = 24 + i * 330
        cy = 258
        draw.rounded_rectangle([cx, cy, cx + 316, cy + 230], radius=6, fill=(24, 28, 42, 255), outline=(124, 196, 182, 255), width=2)
        draw.text((cx + 10, cy + 8), c["title"], font=font_b, fill=(245, 224, 74, 255))
        f0 = f_img(c, 0)
        f1 = f_img(c, 1)

        t_dry = ctx["floor"].copy(); t_dry.alpha_composite(f0)
        t_wet = ctx["floor"].copy(); t_wet.alpha_composite(puddle); t_wet.alpha_composite(f1)
        t_eng = ctx["reinforced_floor"].copy(); t_eng.alpha_composite(f0)

        for bi, (bt, bl) in enumerate([(t_dry, "Floor"), (t_wet, "Wet/Flow"), (t_eng, "Engine")]):
            bx = cx + 10 + bi * 98
            by = cy + 30
            board.paste(bt.resize((88, 88), Image.NEAREST), (bx, by))
            draw.rectangle([bx - 1, by - 1, bx + 88, by + 88], outline=(71, 74, 91, 255))
            draw.text((bx, by + 92), bl, font=font_s, fill=(148, 151, 171, 255))

        board.paste(t_dry, (cx + 10, cy + 142))
        board.paste(t_eng, (cx + 48, cy + 142))
        t_wh = ctx["white_floor"].copy(); t_wh.alpha_composite(f0)
        board.paste(t_wh, (cx + 86, cy + 142))
        st = c["frame_stats"][0]
        draw.text(
            (cx + 128, cy + 146),
            f"span {st['bbox'][2]}×{st['bbox'][3]} · {st['unique_colors']} cols\nhLuma {st['housing_mean_luma']} (max {st['housing_max_luma']})",
            font=font_s,
            fill=(197, 199, 212, 255),
        )
        draw_wrapped_blurb(cx + 10, cy + 188, c["blurb"])

    # Row 2: Wall Scuppers
    scuppers = [c for c in fixtures if c["kind"] == "scupper"]
    draw.text((24, 506), "SCUPPER", font=font_h2, fill=(124, 196, 182, 255))
    for i, c in enumerate(scuppers):
        cx = 24 + i * 330
        cy = 532
        draw.rounded_rectangle([cx, cy, cx + 316, cy + 236], radius=6, fill=(24, 28, 42, 255), outline=(124, 196, 182, 255), width=2)
        draw.text((cx + 10, cy + 8), c["title"], font=font_b, fill=(245, 224, 74, 255))
        fn, fs, fe, fw = f_img(c, 0), f_img(c, 1), f_img(c, 2), f_img(c, 3)

        rm_base = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
        for gy in range(3):
            for gx in range(3):
                rm_base.paste(ctx["floor"] if (gx == 1 and gy == 1) else ctx["wall"], (gx * 32, gy * 32))

        crops = []
        for d_lbl, sp, pos, box in [
            ("N", fn, (32, 0), (28, 8, 68, 48)),
            ("S", fs, (32, 64), (28, 48, 68, 88)),
            ("E", fe, (64, 32), (48, 28, 88, 68)),
            ("W", fw, (0, 32), (8, 28, 48, 68)),
        ]:
            r = rm_base.copy()
            r.alpha_composite(sp, pos)
            crops.append((d_lbl, r.crop(box)))

        for di, (dl, cim) in enumerate(crops):
            bx = cx + 10 + di * 75
            by = cy + 30
            board.paste(cim.resize((68, 68), Image.NEAREST), (bx, by))
            draw.rectangle([bx - 1, by - 1, bx + 68, by + 68], outline=(71, 74, 91, 255))
            draw.text((bx + 26, by + 71), dl, font=font_s, fill=(197, 199, 212, 255))

        rm4 = rm_base.copy()
        rm4.alpha_composite(flood, (32, 32))
        fn_a = f_img(c, 4) if len(c["frames"]) > 4 else fn
        fs_a = f_img(c, 8) if len(c["frames"]) > 8 else fs
        fe_a = f_img(c, 12) if len(c["frames"]) > 12 else fe
        fw_a = f_img(c, 16) if len(c["frames"]) > 16 else fw
        rm4.alpha_composite(fn_a, (32, 0))
        rm4.alpha_composite(fs_a, (32, 64))
        rm4.alpha_composite(fe_a, (64, 32))
        rm4.alpha_composite(fw_a, (0, 32))
        board.paste(rm4, (cx + 10, cy + 122))
        draw.rectangle([cx + 9, cy + 121, cx + 106, cy + 218], outline=(71, 74, 91, 255))
        st = c["frame_stats"][0]
        draw.text(
            (cx + 116, cy + 132),
            f"1x 3×3 room (4 wall overlays)\nN wall bbox: {st['bbox'][2]}×{st['bbox'][3]} px\nhLuma: {st['housing_mean_luma']} (max {st['housing_max_luma']})\nluma N: {st['luma_top']}>{st['luma_bottom']}",
            font=font_s,
            fill=(197, 199, 212, 255),
        )

    # Row 3: Sump Pumps
    pump = next(c for c in fixtures if c["kind"] == "sump_pump")
    draw.text((24, 788), "SUMP PUMP (E-W axis, N-S axis)", font=font_h2, fill=(124, 196, 182, 255))
    for i, axis in enumerate((0, 6)):
        c = pump
        cx = 24 + i * 330
        cy = 814
        draw.rounded_rectangle([cx, cy, cx + 316, cy + 252], radius=6, fill=(24, 28, 42, 255), outline=(124, 196, 182, 255), width=2)
        draw.text((cx + 10, cy + 8), c["title"], font=font_b, fill=(245, 224, 74, 255))
        f_off = f_img(c, axis)
        f_act = f_img(c, axis + 1)
        f_flt = f_img(c, axis + 5)

        t_off = ctx["floor"].copy(); t_off.alpha_composite(f_off)
        t_act = ctx["floor"].copy(); t_act.alpha_composite(puddle); t_act.alpha_composite(f_act)
        t_flt = ctx["floor"].copy(); t_flt.alpha_composite(f_flt)

        for bi, (bt, bl) in enumerate([(t_off, "Off (Idle)"), (t_act, "Pumping"), (t_flt, "Fault/Full")]):
            bx = cx + 10 + bi * 98
            by = cy + 30
            board.paste(bt.resize((88, 88), Image.NEAREST), (bx, by))
            draw.rectangle([bx - 1, by - 1, bx + 88, by + 88], outline=(71, 74, 91, 255))
            draw.text((bx, by + 92), bl, font=font_s, fill=(148, 151, 171, 255))

        board.paste(t_off, (cx + 10, cy + 144))
        board.paste(t_act, (cx + 48, cy + 144))
        board.paste(t_flt, (cx + 86, cy + 144))
        st = c["frame_stats"][0]
        draw.text(
            (cx + 128, cy + 148),
            f"span {st['bbox'][2]}×{st['bbox'][3]} · {st['unique_colors']} cols\nluma {st['luma_top']}>{st['luma_bottom']} · anim {c['animated_px']}px",
            font=font_s,
            fill=(197, 199, 212, 255),
        )
        draw_wrapped_blurb(cx + 10, cy + 194, c["blurb"])

    # Row 4: the intake's two faces
    intake_names = ("intake_floor", "intake_ceiling")
    intake_cards = [next((c for c in fixtures if c["name"] == nm), None) for nm in intake_names]
    intake_cards = [c for c in intake_cards if c is not None]
    if intake_cards:
        draw.text(
            (24, 1092),
            "INTAKE (Floor Face z, Ceiling Face z-1)",
            font=font_h2,
            fill=(124, 196, 182, 255),
        )
        for i, c in enumerate(intake_cards):
            cx = 24 + i * 330
            cy = 1118
            draw.rounded_rectangle([cx, cy, cx + 316, cy + 252], radius=6, fill=(24, 28, 42, 255), outline=(124, 196, 182, 255), width=2)
            draw.text((cx + 10, cy + 8), c["title"], font=font_b, fill=(245, 224, 74, 255))
            if c["name"] in ("intake_floor", "intake_ceiling"):
                bg = ctx["floor"] if c["name"] == "intake_floor" else ctx["plating"]
                samples = [
                    (bg, f_img(c, 0), "Lowered"),
                    (bg, f_img(c, 3), "Raising"),
                    (bg, f_img(c, 6), "Raised"),
                ]
            else:
                f0 = f_img(c, 0)
                samples = [
                    (ctx["floor"], f0, "Floor"),
                    (ctx["plating"], f0, "Plating"),
                    (ctx["reinforced_floor"], f0, "Engine"),
                ]

            composed_chips = []
            for bi, (bg_tile, fg_im, bl) in enumerate(samples):
                bt = bg_tile.copy()
                bt.alpha_composite(fg_im)
                composed_chips.append(bt)
                bx = cx + 10 + bi * 98
                by = cy + 30
                board.paste(bt.resize((88, 88), Image.NEAREST), (bx, by))
                draw.rectangle([bx - 1, by - 1, bx + 88, by + 88], outline=(71, 74, 91, 255))
                draw.text((bx, by + 92), bl, font=font_s, fill=(148, 151, 171, 255))

            for bi, bt in enumerate(composed_chips):
                board.paste(bt, (cx + 10 + bi * 38, cy + 144))
            st = c["frame_stats"][0]
            draw.text(
                (cx + 128, cy + 148),
                f"span {st['bbox'][2]}×{st['bbox'][3]} · {st['unique_colors']} cols\nluma {st['luma_top']}>{st['luma_bottom']} · anim {c['animated_px']}px",
                font=font_s,
                fill=(197, 199, 212, 255),
            )
            draw_wrapped_blurb(cx + 10, cy + 194, c["blurb"])

    out_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(out_path)


def main() -> None:
    refs_bundle = collect_reference_assets()
    fixtures = load_fixtures_bundle()
    pipes_bundle = collect_pipe_workbench_bundle()
    payload = {
        "swatch_names": NAME_BY_HEX,
        "refs_bundle": refs_bundle,
        "fixtures": fixtures,
        "pipes": pipes_bundle,
    }
    GALLERY_DIR.mkdir(parents=True, exist_ok=True)
    for page_file in GALLERY_SOURCE.iterdir():
        shutil.copy(page_file, GALLERY_DIR / page_file.name)
    data_out = GALLERY_DIR / "gallery_data.js"
    data_out.write_text("const DATA = " + json.dumps(payload) + ";\n", encoding="utf-8")

    render_overview_board(fixtures, OUT_ROOT / "overview_board.png")
    render_pipe_connections_board(OUT_ROOT / "pipe_connections_board.png")
    print(f"Built gallery: {GALLERY_DIR / 'index.html'} ({data_out.stat().st_size // 1024} KiB of data)")


if __name__ == "__main__":
    main()
