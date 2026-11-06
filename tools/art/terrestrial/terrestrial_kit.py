#!/usr/bin/env python3
r"""
Builder, Aseprite MCP source writer, 47-junction BitmaskSlice cutter, and strict
binary/pixel/seam/animation auditor for Tales from Space Terrestrial Art.

CLI modes:
  --check-specs      Pure-Python validation of SPRITES without invoking Aseprite or MCP.
  (default)          Read-only audit + PNG/47-atlas/manifest export from existing .aseprite files.
  --rebuild-sources  Redraw .aseprite files in ORIGINALS_DIR via aseprite_mcp, then export & audit.
Every run that exports a strip with its `flat_of` variants also runs the flat repetition audit.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
from collections import Counter, defaultdict, deque
from contextlib import asynccontextmanager
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
from typing import Any
import zlib

from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from schema_contract import (  # noqa: E402
    DEFAULT_OUT_DIR, EAST, GPL_PATH, JUNCTIONS, NE, NEUTRAL_GRAYS, NORTH, NW,
    ORIGINALS_DIR, PACK_ROOT, SE, SOUTH, SW, WEST, aseprite_binary, mcp_python_and_repo, rgba_pixels,
)
from specs import SPRITES  # noqa: E402


def is_smooth_kind(kind: str) -> bool:
    return kind == "smooth_strip"


def bake_tag(spec: dict[str, Any]) -> str:
    state = str(spec.get("tag", "idle"))
    return f"{state}-s" if is_smooth_kind(spec["kind"]) else state


def assert_inside_out_dir(path: Path, out_dir: Path) -> Path:
    resolved, root = path.resolve(), out_dir.resolve()
    if not resolved.is_relative_to(root):
        raise RuntimeError(f"Refusing to write generated output outside {root}: {resolved}")
    return resolved


def assert_inside_originals(path: Path) -> Path:
    resolved, orig_root = path.resolve(), ORIGINALS_DIR.resolve()
    if not resolved.is_relative_to(orig_root):
        raise RuntimeError(f"Refusing to write .aseprite outside ORIGINALS_DIR ({orig_root}): {resolved}")
    return resolved


def parse_gpl(
    gpl_path: Path = GPL_PATH,
) -> tuple[dict[str, str], dict[tuple[int, int, int], str], dict[tuple[int, int, int], str]]:
    """Return `(allowed_hex, all_rgb, reserved_rgb)` parsed from `tales-from-space.gpl`."""
    allowed_hex: dict[str, str] = {}
    all_rgb: dict[tuple[int, int, int], str] = {}
    reserved_rgb: dict[tuple[int, int, int], str] = {}
    for raw_line in gpl_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(("GIMP Palette", "Name:", "Columns:", "#")):
            continue
        parts = line.split(None, 3)
        if len(parts) >= 3:
            r, g, b = int(parts[0]), int(parts[1]), int(parts[2])
            label = parts[3] if len(parts) > 3 else ""
            hx = f"#{r:02X}{g:02X}{b:02X}"
            allowed_hex[hx] = label
            all_rgb[(r, g, b)] = label
            if label and "reserved" in label.split()[0].lower():
                reserved_rgb[(r, g, b)] = label
    return allowed_hex, all_rgb, reserved_rgb


def parse_aseprite_binary(path: Path) -> dict[str, Any]:
    """Parse header, frame durations, layers, cels, tags, and palette directly from `.aseprite`."""
    data = path.read_bytes()
    _, magic, frames, width, height, depth, _, _ = struct.unpack_from("<IHHHHHIH", data, 0)
    if magic != 0xA5E0:
        raise ValueError(f"{path}: bad Aseprite file magic {magic:#x}")

    pos = 128
    layers: list[dict[str, Any]] = []
    tags: list[dict[str, Any]] = []
    palette_entries: dict[int, tuple[int, int, int, int]] = {}
    frame_durations: list[int] = []
    cels: list[tuple[int, int, int, int, int, int, int, bytes]] = []
    cel_map: dict[tuple[int, int], tuple[int, int, int, int, int, bytes]] = {}

    for f_idx in range(frames):
        f_bytes, f_magic, old_chunks, duration, _, new_chunks = struct.unpack_from("<IHHH2sI", data, pos)
        if f_magic != 0xF1FA:
            raise ValueError(f"{path} frame {f_idx}: bad frame magic {f_magic:#x}")
        n_chunks = new_chunks if new_chunks != 0 else old_chunks
        frame_durations.append(duration)
        c_pos = pos + 16
        for _ in range(n_chunks):
            c_size, c_type = struct.unpack_from("<IH", data, c_pos)
            c_body = data[c_pos + 6 : c_pos + c_size]
            if c_type == 0x2004:
                l_flags, l_type, _, _, _, blend, opacity = struct.unpack_from("<HHHHHHB", c_body, 0)
                name_len = struct.unpack_from("<H", c_body, 16)[0]
                lname = c_body[18 : 18 + name_len].decode("utf-8", errors="replace")
                layers.append(
                    {"flags": l_flags, "visible": bool(l_flags & 1), "type": l_type, "blend": blend, "opacity": opacity, "name": lname}
                )
            elif c_type == 0x2005:
                l_idx, cx, cy, copacity, cel_type, _ = struct.unpack_from("<HhhBHh", c_body, 0)
                if cel_type == 0:
                    cw, ch = struct.unpack_from("<HH", c_body, 16)
                    raw_px = c_body[20 : 20 + cw * ch * (depth // 8)]
                elif cel_type == 1:
                    link_frame = struct.unpack_from("<H", c_body, 16)[0]
                    _, _, cw, ch, _, raw_px = cel_map[(link_frame, l_idx)]
                elif cel_type == 2:
                    cw, ch = struct.unpack_from("<HH", c_body, 16)
                    raw_px = zlib.decompress(c_body[20:])
                else:
                    c_pos += c_size
                    continue
                cel_map[(f_idx, l_idx)] = (cx, cy, cw, ch, copacity, raw_px)
                cels.append((f_idx, l_idx, cx, cy, cw, ch, copacity, raw_px))
            elif c_type == 0x2018:
                num_tags = struct.unpack_from("<H", c_body, 0)[0]
                t_off = 10
                for _t in range(num_tags):
                    t_from, t_to, t_dir, t_rep = struct.unpack_from("<HHBH", c_body, t_off)
                    t_nlen = struct.unpack_from("<H", c_body, t_off + 17)[0]
                    t_off += 19
                    t_name = c_body[t_off : t_off + t_nlen].decode("utf-8", errors="replace")
                    t_off += t_nlen
                    tags.append({"name": t_name, "from": t_from, "to": t_to, "dir": t_dir, "repeat": t_rep})
            elif c_type == 0x2019:
                _, first_idx, last_idx = struct.unpack_from("<III", c_body, 0)
                p_off = 20
                for p_i in range(first_idx, last_idx + 1):
                    e_flags, pr, pg, pb, pa = struct.unpack_from("<HBBBB", c_body, p_off)
                    p_off += 6
                    if e_flags & 1:
                        nlen = struct.unpack_from("<H", c_body, p_off)[0]
                        p_off += 2 + nlen
                    palette_entries[p_i] = (pr, pg, pb, pa)
            c_pos += c_size
        pos += f_bytes

    return {
        "width": width, "height": height, "depth": depth, "frames": frames,
        "durations": frame_durations, "layers": layers, "tags": tags,
        "palette": palette_entries, "cels": cels,
    }


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


def count_lone_and_pieces_rgba(im: Image.Image) -> tuple[int, int]:
    """Return `(lone_pixel_count, connected_pieces_8)` over `alpha > 0` pixels."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    occ = [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]
    lone = 0
    for y in range(h):
        for x in range(w):
            if occ[y][x] and not any(
                0 <= x + dx < w and 0 <= y + dy < h and occ[y + dy][x + dx]
                for dy in (-1, 0, 1)
                for dx in (-1, 0, 1)
                if (dx, dy) != (0, 0)
            ):
                lone += 1

    visited = [[False] * w for _ in range(h)]
    pieces = 0
    for y in range(h):
        for x in range(w):
            if not occ[y][x] or visited[y][x]:
                continue
            pieces += 1
            visited[y][x] = True
            q: deque[tuple[int, int]] = deque([(x, y)])
            while q:
                cx, cy = q.popleft()
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if (dx, dy) != (0, 0) and 0 <= nx < w and 0 <= ny < h and occ[ny][nx] and not visited[ny][nx]:
                            visited[ny][nx] = True
                            q.append((nx, ny))
    return lone, pieces


def analyze_rgba_image(
    im: Image.Image,
    allowed_hex: dict[str, str],
    reserved_rgb: dict[tuple[int, int, int], str],
) -> dict[str, Any]:
    rgba = im.convert("RGBA")
    w, h = rgba.size
    active: list[tuple[int, int, int, int, int, int, float]] = []
    rgb_counts: Counter[tuple[int, int, int]] = Counter()
    off_palette: set[str] = set()
    reserved_hits: set[str] = set()
    opaque_255 = 0
    translucent = 0

    for idx, (r, g, b, a) in enumerate(rgba_pixels(rgba)):
        if a > 0:
            x, y = idx % w, idx // w
            hx = f"#{r:02X}{g:02X}{b:02X}"
            if hx not in allowed_hex:
                off_palette.add(hx)
            if (r, g, b) in reserved_rgb:
                reserved_hits.add(hx)
            active.append((x, y, r, g, b, a, 0.2126 * r + 0.7152 * g + 0.0722 * b))
            rgb_counts[(r, g, b)] += 1
            if a == 255:
                opaque_255 += 1
            else:
                translucent += 1

    if not active:
        return {
            "active_px": 0, "transparent_px": w * h, "transparent_share": 1.0,
            "opaque_255_px": 0, "translucent_px": 0, "bbox": [0, 0, 0, 0],
            "alpha": {"min": 0, "avg": 0.0, "max": 0},
            "luma": {"min": 0.0, "avg": 0.0, "max": 0.0, "top": 0.0, "bottom": 0.0},
            "max_chroma": 0, "unique_rgb_count": 0, "dominant_rgb_share": 0.0,
            "passes_bare_mask_gate": True, "lone_pixel_count": 0, "pieces": 0,
            "off_palette": [], "reserved_hits": [], "swatch_shares": {},
        }

    xs, ys = [p[0] for p in active], [p[1] for p in active]
    min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    span_y = max(1, max_y - min_y + 1)
    top_cut, bot_cut = min_y + span_y / 3.0, max_y - span_y / 3.0
    alphas, lumas = [p[5] for p in active], [p[6] for p in active]
    top_l = [p[6] for p in active if p[1] <= top_cut]
    bot_l = [p[6] for p in active if p[1] >= bot_cut]
    chromas = [max(p[2], p[3], p[4]) - min(p[2], p[3], p[4]) for p in active]
    dom_share = rgb_counts.most_common(1)[0][1] / len(active)
    lone_px, pieces = count_lone_and_pieces_rgba(rgba)
    swatch_shares = {f"#{r:02X}{g:02X}{b:02X}": round(cnt / len(active), 3) for (r, g, b), cnt in rgb_counts.most_common()}

    return {
        "active_px": len(active), "transparent_px": w * h - len(active),
        "transparent_share": round((w * h - len(active)) / (w * h), 3),
        "opaque_255_px": opaque_255, "translucent_px": translucent,
        "bbox": [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1],
        "alpha": {"min": min(alphas), "avg": round(sum(alphas) / len(alphas), 1), "max": max(alphas)},
        "luma": {
            "min": round(min(lumas), 1), "avg": round(sum(lumas) / len(lumas), 1), "max": round(max(lumas), 1),
            "top": round(sum(top_l) / max(1, len(top_l)), 1),
            "bottom": round(sum(bot_l) / max(1, len(bot_l)), 1),
        },
        "max_chroma": max(chromas), "unique_rgb_count": len(rgb_counts),
        "dominant_rgb_share": round(dom_share, 3),
        "passes_bare_mask_gate": not (len(active) >= 40 and dom_share >= 0.85),
        "lone_pixel_count": lone_px, "pieces": pieces,
        "off_palette": sorted(off_palette), "reserved_hits": sorted(reserved_hits),
        "swatch_shares": swatch_shares,
    }


def _col(im: Image.Image, x: int, y0: int, y1: int) -> list[tuple[int, int, int, int]]:
    return [im.getpixel((x, y)) for y in range(y0, y1)]


def _row(im: Image.Image, y: int, x0: int, x1: int) -> list[tuple[int, int, int, int]]:
    return [im.getpixel((x, y)) for x in range(x0, x1)]


def _seam_metrics(
    ea: list[tuple[int, int, int, int]],
    eb: list[tuple[int, int, int, int]],
    r1a: list[tuple[int, int, int, int]],
    r1b: list[tuple[int, int, int, int]],
    r2a: list[tuple[int, int, int, int]],
    r2b: list[tuple[int, int, int, int]],
) -> tuple[float, int, float, float]:
    def mae(u: list[tuple[int, int, int, int]], v: list[tuple[int, int, int, int]]) -> tuple[float, int, float]:
        ad = [abs(p[3] - q[3]) for p, q in zip(u, v, strict=True)]
        ld = [
            abs((0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]) * (p[3] / 255.0) - (0.2126 * q[0] + 0.7152 * q[1] + 0.0722 * q[2]) * (q[3] / 255.0))
            for p, q in zip(u, v, strict=True)
        ]
        return sum(ad) / len(u), max(ad), sum(ld) / len(u)

    amae, amax, lmae = mae(ea, eb)
    _, _, lref1 = mae(r1a, r1b)
    _, _, lref2 = mae(r2a, r2b)
    return amae, amax, lmae, lmae / max(2.5, 0.5 * (lref1 + lref2))


def compute_seam_telemetry(frames_im: list[Image.Image]) -> dict[str, Any]:
    """Check intra-tile quadrant joins and inter-tile joins across all frames and 47 junctions."""
    max_alpha_diff, worst_alpha_desc = 0, ""
    max_quad_luma_mae, worst_quad_desc = 0.0, ""
    max_quad_ratio, worst_quad_ratio_desc = 0.0, ""
    max_tile_luma_mae, worst_tile_desc = 0.0, ""
    max_tile_ratio, worst_tile_ratio_desc = 0.0, ""
    max_l_corner_luma_mae = 0.0

    for f_i, fim in enumerate(frames_im):
        for jv in JUNCTIONS:
            jt = slice_junction_tile(fim, jv)
            quad_checks = [
                (f"V-{nm}", _col(jt, 15, a, b), _col(jt, 16, a, b), _col(jt, 14, a, b), _col(jt, 15, a, b), _col(jt, 16, a, b), _col(jt, 17, a, b))
                for nm, (a, b) in (("top", (0, 16)), ("bot", (16, 32)))
            ] + [
                (f"H-{nm}", _row(jt, 15, a, b), _row(jt, 16, a, b), _row(jt, 14, a, b), _row(jt, 15, a, b), _row(jt, 16, a, b), _row(jt, 17, a, b))
                for nm, (a, b) in (("left", (0, 16)), ("right", (16, 32)))
            ]
            for tag, ea, eb, r1a, r1b, r2a, r2b in quad_checks:
                amae, amax, lmae, ratio = _seam_metrics(ea, eb, r1a, r1b, r2a, r2b)
                if amax > max_alpha_diff:
                    max_alpha_diff, worst_alpha_desc = amax, f"f{f_i+1}:j{jv}:{tag}(alphaMAX={amax})"
                if lmae > max_quad_luma_mae:
                    max_quad_luma_mae, worst_quad_desc = lmae, f"f{f_i+1}:j{jv}:{tag}(alphaMAE={amae:.1f}, lumaMAE={lmae:.1f})"
                if ratio > max_quad_ratio and lmae > 8.0:
                    max_quad_ratio, worst_quad_ratio_desc = ratio, f"f{f_i+1}:j{jv}:{tag}(ratio={ratio:.2f}, lumaMAE={lmae:.1f})"

        blocks = [fim.crop((b * 32, 0, (b + 1) * 32, 32)) for b in range(5)]
        tile_checks: list[tuple[str, bool, list[Any], list[Any], list[Any], list[Any], list[Any], list[Any]]] = []
        for bl, br in ((2, 2), (3, 2), (2, 3), (4, 4)):
            spans = [("top", (0, 16)), ("bot", (16, 32))] + ([("full", (0, 32))] if (bl, br) == (4, 4) else [])
            for nm, (a, b) in spans:
                tile_checks.append(
                    (f"HJoin(B{bl}->B{br},{nm})", (bl, br) in ((3, 2), (2, 3)), _col(blocks[bl], 31, a, b), _col(blocks[br], 0, a, b), _col(blocks[bl], 30, a, b), _col(blocks[bl], 31, a, b), _col(blocks[br], 0, a, b), _col(blocks[br], 1, a, b))
                )
        for bt, bb in ((1, 1), (3, 1), (1, 3), (4, 4)):
            spans = [("left", (0, 16)), ("right", (16, 32))] + ([("full", (0, 32))] if (bt, bb) == (4, 4) else [])
            for nm, (a, b) in spans:
                tile_checks.append(
                    (f"VJoin(B{bt}->B{bb},{nm})", (bt, bb) in ((3, 1), (1, 3)), _row(blocks[bt], 31, a, b), _row(blocks[bb], 0, a, b), _row(blocks[bt], 30, a, b), _row(blocks[bt], 31, a, b), _row(blocks[bb], 0, a, b), _row(blocks[bb], 1, a, b))
                )
        for tag, is_l_corner, ea, eb, r1a, r1b, r2a, r2b in tile_checks:
            _, amax, lmae, ratio = _seam_metrics(ea, eb, r1a, r1b, r2a, r2b)
            if is_l_corner:
                max_l_corner_luma_mae = max(max_l_corner_luma_mae, lmae)
            if amax > max_alpha_diff:
                max_alpha_diff, worst_alpha_desc = amax, f"f{f_i+1}:{tag}(alphaMAX={amax})"
            if lmae > max_tile_luma_mae:
                max_tile_luma_mae, worst_tile_desc = lmae, f"f{f_i+1}:{tag}(lumaMAE={lmae:.1f})"
            if ratio > max_tile_ratio and lmae > 8.0:
                max_tile_ratio, worst_tile_ratio_desc = ratio, f"f{f_i+1}:{tag}(ratio={ratio:.2f})"

    return {
        "max_alpha_diff": max_alpha_diff, "worst_alpha_desc": worst_alpha_desc,
        "max_quad_luma_mae": round(max_quad_luma_mae, 2), "max_quad_ratio": round(max_quad_ratio, 2),
        "worst_quad": worst_quad_desc, "worst_quad_ratio": worst_quad_ratio_desc,
        "max_tile_luma_mae": round(max_tile_luma_mae, 2), "max_tile_ratio": round(max_tile_ratio, 2),
        "worst_tile": worst_tile_desc, "worst_tile_ratio": worst_tile_ratio_desc,
        "max_seam_ratio": round(max(max_quad_ratio, max_tile_ratio), 2),
        "max_l_corner_luma_mae": round(max_l_corner_luma_mae, 2),
    }


def compute_anim_telemetry(frames_im: list[Image.Image], kind: str) -> dict[str, Any]:
    """Compute step-to-step RGBA byte MAE, max/min pacing ratio, wrap ratio, and zero-delta checks."""
    n_f = len(frames_im)
    if n_f > 1:
        for f_i, fr in enumerate(frames_im):
            if fr.getbbox() is None:
                raise ValueError(f"blank animation frame f{f_i + 1} (0 active pixels)")
    step_maes: list[float] = []
    changed_counts: list[int] = []
    for f_i in range(n_f):
        ba, bb = frames_im[f_i].tobytes(), frames_im[(f_i + 1) % n_f].tobytes()
        changed_px = 0
        total_abs = 0
        for idx in range(0, len(ba), 4):
            diff = abs(ba[idx] - bb[idx]) + abs(ba[idx + 1] - bb[idx + 1]) + abs(ba[idx + 2] - bb[idx + 2]) + abs(ba[idx + 3] - bb[idx + 3])
            if diff:
                changed_px += 1
                total_abs += diff
        changed_counts.append(changed_px)
        step_maes.append(total_abs / len(ba))

    zero_delta: list[str] = []
    if kind == "single":
        for f_i in range(n_f):
            nxt = (f_i + 1) % n_f
            if frames_im[f_i].tobytes() == frames_im[nxt].tobytes():
                zero_delta.append(f"f{f_i+1}->f{nxt+1}")
    else:
        for jv in JUNCTIONS:
            j_frames = [slice_junction_tile(fr, jv) for fr in frames_im]
            if any(jf.getbbox() is not None for jf in j_frames):
                for f_i in range(n_f):
                    nxt = (f_i + 1) % n_f
                    if j_frames[f_i].tobytes() == j_frames[nxt].tobytes():
                        zero_delta.append(f"j{jv}:f{f_i+1}->f{nxt+1}")

    mean_inner = sum(step_maes[:-1]) / max(1, len(step_maes) - 1)
    return {
        "changed_px_min": min(changed_counts),
        "changed_px_max": max(changed_counts),
        "step_maes": [round(m, 3) for m in step_maes],
        "max_min_step_ratio": round(max(step_maes) / max(1e-6, min(step_maes)), 2),
        "wrap_ratio": round(step_maes[-1] / max(1e-6, mean_inner), 2),
        "zero_delta_count": len(zero_delta),
    }


def png_to_data_uri(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


@asynccontextmanager
async def open_mcp():
    try:
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
    except ImportError as err:
        raise RuntimeError("the `mcp` client package is missing in this Python interpreter") from err

    python_exe, repo = mcp_python_and_repo()
    env = {**os.environ, "ASEPRITE_PATH": aseprite_binary()}
    if repo:
        repo_path = Path(repo)
        py_parts = [str(p) for p in (repo_path / "src", repo_path) if p.exists()]
        if os.environ.get("PYTHONPATH"):
            py_parts.append(os.environ["PYTHONPATH"])
        env["PYTHONPATH"] = os.pathsep.join(py_parts)
    params = StdioServerParameters(command=python_exe, args=["-m", "aseprite_mcp"], env=env)
    with open(os.devnull, "w") as devnull:
        async with stdio_client(params, errlog=devnull) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                yield session


async def mcp_call(session: Any, tool: str, args: dict[str, Any]) -> str:
    res = await session.call_tool(tool, args)
    texts = [c.text for c in res.content if getattr(c, "type", None) == "text" or hasattr(c, "text")]
    out = "\n".join(texts).strip()
    if getattr(res, "isError", False) or out.startswith(("Command failed", "Failed")):
        raise RuntimeError(f"MCP {tool} failed: {out}")
    return out


def validate_spec(
    spec: dict[str, Any],
    allowed_hex: dict[str, str],
    reserved_rgb: dict[tuple[int, int, int], str],
) -> tuple[list[str], dict[str, tuple[int, str]], list[str]]:
    """Pure-Python validation of geometry, frame durations, disjoint layers, and neutral GPL swatches."""
    sid, kind = spec["id"], spec["kind"]
    if kind not in ("smooth_strip", "single"):
        raise ValueError(f"{sid}: invalid kind {kind!r}")
    assert_inside_originals(PACK_ROOT / spec["ase_relpath"])

    expected_w, expected_h = (160 if is_smooth_kind(kind) else 32), 32
    colorable = bool(spec.get("colorable", True))
    allowed_neutral_set = {hx.upper() for hx in NEUTRAL_GRAYS.values()}
    frames_spec = spec.get("frames", [])
    if not frames_spec:
        raise ValueError(f"{sid}: frames cannot be empty")

    layer_order: list[str] = []
    layer_props: dict[str, tuple[int, str]] = {}
    used_hexes: list[str] = []

    for f_idx, fspec in enumerate(frames_spec, start=1):
        dur = int(fspec.get("duration_ms", 200))
        if dur < 100 or dur % 100 != 0:
            raise ValueError(f"{sid} f{f_idx}: duration_ms={dur} must be >= 100 and a multiple of 100")
        occupied: set[tuple[int, int]] = set()
        for lspec in fspec["layers"]:
            lname = lspec["name"]
            opacity = int(lspec.get("opacity", 255))
            if not (1 <= opacity <= 255):
                raise ValueError(f"{sid} f{f_idx}/{lname}: invalid opacity={opacity}")
            bmode = str(lspec.get("blend_mode", "normal"))
            if bmode != "normal":
                raise ValueError(f"{sid} f{f_idx}/{lname}: invalid blend_mode={bmode!r}, expected 'normal'")
            if lname not in layer_order:
                layer_order.append(lname)
                layer_props[lname] = (opacity, bmode)
            elif layer_props[lname] != (opacity, bmode):
                raise ValueError(f"{sid} f{f_idx}/{lname}: inconsistent layer props across frames")

            rows, legend = lspec["rows"], lspec["legend"]
            if len(rows) != expected_h:
                raise ValueError(f"{sid} f{f_idx}/{lname}: expected {expected_h} rows, got {len(rows)}")
            for y, row in enumerate(rows):
                if len(row) != expected_w:
                    raise ValueError(f"{sid} f{f_idx}/{lname} row {y}: expected {expected_w}, got {len(row)}")
                for x, ch in enumerate(row):
                    if ch == ".":
                        continue
                    if ch not in legend:
                        raise ValueError(f"{sid} f{f_idx}/{lname} ({x},{y}): missing legend key {ch!r}")
                    if (x, y) in occupied:
                        raise ValueError(f"{sid} f{f_idx}: overlapping layer pixel at ({x},{y})")
                    occupied.add((x, y))

            for hx in legend.values():
                hx_u = hx.upper()
                if hx_u not in allowed_hex:
                    raise ValueError(f"{sid} f{f_idx}/{lname}: swatch {hx_u} not in tales-from-space.gpl")
                rgb = (int(hx_u[1:3], 16), int(hx_u[3:5], 16), int(hx_u[5:7], 16))
                if rgb in reserved_rgb:
                    raise ValueError(f"{sid} f{f_idx}/{lname}: swatch {hx_u} is RESERVED ({reserved_rgb[rgb]})")
                if colorable and (not (rgb[0] == rgb[1] == rgb[2]) or hx_u not in allowed_neutral_set):
                    raise ValueError(f"{sid} f{f_idx}/{lname}: colorable=True requires neutral gray, got {hx_u}")
                if hx_u not in used_hexes:
                    used_hexes.append(hx_u)

    return layer_order, layer_props, used_hexes


async def draw_source(
    session: Any, spec: dict[str, Any], ase_path: Path, expected_w: int, expected_h: int,
    used_hexes: list[str], layer_order: list[str], layer_props: dict[str, tuple[int, str]],
) -> None:
    """Create `.aseprite` source via `aseprite_mcp` with Forward `idle-s` / `idle` tag."""
    safe_ase = assert_inside_originals(ase_path)
    safe_ase.parent.mkdir(parents=True, exist_ok=True)
    safe_ase.unlink(missing_ok=True)
    fn, frames_spec = str(safe_ase), spec["frames"]
    await mcp_call(session, "create_canvas", {"width": expected_w, "height": expected_h, "filename": fn})
    await mcp_call(session, "set_palette", {"filename": fn, "colors": used_hexes})

    for idx, lname in enumerate(layer_order):
        if idx == 0:
            await mcp_call(session, "rename_layer", {"filename": fn, "layer_name": "Layer 1", "new_name": lname})
        else:
            await mcp_call(session, "add_layer", {"filename": fn, "layer_name": lname})
        opacity, bmode = layer_props[lname]
        if opacity != 255:
            await mcp_call(session, "set_layer_opacity", {"filename": fn, "layer_name": lname, "opacity": opacity})
        if bmode != "normal":
            await mcp_call(session, "set_layer_blend_mode", {"filename": fn, "layer_name": lname, "blend_mode": bmode})

    for _ in range(2, len(frames_spec) + 1):
        await mcp_call(session, "add_frame", {"filename": fn})

    for f_idx, fspec in enumerate(frames_spec, start=1):
        await mcp_call(session, "set_frame_duration", {"filename": fn, "frame_index": f_idx, "duration_ms": int(fspec.get("duration_ms", 200))})
        for lspec in fspec["layers"]:
            await mcp_call(session, "draw_rows", {"filename": fn, "layer_name": lspec["name"], "frame_index": f_idx, "x": 0, "y": 0, "rows": lspec["rows"], "legend": lspec["legend"]})

    await mcp_call(session, "set_tag", {"filename": fn, "name": bake_tag(spec), "from_frame": 1, "to_frame": len(frames_spec), "direction": "forward"})


def audit_aseprite_binary_on_disk(
    spec: dict[str, Any], ase_path: Path, all_rgb: dict[tuple[int, int, int], str], reserved_rgb: dict[tuple[int, int, int], str],
) -> dict[str, Any]:
    """Enforce binary `.aseprite` contract (RGBA depth, canvas, durations, Forward tag, palette, cels)."""
    sid = spec["id"]
    exp_w = 160 if is_smooth_kind(spec["kind"]) else 32
    exp_durs = [int(f.get("duration_ms", 200)) for f in spec["frames"]]
    exp_tag = bake_tag(spec)
    colorable = bool(spec.get("colorable", True))

    info = parse_aseprite_binary(ase_path)
    if info["depth"] != 32:
        raise ValueError(f"{sid}: .aseprite depth={info['depth']}, expected 32-bit RGBA")
    if (info["width"], info["height"]) != (exp_w, 32):
        raise ValueError(f"{sid}: .aseprite canvas={info['width']}x{info['height']}, expected {exp_w}x32")
    if info["frames"] != len(exp_durs) or info["durations"] != exp_durs:
        raise ValueError(f"{sid}: .aseprite durations={info['durations']} != spec {exp_durs}")

    tags = info["tags"]
    if len(tags) != 1:
        raise ValueError(f"{sid}: expected exactly 1 tag ({exp_tag!r}), found {tags}")
    tg = tags[0]
    if tg["dir"] != 0 or tg["name"] != exp_tag or tg["from"] != 0 or tg["to"] != info["frames"] - 1:
        raise ValueError(f"{sid}: invalid tag {tg}, expected name={exp_tag!r} dir=0 span=0..{info['frames'] - 1}")

    for p_idx, (pr, pg, pb, pa) in info["palette"].items():
        if pa == 0 and (pr, pg, pb) == (0, 0, 0):
            continue
        if (pr, pg, pb) not in all_rgb:
            raise ValueError(f"{sid}: embedded palette[{p_idx}] #{pr:02X}{pg:02X}{pb:02X} off-GPL")
        if (pr, pg, pb) in reserved_rgb:
            raise ValueError(f"{sid}: embedded palette[{p_idx}] #{pr:02X}{pg:02X}{pb:02X} is RESERVED")
        if colorable and not (pr == pg == pb):
            raise ValueError(f"{sid}: embedded palette[{p_idx}] #{pr:02X}{pg:02X}{pb:02X} has chroma > 0")

    vis_layers = [lyr for lyr in info["layers"] if lyr["visible"]]
    for lyr in vis_layers:
        if lyr["blend"] != 0:
            raise ValueError(f"{sid}: layer {lyr['name']!r} blend={lyr['blend']} != 0 (Normal)")
    exp_layers = [(l["name"], int(l.get("opacity", 255))) for l in spec["frames"][0]["layers"]]
    act_layers = [(lyr["name"], lyr["opacity"]) for lyr in vis_layers]
    if act_layers != exp_layers:
        raise ValueError(f"{sid}: visible layers {act_layers} != spec {exp_layers}")

    per_frame_coords: dict[int, Counter[tuple[int, int]]] = defaultdict(Counter)
    for f_idx, l_idx, cx, cy, cw, ch, copacity, raw_px in info["cels"]:
        if not info["layers"][l_idx]["visible"]:
            continue
        if copacity != 255:
            raise ValueError(f"{sid} f{f_idx+1} layer {info['layers'][l_idx]['name']!r}: cel_opacity={copacity} != 255")
        for py in range(ch):
            gy, row_base = cy + py, py * cw * 4
            for px_x in range(cw):
                gx, off = cx + px_x, row_base + px_x * 4
                if raw_px[off + 3] > 0:
                    r, g, b = raw_px[off], raw_px[off + 1], raw_px[off + 2]
                    if 0 <= gx < exp_w and 0 <= gy < 32:
                        per_frame_coords[f_idx][(gx, gy)] += 1
                    if (r, g, b) not in all_rgb:
                        raise ValueError(f"{sid} f{f_idx+1}: raw cel off-GPL #{r:02X}{g:02X}{b:02X}")
                    if (r, g, b) in reserved_rgb:
                        raise ValueError(f"{sid} f{f_idx+1}: raw cel RESERVED #{r:02X}{g:02X}{b:02X}")
                    if colorable and not (r == g == b):
                        raise ValueError(f"{sid} f{f_idx+1}: raw cel non-neutral #{r:02X}{g:02X}{b:02X}")

    overlaps = sum(sum(1 for c in counts.values() if c > 1) for counts in per_frame_coords.values())
    if overlaps != 0:
        raise ValueError(f"{sid}: {overlaps} overlapping layer pixels in .aseprite cels")
    return info


def _check_anim_gates(sid: str, frames: list[Image.Image], kind: str) -> dict[str, Any] | None:
    if len(frames) <= 1:
        return None
    for f_i, fr in enumerate(frames):
        if fr.getbbox() is None:
            raise ValueError(f"{sid}: blank animation frame f{f_i + 1} (0 active pixels)")
    anim_tel = compute_anim_telemetry(frames, kind)
    if anim_tel["zero_delta_count"] != 0:
        raise ValueError(f"{sid}: zero_delta_count={anim_tel['zero_delta_count']} != 0")
    if anim_tel["max_min_step_ratio"] > 3.0:
        raise ValueError(f"{sid}: max_min_step_ratio={anim_tel['max_min_step_ratio']} > 3.0")
    if not (0.45 <= anim_tel["wrap_ratio"] <= 1.75):
        raise ValueError(f"{sid}: wrap_ratio={anim_tel['wrap_ratio']} outside [0.45, 1.75]")
    return anim_tel


def export_and_audit_sprite(
    spec: dict[str, Any], ase_path: Path, out_dir: Path, ase_bin: str,
    allowed_hex: dict[str, str], all_rgb: dict[tuple[int, int, int], str],
    reserved_rgb: dict[tuple[int, int, int], str], used_hexes: list[str],
) -> dict[str, Any]:
    """Audit `.aseprite` on disk, export PNGs/47-atlases into `out_dir`, enforce all gates."""
    sid = spec["id"]
    is_smooth = is_smooth_kind(spec["kind"])
    colorable = bool(spec.get("colorable", True))
    require_top_light = bool(spec.get("require_top_light", False))
    allow_multipart = bool(spec.get("allow_multipart", False))

    if not ase_path.exists():
        raise FileNotFoundError(f"{sid}: missing source {ase_path} (run terrestrial_kit.py --rebuild-sources)")

    audit_aseprite_binary_on_disk(spec, ase_path, all_rgb, reserved_rgb)

    png_dir = assert_inside_out_dir(out_dir / "png", out_dir)
    tiles47_dir = assert_inside_out_dir(out_dir / "tiles47", out_dir)
    png_dir.mkdir(parents=True, exist_ok=True)
    tiles47_dir.mkdir(parents=True, exist_ok=True)
    for old_fp in png_dir.glob(f"{sid}_f*.png"):
        assert_inside_out_dir(old_fp, out_dir).unlink()

    n_frames = len(spec["frames"])
    durations_ms = [int(f.get("duration_ms", 200)) for f in spec["frames"]]
    frame_pattern = assert_inside_out_dir(png_dir / f"{sid}_f{{frame1}}.png", out_dir)
    subprocess.run([ase_bin, "-b", str(ase_path), "--save-as", str(frame_pattern)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    frame_images: list[Image.Image] = []
    for f_idx in range(1, n_frames + 1):
        fim = Image.open(assert_inside_out_dir(png_dir / f"{sid}_f{f_idx}.png", out_dir)).convert("RGBA")
        ftel = analyze_rgba_image(fim, allowed_hex, reserved_rgb)
        if ftel["off_palette"] or ftel["reserved_hits"]:
            raise ValueError(f"{sid} f{f_idx}: palette violation off={ftel['off_palette']} res={ftel['reserved_hits']}")
        if colorable and ftel["max_chroma"] != 0:
            raise ValueError(f"{sid} f{f_idx}: max_chroma={ftel['max_chroma']} != 0")
        frame_images.append(fim)

    base_rec: dict[str, Any] = {
        "id": sid, "title": spec.get("title", sid), "element": spec.get("element", "terrestrial"),
        "source": "terrestrial", "category": spec["category"], "kind": "smooth_strip" if is_smooth else "single",
        "ase_relpath": spec["ase_relpath"], "tag": bake_tag(spec), "cell_w": 32, "cell_h": 32,
        "offset_x": 0, "offset_y": 0, "frame_count": n_frames, "durations_ms": durations_ms,
        "rewind": False, "colorable": colorable, "require_top_light": require_top_light,
        "allow_multipart": allow_multipart, "flat_of": spec.get("flat_of"),
        "default_tint": spec.get("default_tint", "#FFFFFF"),
        "citation": spec.get("citation", spec["ase_relpath"]), "description": spec.get("description", ""),
    }

    if not is_smooth:
        sheet_im = Image.new("RGBA", (32 * n_frames, 32), (0, 0, 0, 0))
        frame_tels: list[dict[str, Any]] = []
        for i, fim in enumerate(frame_images):
            sheet_im.paste(fim, (i * 32, 0))
            ftel = analyze_rgba_image(fim, allowed_hex, reserved_rgb)
            if not ftel["passes_bare_mask_gate"]:
                raise ValueError(f"{sid} f{i+1}: fails bare-mask gate (dom={ftel['dominant_rgb_share']})")
            if ftel["lone_pixel_count"] != 0:
                raise ValueError(f"{sid} f{i+1}: lone_pixel_count={ftel['lone_pixel_count']} != 0")
            if not allow_multipart and ftel["pieces"] != 1:
                raise ValueError(f"{sid} f{i+1}: pieces={ftel['pieces']} != 1 (allow_multipart=False)")
            if require_top_light and ftel["luma"]["top"] <= ftel["luma"]["bottom"]:
                raise ValueError(f"{sid} f{i+1}: top-down light failed top={ftel['luma']['top']} <= bottom={ftel['luma']['bottom']}")
            frame_tels.append(ftel)

        anim_tel = _check_anim_gates(sid, frame_images, "single")
        atlas_path = assert_inside_out_dir(png_dir / f"{sid}.png", out_dir)
        sheet_im.save(atlas_path)
        tel0 = frame_tels[0]
        return {
            **base_rec,
            "atlas_png_relpath": atlas_path.relative_to(out_dir.resolve()).as_posix(),
            "strip_png_relpath": None, "atlas_data_uri": png_to_data_uri(sheet_im), "strip_data_uri": None,
            "telemetry": {
                "frame1": tel0, "anim": anim_tel,
                "lint_f1": {"pieces": tel0["pieces"], "lone_pixel_count": tel0["lone_pixel_count"]}, "used_swatches": used_hexes,
            },
        }

    strip_sheet = Image.new("RGBA", (160 * n_frames, 32), (0, 0, 0, 0))
    atlas_47 = Image.new("RGBA", (47 * 32, 32 * n_frames), (0, 0, 0, 0))
    worst_dom_share, worst_dom_loc, worst_block_dom = 0.0, "", 0.0

    for f_i, fim in enumerate(frame_images):
        strip_sheet.paste(fim, (f_i * 160, 0))
        for b_idx in range(5):
            btel = analyze_rgba_image(fim.crop((b_idx * 32, 0, (b_idx + 1) * 32, 32)), allowed_hex, reserved_rgb)
            if (colorable and btel["max_chroma"] != 0) or btel["off_palette"] or btel["reserved_hits"]:
                raise ValueError(f"{sid} f{f_i+1} block={b_idx}: chroma/palette failure {btel}")
            if not btel["passes_bare_mask_gate"]:
                raise ValueError(f"{sid} f{f_i+1} block={b_idx}: raw Slice(5,1) block fails bare-mask gate (dom={btel['dominant_rgb_share']})")
            if btel["active_px"] >= 40 and btel["dominant_rgb_share"] > worst_block_dom:
                worst_block_dom = btel["dominant_rgb_share"]

        for j_i, j_val in enumerate(JUNCTIONS):
            j_tile = slice_junction_tile(fim, j_val)
            jtel = analyze_rgba_image(j_tile, allowed_hex, reserved_rgb)
            if (colorable and jtel["max_chroma"] != 0) or jtel["off_palette"] or jtel["reserved_hits"]:
                raise ValueError(f"{sid} f{f_i+1} j={j_val}: chroma/palette failure {jtel}")
            if not jtel["passes_bare_mask_gate"]:
                raise ValueError(f"{sid} f{f_i+1} j={j_val}: fails bare-mask gate (dom={jtel['dominant_rgb_share']})")
            if jtel["lone_pixel_count"] != 0:
                raise ValueError(f"{sid} f{f_i+1} j={j_val}: lone_pixel_count={jtel['lone_pixel_count']} != 0")
            if jtel["active_px"] >= 40 and jtel["dominant_rgb_share"] > worst_dom_share:
                worst_dom_share, worst_dom_loc = jtel["dominant_rgb_share"], f"f{f_i+1}:j{j_val}"
            atlas_47.paste(j_tile, (j_i * 32, f_i * 32))

    seam_tel = compute_seam_telemetry(frame_images)
    if seam_tel["max_alpha_diff"] != 0:
        raise ValueError(f"{sid}: seam max_alpha_diff={seam_tel['max_alpha_diff']} != 0 ({seam_tel['worst_alpha_desc']})")
    if seam_tel["max_seam_ratio"] > 2.75:
        raise ValueError(f"{sid}: max_seam_ratio={seam_tel['max_seam_ratio']} > 2.75")

    anim_tel = _check_anim_gates(sid, frame_images, "smooth_strip")
    j0_tel = analyze_rgba_image(slice_junction_tile(frame_images[0], 0), allowed_hex, reserved_rgb)
    j255_tel = analyze_rgba_image(slice_junction_tile(frame_images[0], 255), allowed_hex, reserved_rgb)
    if require_top_light and j0_tel["luma"]["top"] <= j0_tel["luma"]["bottom"]:
        raise ValueError(f"{sid} j=0: top-down light failed top={j0_tel['luma']['top']} <= bottom={j0_tel['luma']['bottom']}")

    f1_lone, f1_pieces = count_lone_and_pieces_rgba(frame_images[0])
    strip_path = assert_inside_out_dir(png_dir / f"{sid}_strip.png", out_dir)
    atlas_path = assert_inside_out_dir(tiles47_dir / f"{sid}_47.png", out_dir)
    strip_sheet.save(strip_path)
    atlas_47.save(atlas_path)

    return {
        **base_rec,
        "atlas_png_relpath": atlas_path.relative_to(out_dir.resolve()).as_posix(),
        "strip_png_relpath": strip_path.relative_to(out_dir.resolve()).as_posix(),
        "atlas_data_uri": png_to_data_uri(atlas_47),
        "strip_data_uri": png_to_data_uri(strip_sheet),
        "telemetry": {
            "j0_isolated": j0_tel, "j255_interior": j255_tel, "seams": seam_tel, "anim": anim_tel,
            "worst_47xframes_dom_rgb_share": worst_dom_share, "worst_47xframes_dom_loc": worst_dom_loc,
            "worst_block_dom_rgb_share": worst_block_dom,
            "lint_f1": {"pieces": f1_pieces, "lone_pixel_count": f1_lone}, "used_swatches": used_hexes,
        },
    }


FLAT_VARIANTS_MIN = 3
FLAT_PAIR_DIFF_MIN = 0.05
# Share of non-body pixels a hashed field repeats at a 32 px lag; plain wallpaper is 1.0.
FLAT_FIELD_LAG_MATCH_MAX = 0.85
FLAT_FIELD_TILES = 16


def _field_pick(gx: int, gy: int, n: int) -> int:
    h = (((gx & 0xFFFF) * 374761393) + ((gy & 0xFFFF) * 668265263) + 0x2545F491) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) % n


def audit_flat_repetition(records: list[dict[str, Any]], out_dir: Path) -> list[dict[str, Any]]:
    """Gate each strip's `flat_of` variants: count, shared outer ring, distinctness, field lattice."""
    png_dir = out_dir / "png"
    by_strip: dict[str, list[str]] = defaultdict(list)
    for sp in SPRITES:
        if sp.get("flat_of"):
            by_strip[sp["flat_of"]].append(sp["id"])
    exported = {rec["id"] for rec in records}
    results: list[dict[str, Any]] = []
    for strip_id, variant_ids in by_strip.items():
        if strip_id not in exported or not set(variant_ids) <= exported:
            print(f"[SKIP] flat repetition {strip_id}: strip and all variants must be exported together")
            continue
        if len(variant_ids) < FLAT_VARIANTS_MIN:
            raise ValueError(f"{strip_id}: {len(variant_ids)} flat variants < {FLAT_VARIANTS_MIN}")
        plain = Image.open(png_dir / f"{strip_id}_f1.png").convert("RGBA").crop((128, 0, 160, 32))
        tiles = [plain] + [Image.open(png_dir / f"{vid}_f1.png").convert("RGBA") for vid in variant_ids]
        names = [f"{strip_id}[4]"] + variant_ids
        pixels = [list(rgba_pixels(t)) for t in tiles]
        ring = [i for i in range(1024) if min(i % 32, i // 32, 31 - i % 32, 31 - i // 32) == 0]
        for name, px in zip(names[1:], pixels[1:], strict=True):
            bad = sum(1 for i in ring if px[i] != pixels[0][i])
            if bad:
                raise ValueError(f"{name}: {bad} outer-ring pixels differ from {names[0]}; it would not join")
        min_diff, min_pair = 1.0, ""
        for a in range(len(tiles)):
            for b in range(a + 1, len(tiles)):
                share = sum(1 for p, q in zip(pixels[a], pixels[b], strict=True) if p != q) / 1024
                if share < min_diff:
                    min_diff, min_pair = share, f"{names[a]}~{names[b]}"
        if min_diff < FLAT_PAIR_DIFF_MIN:
            raise ValueError(f"{strip_id}: {min_pair} differ on {min_diff:.3f} of pixels < {FLAT_PAIR_DIFF_MIN}")
        n = FLAT_FIELD_TILES
        body = Counter(pixels[0]).most_common(1)[0][0]
        field = [[_field_pick(gx, gy, len(tiles)) for gx in range(n)] for gy in range(n)]
        same = total = 0
        for gy in range(n):
            for gx in range(n):
                for dx, dy in ((1, 0), (0, 1)):
                    if gx + dx >= n or gy + dy >= n:
                        continue
                    for p, q in zip(pixels[field[gy][gx]], pixels[field[gy + dy][gx + dx]], strict=True):
                        if p != body or q != body:
                            total += 1
                            same += p == q
        lag_match = same / total
        if lag_match > FLAT_FIELD_LAG_MATCH_MAX:
            raise ValueError(f"{strip_id}: 32 px lag match {lag_match:.3f} > {FLAT_FIELD_LAG_MATCH_MAX} on a {n}x{n} field")
        print(f"[PASS] flat repetition {strip_id:30s} | pictures={len(tiles)} | minPairDiff={min_diff:.3f} | lag32={lag_match:.3f}")
        results.append({"strip": strip_id, "variants": variant_ids, "min_pair_diff": round(min_diff, 3), "lag32_match": round(lag_match, 3)})
    return results


def select_specs(only: list[str] | None) -> list[dict[str, Any]]:
    if not isinstance(SPRITES, list) or not SPRITES:
        raise ValueError("specs.SPRITES must be a non-empty list")
    seen: set[str] = set()
    for sp in SPRITES:
        if sp["id"] in seen:
            raise ValueError(f"Duplicate sprite id in specs: {sp['id']!r}")
        seen.add(sp["id"])
    if not only:
        return list(SPRITES)
    unknown = set(only) - seen
    if unknown:
        raise ValueError(f"Unknown --only sprite id(s): {sorted(unknown)}")
    only_set = set(only)
    return [sp for sp in SPRITES if sp["id"] in only_set]


def check_specs(only: list[str] | None = None) -> None:
    allowed_hex, _, reserved_rgb = parse_gpl(GPL_PATH)
    selected = select_specs(only)
    for sp in selected:
        validate_spec(sp, allowed_hex, reserved_rgb)
    print(f"specs valid: {len(selected)} terrestrial sprite(s) verified against {GPL_PATH.name}")


async def run_kit(out_dir: Path, rebuild_sources: bool = False, only: list[str] | None = None) -> None:
    allowed_hex, all_rgb, reserved_rgb = parse_gpl(GPL_PATH)
    selected = select_specs(only)
    validated = [(sp, *validate_spec(sp, allowed_hex, reserved_rgb)) for sp in selected]

    ase_bin = aseprite_binary()
    if rebuild_sources:
        async with open_mcp() as session:
            for sp, layer_order, layer_props, used_hexes in validated:
                ase_path = assert_inside_originals(PACK_ROOT / sp["ase_relpath"])
                await draw_source(session, sp, ase_path, 160 if is_smooth_kind(sp["kind"]) else 32, 32, used_hexes, layer_order, layer_props)

    records: list[dict[str, Any]] = []
    for sp, _, _, used_hexes in validated:
        ase_path = assert_inside_originals(PACK_ROOT / sp["ase_relpath"])
        rec = export_and_audit_sprite(sp, ase_path, out_dir, ase_bin, allowed_hex, all_rgb, reserved_rgb, used_hexes)
        records.append(rec)
        tel = rec["telemetry"]
        if rec["kind"] == "single":
            f1 = tel["frame1"]
            print(f"[PASS] {rec['id']:32s} | single       | f={rec['frame_count']:2d} | px={f1['active_px']:4d} | domRGB={f1['dominant_rgb_share']:.3f}")
        else:
            j255, seams = tel["j255_interior"], tel["seams"]
            print(
                f"[PASS] {rec['id']:32s} | smooth_strip | f={rec['frame_count']:2d} | "
                f"j255_dom={j255['dominant_rgb_share']:.3f} (max47={tel['worst_47xframes_dom_rgb_share']:.3f}, maxBlk={tel['worst_block_dom_rgb_share']:.3f}) | "
                f"alphaMAX={seams['max_alpha_diff']} | seamRatio={seams['max_seam_ratio']:.2f}"
            )

    audit_flat_repetition(records, out_dir)

    manifests_dir = assert_inside_out_dir(out_dir / "manifests", out_dir)
    manifests_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = assert_inside_out_dir(manifests_dir / "terrestrial.json", out_dir)

    if only and manifest_path.exists():
        existing_items = json.loads(manifest_path.read_text(encoding="utf-8"))
        merged = {item["id"]: item for item in existing_items}
        for rec in records:
            merged[rec["id"]] = rec
        ordered_ids = [sp["id"] for sp in SPRITES if sp["id"] in merged]
        extra_ids = [k for k in merged if k not in set(ordered_ids)]
        final_records = [merged[k] for k in ordered_ids + extra_ids]
    else:
        final_records = records

    manifest_path.write_text(json.dumps(final_records, indent=2), encoding="utf-8")
    print(f"Wrote manifest: {manifest_path} ({len(final_records)} sprite(s))")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build, export, and audit Tales from Space terrestrial sprites.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="output root for png/, tiles47/, and manifests/")
    parser.add_argument("--only", action="append", metavar="ID", help="process only this sprite id (repeatable)")
    parser.add_argument("--check-specs", action="store_true", help="validate SPRITES in pure Python without Aseprite/MCP")
    parser.add_argument("--rebuild-sources", action="store_true", help="redraw .aseprite sources via aseprite_mcp before auditing")
    args = parser.parse_args()
    if args.check_specs:
        check_specs(args.only)
        return
    asyncio.run(run_kit(Path(args.out_dir).resolve(), args.rebuild_sources, args.only))


if __name__ == "__main__":
    main()
