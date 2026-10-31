#!/usr/bin/env python3
"""
Assemble the standalone Elemental Matter & Fire HTML gallery from the four domain manifests
(`gasses`, `liquids`, `solids`, `fire`) that `elemental_kit.py` wrote, plus tgstation turf
reference tiles. The authored page lives in `gallery/`; the bundle (that page plus the generated
`gallery_data.js`) is written to `<out-dir>/gallery/`. Open `<out-dir>/gallery/index.html`.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
from pathlib import Path
import shutil
import sys
import zlib

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from elemental_kit import DEFAULT_OUT_DIR, ELEMENTAL_DIR, JUNCTIONS, PACK_ROOT  # noqa: E402

AUTHORED_GALLERY_DIR = ELEMENTAL_DIR / "gallery"
AUTHORED_FILES = ("index.html", "gallery_styles.css", "gallery_app.js")


def find_tg_icons() -> Path | None:
    """The tgstation `icons/` dir: `LUNATIC_TG`, else a `tgstation` sibling of the pack
    (or of the primary checkout when the pack is a `.worktrees/<branch>` worktree)."""
    candidates: list[Path] = []
    if os.environ.get("LUNATIC_TG"):
        candidates.append(Path(os.environ["LUNATIC_TG"]))
    candidates.append(PACK_ROOT.parent / "tgstation")
    if PACK_ROOT.parent.name == ".worktrees":
        candidates.append(PACK_ROOT.parents[2] / "tgstation")
    for root in candidates:
        if (root / "icons").is_dir():
            return root / "icons"
    return None


def reading_thresholds() -> dict[str, dict[str, float]]:
    """THE THRESHOLD SEAM: the amounts at which the gallery switches sprite and shell.

    Liquids are in millilitres, gases in moles. The gallery reads these from
    `DATA.thresholds` only; replace this function's body to source them elsewhere.
    """
    return {
        "liquid": {
            "splatter_min": 10,
            "splash_min": 65,
            "spill_min": 140,
            "puddle_min": 260,
            "pool_min": 2200,
            "zerog_mixed_min": 350,
            "zerog_large_min": 1400,
        },
        "gas": {"mist_min": 0.35, "smoke_min": 2.5, "cloud_min": 8.0},
    }


def extract_dmi_state_tile(dmi_path: Path, state_name: str, frame_idx: int = 0) -> Image.Image:
    """Parse BYOND DMI PNG zTXt header and crop frame `frame_idx` of `state_name`."""
    raw = dmi_path.read_bytes()
    pos = 8
    desc = ""
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

    im = Image.open(dmi_path).convert("RGBA")
    sheet_w, _ = im.size
    icon_w, icon_h = 32, 32
    cols = max(1, sheet_w // icon_w)

    states: list[dict[str, object]] = []
    cur: dict[str, object] | None = None
    for line in desc.splitlines():
        s = line.strip()
        if s.startswith("width ="):
            icon_w = int(s.split("=")[1].strip())
            cols = max(1, sheet_w // icon_w)
        elif s.startswith("height ="):
            icon_h = int(s.split("=")[1].strip())
        elif s.startswith("state ="):
            if cur is not None:
                states.append(cur)
            name = s.split("=", 1)[1].strip().strip('"')
            cur = {"name": name, "dirs": 1, "frames": 1}
        elif cur is not None and "=" in s:
            k, v = [p.strip() for p in s.split("=", 1)]
            if k in ("dirs", "frames"):
                cur[k] = int(v)
    if cur is not None:
        states.append(cur)

    cell_offset = 0
    for st in states:
        dirs = int(st["dirs"])
        frames = int(st["frames"])
        if st["name"] == state_name:
            idx = cell_offset + min(frame_idx, frames - 1) * dirs
            cx = (idx % cols) * icon_w
            cy = (idx // cols) * icon_h
            return im.crop((cx, cy, cx + icon_w, cy + icon_h))
        cell_offset += dirs * frames
    raise KeyError(f"State {state_name!r} not found in {dmi_path}")


def img_to_data_uri(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def load_turf_backgrounds() -> dict[str, dict[str, str]]:
    tg_icons = find_tg_icons()
    if tg_icons is None:
        print("warning: no tgstation checkout (set LUNATIC_TG); the gallery has no turf backgrounds")
        return {}
    specs = [
        ("plating", "Station Plating", tg_icons / "turf/floors.dmi", "plating"),
        ("floor", "Station Deck Tile", tg_icons / "turf/floors.dmi", "floor"),
        ("reinforced_floor", "Engine Reinforced Deck", tg_icons / "turf/floors.dmi", "engine"),
        ("rock_floor", "Mined Tunnel Asteroid Rock", tg_icons / "turf/floors.dmi", "asteroid"),
        ("ground_snow", "Exterior Pale Ground", tg_icons / "turf/snow.dmi", "snow"),
        ("wall", "Station Bulkhead Wall", tg_icons / "turf/walls/wall.dmi", "wall-0"),
    ]
    out: dict[str, dict[str, str]] = {}
    for key, label, dmi_path, state in specs:
        if dmi_path.exists():
            tile = extract_dmi_state_tile(dmi_path, state, 0)
            out[key] = {
                "id": key,
                "label": label,
                "source": f"{dmi_path.relative_to(tg_icons)}:{state}",
                "data_uri": img_to_data_uri(tile),
            }
    return out


SOLID_SUBSTANCES_REFERENCE = [
    {"id": "flour_starch", "name": "Spilled Flour / Starch", "hex": "#F5F0E1", "morphology": "dusting", "sprite": "solid_dusting_flour_smooth", "notes": "Fine cohesive organic powder; forms explosive dust suspensions when aerosolized."},
    {"id": "ash_soot", "name": "Combustion Ash / Soot", "hex": "#3B3B40", "morphology": "dusting", "sprite": "solid_dusting_flour_smooth", "notes": "Low-albedo carbon/ash residue left after solid or pool oxidation."},
    {"id": "salt", "name": "Sodium Chloride (Salt)", "hex": "#FFFFFF", "morphology": "discrete", "sprite": "solid_sprinkles", "notes": "Cubic ionic crystal grains; high specular facet contrast."},
    {"id": "sugar", "name": "Sucrose Crystals", "hex": "#FFF9EB", "morphology": "discrete", "sprite": "solid_sprinkles", "notes": "Translucent crystalline granules; caramelizes/chars under heat."},
    {"id": "gunpowder", "name": "Black Powder / Propellant", "hex": "#38363A", "morphology": "discrete", "sprite": "solid_pile_small", "notes": "Graphite-glazed KNO3/charcoal/sulfur corned grains; rapid deflagration."},
    {"id": "sulfur", "name": "Orthorhombic Sulfur", "hex": "#E3CF3B", "morphology": "dusting", "sprite": "solid_pile_large", "notes": "Bright yellow brittle powder/pellets; oxidizes with blue SO2 flame."},
    {"id": "carbon", "name": "Carbon / Coal / Charcoal", "hex": "#2E2D30", "morphology": "discrete", "sprite": "solid_pile_large", "notes": "Porous black solid fuel; sustains incandescent ember bed + campfire."},
    {"id": "iron_ore", "name": "Spalled Iron / Tunnel Rubble", "hex": "#8A837C", "morphology": "debris", "sprite": "solid_debris_jagged_smooth", "notes": "Angular fractured rock and metallic scree layering tunnel floors."},
    {"id": "rust_oxide", "name": "Ferric Oxide (Rust)", "hex": "#A84824", "morphology": "dusting", "sprite": "solid_dusting_flour_single", "notes": "Red-ochre oxide powder flaking onto maintenance plating."},
    {"id": "silicon_glass", "name": "Shattered Silicate / Quartz", "hex": "#B8DCED", "morphology": "shards", "sprite": "solid_shards_large", "notes": "Conchoidal/cleavage sharp splinters with bright specular ridges."},
    {"id": "water_ice", "name": "Water Ice Splinters", "hex": "#CBEBFF", "morphology": "shards", "sprite": "solid_shards_small", "notes": "Vitreous cryogenic shards; melts to liquid water above 273.15 K."},
    {"id": "solid_plasma", "name": "Crystallized Plasma", "hex": "#D452FF", "morphology": "shards", "sprite": "solid_shards_large", "notes": "High-energy purple crystal shards; sublimates into violently flammable gas."},
    {"id": "copper_nuggets", "name": "Copper Granules / Slag", "hex": "#C86D3B", "morphology": "discrete", "sprite": "solid_scattering", "notes": "Coarse metallic pellets; imparts emerald-green emission to flames."},
    {"id": "farm_loam_dry", "name": "Hydroponic Loam (Dry)", "hex": "#7D5838", "morphology": "soil", "sprite": "solid_soil_tilled_smooth", "notes": "Aerated clodded organic topsoil; lightens when dry."},
    {"id": "farm_loam_wet", "name": "Hydroponic Loam (Irrigated)", "hex": "#4A321F", "morphology": "soil", "sprite": "solid_soil_tilled_smooth", "notes": "Water-saturated dark humus bed; pore water reduces diffuse reflectance."},
    {"id": "regolith_mars", "name": "Iron-Rich Regolith Bed", "hex": "#9E5637", "morphology": "soil", "sprite": "solid_soil_smooth", "notes": "Uncultivated oxidized planetary soil covering."},
]


def main() -> None:
    parser = argparse.ArgumentParser(description="Assemble the elemental gallery bundle")
    parser.add_argument(
        "--out-dir",
        default=str(DEFAULT_OUT_DIR),
        help="the kit's output dir: reads manifests/, writes gallery/ (default: <pack>/target/art/elemental)",
    )
    args = parser.parse_args()
    out_dir = Path(args.out_dir).resolve()
    manifests_dir = out_dir / "manifests"
    bundle_dir = out_dir / "gallery"

    domains = ["gasses", "liquids", "solids", "fire"]
    all_sprites: list[dict[str, object]] = []
    counts_by_domain: dict[str, int] = {}

    for dom in domains:
        mp = manifests_dir / f"{dom}.json"
        if not mp.exists():
            raise FileNotFoundError(f"Missing manifest: {mp} (run elemental_kit.py --domain {dom})")
        items = json.loads(mp.read_text(encoding="utf-8"))
        counts_by_domain[dom] = len(items)
        all_sprites.extend(items)

    turfs = load_turf_backgrounds()

    payload = {
        "generated_by": "tools/art/elemental/build_gallery.py",
        "counts_by_domain": counts_by_domain,
        "total_sprites": len(all_sprites),
        "junctions": JUNCTIONS,
        "thresholds": reading_thresholds(),
        "turfs": turfs,
        "solid_substances": SOLID_SUBSTANCES_REFERENCE,
        "sprites": all_sprites,
    }

    bundle_dir.mkdir(parents=True, exist_ok=True)
    data_js = "window.ELEMENTAL_GALLERY_DATA = " + json.dumps(payload, separators=(",", ":")) + ";\n"
    (bundle_dir / "gallery_data.js").write_text(data_js, encoding="utf-8")
    for fname in AUTHORED_FILES:
        shutil.copy2(AUTHORED_GALLERY_DIR / fname, bundle_dir / fname)

    print(
        f"Built gallery_data.js with {len(all_sprites)} sprites {counts_by_domain} "
        f"and {len(turfs)} turf backgrounds."
    )
    print(f"Gallery: {bundle_dir / 'index.html'}")


if __name__ == "__main__":
    main()
