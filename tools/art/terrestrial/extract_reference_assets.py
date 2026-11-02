#!/usr/bin/env python3
r"""
Extract read-only TfS Elemental Matter/Fire (`tfs_matter`, including
`solid_debris_jagged_smooth`), TfS Station Turfs/Props (`tfs_station`), and curated
`tgstation` Outdoor/Planetary/Nature (`tg_outdoor`) reference assets into
`<out_dir>/cache/` and `<out_dir>/manifests/existing.json`.

Strictly writes ONLY inside `--out-dir` (default: `DEFAULT_OUT_DIR`). Never modifies
`tgstation` or tracked pack originals.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
from pathlib import Path
import subprocess
import sys
from typing import Any
import zlib

from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from schema_contract import (  # noqa: E402
    DEFAULT_OUT_DIR,
    EAST,
    JUNCTIONS,
    NE,
    NORTH,
    NW,
    PACK_ROOT,
    SE,
    SOUTH,
    SW,
    WEST,
    aseprite_binary,
    tgstation_root,
)

ORIGINALS_ART = PACK_ROOT / "assets" / "originals" / "art"


def assert_out_write(path: Path, out_dir: Path) -> Path:
    resolved = path.resolve()
    root = out_dir.resolve()
    if not resolved.is_relative_to(root):
        raise RuntimeError(f"Refusing write outside {root}: {resolved}")
    rel = resolved.relative_to(root)
    top = rel.parts[0] if rel.parts else ""
    if top not in ("cache", "manifests"):
        raise RuntimeError(f"Refusing write to non-owned subdirectory {rel}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def png_to_data_uri(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def save_png(im: Image.Image, path: Path, out_dir: Path) -> str:
    safe = assert_out_write(path, out_dir)
    im.save(safe, format="PNG", optimize=True)
    return safe.relative_to(out_dir.resolve()).as_posix()


def sanitize_mask(mask: int) -> int:
    out = mask & (NORTH | SOUTH | EAST | WEST)
    for diag, a, b in ((NW, NORTH, WEST), (NE, NORTH, EAST), (SE, SOUTH, EAST), (SW, SOUTH, WEST)):
        if (mask & diag) and (mask & a) and (mask & b):
            out |= diag
    return out


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


class DmiSheet:
    """Read-only BYOND DMI PNG zTXt parser with full state/dir/frame/delay/rewind metadata."""

    def __init__(self, dmi_path: Path) -> None:
        self.path = dmi_path
        raw = dmi_path.read_bytes()
        pos, desc = 8, ""
        while pos < len(raw):
            length = int.from_bytes(raw[pos : pos + 4], "big")
            ctype = raw[pos + 4 : pos + 8].decode("latin1")
            cdata = raw[pos + 8 : pos + 8 + length]
            pos += 12 + length
            if ctype == "zTXt":
                nul = cdata.index(0)
                desc = zlib.decompress(cdata[nul + 2 :]).decode("utf-8", errors="replace")
                break
            if ctype == "tEXt":
                nul = cdata.index(0)
                desc = cdata[nul + 1 :].decode("utf-8", errors="replace")
                break

        self.image = Image.open(dmi_path).convert("RGBA")
        self.sheet_w, self.sheet_h = self.image.size
        self.icon_w, self.icon_h = 32, 32
        states: list[dict[str, Any]] = []
        cur: dict[str, Any] | None = None
        for line in desc.splitlines():
            s = line.strip()
            if s.startswith("width ="):
                self.icon_w = int(s.split("=", 1)[1].strip())
            elif s.startswith("height ="):
                self.icon_h = int(s.split("=", 1)[1].strip())
            elif s.startswith("state ="):
                if cur is not None:
                    states.append(cur)
                name = s.split("=", 1)[1].strip().strip('"')
                cur = {"name": name, "dirs": 1, "frames": 1, "delay": [], "rewind": False}
            elif cur is not None and "=" in s:
                k, v = [p.strip() for p in s.split("=", 1)]
                if k in ("dirs", "frames"):
                    cur[k] = int(v)
                elif k == "rewind":
                    cur["rewind"] = bool(int(v))
                elif k == "delay":
                    cur["delay"] = [max(100, round(float(x) * 100)) for x in v.split(",") if x.strip()]
        if cur is not None:
            states.append(cur)

        self.cols = max(1, self.sheet_w // self.icon_w)
        self.states: dict[str, dict[str, Any]] = {}
        offset = 0
        for st in states:
            st["offset"] = offset
            if st["name"] not in self.states:
                self.states[st["name"]] = st
            offset += int(st["dirs"]) * int(st["frames"])

    def state_meta(self, state_name: str) -> dict[str, Any]:
        if state_name not in self.states:
            raise KeyError(f"State {state_name!r} not found in {self.path}")
        return self.states[state_name]

    def crop(self, state_name: str, dir_idx: int = 0, frame_idx: int = 0) -> Image.Image:
        st = self.state_meta(state_name)
        dirs, frames = int(st["dirs"]), int(st["frames"])
        if dir_idx >= dirs:
            raise ValueError(f"{self.path}: state {state_name!r} has {dirs} dirs, requested {dir_idx}")
        idx = int(st["offset"]) + min(frame_idx, frames - 1) * dirs + dir_idx
        cx, cy = (idx % self.cols) * self.icon_w, (idx // self.cols) * self.icon_h
        return self.image.crop((cx, cy, cx + self.icon_w, cy + self.icon_h))


def tint_image(im: Image.Image, hex_color: str) -> Image.Image:
    h = hex_color.lstrip("#")
    tr, tg, tb = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size)
    px_in, px_out = src.load(), out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px_in[x, y]
            px_out[x, y] = ((r * tr) // 255, (g * tg) // 255, (b * tb) // 255, a)
    return out


class ExtractionContext:
    def __init__(self, out_dir: Path, tg_icons: Path, ase_bin: str) -> None:
        self.out_dir = out_dir.resolve()
        self.cache_dir = self.out_dir / "cache"
        self.manifests_dir = self.out_dir / "manifests"
        self.tg_icons = tg_icons.resolve()
        self.ase_bin = ase_bin
        self._dmi_cache: dict[str, DmiSheet] = {}

    def get_dmi(self, rel_icon_path: str) -> DmiSheet:
        if rel_icon_path not in self._dmi_cache:
            p = self.tg_icons / rel_icon_path
            if not p.exists():
                raise FileNotFoundError(f"Missing DMI file: {p}")
            self._dmi_cache[rel_icon_path] = DmiSheet(p)
        return self._dmi_cache[rel_icon_path]

    def blend_canister(
        self, paint_hex: str, stripe_state: str | None = None, stripe_hex: str | None = None,
    ) -> Image.Image:
        """Exact Lunatic `bake_dmi_blend` (`crates/xtask/src/sprites/compose.rs:378-418`) for canisters."""
        dmi = self.get_dmi("obj/pipes_n_cables/canisters.dmi")
        acc = Image.new("RGBA", (32, 32), (0, 0, 0, 0))

        def over(layer: Image.Image) -> None:
            nonlocal acc
            acc = Image.alpha_composite(acc, layer)

        def shade(layer: Image.Image, mode: str) -> None:
            dst_px, src_px = acc.load(), layer.load()
            for y in range(32):
                for x in range(32):
                    dr, dg, db, da = dst_px[x, y]
                    sr, sg, sb, sa = src_px[x, y]
                    if da == 0 or sa == 0:
                        continue
                    if mode == "add":
                        dst_px[x, y] = (min(255, dr + sr), min(255, dg + sg), min(255, db + sb), da)
                    elif mode == "multiply":
                        dst_px[x, y] = ((dr * sr) // 255, (dg * sg) // 255, (db * sb) // 255, da)

        over(tint_image(dmi.crop("base"), paint_hex))
        shade(dmi.crop("add_shader"), "add")
        shade(dmi.crop("multi_shader"), "multiply")
        over(tint_image(dmi.crop("outline"), paint_hex))
        if stripe_state and stripe_hex:
            over(tint_image(dmi.crop(stripe_state), stripe_hex))
        over(dmi.crop("lights"))
        over(dmi.crop("can-2"))
        return acc

    def export_aseprite_frames(self, ase_path: Path, tmp_sheet_path: Path) -> tuple[list[Image.Image], list[int]]:
        """Export frames and frame durations read-only from `ase_path`."""
        if not ase_path.exists():
            raise FileNotFoundError(f"Missing Aseprite source: {ase_path}")
        safe_sheet = assert_out_write(tmp_sheet_path, self.out_dir)
        safe_json = assert_out_write(tmp_sheet_path.with_suffix(".json"), self.out_dir)
        subprocess.run(
            [
                self.ase_bin, "-b", str(ase_path),
                "--sheet", str(safe_sheet), "--sheet-type", "horizontal",
                "--format", "json-array", "--data", str(safe_json),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        meta = json.loads(safe_json.read_text(encoding="utf-8"))
        safe_json.unlink(missing_ok=True)
        sheet_im = Image.open(safe_sheet).convert("RGBA")
        frames: list[Image.Image] = []
        durations: list[int] = []
        for f in meta["frames"]:
            fr = f["frame"]
            frames.append(sheet_im.crop((fr["x"], fr["y"], fr["x"] + fr["w"], fr["y"] + fr["h"])))
            durations.append(int(f["duration"]))
        return frames, durations

    def make_record(
        self,
        *,
        item_id: str,
        title: str,
        source: str,
        category: str,
        kind: str,
        cell_w: int,
        cell_h: int,
        offset_x: int,
        offset_y: int,
        durations_ms: list[int],
        rewind: bool,
        colorable: bool,
        default_tint: str,
        citation: str,
        atlas_im: Image.Image,
        strip_im: Image.Image | None = None,
    ) -> dict[str, Any]:
        sub = self.cache_dir / source
        suffix = "_47.png" if kind == "smooth_strip" else ".png"
        atlas_rel = save_png(atlas_im, sub / f"{item_id}{suffix}", self.out_dir)
        strip_rel: str | None = None
        strip_uri: str | None = None
        if strip_im is not None:
            strip_rel = save_png(strip_im, sub / f"{item_id}_strip.png", self.out_dir)
            strip_uri = png_to_data_uri(strip_im)

        return {
            "id": item_id, "title": title, "source": source, "category": category, "kind": kind,
            "cell_w": cell_w, "cell_h": cell_h, "offset_x": offset_x, "offset_y": offset_y,
            "frame_count": len(durations_ms), "durations_ms": durations_ms, "rewind": rewind,
            "colorable": colorable, "default_tint": default_tint, "citation": citation,
            "atlas_png_relpath": atlas_rel, "strip_png_relpath": strip_rel,
            "atlas_data_uri": png_to_data_uri(atlas_im), "strip_data_uri": strip_uri,
        }


def max_chroma(im: Image.Image) -> int:
    px = im.load()
    mc = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a > 0:
                mc = max(mc, max(r, g, b) - min(r, g, b))
    return mc


def extract_tfs_matter(ctx: ExtractionContext) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    jagged_ase = PACK_ROOT / "assets" / "originals" / "art" / "matter" / "solids" / "solid_debris_jagged_smooth.aseprite"
    smooth_specs = [
        ("liquid_puddle_smooth", "Liquid Puddle (Smooth)", ORIGINALS_ART / "matter/liquids/liquid_puddle_smooth.aseprite", True, "#5EB5C4", "94-elemental.ron:28"),
        ("liquid_puddle_smooth_shimmer", "Liquid Puddle Shimmer (Smooth)", ORIGINALS_ART / "matter/liquids/liquid_puddle_smooth_shimmer.aseprite", True, "#5EB5C4", "94-elemental.ron:29"),
        ("liquid_pool_smooth_ripple", "Liquid Pool Ripple (Smooth)", ORIGINALS_ART / "matter/liquids/liquid_pool_smooth_ripple.aseprite", True, "#3889C9", "94-elemental.ron:26"),
        ("solid_dusting_flour_smooth", "Fine Dusting / Frost / Regolith (Smooth)", ORIGINALS_ART / "matter/solids/solid_dusting_flour_smooth.aseprite", True, "#EAF6FA", "94-elemental.ron:31"),
        ("solid_debris_jagged_smooth", "Jagged Scree / Rubble (Smooth)", jagged_ase, True, "#9E5637", "94-elemental.ron:30"),
        ("solid_soil_smooth", "Planetary Soil / Regolith Bed (Smooth)", ORIGINALS_ART / "matter/solids/solid_soil_smooth.aseprite", True, "#9E5637", "94-elemental.ron:32"),
        ("solid_soil_tilled_smooth", "Tilled Soil Bed (Smooth)", ORIGINALS_ART / "matter/solids/solid_soil_tilled_smooth.aseprite", True, "#7D5838", "94-elemental.ron:33"),
        ("gas_mist_smooth_gentle", "Low Mist / Vapor (Smooth)", ORIGINALS_ART / "matter/gasses/gas_mist_smooth_gentle.aseprite", True, "#DFE8C0", "94-elemental.ron:20"),
        ("gas_cloud_smooth_gentle", "Dense Gas Cloud / Haze (Smooth)", ORIGINALS_ART / "matter/gasses/gas_cloud_smooth_gentle.aseprite", True, "#DFE8C0", "94-elemental.ron:17"),
        ("fire_gas_smooth_violent", "Violent Gas Fire (Smooth)", ORIGINALS_ART / "fx/fire/fire_gas_smooth_violent.aseprite", False, "#FFFFFF", "94-elemental.ron:35"),
    ]
    for sid, title, ase_path, colorable, tint, ron_ref in smooth_specs:
        raw_strip_path = ctx.cache_dir / "tfs_matter" / f"{sid}_strip.png"
        frames, durs = ctx.export_aseprite_frames(ase_path, raw_strip_path)
        strip_im = Image.open(raw_strip_path).convert("RGBA")
        atlas = Image.new("RGBA", (47 * 32, len(frames) * 32), (0, 0, 0, 0))
        for f_i, fim in enumerate(frames):
            for j_i, j_val in enumerate(JUNCTIONS):
                atlas.paste(slice_junction_tile(fim, j_val), (j_i * 32, f_i * 32))
        ase_rel = ase_path.relative_to(PACK_ROOT).as_posix()
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tfs_matter", category="matter", kind="smooth_strip",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=durs, rewind=False,
                colorable=colorable, default_tint=tint, citation=f"{ase_rel} (assets/sprites/{ron_ref})",
                atlas_im=atlas, strip_im=strip_im,
            )
        )

    single_specs = [
        ("solid_shards_large", "Crystalline / Ice Shards (Large)", "matter/solids/solid_shards_large.aseprite", True, "#D4EFF7", "94-elemental.ron:68"),
        ("solid_shards_small", "Crystalline / Ice Shards (Small)", "matter/solids/solid_shards_small.aseprite", True, "#D4EFF7", "94-elemental.ron:69"),
        ("solid_pile_large", "Loose Granular Pile (Large)", "matter/solids/solid_pile_large.aseprite", True, "#9E5637", "94-elemental.ron:65"),
        ("solid_pile_small", "Loose Granular Pile (Small)", "matter/solids/solid_pile_small.aseprite", True, "#8A837C", "94-elemental.ron:66"),
        ("solid_scattering", "Coarse Pebble / Slag Scattering", "matter/solids/solid_scattering.aseprite", True, "#B85C3C", "94-elemental.ron:67"),
        ("liquid_spill_1", "Liquid Spill Splash 1", "matter/liquids/liquid_spill_1.aseprite", True, "#5EB5C4", "94-elemental.ron:50"),
        ("fire_campfire_steady", "Steady Campfire / Brazier Flame", "fx/fire/fire_campfire_steady.aseprite", False, "#FFFFFF", "94-elemental.ron:74"),
    ]
    for sid, title, ase_rel, colorable, tint, ron_ref in single_specs:
        sheet_path = ctx.cache_dir / "tfs_matter" / f"{sid}.png"
        frames, durs = ctx.export_aseprite_frames(ORIGINALS_ART / ase_rel, sheet_path)
        sheet_im = Image.new("RGBA", (32 * len(frames), 32), (0, 0, 0, 0))
        for i, fim in enumerate(frames):
            sheet_im.paste(fim, (i * 32, 0))
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tfs_matter", category="matter", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=durs, rewind=False,
                colorable=colorable, default_tint=tint,
                citation=f"assets/originals/art/{ase_rel} (assets/sprites/{ron_ref})", atlas_im=sheet_im,
            )
        )
    return records


def extract_tfs_station(ctx: ExtractionContext) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []

    def add_single(sid: str, title: str, cat: str, im: Image.Image, cit: str) -> None:
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tfs_station", category=cat, kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=False, default_tint="#FFFFFF", citation=cit, atlas_im=im,
            )
        )

    floors = ctx.get_dmi("turf/floors.dmi")
    add_single("plating", "Station Hull Plating", "station", floors.crop("plating"), 'icons/turf/floors.dmi:"plating" (10-turf-fixtures-and-tools.ron:67)')
    add_single("floor", "Station Deck Tile", "station", floors.crop("floor"), 'icons/turf/floors.dmi:"floor" (10-turf-fixtures-and-tools.ron:66)')
    add_single("reinforced_floor", "Reinforced Engine Deck", "station", floors.crop("engine"), 'icons/turf/floors.dmi:"engine" (10-turf-fixtures-and-tools.ron:73)')

    tmp_open = ctx.cache_dir / "tfs_station" / "_open_floor_raw.png"
    open_frames, _ = ctx.export_aseprite_frames(ORIGINALS_ART / "turf/open_floor.aseprite", tmp_open)
    tmp_open.unlink(missing_ok=True)
    add_single("open_floor", "Maintenance Open Floor Grid", "station", open_frames[0], "assets/originals/art/turf/open_floor.aseprite (95-originals.ron:22)")

    add_single("rock_floor", "Asteroid Mined Rock Floor", "terrain", floors.crop("asteroid"), 'icons/turf/floors.dmi:"asteroid" (10-turf-fixtures-and-tools.ron:65; code/game/turfs/open/asteroid.dm:5-14)')
    add_single("ground", "Exterior Snow / Pale Ground", "ice", ctx.get_dmi("turf/snow.dmi").crop("snow"), 'icons/turf/snow.dmi:"snow" (10-turf-fixtures-and-tools.ron:63; code/game/turfs/open/snow.dm:4-7)')
    add_single("space", "Vacuum Space Backdrop", "station", ctx.get_dmi("turf/space.dmi").crop("space"), 'icons/turf/space.dmi:"space" (10-turf-fixtures-and-tools.ron:61)')
    add_single("wall", "Station Bulkhead Wall", "station", ctx.get_dmi("turf/walls/wall.dmi").crop("wall-0"), 'icons/turf/walls/wall.dmi:"wall-0" (10-turf-fixtures-and-tools.ron:68)')
    add_single("reinforced_wall", "Reinforced Bulkhead Wall", "station", ctx.get_dmi("turf/walls/reinforced_wall.dmi").crop("reinforced_wall-0"), 'icons/turf/walls/reinforced_wall.dmi:"reinforced_wall-0" (10-turf-fixtures-and-tools.ron:74)')

    airlock_pub = ctx.get_dmi("obj/doors/airlocks/station/public.dmi")
    airlock_ov = ctx.get_dmi("obj/doors/airlocks/station/overlays.dmi")
    add_single(
        "airlock_closed", "Station Airlock (Closed Solid)", "station",
        Image.alpha_composite(airlock_pub.crop("closed"), airlock_pub.crop("fill_closed")),
        'icons/obj/doors/airlocks/station/public.dmi:"closed"+"fill_closed" (10-turf-fixtures-and-tools.ron:111-114; code/game/machinery/doors/airlock.dm:592-597)',
    )
    add_single(
        "airlock_glass_closed", "Station Airlock (Closed Glazed)", "station",
        Image.alpha_composite(airlock_pub.crop("closed"), airlock_ov.crop("glass_closed")),
        'icons/obj/doors/airlocks/station/public.dmi:"closed"+overlays.dmi:"glass_closed" (10-turf-fixtures-and-tools.ron:127-130)',
    )

    add_single("canister_ammonia", "Gas Canister (Ammonia)", "station", ctx.blend_canister("#8D9646", "double_stripe", "#DFE8C0"), "icons/obj/pipes_n_cables/canisters.dmi DmiBlend (21-atmos-thermal-room-and-canisters.ron:229-293; content/substances/ammonia.luau:64-66)")
    add_single("canister_blue", "Gas Canister (Blue / Oxygen)", "station", ctx.blend_canister("#2786E5", "stripe", "#E8FEFE"), "icons/obj/pipes_n_cables/canisters.dmi DmiBlend (21-atmos-thermal-room-and-canisters.ron:229-293; code/modules/atmospherics/machinery/portable/canister.dm:262-263)")
    add_single("canister_orange", "Gas Canister (Orange / Plasma Hazard)", "station", ctx.blend_canister("#F62800", "hazard_stripes", "#1B1B1B"), "icons/obj/pipes_n_cables/canisters.dmi DmiBlend (21-atmos-thermal-room-and-canisters.ron:229-293; code/modules/atmospherics/machinery/portable/canister.dm:287-288)")

    crates = ctx.get_dmi("obj/storage/crates.dmi")
    add_single("crate_steel", "Steel Supply Crate", "station", crates.crop("crate").crop((0, 16, 32, 48)), 'icons/obj/storage/crates.dmi:"crate" window(0,16) (48-crates.ron:12; code/game/objects/structures/crates_lockers/crates.dm:5-6)')
    add_single("crate_hydro", "Hydroponics Supply Crate", "station", crates.crop("hydrocrate").crop((0, 16, 32, 48)), 'icons/obj/storage/crates.dmi:"hydrocrate" window(0,16) (48-crates.ron:25; code/game/objects/structures/crates_lockers/crates.dm:352-356)')

    wm = ctx.get_dmi("obj/machines/wallmounts.dmi")
    apc_im = wm.crop("apc0")
    for ov in ("apco3-2", "apco0-3", "apco1-3", "apco2-3"):
        apc_im = Image.alpha_composite(apc_im, wm.crop(ov))
    add_single("apc", "Area Power Controller (APC)", "station", apc_im, 'icons/obj/machines/wallmounts.dmi:"apc0"+status overlays (10-turf-fixtures-and-tools.ron:289-303)')

    decals = ctx.get_dmi("turf/decals.dmi")
    for d_idx, d_tag, d_label in ((0, "s", "South"), (1, "n", "North"), (2, "e", "East"), (3, "w", "West")):
        add_single(
            f"decal_hazard_{d_tag}", f"Hazard Warning Stripe ({d_label})", "decal",
            decals.crop("warningline", dir_idx=d_idx),
            f'icons/turf/decals.dmi:"warningline" dir={d_idx} (11-decals.ron:117; code/game/objects/effects/decals/turfdecal/markings.dm:1-59)',
        )

    smooth_station = [
        ("catwalk", "Lattice Catwalk (Smooth 47)", "station", "obj/smooth_structures/catwalk.dmi", "catwalk", None, "90-smooth-structures.ron:98-101; code/game/objects/structures/lattice.dm:116-125"),
        ("lattice", "Structural Space Lattice (Smooth 47)", "station", "obj/smooth_structures/lattice.dmi", "lattice", None, "90-smooth-structures.ron:91-95; code/game/objects/structures/lattice.dm:1-16"),
        ("glass_floor", "Reinforced Structural Glass Floor (Smooth 47)", "station", "turf/floors/glass.dmi", "glass", None, "90-smooth-structures.ron:130-134; code/game/turfs/open/floor/glass.dm:4-11"),
        ("rock", "Asteroid Mineral Rock Wall (32x32 Window Smooth 47)", "cliff", "turf/smoothrocks.dmi", "smoothrocks", (4, 4, 36, 36), "90-smooth-structures.ron:34-88; code/game/turfs/closed/minerals.dm:6-21"),
    ]
    for sid, title, cat, dmi_rel, prefix, win, cit in smooth_station:
        dmi = ctx.get_dmi(dmi_rel)
        atlas = Image.new("RGBA", (47 * 32, 32), (0, 0, 0, 0))
        for j_i, j_val in enumerate(JUNCTIONS):
            cell = dmi.crop(f"{prefix}-{j_val}")
            atlas.paste(cell.crop(win) if win is not None else cell, (j_i * 32, 0))
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tfs_station", category=cat, kind="smooth_strip",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=False, default_tint="#FFFFFF", citation=f"icons/{dmi_rel} ({cit})", atlas_im=atlas,
            )
        )
    return records


def extract_tg_outdoor(ctx: ExtractionContext) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    smooth_specs = [
        ("tg_grass_smooth", "Meadow Grass Turf (50x50 Smooth)", "terrain", "turf/floors/grass.dmi", "grass", False, "code/game/turfs/open/grass.dm:1-22"),
        ("tg_junglegrass_smooth", "Jungle Grass Turf (50x50 Smooth)", "terrain", "turf/floors/junglegrass.dmi", "junglegrass", False, "code/game/turfs/open/planet.dm:68-77"),
        ("tg_grass_damaged_smooth", "Trampled / Dry Grass Turf (50x50 Smooth)", "terrain", "turf/floors/grass_damaged.dmi", "grass_damaged", False, "code/game/turfs/open/grass.dm:20-26"),
        ("tg_icerock_cliff", "Icerock Cliff Ridge (40x40 Smooth)", "cliff", "turf/cliff/icerock_cliff.dmi", "icerock_wall", False, "code/game/turfs/open/cliff.dm:123-128"),
        ("tg_mountain_wall", "Snowy / Tintable Mountain Wall (40x40 Smooth)", "cliff", "turf/walls/mountain_wall.dmi", "mountain_wall", True, "code/game/turfs/closed/minerals.dm:669-674"),
        ("tg_red_rock_wall", "Martian Red Rock Cliff Wall (48x48 Smooth)", "cliff", "turf/walls/red_rock.dmi", "red_rock", False, "code/game/turfs/closed/minerals.dm:612-623"),
        ("tg_siderite_smooth", "Martian Siderite Silicate Floor (48x48 Smooth)", "terrain", "turf/floors/siderite.dmi", "siderite", False, "code/game/turfs/open/asteroid.dm:368-376"),
        ("tg_siderite_outline", "Siderite Shoreline Bank Outline (32x32 Inverse Smooth)", "ocean", "turf/floors/siderite_outline.dmi", "siderite_outline", False, "code/game/turfs/open/water.dm:193"),
        ("tg_shale_smooth", "Layered Shale Floor (48x48 Smooth)", "terrain", "turf/floors/shale.dmi", "shale", False, "code/game/turfs/open/asteroid.dm:389-396"),
        ("tg_shale_outline", "Shale Shoreline Bank Outline (32x32 Inverse Smooth)", "ocean", "turf/floors/shale_outline.dmi", "shale_outline", False, "code/game/turfs/open/water.dm:195"),
        ("tg_basalt_outline", "Basalt Shoreline Bank Outline (32x32 Inverse Smooth)", "ocean", "turf/floors/basalt_outline.dmi", "basalt_outline", True, "code/game/turfs/open/water.dm:191"),
        ("tg_water_lavaland", "Mineral Basin Water (32x32 Smooth)", "ocean", "turf/floors/water_lavaland.dmi", "water_lavaland", False, "code/game/turfs/open/water.dm:141-147"),
        ("tg_ice_turf", "Glacial Ice Sheet Turf (32x32 Smooth)", "ice", "turf/floors/ice_turf.dmi", "ice_turf", False, "code/game/turfs/open/ice.dm:75-78"),
        ("tg_snow_turf", "Drifted Snowpack Turf (32x32 Smooth)", "ice", "turf/floors/snow_turf.dmi", "snow_turf", False, "code/game/turfs/open/floor/plating/misc_plating.dm:74-78"),
        ("tg_hedge", "Trimmed Foliage Hedge (32x32 Smooth)", "flora", "obj/smooth_structures/hedge.dmi", "hedge", False, "code/modules/hydroponics/grown/hedges.dm:35-40"),
        ("tg_boulder_platform", "Stepping Boulder Platform (32x32 Smooth)", "prop", "obj/smooth_structures/boulder_platform.dmi", "boulder_platform", False, "code/game/objects/structures/lattice.dm:195-202"),
    ]
    for sid, title, cat, dmi_rel, prefix, colorable, dm_cit in smooth_specs:
        dmi = ctx.get_dmi(dmi_rel)
        cw, ch = dmi.icon_w, dmi.icon_h
        ox, oy = -(cw - 32) // 2, -(ch - 32) // 2
        atlas = Image.new("RGBA", (47 * cw, ch), (0, 0, 0, 0))
        for j_i, j_val in enumerate(JUNCTIONS):
            atlas.paste(dmi.crop(f"{prefix}-{j_val}"), (j_i * cw, 0))
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tg_outdoor", category=cat, kind="smooth_strip",
                cell_w=cw, cell_h=ch, offset_x=ox, offset_y=oy, durations_ms=[200], rewind=False,
                colorable=colorable, default_tint="#FFFFFF", citation=f"icons/{dmi_rel} ({dm_cit})", atlas_im=atlas,
            )
        )

    base_tiles = [
        ("tg_ironsand_1", "Martian Iron Sand 1", "terrain", "turf/floors.dmi", "ironsand1", False, "code/game/turfs/open/sand.dm:113-118"),
        ("tg_ironsand_5", "Martian Iron Sand 5", "terrain", "turf/floors.dmi", "ironsand5", False, "code/game/turfs/open/sand.dm:113-126"),
        ("tg_ironsand_9", "Martian Iron Sand 9", "terrain", "turf/floors.dmi", "ironsand9", False, "code/game/turfs/open/sand.dm:113-126"),
        ("tg_moon", "Lunar / Tintable Regolith Surface", "terrain", "turf/floors.dmi", "moon", True, "code/game/turfs/open/asteroid.dm:576-582"),
        ("tg_basalt", "Volcanic Basalt Regolith", "terrain", "turf/floors.dmi", "basalt", True, "code/game/turfs/open/asteroid.dm:177-183"),
        ("tg_sand", "Sandy Dirt Substrate", "terrain", "turf/floors.dmi", "sand", False, "code/game/turfs/open/sand.dm:90-98"),
        ("tg_beach_sand", "Golden Coastal Beach Sand", "terrain", "turf/sand.dmi", "sand", False, "code/game/turfs/open/sand.dm:50-56"),
        ("tg_dirt", "Packed Earth Dirt", "terrain", "turf/floors.dmi", "dirt", False, "code/game/turfs/open/planet.dm:1-8"),
        ("tg_greenerdirt", "Mossy Jungle Loam Dirt", "terrain", "turf/floors.dmi", "greenerdirt", False, "code/game/turfs/open/planet.dm:29-32"),
        ("tg_fairygrass", "Luminous Fairygrass Turf", "terrain", "turf/floors.dmi", "fairygrass", False, "code/game/turfs/open/floor/fancy_floor.dm:192-196"),
    ]
    for sid, title, cat, dmi_rel, st_name, colorable, dm_cit in base_tiles:
        dmi = ctx.get_dmi(dmi_rel)
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tg_outdoor", category=cat, kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=colorable, default_tint="#FFFFFF",
                citation=f'icons/{dmi_rel}:"{st_name}" ({dm_cit})', atlas_im=dmi.crop(st_name),
            )
        )

    beach = ctx.get_dmi("turf/beach.dmi")
    for sid, title, st_name, dm_cit in (
        ("tg_beach_water", "Shallow Coastal Water (4f Loop)", "water", "code/game/turfs/open/water.dm:106-115"),
        ("tg_beach_deepwater", "Deep Ocean Water (4f Loop)", "deepwater", "code/game/turfs/open/water.dm:122-131"),
        ("tg_tizira_water", "Tizira Lagoon Water (4f Loop)", "tizira_water", "code/game/turfs/open/water.dm:202-206"),
    ):
        seq = (0, 1, 2, 1)
        sheet = Image.new("RGBA", (32 * len(seq), 32), (0, 0, 0, 0))
        for i, f_idx in enumerate(seq):
            sheet.paste(beach.crop(st_name, 0, f_idx), (i * 32, 0))
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tg_outdoor", category="ocean", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[300, 300, 300, 300],
                rewind=False, colorable=False, default_tint="#FFFFFF",
                citation=f'icons/turf/beach.dmi:"{st_name}" ({dm_cit})', atlas_im=sheet,
            )
        )

    coast_specs = [
        ("tg_beach_coast_s", "Beach Swash Coastline (Water South)", "beach", 0, "code/game/turfs/open/sand.dm:63-73"),
        ("tg_beach_coast_n", "Beach Swash Coastline (Water North)", "beach", 1, "code/game/turfs/open/sand.dm:63-73"),
        ("tg_beach_coast_e", "Beach Swash Coastline (Water East)", "beach", 2, "code/game/turfs/open/sand.dm:63-73"),
        ("tg_beach_coast_w", "Beach Swash Coastline (Water West)", "beach", 3, "code/game/turfs/open/sand.dm:63-73"),
        ("tg_beach_coast_se", "Beach Swash Cape (Water SE)", "beach", 4, "code/game/turfs/open/sand.dm:63-73"),
        ("tg_beach_corner_s", "Beach Swash Inner Corner (Water SE Bay)", "beach-corner", 0, "code/game/turfs/open/sand.dm:82-89"),
    ]
    for sid, title, st_name, d_idx, dm_cit in coast_specs:
        sheet = Image.new("RGBA", (32 * 8, 32), (0, 0, 0, 0))
        for f_i in range(8):
            sheet.paste(beach.crop(st_name, d_idx, f_i), (f_i * 32, 0))
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tg_outdoor", category="ocean", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[300] * 8, rewind=False,
                colorable=False, default_tint="#FFFFFF",
                citation=f'icons/turf/beach.dmi:"{st_name}" dir={d_idx} ({dm_cit})', atlas_im=sheet,
            )
        )

    floors = ctx.get_dmi("turf/floors.dmi")
    for sid, title, st_name, dm_cit in (
        ("tg_riverwater_motion", "Flowing River Water (8f)", "riverwater_motion", "code/game/turfs/open/water.dm:1-7"),
        ("tg_deep_riverwater_motion", "Deep Flowing River Water (8f)", "deep_riverwater_motion", "code/game/turfs/open/water.dm:89-95"),
    ):
        st_meta = floors.state_meta(st_name)
        n_f = int(st_meta["frames"])
        durs = list(st_meta["delay"]) if st_meta["delay"] else [200] * n_f
        sheet = Image.new("RGBA", (32 * n_f, 32), (0, 0, 0, 0))
        for f_i in range(n_f):
            sheet.paste(floors.crop(st_name, 0, f_i), (f_i * 32, 0))
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tg_outdoor", category="ocean", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=durs, rewind=bool(st_meta["rewind"]),
                colorable=False, default_tint="#FFFFFF",
                citation=f'icons/turf/floors.dmi:"{st_name}" ({dm_cit})', atlas_im=sheet,
            )
        )

    aus_specs = [
        ("ywflowers_1", "Yellow Wildflowers 1", "flora.dm:870-871"),
        ("ywflowers_2", "Yellow Wildflowers 2", "flora.dm:873-874"),
        ("ppflowers_1", "Purple Wildflowers 1", "flora.dm:898-899"),
        ("ppflowers_2", "Purple Wildflowers 2", "flora.dm:901-902"),
        ("brflowers_1", "Crimson / Bracted Wildflowers 1", "flora.dm:884-885"),
        ("lavendergrass_1", "Lavender Grass Clump 1", "flora.dm:853-854"),
        ("lavendergrass_2", "Lavender Grass Clump 2", "flora.dm:856-857"),
        ("fernybush_1", "Broadleaf Fern Bush 1", "flora.dm:791-792"),
        ("fernybush_2", "Broadleaf Fern Bush 2", "flora.dm:794-795"),
        ("reedbush_1", "Shoreline Reed Clump 1", "flora.dm:684-685"),
        ("reedbush_2", "Shoreline Reed Clump 2", "flora.dm:687-688"),
        ("leafybush_1", "Leafy Shrub 1", "flora.dm:701-702"),
        ("sunnybush_1", "Golden Sunny Shrub 1", "flora.dm:805-806"),
        ("grassybush_1", "Grassy Tussock 1", "flora.dm:746-747"),
        ("sparsegrass_1", "Sparse Meadow Tuft 1", "flora.dm:763-764"),
        ("fullgrass_1", "Lush Meadow Sedge 1", "flora.dm:777-778"),
    ]
    aus = ctx.get_dmi("obj/fluff/flora/ausflora.dmi")
    for st_name, title, line_ref in aus_specs:
        records.append(
            ctx.make_record(
                item_id=st_name, title=title, source="tg_outdoor", category="flora", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=False, default_tint="#FFFFFF",
                citation=f'icons/obj/fluff/flora/ausflora.dmi:"{st_name}" (code/game/objects/structures/{line_ref})',
                atlas_im=aus.crop(st_name),
            )
        )

    jf_specs = [
        ("busha1", "Jungle Broadleaf Bush A1", "flora", "flora.dm:936-939"),
        ("bushb1", "Jungle Palm Frond Bush B1", "flora", "flora.dm:953-954"),
        ("bushc1", "Jungle Understory Bush C1", "flora", "flora.dm:967-968"),
        ("grassa1", "Jungle Tall Grass A1", "flora", "flora.dm:616-620"),
        ("grassb1", "Jungle Fern Grass B1", "flora", "flora.dm:639-640"),
        ("rock1", "Mossy Outcrop Scatter 1", "prop", "flora.dm:1152-1154"),
        ("rock2", "Mossy Outcrop Scatter 2", "prop", "flora.dm:1156-1157"),
        ("rock3", "Mossy Outcrop Scatter 3", "prop", "flora.dm:1159-1160"),
    ]
    jf = ctx.get_dmi("obj/fluff/flora/jungleflora.dmi")
    for st_name, title, cat, line_ref in jf_specs:
        records.append(
            ctx.make_record(
                item_id=st_name, title=title, source="tg_outdoor", category=cat, kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=False, default_tint="#FFFFFF",
                citation=f'icons/obj/fluff/flora/jungleflora.dmi:"{st_name}" (code/game/objects/structures/{line_ref})',
                atlas_im=jf.crop(st_name),
            )
        )

    oversized_specs = [
        ("pine_1", "Coniferous Pine Tree 1 (64x96)", "flora", "obj/fluff/flora/pinetrees.dmi", "pine_1", -16, -64, False, "code/game/objects/structures/flora.dm:451-456"),
        ("pine_2", "Coniferous Pine Tree 2 (64x96)", "flora", "obj/fluff/flora/pinetrees.dmi", "pine_2", -16, -64, False, "code/game/objects/structures/flora.dm:460-462"),
        ("tree1", "Canopy Jungle Tree 1 (96x96)", "flora", "obj/fluff/flora/jungletreesmall.dmi", "tree1", -32, -64, False, "code/game/objects/structures/flora.dm:418-423"),
        ("tree2", "Canopy Jungle Tree 2 (96x96)", "flora", "obj/fluff/flora/jungletreesmall.dmi", "tree2", -32, -64, False, "code/game/objects/structures/flora.dm:427-429"),
        ("tree_1", "Gnarled Dead Tree 1 (64x64)", "flora", "obj/fluff/flora/deadtrees.dmi", "tree_1", -16, -32, False, "code/game/objects/structures/flora.dm:360-366"),
        ("tree_4", "Snagged Dead Tree 4 (64x64)", "flora", "obj/fluff/flora/deadtrees.dmi", "tree_4", -16, -32, False, "code/game/objects/structures/flora.dm:374-376"),
        ("rocks1", "Large Boulder Cluster 1 (64x64)", "prop", "obj/fluff/flora/largejungleflora.dmi", "rocks1", -16, -16, False, "code/game/objects/structures/flora.dm:1173-1179"),
        ("bush1", "Large Jungle Thicket 1 (64x64)", "flora", "obj/fluff/flora/largejungleflora.dmi", "bush1", -16, -20, False, "code/game/objects/structures/flora.dm:981-986"),
        ("palm1", "Coastal Palm Tree 1 (32x64)", "flora", "obj/fluff/beach2.dmi", "palm1", 0, -32, False, "code/game/objects/structures/flora.dm:537-543"),
        ("siderite_growth1", "Siderite Stalagmite Spire 1 (32x64)", "prop", "obj/mining_zones/terrain.dmi", "siderite_growth1", 0, -32, False, "code/game/objects/structures/flora.dm:1110-1116"),
        ("siderite_growth2", "Siderite Stalagmite Spire 2 (32x64)", "prop", "obj/mining_zones/terrain.dmi", "siderite_growth2", 0, -32, False, "code/game/objects/structures/flora.dm:1110-1121"),
        ("ore_vent_ice", "Cryogenic Ice Fumarole Vent (32x64)", "prop", "obj/mining_zones/terrain.dmi", "ore_vent_ice", 0, -32, False, "code/game/objects/structures/lavaland/vent_mining/ore_vent.dm:708-711"),
        ("geyser", "Planetary Hydrothermal Geyser (32x64)", "prop", "obj/mining_zones/terrain.dmi", "geyser", 0, -32, True, "code/game/objects/structures/lavaland/geyser.dm:5-11"),
    ]
    for sid, title, cat, dmi_rel, st_name, ox, oy, colorable, dm_cit in oversized_specs:
        dmi = ctx.get_dmi(dmi_rel)
        records.append(
            ctx.make_record(
                item_id=sid, title=title, source="tg_outdoor", category=cat, kind="oversized",
                cell_w=dmi.icon_w, cell_h=dmi.icon_h, offset_x=ox, offset_y=oy, durations_ms=[200],
                rewind=False, colorable=colorable, default_tint="#FFFFFF",
                citation=f'icons/{dmi_rel}:"{st_name}" ({dm_cit})', atlas_im=dmi.crop(st_name),
            )
        )

    rock_specs = [
        ("basalt1", "Volcanic Basalt Outcrop 1", True, "flora.dm:1027-1032"),
        ("basalt2", "Volcanic Basalt Outcrop 2", True, "flora.dm:1045-1047"),
        ("lavarocks_siderite1", "Martian Siderite Scree 1", False, "flora.dm:1079-1081"),
        ("lavarocks_siderite2", "Martian Siderite Scree 2", False, "flora.dm:1085-1087"),
        ("lavarocks_shale1", "Shale Rock Pile 1", False, "flora.dm:1096-1098"),
    ]
    rocks_dmi = ctx.get_dmi("obj/fluff/flora/rocks.dmi")
    for st_name, title, colorable, line_ref in rock_specs:
        records.append(
            ctx.make_record(
                item_id=st_name, title=title, source="tg_outdoor", category="prop", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=colorable, default_tint="#FFFFFF",
                citation=f'icons/obj/fluff/flora/rocks.dmi:"{st_name}" (code/game/objects/structures/{line_ref})',
                atlas_im=rocks_dmi.crop(st_name),
            )
        )

    ash_specs = [
        ("glowgrowth1", "Bioluminescent Glowgrowth Colony", "ash_flora.dm:177-182"),
        ("chilly_pepper1", "Cryo Chilly Pepper Bush", "ash_flora.dm:222-227"),
        ("fireblossom1", "Incandescent Fireblossom", "ash_flora.dm:144-149"),
        ("seraka_mushroom1", "Seraka Fungal Cluster", "ash_flora.dm:124-129"),
        ("cactus1", "Xeric Fruiting Cactus", "ash_flora.dm:101-106"),
    ]
    ash_dmi = ctx.get_dmi("obj/mining_zones/ash_flora.dmi")
    for st_name, title, line_ref in ash_specs:
        records.append(
            ctx.make_record(
                item_id=st_name, title=title, source="tg_outdoor", category="flora", kind="single",
                cell_w=32, cell_h=32, offset_x=0, offset_y=0, durations_ms=[200], rewind=False,
                colorable=False, default_tint="#FFFFFF",
                citation=f'icons/obj/mining_zones/ash_flora.dmi:"{st_name}" (code/modules/mining/lavaland/{line_ref})',
                atlas_im=ash_dmi.crop(st_name),
            )
        )

    return records


def validate_records(records: list[dict[str, Any]], out_dir: Path) -> None:
    expected_keys = {
        "id", "title", "source", "category", "kind", "cell_w", "cell_h", "offset_x", "offset_y",
        "frame_count", "durations_ms", "rewind", "colorable", "default_tint", "citation",
        "atlas_png_relpath", "strip_png_relpath", "atlas_data_uri", "strip_data_uri",
    }
    valid_sources = {"terrestrial", "tfs_matter", "tfs_station", "tg_outdoor"}
    valid_cats = {"terrain", "ice", "cliff", "ocean", "decal", "matter", "flora", "prop", "station"}
    valid_kinds = {"smooth_strip", "single", "oversized"}
    seen: set[str] = set()

    for rec in records:
        if set(rec.keys()) != expected_keys:
            raise ValueError(f"{rec.get('id')}: schema key mismatch: {set(rec.keys()) ^ expected_keys}")
        rid = rec["id"]
        if rid in seen:
            raise ValueError(f"Duplicate manifest id: {rid}")
        seen.add(rid)
        if rec["source"] not in valid_sources:
            raise ValueError(f"{rid}: invalid source {rec['source']}")
        if rec["category"] not in valid_cats:
            raise ValueError(f"{rid}: invalid category {rec['category']}")
        if rec["kind"] not in valid_kinds:
            raise ValueError(f"{rid}: invalid kind {rec['kind']}")
        im = Image.open(out_dir / rec["atlas_png_relpath"]).convert("RGBA")
        cw, ch, fc = rec["cell_w"], rec["cell_h"], rec["frame_count"]
        exp_size = (47 * cw, fc * ch) if rec["kind"] == "smooth_strip" else (fc * cw, ch)
        if im.size != exp_size:
            raise ValueError(f"{rid}: expected atlas size {exp_size}, got {im.size}")
        if len(rec["durations_ms"]) != fc:
            raise ValueError(f"{rid}: durations_ms length != frame_count")
        if rec["colorable"] and max_chroma(im) > 0:
            raise ValueError(f"{rid}: marked colorable=True but max_chroma={max_chroma(im)} > 0")


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract TfS matter/station and tgstation outdoor reference assets.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="output root for cache/ and manifests/existing.json")
    args = parser.parse_args()

    out_dir = Path(args.out_dir).resolve()
    tg_icons = Path(tgstation_root()) / "icons"
    ctx = ExtractionContext(out_dir=out_dir, tg_icons=tg_icons, ase_bin=aseprite_binary())

    records: list[dict[str, Any]] = []
    records.extend(extract_tfs_matter(ctx))
    records.extend(extract_tfs_station(ctx))
    records.extend(extract_tg_outdoor(ctx))
    validate_records(records, out_dir)

    manifest_path = assert_out_write(ctx.manifests_dir / "existing.json", out_dir)
    manifest_path.write_text(json.dumps(records, indent=2), encoding="utf-8")

    by_src: dict[str, int] = {}
    for r in records:
        by_src[r["source"]] = by_src.get(r["source"], 0) + 1
    print(f"Wrote {manifest_path} ({len(records)} reference assets: {by_src})")


if __name__ == "__main__":
    main()
