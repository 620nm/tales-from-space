"""Validation rules for the intake: its two faces, its 5-layer mouth caps, and the head and
hatch pixel libraries the faces are built from."""

from __future__ import annotations

from typing import Any, Callable

INTAKE_KINDS: tuple[str, ...] = (
    "intake_head",
    "intake_vault",
    "intake_floor",
    "intake_ceiling",
    "intake_mouth_caps",
)

SHAFT_X_SPAN: dict[int, tuple[int, int]] = {
    4: (9, 22),
    5: (8, 23),
    6: (7, 24),
    7: (6, 25),
    8: (5, 26),
    **{y: (4, 27) for y in range(9, 23)},
    23: (5, 26),
    24: (6, 25),
    25: (7, 24),
    26: (8, 23),
    27: (9, 22),
}


def _is_outer_3px_border(x: int, y: int) -> bool:
    return x < 3 or x >= 29 or y < 3 or y >= 29


def _assert_stationary_3px_border(name: str, frames: list[list[list[str | None]]]) -> None:
    ref = frames[0]
    for fi in range(1, len(frames)):
        cur = frames[fi]
        for y in range(32):
            for x in range(32):
                if _is_outer_3px_border(x, y) and cur[y][x] != ref[y][x]:
                    raise AssertionError(
                        f"{name} f{fi+1} ({x},{y}): 3px outer border mutated ({ref[y][x]} -> {cur[y][x]})"
                    )


def _assert_zero_shared_boundary_hexes(
    name: str,
    head_grid: list[list[str | None]],
    hatch_grid: list[list[str | None]],
) -> None:
    collisions: list[tuple[int, int, int, int, str]] = []
    for y in range(32):
        for x in range(32):
            hx = head_grid[y][x]
            if hx is None:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 32 and 0 <= ny < 32 and head_grid[ny][nx] is None:
                        if hatch_grid[ny][nx] == hx:
                            collisions.append((x, y, nx, ny, hx))
    if collisions:
        raise AssertionError(
            f"{name}: shared boundary hexes between the raised head (dy=0) and the open hatch: {collisions[:6]}"
        )


def validate_intake_spec(
    spec: dict[str, Any],
    composite_frame: Callable[..., list[list[str | None]]],
    analyze_grid: Callable[[list[list[str | None]]], dict[str, Any]],
    rec709_luma: Callable[[str], float],
) -> dict[str, Any]:
    """Validate an intake fixture spec and return frame_stats and animated_px."""
    name = spec["name"]
    kind = spec["kind"]
    n_frames = int(spec["frame_count"])

    # Check layer-level lone pixels and token validity
    for layer in spec["layers"]:
        rows_list = layer["frames"] if "frames" in layer else [layer["rows"]]
        if len(rows_list) not in (1, n_frames):
            raise AssertionError(f"{name}/{layer['name']}: expected 1 or {n_frames} frames, got {len(rows_list)}")
        layer_spec = {
            "name": f"{name}/{layer['name']}",
            "width": 32,
            "height": 32,
            "layers": [layer],
        }
        for fi in range(len(rows_list)):
            l_grid = composite_frame(layer_spec, fi)
            if any(hx is not None for row in l_grid for hx in row):
                l_st = analyze_grid(l_grid)
                if l_st["lone_pixels"] != 0:
                    raise AssertionError(
                        f"{name}/{layer['name']} f{fi+1}: lone_pixels={l_st['lone_pixels']} != 0"
                    )

    all_frames: list[list[list[str | None]]] = []
    per_frame_stats: list[dict[str, Any]] = []

    for f in range(n_frames):
        full = composite_frame(spec, f)
        all_frames.append(full)
        st = analyze_grid(full)
        if st["lone_pixels"] != 0:
            raise AssertionError(f"{name} f{f+1}: lone_pixels={st['lone_pixels']} != 0")

        if kind == "intake_ceiling":
            rig_grid = [row[:] if y < 30 else [None] * 32 for y, row in enumerate(full)]
            rig_st = analyze_grid(rig_grid)
            if rig_st["pieces"] != 1 or rig_st["lone_pixels"] != 0:
                raise AssertionError(
                    f"{name} f{f+1}: ceiling rig (y<30) must have pieces=1, lone=0; got {rig_st['pieces']}, {rig_st['lone_pixels']}"
                )
            shadow_pts = [(x, y) for y in (30, 31) for x in range(32) if full[y][x] is not None]
            if shadow_pts:
                sh_grid = [row[:] if y >= 30 else [None] * 32 for y, row in enumerate(full)]
                sh_st = analyze_grid(sh_grid)
                if sh_st["pieces"] != 1 or sh_st["lone_pixels"] != 0:
                    raise AssertionError(f"{name} f{f+1}: floor shadow (y=30..31) must be 1 connected piece")
                if st["pieces"] != 2:
                    raise AssertionError(f"{name} f{f+1}: expected 2 pieces (rig + shadow), got {st['pieces']}")
            elif st["pieces"] != 1:
                raise AssertionError(f"{name} f{f+1}: expected 1 piece when shadow is empty, got {st['pieces']}")
        else:
            if st["pieces"] != 1:
                raise AssertionError(f"{name} f{f+1}: pieces={st['pieces']} != 1")

        if kind == "intake_head":
            if n_frames != 1:
                raise AssertionError(f"{name}: expected 1 static frame, got {n_frames}")
            if st["bbox"] != [4, 3, 24, 24]:
                raise AssertionError(f"{name}: expected bbox [4, 3, 24, 24], got {st['bbox']}")
            if st["luma_top"] <= st["luma_bottom"] + 6.0:
                raise AssertionError(f"{name}: expected top-lit 3/4 gradient, got {st['luma_top']} vs {st['luma_bottom']}")
            if abs(st["luma_left"] - st["luma_right"]) > 3.5:
                raise AssertionError(f"{name}: lateral luma bias {st['luma_left']} vs {st['luma_right']}")
            for y in range(22, 27):
                sx0, sx1 = SHAFT_X_SPAN[y]
                xs_row = [x for x in range(32) if full[y][x] is not None]
                if xs_row and (min(xs_row) < sx0 or max(xs_row) > sx1):
                    raise AssertionError(f"{name} row y={y}: span exceeds open shaft {sx0}..{sx1}")

        elif kind == "intake_vault":
            if n_frames != 4:
                raise AssertionError(f"{name}: expected 4 frames, got {n_frames}")
            if st["opaque_pixels"] != 1024 or st["bbox"] != [0, 0, 32, 32]:
                raise AssertionError(f"{name} f{f+1}: expected 1024 opaque px [0,0,32,32], got {st['opaque_pixels']}")
            if abs(st["luma_top"] - st["luma_bottom"]) > 6.0 or abs(st["luma_left"] - st["luma_right"]) > 2.0:
                raise AssertionError(f"{name} f{f+1}: top-down orthographic luma imbalance")
            dark_px = sum(1 for y in range(32) for x in range(32) if full[y][x] and rec709_luma(full[y][x]) < 36.0)
            if f == 0 and dark_px > 12:
                raise AssertionError(f"{name} f1: closed vault should conceal dark throat (got {dark_px} dark px)")
            if f == 3 and dark_px < 280:
                raise AssertionError(f"{name} f4: open vault must expose >=280 dark throat px (got {dark_px})")

        elif kind == "intake_floor":
            if n_frames != 12:
                raise AssertionError(f"{name}: expected 12 frames, got {n_frames}")
            if st["opaque_pixels"] != 1024 or st["bbox"] != [0, 0, 32, 32]:
                raise AssertionError(f"{name} f{f+1}: expected 1024 opaque px [0,0,32,32], got {st['opaque_pixels']}")

        elif kind == "intake_ceiling":
            if n_frames != 12:
                raise AssertionError(f"{name}: expected 12 frames, got {n_frames}")
            if st["bbox"][0] != 2 or st["bbox"][1] != 0 or st["bbox"][2] != 28:
                raise AssertionError(f"{name} f{f+1}: expected x=2..29 ceiling collar bbox, got {st['bbox']}")

        elif kind == "intake_mouth_caps":
            if n_frames != 20:
                raise AssertionError(f"{name}: expected 20 frames, got {n_frames}")
            if st["opaque_pixels"] != 15:
                raise AssertionError(f"{name} f{f+1}: expected 15px (5x3 collar), got {st['opaque_pixels']}")
            if sorted(st["bbox"][2:]) != [3, 5]:
                raise AssertionError(f"{name} f{f+1}: expected 5x3 or 3x5 bbox, got {st['bbox']}")
            for y in range(32):
                for x in range(32):
                    if full[y][x] is not None and not _is_outer_3px_border(x, y):
                        raise AssertionError(f"{name} f{f+1} ({x},{y}): collar pixel outside stationary 3px curb")

        per_frame_stats.append({k: v for k, v in st.items() if k != "boundary_swatches"})

    if kind in ("intake_vault", "intake_floor"):
        _assert_stationary_3px_border(name, all_frames)

    if kind == "intake_floor":
        raised = next(tg["from"] - 1 for tg in spec["tags"] if tg["name"] == "raised")
        hatch_layers = [layer for layer in spec["layers"] if layer["name"] != "head"]
        head_layers = [layer for layer in spec["layers"] if layer["name"] == "head"]
        hatch_layer_spec = {"name": f"{name}/hatch", "width": 32, "height": 32, "layers": hatch_layers}
        head_layer_spec = {"name": f"{name}/head", "width": 32, "height": 32, "layers": head_layers}
        _assert_zero_shared_boundary_hexes(
            name,
            composite_frame(head_layer_spec, raised),
            composite_frame(hatch_layer_spec, raised),
        )

    if kind == "intake_ceiling":
        shadow_counts = [
            sum(1 for y in (30, 31) for x in range(32) if all_frames[fi][y][x] is not None)
            for fi in range(7)
        ]
        if shadow_counts[0] <= 0 or shadow_counts[6] != 0:
            raise AssertionError(f"{name}: expected positive f1 shadow and 0 f7 shadow, got {shadow_counts}")
        for i in range(6):
            if shadow_counts[i] < shadow_counts[i + 1]:
                raise AssertionError(f"{name}: non-monotonic shadow shrinkage f1..f7: {shadow_counts}")

    if kind == "intake_mouth_caps":
        seen_coords: dict[tuple[int, int], int] = {}
        for fi, grid in enumerate(all_frames):
            for y in range(32):
                for x in range(32):
                    if grid[y][x] is not None:
                        if (x, y) in seen_coords:
                            raise AssertionError(
                                f"{name}: frames f{seen_coords[(x, y)]+1} and f{fi+1} overlap at ({x},{y})"
                            )
                        seen_coords[(x, y)] = fi
        if len(seen_coords) != 300:
            raise AssertionError(f"{name}: expected 300 disjoint pixels across 20 frames, got {len(seen_coords)}")

    animated_px = 0
    if n_frames > 1 and any(tg["to"] > tg["from"] for tg in spec["tags"]):
        changed = {
            (x, y)
            for fi in range(1, n_frames)
            for y in range(32)
            for x in range(32)
            if all_frames[fi][y][x] != all_frames[0][y][x]
        }
        animated_px = len(changed)

    return {
        "frame_stats": per_frame_stats,
        "animated_px": animated_px,
    }
