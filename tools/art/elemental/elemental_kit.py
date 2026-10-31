#!/usr/bin/env python3
"""
Shared Aseprite MCP builder, 47-junction BitmaskSlice cutter, and Tales from Space
art-gate / colorability auditor for Elemental Matter & Fire assets.

Drives the `aseprite_mcp` server (a separate checkout, see README.md) against the
pack's `assets/originals/art/**.aseprite` sources. An existing source is exported
and audited as it stands; `--rebuild-sources` redraws it from the spec.

Spec format (`SPRITES = [...]` in a domain python module):
Each entry is a dict:
  {
      "id": "gas_mist_smooth_gentle",
      "element": "gas" | "liquid" | "solid" | "fire",
      "kind": "single" | "smooth_strip",   # single = 32x32, smooth_strip = 160x32 (5x 32x32 blocks)
      "colorable": True | False,           # True enforces neutral greyscale (chroma == 0)
      "require_top_light": True | False,   # True enforces luma_top >= luma_bottom - 1.0
      "ase_relpath": "assets/originals/art/matter/gasses/gas_mist_smooth_gentle.aseprite",
      "tag": "idle",
      "description": "Concise technical note on physical appearance & layer usage.",
      "frames": [
          {
              "duration_ms": 200,          # must be multiple of 100 >= 100
              "layers": [
                  {
                      "name": "base",
                      "opacity": 255,      # 1..255
                      "blend_mode": "normal",
                      "rows": [...],       # height=32 strings of length 32 (single) or 160 (smooth_strip)
                      "legend": {"A": "#FFFFFF", ...},
                  },
              ],
          },
      ],
  }
"""
from __future__ import annotations

import argparse
import asyncio
import base64
from collections import Counter
from contextlib import asynccontextmanager
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
from typing import Any

from PIL import Image, ImageDraw

# tools/art/elemental/elemental_kit.py -> the pack root is three levels up.
PACK_ROOT = Path(__file__).resolve().parents[3]
ELEMENTAL_DIR = Path(__file__).resolve().parent
GPL_PATH = PACK_ROOT / "docs/art-reference/palettes/tales-from-space.gpl"
DEFAULT_OUT_DIR = PACK_ROOT / "target/art/elemental"


def aseprite_binary() -> str:
    """`ASEPRITE_PATH`, else `aseprite` on PATH."""
    found = os.environ.get("ASEPRITE_PATH") or shutil.which("aseprite")
    if not found:
        raise RuntimeError("aseprite not found: set ASEPRITE_PATH or put aseprite on PATH")
    return found


def mcp_python_and_repo() -> tuple[str, str | None]:
    """The interpreter that runs `aseprite_mcp`, and the checkout to put on its PYTHONPATH.

    `ASEPRITE_MCP_REPO` names the checkout; `ASEPRITE_MCP_PYTHON` names the interpreter
    and defaults to the checkout's `.venv/bin/python`, then to this interpreter.
    """
    repo = os.environ.get("ASEPRITE_MCP_REPO")
    python = os.environ.get("ASEPRITE_MCP_PYTHON")
    if not python and repo:
        venv = Path(repo) / ".venv" / "bin" / "python"
        python = str(venv) if venv.exists() else None
    return python or sys.executable, repo

# The 47 reachable junction values (the engine's xtask roster `JUNCTIONS`).
# Diagonal bits: NE=16, SE=32, SW=64, NW=128.
NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
NE, SE, SW, NW = 16, 32, 64, 128
JUNCTIONS: list[int] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    21, 23, 29, 31, 38, 39, 46, 47, 55, 63,
    74, 75, 78, 79, 95, 110, 111, 127,
    137, 139, 141, 143, 157, 159, 175, 191,
    203, 207, 223, 239, 255,
]


def load_gpl_palette(gpl_path: Path = GPL_PATH) -> dict[str, str]:
    """Return {HEX_UPPER: swatch_name} from tales-from-space.gpl."""
    allowed: dict[str, str] = {}
    for raw_line in gpl_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if (
            not line
            or line.startswith("GIMP Palette")
            or line.startswith("Name:")
            or line.startswith("Columns:")
            or line.startswith("#")
        ):
            continue
        parts = line.split(None, 3)
        if len(parts) >= 3:
            r, g, b = int(parts[0]), int(parts[1]), int(parts[2])
            label = parts[3] if len(parts) > 3 else ""
            allowed[f"#{r:02X}{g:02X}{b:02X}"] = label
    return allowed


def sanitize_mask(mask: int) -> int:
    """Drop every diagonal bit whose two flanking cardinals are not both set."""
    out = mask & (NORTH | SOUTH | EAST | WEST)
    for diag, a, b in ((NW, NORTH, WEST), (NE, NORTH, EAST), (SE, SOUTH, EAST), (SW, SOUTH, WEST)):
        if (mask & diag) and (mask & a) and (mask & b):
            out |= diag
    return out


def compute_junction(pred, x: int, y: int, grid_w: int, grid_h: int) -> int:
    """Junction value of tile (x, y) where `pred(nx, ny)` says a tile is part of the shape."""

    def ok(nx: int, ny: int) -> bool:
        return 0 <= nx < grid_w and 0 <= ny < grid_h and pred(nx, ny)

    mask = 0
    for bit, dx, dy in (
        (NORTH, 0, -1), (SOUTH, 0, 1), (EAST, 1, 0), (WEST, -1, 0),
        (NE, 1, -1), (SE, 1, 1), (SW, -1, 1), (NW, -1, -1),
    ):
        if ok(x + dx, y + dy):
            mask |= bit
    return sanitize_mask(mask)


def slice_junction_tile(strip_frame: Image.Image, junction: int) -> Image.Image:
    """
    Slice one 32x32 junction tile from a 160x32 5-block strip frame using tgstation's
    `bitmask/diagonal_32x32.toml` rule:
      block 0 = convex (!v and !h)
      block 1 = vertical (v and !h)
      block 2 = horizontal (!v and h)
      block 3 = concave (v and h and !d)
      block 4 = flat (v and h and d)
    """
    if strip_frame.size != (160, 32):
        raise ValueError(f"Expected 160x32 strip frame, got {strip_frame.size}")
    junction = sanitize_mask(junction)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    quads = [
        (0, 0, bool(junction & NORTH), bool(junction & WEST), bool(junction & NW)),
        (16, 0, bool(junction & NORTH), bool(junction & EAST), bool(junction & NE)),
        (0, 16, bool(junction & SOUTH), bool(junction & WEST), bool(junction & SW)),
        (16, 16, bool(junction & SOUTH), bool(junction & EAST), bool(junction & SE)),
    ]
    for qx, qy, v, h, d in quads:
        if not v and not h:
            block = 0
        elif v and not h:
            block = 1
        elif not v and h:
            block = 2
        elif v and h and not d:
            block = 3
        else:
            block = 4
        quad = strip_frame.crop((block * 32 + qx, qy, block * 32 + qx + 16, qy + 16))
        out.paste(quad, (qx, qy))
    return out


def analyze_rgba_image(im: Image.Image) -> dict[str, Any]:
    """Compute pixel, alpha, chroma, bare-mask ratio, and Rec.709 luma telemetry."""
    im = im.convert("RGBA")
    w, h = im.size
    active: list[tuple[int, int, int, int, int, int, float]] = []
    rgb_counts: Counter[tuple[int, int, int]] = Counter()
    opaque_255 = 0
    translucent = 0

    for y in range(h):
        for x in range(w):
            r, g, b, a = im.getpixel((x, y))
            if a > 0:
                luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                active.append((x, y, r, g, b, a, luma))
                rgb_counts[(r, g, b)] += 1
                if a == 255:
                    opaque_255 += 1
                else:
                    translucent += 1

    if not active:
        return {
            "active_px": 0,
            "opaque_255_px": 0,
            "translucent_px": 0,
            "bbox": [0, 0, 0, 0],
            "alpha": {"min": 0, "avg": 0.0, "max": 0},
            "luma": {"min": 0.0, "avg": 0.0, "max": 0.0, "top": 0.0, "bottom": 0.0},
            "max_chroma": 0,
            "unique_rgb_count": 0,
            "dominant_rgb_share": 0.0,
            "passes_bare_mask_gate": True,
        }

    xs = [p[0] for p in active]
    ys = [p[1] for p in active]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    span_y = max(1, max_y - min_y + 1)
    top_cut = min_y + span_y / 3.0
    bot_cut = max_y - span_y / 3.0

    alphas = [p[5] for p in active]
    lumas = [p[6] for p in active]
    top_l = [p[6] for p in active if p[1] <= top_cut]
    bot_l = [p[6] for p in active if p[1] >= bot_cut]
    chromas = [max(p[2], p[3], p[4]) - min(p[2], p[3], p[4]) for p in active]

    most_common_count = rgb_counts.most_common(1)[0][1]
    dom_share = most_common_count / len(active)
    # test-bake-art.mjs fails if active_px >= 40 and achromatic single-RGB share >= 0.85
    passes_bare_mask = not (len(active) >= 40 and dom_share >= 0.85)

    return {
        "active_px": len(active),
        "opaque_255_px": opaque_255,
        "translucent_px": translucent,
        "bbox": [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1],
        "alpha": {
            "min": min(alphas),
            "avg": round(sum(alphas) / len(alphas), 1),
            "max": max(alphas),
        },
        "luma": {
            "min": round(min(lumas), 1),
            "avg": round(sum(lumas) / len(lumas), 1),
            "max": round(max(lumas), 1),
            "top": round(sum(top_l) / max(1, len(top_l)), 1),
            "bottom": round(sum(bot_l) / max(1, len(bot_l)), 1),
        },
        "max_chroma": max(chromas),
        "unique_rgb_count": len(rgb_counts),
        "dominant_rgb_share": round(dom_share, 3),
        "passes_bare_mask_gate": passes_bare_mask,
    }


def tint_multiply(im: Image.Image, hex_color: str) -> Image.Image:
    """Apply lunatic's sRGB byte multiply (COLOR.md) to an RGBA image."""
    hx = hex_color.lstrip("#")
    tr, tg, tb = int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size)
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = src.getpixel((x, y))
            if a == 0:
                out.putpixel((x, y), (0, 0, 0, 0))
            else:
                out.putpixel(
                    (x, y),
                    ((r * tr + 127) // 255, (g * tg + 127) // 255, (b * tb + 127) // 255, a),
                )
    return out


def png_to_data_uri(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/png;base64,{b64}"


@asynccontextmanager
async def open_mcp():
    try:
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
    except ImportError as err:
        raise RuntimeError(
            "the `mcp` client package is missing: install it in the interpreter running this "
            "kit (README.md, Setup)"
        ) from err
    python_exe, repo = mcp_python_and_repo()
    env = {**os.environ, "ASEPRITE_PATH": aseprite_binary()}
    if repo:
        env["PYTHONPATH"] = os.pathsep.join(filter(None, [repo, os.environ.get("PYTHONPATH")]))
    params = StdioServerParameters(command=python_exe, args=["-m", "aseprite_mcp"], env=env)
    with open(os.devnull, "w") as devnull:
        async with stdio_client(params, errlog=devnull) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                yield session


async def mcp_call(session: Any, tool: str, args: dict[str, Any]) -> str:
    res = await session.call_tool(tool, args)
    texts = [
        c.text
        for c in res.content
        if getattr(c, "type", None) == "text" or hasattr(c, "text")
    ]
    out = "\n".join(texts).strip()
    if getattr(res, "isError", False) or out.startswith("Command failed") or out.startswith("Failed"):
        raise RuntimeError(f"MCP {tool} failed: {out}")
    return out


def validate_spec(
    spec: dict[str, Any], allowed_gpl: dict[str, str]
) -> tuple[list[str], dict[str, tuple[int, str]], list[str]]:
    """Check a spec's geometry, durations and palette; return (layer order, layer props, hexes)."""
    sid = spec["id"]
    element = spec["element"]
    kind = spec["kind"]
    colorable = bool(spec.get("colorable", element != "fire"))
    expected_w = 32 if kind == "single" else 160
    expected_h = 32
    frames_spec = spec["frames"]
    if not frames_spec:
        raise ValueError(f"{sid}: frames cannot be empty")

    # Gather canonical layer list in bottom-to-top order across frames
    layer_order: list[str] = []
    layer_props: dict[str, tuple[int, str]] = {}
    used_hexes: list[str] = []

    for f_idx, fspec in enumerate(frames_spec, start=1):
        dur = int(fspec.get("duration_ms", 200))
        if dur < 100 or dur % 100 != 0:
            raise ValueError(f"{sid} frame {f_idx}: duration_ms={dur} must be a multiple of 100 >= 100")
        for lspec in fspec["layers"]:
            lname = lspec["name"]
            opacity = int(lspec.get("opacity", 255))
            bmode = str(lspec.get("blend_mode", "normal"))
            if lname not in layer_order:
                layer_order.append(lname)
                layer_props[lname] = (opacity, bmode)
            rows = lspec["rows"]
            legend = lspec["legend"]
            if len(rows) != expected_h:
                raise ValueError(f"{sid} f{f_idx}/{lname}: expected {expected_h} rows, got {len(rows)}")
            for r_i, row in enumerate(rows):
                if len(row) != expected_w:
                    raise ValueError(
                        f"{sid} f{f_idx}/{lname} row {r_i}: expected width {expected_w}, got {len(row)}"
                    )
                for ch in row:
                    if ch != "." and ch not in legend:
                        raise ValueError(f"{sid} f{f_idx}/{lname} row {r_i}: char {ch!r} not in legend")
            for ch, hx in legend.items():
                hx_u = hx.upper()
                if hx_u not in allowed_gpl:
                    raise ValueError(
                        f"{sid} f{f_idx}/{lname}: hex {hx_u} is NOT in tales-from-space.gpl!"
                    )
                if colorable:
                    r, g, b = int(hx_u[1:3], 16), int(hx_u[3:5], 16), int(hx_u[5:7], 16)
                    if not (r == g == b):
                        raise ValueError(
                            f"{sid} f{f_idx}/{lname}: colorable=True requires neutral greyscale, got {hx_u}"
                        )
                if hx_u not in used_hexes:
                    used_hexes.append(hx_u)
    return layer_order, layer_props, used_hexes


async def draw_source(
    session: Any,
    spec: dict[str, Any],
    ase_path: Path,
    expected_w: int,
    expected_h: int,
    used_hexes: list[str],
    layer_order: list[str],
    layer_props: dict[str, tuple[int, str]],
) -> None:
    """Create `ase_path` from the spec: canvas, palette, layers, frames, rows, tag."""
    frames_spec = spec["frames"]
    await mcp_call(
        session,
        "create_canvas",
        {"width": expected_w, "height": expected_h, "filename": str(ase_path)},
    )
    await mcp_call(
        session,
        "set_palette",
        {"filename": str(ase_path), "colors": used_hexes},
    )

    for idx, lname in enumerate(layer_order):
        if idx == 0:
            await mcp_call(
                session,
                "rename_layer",
                {"filename": str(ase_path), "layer_name": "Layer 1", "new_name": lname},
            )
        else:
            await mcp_call(
                session,
                "add_layer",
                {"filename": str(ase_path), "layer_name": lname},
            )
        opacity, bmode = layer_props[lname]
        if opacity != 255:
            await mcp_call(
                session,
                "set_layer_opacity",
                {"filename": str(ase_path), "layer_name": lname, "opacity": opacity},
            )
        if bmode != "normal":
            await mcp_call(
                session,
                "set_layer_blend_mode",
                {"filename": str(ase_path), "layer_name": lname, "blend_mode": bmode},
            )

    for f_idx in range(2, len(frames_spec) + 1):
        await mcp_call(session, "add_frame", {"filename": str(ase_path)})

    for f_idx, fspec in enumerate(frames_spec, start=1):
        dur = int(fspec.get("duration_ms", 200))
        await mcp_call(
            session,
            "set_frame_duration",
            {"filename": str(ase_path), "frame_index": f_idx, "duration_ms": dur},
        )
        for lspec in fspec["layers"]:
            await mcp_call(
                session,
                "draw_rows",
                {
                    "filename": str(ase_path),
                    "layer_name": lspec["name"],
                    "frame_index": f_idx,
                    "x": 0,
                    "y": 0,
                    "rows": lspec["rows"],
                    "legend": lspec["legend"],
                },
            )

    await mcp_call(
        session,
        "set_tag",
        {
            "filename": str(ase_path),
            "name": spec.get("tag", "idle"),
            "from_frame": 1,
            "to_frame": len(frames_spec),
            "direction": "forward",
        },
    )


async def build_and_validate_sprite(
    session: Any,
    spec: dict[str, Any],
    pack_root: Path,
    gallery_out_dir: Path,
    allowed_gpl: dict[str, str],
    rebuild_source: bool = False,
) -> dict[str, Any]:
    sid = spec["id"]
    element = spec["element"]
    kind = spec["kind"]
    colorable = bool(spec.get("colorable", element != "fire"))
    require_top_light = bool(spec.get("require_top_light", False))
    expected_w = 32 if kind == "single" else 160
    expected_h = 32

    frames_spec = spec["frames"]
    layer_order, layer_props, used_hexes = validate_spec(spec, allowed_gpl)

    ase_path = (pack_root / spec["ase_relpath"]).resolve()
    if not ase_path.is_relative_to(pack_root / "assets/originals"):
        raise ValueError(f"{sid}: ase_relpath must stay under assets/originals/")
    durations_ms = [int(f.get("duration_ms", 200)) for f in frames_spec]
    if rebuild_source or not ase_path.exists():
        ase_path.parent.mkdir(parents=True, exist_ok=True)
        if ase_path.exists():
            ase_path.unlink()
        await draw_source(
            session, spec, ase_path, expected_w, expected_h, used_hexes, layer_order, layer_props
        )

    # Export frames via Aseprite MCP and run lint_sprite + get_color_stats
    png_dir = gallery_out_dir / "png" / element
    views_dir = gallery_out_dir / "views" / element
    png_dir.mkdir(parents=True, exist_ok=True)
    views_dir.mkdir(parents=True, exist_ok=True)

    lint_f1 = json.loads(await mcp_call(session, "lint_sprite", {"filename": str(ase_path), "frame_index": 1}))
    await mcp_call(
        session,
        "view_sprite",
        {
            "filename": str(ase_path),
            "frames": "1",
            "scale": 6,
            "grid": True,
            "rulers": True,
            "bg_mode": "checker",
            "output_filename": str((views_dir / f"{sid}_view.png").resolve()),
        },
    )

    frame_images: list[Image.Image] = []
    for f_idx in range(1, len(frames_spec) + 1):
        fp = png_dir / f"{sid}_f{f_idx}.png"
        await mcp_call(
            session,
            "export_frame",
            {
                "filename": str(ase_path),
                "output_filename": str(fp.resolve()),
                "frame_index": f_idx,
                "scale": 1,
            },
        )
        frame_images.append(Image.open(fp).convert("RGBA"))

    # Pack frames horizontally (for single: (32*F)x32; for smooth_strip: raw strip (160*F)x32 + 47-junction atlas (47*32)x(32*F))
    n_frames = len(frame_images)
    if kind == "single":
        sheet_im = Image.new("RGBA", (32 * n_frames, 32), (0, 0, 0, 0))
        for i, fim in enumerate(frame_images):
            sheet_im.paste(fim, (i * 32, 0))
            ftel = analyze_rgba_image(fim)
            if not ftel["passes_bare_mask_gate"]:
                raise ValueError(
                    f"{sid} (frame {i + 1}): fails bare-colour-mask gate! "
                    f"dominant_rgb_share={ftel['dominant_rgb_share']} >= 0.85 over {ftel['active_px']} px."
                )
            if colorable and ftel["max_chroma"] > 0:
                raise ValueError(f"{sid} (frame {i + 1}): colorable sprite has chroma={ftel['max_chroma']} > 0!")
        sheet_path = png_dir / f"{sid}_sheet.png"
        sheet_im.save(sheet_path)
        telemetry = analyze_rgba_image(frame_images[0])
        junction_telemetry = None
        atlas_data_uri = png_to_data_uri(sheet_im)
        strip_data_uri = None
    else:
        strip_sheet = Image.new("RGBA", (160 * n_frames, 32), (0, 0, 0, 0))
        atlas_47 = Image.new("RGBA", (47 * 32, 32 * n_frames), (0, 0, 0, 0))
        for f_i, fim in enumerate(frame_images):
            strip_sheet.paste(fim, (f_i * 160, 0))
            for j_i, j_val in enumerate(JUNCTIONS):
                j_tile = slice_junction_tile(fim, j_val)
                jtel = analyze_rgba_image(j_tile)
                if not jtel["passes_bare_mask_gate"]:
                    raise ValueError(
                        f"{sid} (f={f_i + 1}, j={j_val}): fails bare-colour-mask gate! "
                        f"dominant_rgb_share={jtel['dominant_rgb_share']} >= 0.85 over {jtel['active_px']} px."
                    )
                if colorable and jtel["max_chroma"] > 0:
                    raise ValueError(f"{sid} (f={f_i + 1}, j={j_val}): colorable sprite has chroma={jtel['max_chroma']} > 0!")
                atlas_47.paste(j_tile, (j_i * 32, f_i * 32))
        strip_path = png_dir / f"{sid}_strip.png"
        atlas_path = png_dir / f"{sid}_47.png"
        strip_sheet.save(strip_path)
        atlas_47.save(atlas_path)

        j0_im = slice_junction_tile(frame_images[0], 0)
        j255_im = slice_junction_tile(frame_images[0], 255)
        telemetry = analyze_rgba_image(j0_im)
        j255_tel = analyze_rgba_image(j255_im)
        # Measure tile-join seam continuity across connected horizontal (block 2/3/4) and vertical (block 1/3/4) edges
        h_alpha_diff = 0.0
        v_alpha_diff = 0.0
        for y in range(32):
            p_left = j255_im.getpixel((31, y))
            p_right = j255_im.getpixel((0, y))
            h_alpha_diff += abs(p_left[3] - p_right[3])
        for x in range(32):
            p_bot = j255_im.getpixel((x, 31))
            p_top = j255_im.getpixel((x, 0))
            v_alpha_diff += abs(p_bot[3] - p_top[3])
        junction_telemetry = {
            "j0_isolated": telemetry,
            "j255_interior": j255_tel,
            "j255_edge_alpha_mae_h": round(h_alpha_diff / 32.0, 2),
            "j255_edge_alpha_mae_v": round(v_alpha_diff / 32.0, 2),
        }
        if not j255_tel["passes_bare_mask_gate"]:
            raise ValueError(
                f"{sid} (j=255 interior): fails bare-colour-mask gate! "
                f"dominant_rgb_share={j255_tel['dominant_rgb_share']} >= 0.85 over {j255_tel['active_px']} px. "
                f"Add multi-step greyscale shading!"
            )
        atlas_data_uri = png_to_data_uri(atlas_47)
        strip_data_uri = png_to_data_uri(strip_sheet)

    if not telemetry["passes_bare_mask_gate"]:
        raise ValueError(
            f"{sid}: fails bare-colour-mask gate! "
            f"dominant_rgb_share={telemetry['dominant_rgb_share']} >= 0.85 over {telemetry['active_px']} px. "
            f"Add multi-step shading!"
        )
    if colorable and telemetry["max_chroma"] > 0:
        raise ValueError(f"{sid}: colorable sprite has chroma={telemetry['max_chroma']} > 0!")
    if require_top_light and telemetry["luma"]["top"] < telemetry["luma"]["bottom"] - 1.0:
        raise ValueError(
            f"{sid}: top-down lighting violated: luma_top={telemetry['luma']['top']} < luma_bottom={telemetry['luma']['bottom']}"
        )

    return {
        "id": sid,
        "title": spec.get("title", sid),
        "element": element,
        "category": spec.get("category", element),
        "kind": kind,
        "colorable": colorable,
        "default_tint": spec.get("default_tint", "#FFFFFF"),
        "sample_tints": spec.get("sample_tints", []),
        "ase_relpath": spec["ase_relpath"],
        "description": spec.get("description", ""),
        "physics_notes": spec.get("physics_notes", ""),
        "frame_count": n_frames,
        "durations_ms": durations_ms,
        "layers": [
            {"name": ln, "opacity": layer_props[ln][0], "blend_mode": layer_props[ln][1]}
            for ln in layer_order
        ],
        "used_swatches": [
            {"hex": hx, "name": allowed_gpl.get(hx, "")} for hx in used_hexes
        ],
        "lint_f1": {
            "pieces": lint_f1.get("pieces", 0),
            "lone_pixel_count": lint_f1.get("lone_pixel_count", 0),
        },
        "telemetry": telemetry,
        "junction_telemetry": junction_telemetry,
        "atlas_data_uri": atlas_data_uri,
        "strip_data_uri": strip_data_uri,
    }


def render_domain_review_board(records: list[dict[str, Any]], out_png: Path) -> None:
    """Render a crisp visual inspection board (dark bg, light bg, tinted, and 3x3 smooth patch)."""
    row_h = 230
    width = 1280
    height = max(260, 60 + len(records) * row_h)
    board = Image.new("RGBA", (width, height), (14, 16, 24, 255))
    draw = ImageDraw.Draw(board)
    draw.text((20, 18), f"ELEMENTAL REVIEW BOARD ({len(records)} assets)", fill=(235, 240, 248, 255))

    # Simple 3x3 layout mask for smooth preview:
    # [TL=10(S+E), T=14(S+E+W), TR=6(S+W)] -> wait: N=1,S=2,E=4,W=8,NE=16,SE=32,SW=64,NW=128
    # Row 0 (top): (0,0) has S+E+SE = 2+4+32=38; (1,0) has S+E+W+SE+SW = 2+4+8+32+64=110; (2,0) has S+W+SW = 2+8+64=74
    # Row 1 (mid): (0,1) has N+S+E+NE+SE = 1+2+4+16+32=55; (1,1) = 255; (2,1) has N+S+W+NW+SW = 1+2+8+128+64=203
    # Row 2 (bot): (0,2) has N+E+NE = 1+4+16=21; (1,2) has N+E+W+NE+NW = 1+4+8+16+128=157; (2,2) has N+W+NW = 1+8+128=137
    patch_3x3 = [
        [38, 110, 74],
        [55, 255, 203],
        [21, 157, 137],
    ]

    for idx, rec in enumerate(records):
        y0 = 52 + idx * row_h
        draw.rectangle([14, y0, width - 14, y0 + row_h - 10], fill=(22, 26, 38, 255), outline=(55, 62, 82, 255))
        tel = rec["telemetry"]
        header = (
            f"{rec['id']} [{rec['kind']}] | frames={rec['frame_count']} {rec['durations_ms']}ms | "
            f"px={tel['active_px']} alpha={tel['alpha']['min']}/{tel['alpha']['avg']}/{tel['alpha']['max']} | "
            f"luma={tel['luma']['min']}/{tel['luma']['avg']}/{tel['luma']['max']} (T:{tel['luma']['top']} B:{tel['luma']['bottom']}) | "
            f"domRGB={tel['dominant_rgb_share']}"
        )
        draw.text((26, y0 + 8), header, fill=(220, 228, 242, 255))

        raw_b64 = rec["atlas_data_uri"].split(",", 1)[1]
        atlas_im = Image.open(io.BytesIO(base64.b64decode(raw_b64))).convert("RGBA")

        if rec["kind"] == "single":
            base_tile = atlas_im.crop((0, 0, 32, 32))
        else:
            # j=0 is index 0
            base_tile = atlas_im.crop((0, 0, 32, 32))

        # 1) 4x Dark (#151824)
        dark_box = Image.new("RGBA", (128, 128), (21, 24, 36, 255))
        s4 = base_tile.resize((128, 128), Image.Resampling.NEAREST)
        dark_box.alpha_composite(s4, (0, 0))
        board.paste(dark_box, (26, y0 + 34))
        draw.text((26, y0 + 168), "4x Dark (#151824)", fill=(150, 160, 180, 255))

        # 2) 4x Light (#F1EAD4)
        light_box = Image.new("RGBA", (128, 128), (241, 234, 212, 255))
        light_box.alpha_composite(s4, (0, 0))
        board.paste(light_box, (170, y0 + 34))
        draw.text((170, y0 + 168), "4x Light (#F1EAD4)", fill=(150, 160, 180, 255))

        # 3) 4x Tinted sample
        tint_hex = rec.get("default_tint", "#FFFFFF")
        if tint_hex == "#FFFFFF" and rec.get("sample_tints"):
            tint_hex = rec["sample_tints"][0]["hex"]
        tinted_tile = tint_multiply(base_tile, tint_hex).resize((128, 128), Image.Resampling.NEAREST)
        tint_box = Image.new("RGBA", (128, 128), (38, 38, 44, 255))
        tint_box.alpha_composite(tinted_tile, (0, 0))
        board.paste(tint_box, (314, y0 + 34))
        draw.text((314, y0 + 168), f"4x Tint {tint_hex}", fill=(150, 160, 180, 255))

        # 4) If smooth_strip: show 2x strip AND 2x 3x3 smoothed island + concave L!
        if rec["kind"] == "smooth_strip" and rec["strip_data_uri"]:
            strip_im = Image.open(io.BytesIO(base64.b64decode(rec["strip_data_uri"].split(",", 1)[1]))).convert("RGBA")
            strip_f1 = strip_im.crop((0, 0, 160, 32)).resize((320, 64), Image.Resampling.NEAREST)
            s_bg = Image.new("RGBA", (320, 64), (38, 38, 44, 255))
            s_bg.alpha_composite(strip_f1, (0, 0))
            board.paste(s_bg, (460, y0 + 34))
            draw.text((460, y0 + 102), "2x Strip [0:conv, 1:V, 2:H, 3:conc, 4:flat]", fill=(150, 160, 180, 255))

            # L-spur + concave corner test (4x2 grid at 1.25x = 40px/tile -> 160x80)
            l_mask = [
                [1, 1, 0, 1],
                [1, 1, 1, 1],
            ]
            l_im = Image.new("RGBA", (128, 64), (38, 38, 44, 255))
            for gy in range(2):
                for gx in range(4):
                    if not l_mask[gy][gx]:
                        continue
                    n = gy > 0 and bool(l_mask[gy - 1][gx])
                    s = gy < 1 and bool(l_mask[gy + 1][gx])
                    e = gx < 3 and bool(l_mask[gy][gx + 1])
                    w = gx > 0 and bool(l_mask[gy][gx - 1])
                    jv = (NORTH if n else 0) | (SOUTH if s else 0) | (EAST if e else 0) | (WEST if w else 0)
                    if n and e and l_mask[gy - 1][gx + 1]:
                        jv |= NE
                    if s and e and l_mask[gy + 1][gx + 1]:
                        jv |= SE
                    if s and w and l_mask[gy + 1][gx - 1]:
                        jv |= SW
                    if n and w and l_mask[gy - 1][gx - 1]:
                        jv |= NW
                    j_idx = JUNCTIONS.index(jv)
                    jt = tint_multiply(atlas_im.crop((j_idx * 32, 0, (j_idx + 1) * 32, 32)), tint_hex)
                    l_im.alpha_composite(jt, (gx * 32, gy * 32))
            board.paste(l_im.resize((160, 80), Image.Resampling.NEAREST), (460, y0 + 118))
            draw.text((628, y0 + 148), "Concave L + Spur", fill=(150, 160, 180, 255))

            # 3x3 island + interior test (3x3 grid at 1.5x = 48px/tile -> 144x144)
            grid_im = Image.new("RGBA", (96, 96), (38, 38, 44, 255))
            for gy in range(3):
                for gx in range(3):
                    jv = patch_3x3[gy][gx]
                    j_idx = JUNCTIONS.index(jv)
                    jt = tint_multiply(atlas_im.crop((j_idx * 32, 0, (j_idx + 1) * 32, 32)), tint_hex)
                    grid_im.alpha_composite(jt, (gx * 32, gy * 32))
            board.paste(grid_im.resize((144, 144), Image.Resampling.NEAREST), (810, y0 + 34))
            draw.text((810, y0 + 182), "1.5x 3x3 Connected Patch", fill=(150, 160, 180, 255))

            # Animation frames strip (j=0 or j=255 across frames)
            if rec["frame_count"] > 1:
                fc = min(rec["frame_count"], 4)
                anim_bg = Image.new("RGBA", (fc * 64, 64), (28, 32, 44, 255))
                j255_idx = JUNCTIONS.index(255)
                for fi in range(fc):
                    ft = tint_multiply(atlas_im.crop((j255_idx * 32, fi * 32, (j255_idx + 1) * 32, (fi + 1) * 32)), tint_hex)
                    anim_bg.alpha_composite(ft.resize((64, 64), Image.Resampling.NEAREST), (fi * 64, 0))
                board.paste(anim_bg, (980, y0 + 34))
                draw.text((980, y0 + 102), f"2x Anim Frames (1..{fc})", fill=(150, 160, 180, 255))
        elif rec["frame_count"] > 1:
            fc = min(rec["frame_count"], 6)
            anim_bg = Image.new("RGBA", (fc * 96, 96), (28, 32, 44, 255))
            for fi in range(fc):
                ft = tint_multiply(atlas_im.crop((fi * 32, 0, (fi + 1) * 32, 32)), tint_hex)
                anim_bg.alpha_composite(ft.resize((96, 96), Image.Resampling.NEAREST), (fi * 96, 0))
            board.paste(anim_bg, (460, y0 + 34))
            draw.text((460, y0 + 136), f"3x Animation Frames (1..{fc})", fill=(150, 160, 180, 255))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    board.save(out_png)


def load_sprites(spec_path: Path) -> list[dict[str, Any]]:
    mod_spec = importlib.util.spec_from_file_location("domain_sprites", str(spec_path))
    if mod_spec is None or mod_spec.loader is None:
        raise RuntimeError(f"Cannot load spec module: {spec_path}")
    mod = importlib.util.module_from_spec(mod_spec)
    mod_spec.loader.exec_module(mod)
    sprites = getattr(mod, "SPRITES", None)
    if not isinstance(sprites, list) or not sprites:
        raise ValueError(f"{spec_path}: must define non-empty SPRITES = [...]")
    return sprites


def check_specs(spec_path: Path) -> None:
    allowed_gpl = load_gpl_palette(GPL_PATH)
    sprites = load_sprites(spec_path)
    for sp in sprites:
        validate_spec(sp, allowed_gpl)
    print(f"{spec_path.name}: {len(sprites)} specs valid against {GPL_PATH.name}")


async def run_build(
    spec_path: Path,
    domain_name: str,
    gallery_out_dir: Path,
    rebuild_sources: bool = False,
    only: list[str] | None = None,
) -> None:
    sprites = load_sprites(spec_path)
    if only:
        unknown = set(only) - {sp["id"] for sp in sprites}
        if unknown:
            raise ValueError(f"{spec_path.name}: no spec with id {sorted(unknown)}")
        sprites = [sp for sp in sprites if sp["id"] in only]
    allowed_gpl = load_gpl_palette(GPL_PATH)
    records: list[dict[str, Any]] = []
    async with open_mcp() as session:
        for sp in sprites:
            rec = await build_and_validate_sprite(
                session=session,
                spec=sp,
                pack_root=PACK_ROOT,
                gallery_out_dir=gallery_out_dir,
                allowed_gpl=allowed_gpl,
                rebuild_source=rebuild_sources,
            )
            records.append(rec)
            print(
                f"[OK] {rec['id']:32s} | {rec['kind']:12s} | f={rec['frame_count']} | "
                f"px={rec['telemetry']['active_px']:4d} | domRGB={rec['telemetry']['dominant_rgb_share']:.2f}"
            )

    if only:
        print("--only: exported the named sprites; manifest and review board left untouched")
        return
    manifests_dir = gallery_out_dir / "manifests"
    manifests_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = manifests_dir / f"{domain_name}.json"
    manifest_path.write_text(json.dumps(records, indent=2), encoding="utf-8")

    board_path = gallery_out_dir / "boards" / f"review_{domain_name}.png"
    render_domain_review_board(records, board_path)
    print(f"Wrote manifest: {manifest_path}")
    print(f"Wrote review board: {board_path}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export and audit elemental matter/fire sprites through Aseprite MCP. "
        "Sources live in the pack's assets/originals/art/; outputs go under --out-dir."
    )
    parser.add_argument("--domain", required=True, choices=["gasses", "liquids", "solids", "fire"])
    parser.add_argument(
        "--spec",
        help="Python spec file defining SPRITES = [...] (default: specs/spec_<domain>.py beside this file)",
    )
    parser.add_argument(
        "--out-dir",
        default=str(DEFAULT_OUT_DIR),
        help="where png/, views/, boards/ and manifests/ land (default: <pack>/target/art/elemental)",
    )
    parser.add_argument(
        "--only",
        action="append",
        metavar="ID",
        help="export just this sprite id (repeatable); leaves the domain manifest and board untouched",
    )
    parser.add_argument(
        "--check-specs",
        action="store_true",
        help="validate the spec's geometry, durations and palette; needs no Aseprite or MCP",
    )
    parser.add_argument(
        "--rebuild-sources",
        action="store_true",
        help="redraw every .aseprite from its spec, replacing the file (default: export what is on disk; "
        "a missing source is always drawn)",
    )
    args = parser.parse_args()
    spec = Path(args.spec) if args.spec else ELEMENTAL_DIR / "specs" / f"spec_{args.domain}.py"
    if args.check_specs:
        check_specs(spec.resolve())
        return
    asyncio.run(
        run_build(
            spec.resolve(),
            args.domain,
            Path(args.out_dir).resolve(),
            args.rebuild_sources,
            args.only,
        )
    )


if __name__ == "__main__":
    main()
