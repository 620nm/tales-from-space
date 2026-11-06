#!/usr/bin/env python3
r"""
Assemble the standalone Tales from Space Terrestrial Art Workbench in `<out-dir>/workbench/`.

Reads `<out-dir>/manifests/terrestrial.json` and `<out-dir>/manifests/existing.json`,
copies the authored `{index.html, workbench.css, workbench_render.js, workbench_app.js}`
from `tools/art/terrestrial/workbench/`, and writes `<out-dir>/workbench/workbench_data.js`
(`window.WORKBENCH_DATA = ...;`) with inline base64 PNG data URIs for `file://` use.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sys
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from schema_contract import (  # noqa: E402
    BIOME_TINT_PRESETS,
    DEFAULT_OUT_DIR,
    JUNCTIONS,
    NEUTRAL_GRAYS,
    TERRESTRIAL_DIR,
)

AUTHORED_WORKBENCH_DIR = TERRESTRIAL_DIR / "workbench"
AUTHORED_FILES = ("index.html", "workbench.css", "workbench_render.js", "workbench_app.js")


def assert_workbench_write(path: Path, out_dir: Path) -> Path:
    resolved = path.resolve()
    wb_root = (out_dir.resolve() / "workbench").resolve()
    if not resolved.is_relative_to(wb_root):
        raise RuntimeError(f"Refusing workbench write outside {wb_root}: {resolved}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def summarize_telemetry(rec: dict[str, Any]) -> dict[str, Any] | None:
    if isinstance(rec.get("telemetry_summary"), dict):
        return dict(rec["telemetry_summary"])
    tel = rec.get("telemetry")
    if not isinstance(tel, dict):
        return None
    swatches = len(tel.get("used_swatches", []))
    anim = tel.get("anim") if isinstance(tel.get("anim"), dict) else None
    kind = rec.get("kind", "")
    if kind == "smooth_strip":
        j0 = tel["j0_isolated"]
        j255 = tel["j255_interior"]
        seams = tel.get("seams", {})
        summary: dict[str, Any] = {
            "swatches": swatches,
            "j0_luma_tb": f"{float(j0['luma']['top']):.1f}/{float(j0['luma']['bottom']):.1f}",
            "j255_dom_rgb": round(float(j255["dominant_rgb_share"]), 3),
            "j255_holes_pct": round(float(j255["transparent_share"]) * 100.0, 1),
            "max_47_dom_rgb": round(float(tel.get("worst_47xframes_dom_rgb_share", j255["dominant_rgb_share"])), 3),
            "max_blk_dom_rgb": round(float(tel.get("worst_block_dom_rgb_share", 0.0)), 3),
            "alpha_max": int(seams.get("max_alpha_diff", 0)),
            "seam_ratio": round(float(seams.get("max_seam_ratio", 0.0)), 2),
        }
    else:
        f1 = tel["frame1"]
        lint = tel.get("lint_f1", {})
        summary = {
            "swatches": swatches,
            "luma_tb": f"{float(f1['luma']['top']):.1f}/{float(f1['luma']['bottom']):.1f}",
            "dom_rgb": round(float(f1["dominant_rgb_share"]), 3),
            "active_px": int(f1["active_px"]),
            "pieces": int(lint.get("pieces", 1)),
            "lone_px": int(lint.get("lone_pixel_count", 0)),
        }
    if anim is not None:
        summary["step_ratio"] = round(float(anim["max_min_step_ratio"]), 2)
        summary["wrap_ratio"] = round(float(anim["wrap_ratio"]), 2)
        summary["zero_delta"] = int(anim["zero_delta_count"])
    return summary


def prepare_terrestrial_record(raw: dict[str, Any]) -> dict[str, Any]:
    out = {k: v for k, v in raw.items() if k != "telemetry"}
    out["require_top_light"] = bool(raw.get("require_top_light", False))
    summary = summarize_telemetry(raw)
    if summary is not None:
        out["telemetry_summary"] = summary
    return out


def build_workbench(out_dir: Path) -> Path:
    manifests_dir = out_dir / "manifests"
    terr_path = manifests_dir / "terrestrial.json"
    exist_path = manifests_dir / "existing.json"
    if not terr_path.exists():
        raise FileNotFoundError(f"Missing {terr_path} (run terrestrial_kit.py first)")
    if not exist_path.exists():
        raise FileNotFoundError(f"Missing {exist_path} (run extract_reference_assets.py first)")

    terrestrial_raw = json.loads(terr_path.read_text(encoding="utf-8"))
    existing_raw = json.loads(exist_path.read_text(encoding="utf-8"))

    terrestrial = [prepare_terrestrial_record(r) for r in terrestrial_raw]
    existing = [{k: v for k, v in r.items() if k != "telemetry"} for r in existing_raw]

    for rec in terrestrial + existing:
        if not rec.get("atlas_data_uri"):
            raise ValueError(f"Record {rec.get('id')!r} is missing atlas_data_uri")

    wb_dir = assert_workbench_write(out_dir / "workbench" / "index.html", out_dir).parent
    for fname in AUTHORED_FILES:
        src = AUTHORED_WORKBENCH_DIR / fname
        if not src.exists():
            raise FileNotFoundError(f"Missing authored workbench file: {src}")
        dst = assert_workbench_write(wb_dir / fname, out_dir)
        shutil.copy2(src, dst)

    payload = {
        "terrestrial": terrestrial,
        "existing": existing,
        "junctions": JUNCTIONS,
        "neutralGrays": NEUTRAL_GRAYS,
        "biomePresets": BIOME_TINT_PRESETS,
    }
    header = (
        "// Auto-generated standalone data bundle for Tales from Space — Terrestrial Art Workbench\n"
        f"// Contains {len(terrestrial)} terrestrial assets + {len(existing)} TfS/tgstation reference assets.\n"
    )
    js_body = header + "window.WORKBENCH_DATA = " + json.dumps(payload, separators=(",", ":")) + ";\n"

    data_js_path = assert_workbench_write(wb_dir / "workbench_data.js", out_dir)
    data_js_path.write_text(js_body, encoding="utf-8")
    print(
        f"Built workbench at {wb_dir / 'index.html'} "
        f"({len(terrestrial)} terrestrial + {len(existing)} reference = {len(terrestrial) + len(existing)} assets, "
        f"{len(js_body):,} bytes)"
    )
    return wb_dir / "index.html"


def main() -> None:
    parser = argparse.ArgumentParser(description="Assemble the standalone Terrestrial Art HTML workbench.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="output root containing manifests/ and receiving workbench/")
    args = parser.parse_args()
    build_workbench(Path(args.out_dir).resolve())


if __name__ == "__main__":
    main()
