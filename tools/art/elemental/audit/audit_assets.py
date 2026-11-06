#!/usr/bin/env python3
"""
Audit of the elemental matter and fire .aseprite sources (assets/originals/art/matter and
assets/originals/art/fx/fire). Pure Python + Pillow.
Audits directly from .aseprite binary files, Aseprite CLI frame exports, manifests/*.json,
gallery/gallery_data.js, and tales-from-space.gpl across ALL frames and ALL 47 junctions.
Reads and writes under --out-dir (default <pack>/target/art/elemental); run elemental_kit.py
and build_gallery.py first so the manifests and gallery data exist.
"""
from __future__ import annotations

import argparse
import base64
from collections import Counter, defaultdict
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import zlib

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from elemental_kit import (  # noqa: E402
    DEFAULT_OUT_DIR,
    GPL_PATH,
    JUNCTIONS,
    PACK_ROOT,
    aseprite_binary,
    slice_junction_tile as slice_junction_im,
)

WORKTREE_ROOT = PACK_ROOT


def parse_gpl(path: Path):
    all_swatches: dict[tuple[int, int, int], str] = {}
    reserved_swatches: dict[tuple[int, int, int], str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if not s or s.startswith(("GIMP Palette", "Name:", "Columns:", "#")):
            continue
        parts = s.split(None, 3)
        if len(parts) >= 3:
            rgb = (int(parts[0]), int(parts[1]), int(parts[2]))
            name = parts[3] if len(parts) > 3 else ""
            all_swatches[rgb] = name
            token = name.split()[0] if name else ""
            if "reserved" in token.lower():
                reserved_swatches[rgb] = name
    return all_swatches, reserved_swatches


def parse_aseprite_binary(path: Path) -> dict:
    data = path.read_bytes()
    file_size, magic, frames, width, height, depth, flags, speed = struct.unpack_from(
        "<IHHHHHIH", data, 0
    )
    if magic != 0xA5E0:
        raise ValueError(f"{path}: bad magic {magic:#x}")

    pos = 128
    layers = []
    tags = []
    palette_entries = {}
    frame_durations = []
    cels = []
    cel_map = {}

    for f_idx in range(frames):
        f_bytes, f_magic, old_chunks, duration, _, new_chunks = struct.unpack_from(
            "<IHHH2sI", data, pos
        )
        if f_magic != 0xF1FA:
            raise ValueError(f"{path} frame {f_idx}: bad frame magic {f_magic:#x}")
        n_chunks = new_chunks if new_chunks != 0 else old_chunks
        frame_durations.append(duration)
        c_pos = pos + 16
        for _ in range(n_chunks):
            c_size, c_type = struct.unpack_from("<IH", data, c_pos)
            c_body = data[c_pos + 6 : c_pos + c_size]
            if c_type == 0x2004:
                l_flags, l_type, child_lvl, def_w, def_h, blend, opacity = struct.unpack_from(
                    "<HHHHHHB", c_body, 0
                )
                name_len = struct.unpack_from("<H", c_body, 16)[0]
                lname = c_body[18 : 18 + name_len].decode("utf-8", errors="replace")
                layers.append(
                    {
                        "flags": l_flags,
                        "visible": bool(l_flags & 1),
                        "type": l_type,
                        "blend": blend,
                        "opacity": opacity,
                        "name": lname,
                    }
                )
            elif c_type == 0x2005:
                l_idx, cx, cy, copacity, cel_type, z_idx = struct.unpack_from(
                    "<HhhBHh", c_body, 0
                )
                if cel_type == 0:
                    cw, ch = struct.unpack_from("<HH", c_body, 16)
                    raw_px = c_body[20 : 20 + cw * ch * (depth // 8)]
                    cel_map[(f_idx, l_idx)] = (cx, cy, cw, ch, copacity, raw_px)
                    cels.append((f_idx, l_idx, cx, cy, cw, ch, copacity, raw_px))
                elif cel_type == 1:
                    link_frame = struct.unpack_from("<H", c_body, 16)[0]
                    cx2, cy2, cw, ch, _, raw_px = cel_map[(link_frame, l_idx)]
                    cel_map[(f_idx, l_idx)] = (cx, cy, cw, ch, copacity, raw_px)
                    cels.append((f_idx, l_idx, cx, cy, cw, ch, copacity, raw_px))
                elif cel_type == 2:
                    cw, ch = struct.unpack_from("<HH", c_body, 16)
                    raw_px = zlib.decompress(c_body[20:])
                    cel_map[(f_idx, l_idx)] = (cx, cy, cw, ch, copacity, raw_px)
                    cels.append((f_idx, l_idx, cx, cy, cw, ch, copacity, raw_px))
            elif c_type == 0x2018:
                num_tags = struct.unpack_from("<H", c_body, 0)[0]
                t_off = 10
                for _t in range(num_tags):
                    t_from, t_to, t_dir, t_rep = struct.unpack_from("<HHBH", c_body, t_off)
                    t_off += 17
                    t_nlen = struct.unpack_from("<H", c_body, t_off)[0]
                    t_off += 2
                    t_name = c_body[t_off : t_off + t_nlen].decode("utf-8", errors="replace")
                    t_off += t_nlen
                    tags.append(
                        {
                            "name": t_name,
                            "from": t_from,
                            "to": t_to,
                            "dir": t_dir,
                            "repeat": t_rep,
                        }
                    )
            elif c_type == 0x2019:
                p_size, first_idx, last_idx = struct.unpack_from("<III", c_body, 0)
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
        "width": width,
        "height": height,
        "depth": depth,
        "frames": frames,
        "durations": frame_durations,
        "layers": layers,
        "tags": tags,
        "palette": palette_entries,
        "cels": cels,
    }


def check_bare_mask_js_exact(im: Image.Image) -> dict:
    px = list(im.getdata())
    hist: Counter[tuple[int, int, int]] = Counter()
    area = 0
    max_chroma = 0
    for r, g, b, a in px:
        if a == 0:
            continue
        hist[(r, g, b)] += 1
        area += 1
        c = max(r, g, b) - min(r, g, b)
        if c > max_chroma:
            max_chroma = c
    if area == 0:
        return {
            "area": 0,
            "dom_share": 0.0,
            "dom_rgb": None,
            "dom_chroma": 0,
            "max_chroma": 0,
            "unique_rgb": 0,
            "js_gate_pass": True,
            "strict_share_pass": True,
        }
    dom_rgb, dom_count = hist.most_common(1)[0]
    dom_chroma = max(dom_rgb) - min(dom_rgb)
    frac = dom_count / area
    js_pass = not (area >= 40 and dom_chroma <= 6 and frac >= 0.85)
    strict_pass = not (area >= 40 and frac >= 0.85)
    return {
        "area": area,
        "dom_share": frac,
        "dom_rgb": dom_rgb,
        "dom_chroma": dom_chroma,
        "max_chroma": max_chroma,
        "unique_rgb": len(hist),
        "js_gate_pass": js_pass,
        "strict_share_pass": strict_pass,
    }


def get_col(im: Image.Image, x: int, y0: int, y1: int) -> list[tuple[int, int, int, int]]:
    return [im.getpixel((x, y)) for y in range(y0, y1)]


def get_row(im: Image.Image, y: int, x0: int, x1: int) -> list[tuple[int, int, int, int]]:
    return [im.getpixel((x, y)) for x in range(x0, x1)]


def boundary_mae(edge_a: list[tuple[int, int, int, int]], edge_b: list[tuple[int, int, int, int]]):
    n = len(edge_a)
    adiffs = []
    ldiffs = []
    for (r1, g1, b1, a1), (r2, g2, b2, a2) in zip(edge_a, edge_b):
        adiffs.append(abs(a1 - a2))
        l1 = (0.2126 * r1 + 0.7152 * g1 + 0.0722 * b1) * (a1 / 255.0)
        l2 = (0.2126 * r2 + 0.7152 * g2 + 0.0722 * b2) * (a2 / 255.0)
        ldiffs.append(abs(l1 - l2))
    return sum(adiffs) / n, max(adiffs), sum(ldiffs) / n, max(ldiffs)


def image_diff_stats(im_a: Image.Image, im_b: Image.Image) -> tuple[int, float]:
    ba = im_a.tobytes()
    bb = im_b.tobytes()
    changed_px = 0
    total_abs = 0
    for i in range(0, len(ba), 4):
        dr = abs(ba[i] - bb[i])
        dg = abs(ba[i + 1] - bb[i + 1])
        db = abs(ba[i + 2] - bb[i + 2])
        da = abs(ba[i + 3] - bb[i + 3])
        if dr or dg or db or da:
            changed_px += 1
            total_abs += dr + dg + db + da
    return changed_px, total_abs / len(ba)


def alpha_centroid(im: Image.Image) -> tuple[float, float]:
    w, h = im.size
    tot = 0
    sx = 0.0
    sy = 0.0
    px = im.load()
    for y in range(h):
        for x in range(w):
            a = px[x, y][3]
            if a:
                tot += a
                sx += x * a
                sy += y * a
    if tot == 0:
        return (0.0, 0.0)
    return (sx / tot, sy / tot)


def main():
    parser = argparse.ArgumentParser(description="Audit the elemental .aseprite sources")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR))
    args = parser.parse_args()
    out_dir = Path(args.out_dir).resolve()
    AUDIT_DIR = out_dir / "audit"
    ASEPRITE_BIN = aseprite_binary()
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    export_tmp = AUDIT_DIR / "ase_exports"
    export_tmp.mkdir(parents=True, exist_ok=True)

    all_gpl, reserved_gpl = parse_gpl(GPL_PATH)
    print(f"Loaded tales-from-space.gpl: {len(all_gpl)} unique RGB swatches, {len(reserved_gpl)} reserved swatches:")
    for rgb, name in reserved_gpl.items():
        print(f"  RESERVED: #{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X} -> {name}")

    manifest_sprites = []
    for dom in ("gasses", "liquids", "solids", "fire"):
        mp = out_dir / "manifests" / f"{dom}.json"
        items = json.loads(mp.read_text(encoding="utf-8"))
        manifest_sprites.extend(items)

    gd_raw = (out_dir / "gallery" / "gallery_data.js").read_text(encoding="utf-8")
    gd_json = gd_raw.split("window.ELEMENTAL_GALLERY_DATA = ", 1)[1].rstrip(";\n")
    gallery_data = json.loads(gd_json)

    print(f"\nManifest sprite count: {len(manifest_sprites)} | gallery_data sprite count: {len(gallery_data['sprites'])}")

    findings = []
    sprite_summaries = []

    disk_ase = sorted(
        list((WORKTREE_ROOT / "assets/originals/art/fx/fire").glob("*.aseprite"))
        + list((WORKTREE_ROOT / "assets/originals/art/matter").rglob("*.aseprite"))
    )
    manifest_paths = {(WORKTREE_ROOT / sp["ase_relpath"]).resolve() for sp in manifest_sprites}
    if set(p.resolve() for p in disk_ase) != manifest_paths:
        findings.append(("CRITICAL", "manifest_vs_disk", f"Disk .aseprite set ({len(disk_ase)}) != manifest set ({len(manifest_paths)})"))

    for sp in manifest_sprites:
        sid = sp["id"]
        kind = sp["kind"]
        colorable = sp["colorable"]
        element = sp["element"]
        ase_path = WORKTREE_ROOT / sp["ase_relpath"]
        if not ase_path.exists():
            findings.append(("CRITICAL", sid, f"Missing .aseprite file: {ase_path}"))
            continue

        ase_info = parse_aseprite_binary(ase_path)
        exp_w = 32 if kind == "single" else 160
        if (ase_info["width"], ase_info["height"]) != (exp_w, 32):
            findings.append(("CRITICAL", sid, f"Wrong canvas size {ase_info['width']}x{ase_info['height']}, expected {exp_w}x32"))
        if ase_info["depth"] != 32:
            findings.append(("CRITICAL", sid, f"Color depth is {ase_info['depth']}, expected 32-bit RGBA"))
        if ase_info["frames"] != sp["frame_count"]:
            findings.append(("CRITICAL", sid, f"Frame count mismatch: .aseprite={ase_info['frames']} vs manifest={sp['frame_count']}"))
        if ase_info["durations"] != sp["durations_ms"]:
            findings.append(("CRITICAL", sid, f"Durations mismatch: .aseprite={ase_info['durations']} vs manifest={sp['durations_ms']}"))

        for f_i, dur in enumerate(ase_info["durations"], 1):
            if dur < 100 or dur % 100 != 0:
                findings.append(("MAJOR", sid, f"Frame {f_i} duration {dur}ms violates 100ms decisecond rule"))

        if not ase_info["tags"]:
            findings.append(("MAJOR", sid, "No Aseprite tag defined (lunatic Ase/AseAnim requires a Forward tag)"))
        else:
            for tg in ase_info["tags"]:
                if tg["dir"] != 0:
                    findings.append(("CRITICAL", sid, f"Tag {tg['name']!r} has non-Forward direction {tg['dir']}"))
                if tg["from"] != 0 or tg["to"] != ase_info["frames"] - 1:
                    findings.append(("MINOR", sid, f"Tag {tg['name']!r} spans {tg['from']}..{tg['to']} instead of 0..{ase_info['frames']-1}"))

        off_gpl_pal = []
        reserved_pal = []
        for p_idx, (pr, pg, pb, pa) in ase_info["palette"].items():
            if pa == 0 and (pr, pg, pb) == (0, 0, 0):
                continue
            if (pr, pg, pb) not in all_gpl:
                off_gpl_pal.append(f"idx {p_idx}=#{pr:02X}{pg:02X}{pb:02X}")
            if (pr, pg, pb) in reserved_gpl:
                reserved_pal.append(f"#{pr:02X}{pg:02X}{pb:02X} ({reserved_gpl[(pr, pg, pb)]})")
        if off_gpl_pal:
            findings.append(("CRITICAL", sid, f"Embedded palette has off-GPL colors: {off_gpl_pal}"))
        if reserved_pal:
            findings.append(("CRITICAL", sid, f"Embedded palette uses RESERVED antagonist swatches: {reserved_pal}"))

        off_gpl_cel = set()
        reserved_cel = set()
        cel_chroma_max = 0
        overlapping_layer_pixels = 0
        per_frame_coords = defaultdict(Counter)

        for f_idx, l_idx, cx, cy, cw, ch, copacity, raw_px in ase_info["cels"]:
            if not ase_info["layers"][l_idx]["visible"]:
                continue
            for py in range(ch):
                gy = cy + py
                row_base = py * cw * 4
                for px_x in range(cw):
                    gx = cx + px_x
                    idx = row_base + px_x * 4
                    a = raw_px[idx + 3]
                    if a > 0:
                        r, g, b = raw_px[idx], raw_px[idx + 1], raw_px[idx + 2]
                        if 0 <= gx < exp_w and 0 <= gy < 32:
                            per_frame_coords[f_idx][(gx, gy)] += 1
                        ch_v = max(r, g, b) - min(r, g, b)
                        if ch_v > cel_chroma_max:
                            cel_chroma_max = ch_v
                        if (r, g, b) not in all_gpl:
                            off_gpl_cel.add(f"#{r:02X}{g:02X}{b:02X}")
                        if (r, g, b) in reserved_gpl:
                            reserved_cel.add(f"#{r:02X}{g:02X}{b:02X}")

        for f_idx, coord_counts in per_frame_coords.items():
            overlapping_layer_pixels += sum(1 for c in coord_counts.values() if c > 1)

        if off_gpl_cel:
            findings.append(("CRITICAL", sid, f"Raw cel pixels contain off-GPL colors: {sorted(off_gpl_cel)}"))
        if reserved_cel:
            findings.append(("CRITICAL", sid, f"Raw cel pixels use RESERVED swatches: {sorted(reserved_cel)}"))
        if colorable and cel_chroma_max > 0:
            findings.append(("CRITICAL", sid, f"Colorable sprite has raw cel chroma {cel_chroma_max} > 0"))

        out_pattern = export_tmp / f"{sid}_f{{frame1}}.png"
        subprocess.run(
            [str(ASEPRITE_BIN), "-b", str(ase_path), "--save-as", str(out_pattern)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        frames_im = [
            Image.open(export_tmp / f"{sid}_f{f_i}.png").convert("RGBA")
            for f_i in range(1, ase_info["frames"] + 1)
        ]

        # Verify gallery_data.js atlas_data_uri matches fresh .aseprite export byte-for-pixel
        atlas_b64 = sp["atlas_data_uri"].split(",", 1)[1]
        atlas_im = Image.open(io.BytesIO(base64.b64decode(atlas_b64))).convert("RGBA")
        if kind == "single":
            for f_i, fim in enumerate(frames_im):
                cached_cell = atlas_im.crop((f_i * 32, 0, (f_i + 1) * 32, 32))
                if fim.tobytes() != cached_cell.tobytes():
                    findings.append(("CRITICAL", sid, f"Stale gallery_data.js atlas on frame {f_i+1}: differs from .aseprite on disk!"))
        else:
            strip_b64 = sp["strip_data_uri"].split(",", 1)[1]
            strip_im = Image.open(io.BytesIO(base64.b64decode(strip_b64))).convert("RGBA")
            for f_i, fim in enumerate(frames_im):
                cached_strip = strip_im.crop((f_i * 160, 0, (f_i + 1) * 160, 32))
                if fim.tobytes() != cached_strip.tobytes():
                    findings.append(("CRITICAL", sid, f"Stale gallery_data.js strip on frame {f_i+1}: differs from .aseprite on disk!"))
                for j_i, j_val in enumerate(JUNCTIONS):
                    sliced = slice_junction_im(fim, j_val)
                    cached_j = atlas_im.crop((j_i * 32, f_i * 32, (j_i + 1) * 32, (f_i + 1) * 32))
                    if sliced.tobytes() != cached_j.tobytes():
                        findings.append(("CRITICAL", sid, f"Stale gallery_data.js 47-atlas at f{f_i+1} j={j_val}"))
                        break

        flat_off_gpl = set()
        flat_reserved = set()
        flat_max_chroma = 0
        worst_dom_share = 0.0
        worst_dom_loc = ""
        bare_mask_failures = []
        strict_share_failures = []

        for f_i, fim in enumerate(frames_im):
            for r, g, b, a in fim.getdata():
                if a == 0:
                    continue
                c = max(r, g, b) - min(r, g, b)
                if c > flat_max_chroma:
                    flat_max_chroma = c
                if (r, g, b) not in all_gpl:
                    flat_off_gpl.add(f"#{r:02X}{g:02X}{b:02X}")
                if (r, g, b) in reserved_gpl:
                    flat_reserved.add(f"#{r:02X}{g:02X}{b:02X}")

            if kind == "single":
                bm = check_bare_mask_js_exact(fim)
                if bm["area"] >= 40 and bm["dom_share"] > worst_dom_share:
                    worst_dom_share = bm["dom_share"]
                    worst_dom_loc = f"f{f_i+1}"
                if not bm["js_gate_pass"]:
                    bare_mask_failures.append(f"f{f_i+1}(area={bm['area']}, share={bm['dom_share']:.3f}, rgb={bm['dom_rgb']})")
                if not bm["strict_share_pass"]:
                    strict_share_failures.append(f"f{f_i+1}(area={bm['area']}, share={bm['dom_share']:.3f}, rgb={bm['dom_rgb']})")
            else:
                for j_val in JUNCTIONS:
                    j_tile = slice_junction_im(fim, j_val)
                    bm = check_bare_mask_js_exact(j_tile)
                    if bm["area"] >= 40 and bm["dom_share"] > worst_dom_share:
                        worst_dom_share = bm["dom_share"]
                        worst_dom_loc = f"f{f_i+1}:j{j_val}"
                    if not bm["js_gate_pass"]:
                        bare_mask_failures.append(f"f{f_i+1}:j{j_val}(area={bm['area']}, share={bm['dom_share']:.3f}, rgb={bm['dom_rgb']})")
                    if not bm["strict_share_pass"]:
                        strict_share_failures.append(f"f{f_i+1}:j{j_val}(area={bm['area']}, share={bm['dom_share']:.3f}, rgb={bm['dom_rgb']})")

        if colorable and flat_max_chroma > 0:
            findings.append(("CRITICAL", sid, f"Flattened RGBA has chroma={flat_max_chroma} > 0 on colorable sprite!"))
        if flat_reserved:
            findings.append(("CRITICAL", sid, f"Flattened RGBA hits reserved swatch: {sorted(flat_reserved)}"))
        if flat_off_gpl:
            findings.append((
                "MINOR" if overlapping_layer_pixels > 0 else "CRITICAL",
                sid,
                f"Flattened RGBA produces {len(flat_off_gpl)} blended non-GPL RGB values (overlapping_layer_px={overlapping_layer_pixels}): sample={sorted(flat_off_gpl)[:6]}",
            ))
        if bare_mask_failures:
            findings.append(("CRITICAL", sid, f"FAILS test-bake-art.mjs no_sprite_is_a_bare_color_mask on {len(bare_mask_failures)} cell(s): {bare_mask_failures[:8]}"))
        elif strict_share_failures:
            findings.append(("MAJOR", sid, f"Chromatic sprite has dominant_rgb_share >= 0.85 on {len(strict_share_failures)} cell(s): {strict_share_failures[:8]}"))

        # Animation checks
        anim_stats = {}
        if len(frames_im) > 1:
            F = len(frames_im)
            changed_counts = []
            step_maes = []
            centroids_x = []
            centroids_y = []
            for f_i in range(F):
                nxt = (f_i + 1) % F
                c_px, mae = image_diff_stats(frames_im[f_i], frames_im[nxt])
                changed_counts.append(c_px)
                step_maes.append(mae)
                cx_v, cy_v = alpha_centroid(frames_im[f_i])
                centroids_x.append(cx_v)
                centroids_y.append(cy_v)

            zero_delta_junctions = []
            if kind == "single":
                for f_i in range(F):
                    nxt = (f_i + 1) % F
                    if frames_im[f_i].tobytes() == frames_im[nxt].tobytes():
                        zero_delta_junctions.append(f"f{f_i+1}->f{nxt+1}")
            else:
                for j_val in JUNCTIONS:
                    j_frames = [slice_junction_im(fr, j_val) for fr in frames_im]
                    for f_i in range(F):
                        nxt = (f_i + 1) % F
                        if j_frames[f_i].tobytes() == j_frames[nxt].tobytes():
                            zero_delta_junctions.append(f"j{j_val}:f{f_i+1}->f{nxt+1}")

            if zero_delta_junctions:
                findings.append(("MAJOR", sid, f"Identical consecutive frames on {len(zero_delta_junctions)} junction transition(s): {zero_delta_junctions[:8]}"))

            mean_inner = sum(step_maes[:-1]) / max(1, len(step_maes) - 1)
            wrap_ratio = step_maes[-1] / max(1e-6, mean_inner)
            if wrap_ratio > 1.75 or wrap_ratio < 0.45:
                findings.append(("MAJOR", sid, f"Loop wrap-around snap (f{F}->f1 MAE={step_maes[-1]:.2f} vs mean={mean_inner:.2f}, ratio={wrap_ratio:.2f})"))

            ping_pong_matches = sum(
                1 for f_i in range(F) if frames_im[f_i].tobytes() == frames_im[(f_i + 2) % F].tobytes()
            )
            if ping_pong_matches > 0:
                findings.append(("MAJOR", sid, f"2-frame ping-pong / jello repetition detected ({ping_pong_matches}/{F} frames equal f+2)"))

            anim_stats = {
                "changed_px_min": min(changed_counts),
                "changed_px_max": max(changed_counts),
                "step_mae_mean": round(mean_inner, 3),
                "wrap_mae": round(step_maes[-1], 3),
                "wrap_ratio": round(wrap_ratio, 2),
                "centroid_span_x": round(max(centroids_x) - min(centroids_x), 2),
                "centroid_span_y": round(max(centroids_y) - min(centroids_y), 2),
            }

        # Seam checks across ALL frames & ALL 47 junctions
        seam_stats = {}
        if kind == "smooth_strip":
            max_quad_luma_mae = 0.0
            worst_quad_desc = ""
            max_quad_ratio = 0.0
            worst_quad_ratio_desc = ""

            max_tile_luma_mae = 0.0
            worst_tile_desc = ""
            max_tile_ratio = 0.0
            worst_tile_ratio_desc = ""

            for f_i, fim in enumerate(frames_im):
                j_tiles = {jv: slice_junction_im(fim, jv) for jv in JUNCTIONS}

                for jv, jt in j_tiles.items():
                    for half_name, (y0, y1) in (("top", (0, 16)), ("bot", (16, 32))):
                        amae, amax, lmae, lmax = boundary_mae(get_col(jt, 15, y0, y1), get_col(jt, 16, y0, y1))
                        _, _, lref1, _ = boundary_mae(get_col(jt, 14, y0, y1), get_col(jt, 15, y0, y1))
                        _, _, lref2, _ = boundary_mae(get_col(jt, 16, y0, y1), get_col(jt, 17, y0, y1))
                        ref_l = max(2.5, 0.5 * (lref1 + lref2))
                        ratio = lmae / ref_l
                        if lmae > max_quad_luma_mae:
                            max_quad_luma_mae = lmae
                            worst_quad_desc = f"f{f_i+1}:j{jv}:V-{half_name}(alphaMAE={amae:.1f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f})"
                        if ratio > max_quad_ratio and lmae > 8.0:
                            max_quad_ratio = ratio
                            worst_quad_ratio_desc = f"f{f_i+1}:j{jv}:V-{half_name}(ratio={ratio:.2f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f}, alphaMAE={amae:.1f})"

                    for half_name, (x0, x1) in (("left", (0, 16)), ("right", (16, 32))):
                        amae, amax, lmae, lmax = boundary_mae(get_row(jt, 15, x0, x1), get_row(jt, 16, x0, x1))
                        _, _, lref1, _ = boundary_mae(get_row(jt, 14, x0, x1), get_row(jt, 15, x0, x1))
                        _, _, lref2, _ = boundary_mae(get_row(jt, 16, x0, x1), get_row(jt, 17, x0, x1))
                        ref_l = max(2.5, 0.5 * (lref1 + lref2))
                        ratio = lmae / ref_l
                        if lmae > max_quad_luma_mae:
                            max_quad_luma_mae = lmae
                            worst_quad_desc = f"f{f_i+1}:j{jv}:H-{half_name}(alphaMAE={amae:.1f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f})"
                        if ratio > max_quad_ratio and lmae > 8.0:
                            max_quad_ratio = ratio
                            worst_quad_ratio_desc = f"f{f_i+1}:j{jv}:H-{half_name}(ratio={ratio:.2f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f}, alphaMAE={amae:.1f})"

                blocks = [fim.crop((b * 32, 0, (b + 1) * 32, 32)) for b in range(5)]
                for b_left, b_right in ((2, 2), (3, 2), (2, 3), (4, 4)):
                    for half_name, (y0, y1) in (("top", (0, 16)), ("bot", (16, 32))):
                        amae, amax, lmae, lmax = boundary_mae(get_col(blocks[b_left], 31, y0, y1), get_col(blocks[b_right], 0, y0, y1))
                        _, _, lref1, _ = boundary_mae(get_col(blocks[b_left], 30, y0, y1), get_col(blocks[b_left], 31, y0, y1))
                        _, _, lref2, _ = boundary_mae(get_col(blocks[b_right], 0, y0, y1), get_col(blocks[b_right], 1, y0, y1))
                        ref_l = max(2.5, 0.5 * (lref1 + lref2))
                        ratio = lmae / ref_l
                        if lmae > max_tile_luma_mae:
                            max_tile_luma_mae = lmae
                            worst_tile_desc = f"f{f_i+1}:HJoin(B{b_left}->B{b_right},{half_name}: alphaMAE={amae:.1f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f})"
                        if ratio > max_tile_ratio and lmae > 8.0:
                            max_tile_ratio = ratio
                            worst_tile_ratio_desc = f"f{f_i+1}:HJoin(B{b_left}->B{b_right},{half_name}: ratio={ratio:.2f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f}, alphaMAE={amae:.1f})"

                for b_top, b_bot in ((1, 1), (3, 1), (1, 3), (4, 4)):
                    for half_name, (x0, x1) in (("left", (0, 16)), ("right", (16, 32))):
                        amae, amax, lmae, lmax = boundary_mae(get_row(blocks[b_top], 31, x0, x1), get_row(blocks[b_bot], 0, x0, x1))
                        _, _, lref1, _ = boundary_mae(get_row(blocks[b_top], 30, x0, x1), get_row(blocks[b_top], 31, x0, x1))
                        _, _, lref2, _ = boundary_mae(get_row(blocks[b_bot], 0, x0, x1), get_row(blocks[b_bot], 1, x0, x1))
                        ref_l = max(2.5, 0.5 * (lref1 + lref2))
                        ratio = lmae / ref_l
                        if lmae > max_tile_luma_mae:
                            max_tile_luma_mae = lmae
                            worst_tile_desc = f"f{f_i+1}:VJoin(B{b_top}->B{b_bot},{half_name}: alphaMAE={amae:.1f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f})"
                        if ratio > max_tile_ratio and lmae > 8.0:
                            max_tile_ratio = ratio
                            worst_tile_ratio_desc = f"f{f_i+1}:VJoin(B{b_top}->B{b_bot},{half_name}: ratio={ratio:.2f}, lumaMAE={lmae:.1f}, ref={ref_l:.1f}, alphaMAE={amae:.1f})"

            if max_quad_ratio > 2.8:
                findings.append(("MAJOR", sid, f"Intra-tile quadrant seam discontinuity: {worst_quad_ratio_desc}"))
            if max_tile_ratio > 2.8:
                findings.append(("MAJOR", sid, f"Inter-tile boundary seam discontinuity: {worst_tile_ratio_desc}"))

            seam_stats = {
                "max_quad_luma_mae": round(max_quad_luma_mae, 2),
                "max_quad_ratio": round(max_quad_ratio, 2),
                "worst_quad": worst_quad_desc,
                "worst_quad_ratio": worst_quad_ratio_desc,
                "max_tile_luma_mae": round(max_tile_luma_mae, 2),
                "max_tile_ratio": round(max_tile_ratio, 2),
                "worst_tile": worst_tile_desc,
                "worst_tile_ratio": worst_tile_ratio_desc,
            }

        sprite_summaries.append({
            "id": sid,
            "element": element,
            "kind": kind,
            "colorable": colorable,
            "frames": ase_info["frames"],
            "durations": ase_info["durations"],
            "overlapping_layer_px": overlapping_layer_pixels,
            "flat_off_gpl_count": len(flat_off_gpl),
            "worst_dom_share": round(worst_dom_share, 3),
            "worst_dom_loc": worst_dom_loc,
            "anim": anim_stats,
            "seam": seam_stats,
        })

    report = {
        "total_sprites": len(sprite_summaries),
        "findings_count": len(findings),
        "findings": [{"severity": sev, "sprite": sid, "detail": det} for sev, sid, det in findings],
        "summaries": sprite_summaries,
    }
    out_json = AUDIT_DIR / "audit_report.json"
    out_json.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"\n=== AUDIT COMPLETE: {len(findings)} findings across {len(sprite_summaries)} sprites ===")
    for sev, sid, det in findings:
        print(f"[{sev:8s}] {sid:30s} | {det}")

    print("\n=== ANIMATION & FRAME COUNT SUMMARY ===")
    for s in sprite_summaries:
        if s["frames"] > 1 or s["element"] in ("gas", "liquid", "fire"):
            print(
                f"  {s['id']:32s} | f={s['frames']} durs={s['durations']} | "
                f"worstDom={s['worst_dom_share']:.3f}@{s['worst_dom_loc']} | anim={s['anim']}"
            )

    print("\n=== SMOOTH STRIP SEAM SUMMARY ===")
    for s in sprite_summaries:
        if s["kind"] == "smooth_strip":
            sm = s["seam"]
            print(
                f"  {s['id']:32s} | quadRatio={sm['max_quad_ratio']:.2f} ({sm['worst_quad_ratio'] or sm['worst_quad']}) | "
                f"tileRatio={sm['max_tile_ratio']:.2f} ({sm['worst_tile_ratio'] or sm['worst_tile']})"
            )


if __name__ == "__main__":
    main()
