# Terrestrial sprite tools

Authors, exports and audits the 20 neutral-greyscale planetary terrain, flat-variant,
shoreline, botanical decal and outcrop `.aseprite` sources under `assets/originals/art/terrestrial/`
(paired with `solid_debris_jagged_smooth` under `assets/originals/art/matter/solids/`).
The art rules are
[docs/art-reference/terrestrial-asset-guide.md](../../../docs/art-reference/terrestrial-asset-guide.md)
and the pack roster is
[assets/sprites/94-terrestrial.ron](../../../assets/sprites/94-terrestrial.ron).
Everything generated lands in the pack's gitignored `target/art/terrestrial/`
(`png/`, `tiles47/`, `cache/`, `manifests/`, `plates/`, `workbench/`);
nothing generated is tracked.

| Path | Purpose |
|---|---|
| `terrestrial_kit.py` | Validates `specs/`, exports `.aseprite` frames through Aseprite MCP, audits palette membership, neutral-greyscale chroma (`R == G == B`), bare-mask contrast, 47-junction seams and 12-frame loop pacing, runs the flat repetition audit over each strip's `flat_of` variants, and writes `manifests/terrestrial.json`. |
| `pack_tints.py` | Reads the `PackTint` roles of `schema_contract.py`'s biome presets from the pack's `content/` Luau (substance colours and tints, terrain `face_tint`); a missing address is an error. |
| `specs/` | Procedural and hand-authored neutral-greyscale layer rows, opacities, frame durations, default biome tints and citations per sprite. |
| `extract_reference_assets.py` | Extracts read-only pack matter/station sprites and pinned `tgstation` outdoor references into `target/art/terrestrial/cache/` and `manifests/existing.json`. |
| `plates/render_audit_plates.py` | Renders strip telemetry, 5-point visual refinement and `4×4` anti-repetition audit plates under `target/art/terrestrial/plates/`. |
| `plates/render_biome_plates.py` | Renders Martian ammonia, polar ice and Earth coastal biome dioramas plus 12-frame (`200 ms/f`) shoreline GIF loops under `target/art/terrestrial/plates/`. |
| `build_workbench.py` | Bundles the terrestrial and reference manifests into the standalone HTML5 diorama painter and live multiply-tint previewer at `target/art/terrestrial/workbench/index.html`. |

## Setup

- Python 3 with Pillow (`pip install pillow`). `--check-specs`, reference extraction,
  plate rendering and `build_workbench.py` need only that.
- Exporting or rebuilding `.aseprite` originals in `terrestrial_kit.py` also needs the
  `mcp` client package, an `aseprite-mcp` server checkout (`python -m aseprite_mcp`),
  and the Aseprite CLI binary.

| Variable | Meaning | Default |
|---|---|---|
| `ASEPRITE_PATH` | Aseprite CLI binary | `aseprite` on `PATH` |
| `ASEPRITE_MCP_REPO` | `aseprite-mcp` checkout added to the server's `PYTHONPATH` | unset: `aseprite_mcp` must import in the interpreter below |
| `ASEPRITE_MCP_PYTHON` | Python interpreter that runs `aseprite_mcp` | `$ASEPRITE_MCP_REPO/.venv/bin/python`, else the interpreter running the kit |
| `LUNATIC_TG` | `tgstation` checkout for `extract_reference_assets.py` | `../tgstation` beside the pack (or beside the primary checkout from `.worktrees/<branch>`) |

The pack root is derived from these scripts' location (`tools/art/terrestrial/` is three
levels below it); no path in them is machine-specific.

## Use

Run from anywhere; each script resolves the pack root itself.

```sh
python3 tools/art/terrestrial/terrestrial_kit.py --check-specs
python3 tools/art/terrestrial/terrestrial_kit.py
python3 tools/art/terrestrial/terrestrial_kit.py --rebuild-sources
python3 tools/art/terrestrial/extract_reference_assets.py
python3 tools/art/terrestrial/plates/render_audit_plates.py
python3 tools/art/terrestrial/plates/render_biome_plates.py
python3 tools/art/terrestrial/build_workbench.py
```

- `--check-specs` checks canvas sizes, disjoint per-layer pixel occupancy, neutral
  swatches against `docs/art-reference/palettes/tales-from-space.gpl`, and `100 ms`
  frame-duration multiples without invoking Aseprite or MCP.
- Running `terrestrial_kit.py` with no flags exports and audits the existing
  `assets/originals/art/terrestrial/*.aseprite` files on disk without modifying them,
  raising an error if any `.aseprite` source is missing.
- `--rebuild-sources` draws/regenerates `.aseprite` originals from `specs/`, replacing
  hand edits; inspect the diff before committing. Pass `--only ID` (repeatable) to
  narrow export or rebuild runs to specific sprites.
- Run `extract_reference_assets.py` alongside `terrestrial_kit.py` before rendering the
  comparison plates (`plates/render_audit_plates.py`, `plates/render_biome_plates.py`)
  or building `target/art/terrestrial/workbench/index.html` (`build_workbench.py`).

## Bake link

The atlas baker reads `assets/originals/art/terrestrial/*.aseprite` directly through
[assets/sprites/94-terrestrial.ron](../../../assets/sprites/94-terrestrial.ron); nothing
under `target/art/terrestrial/` is baked. Every source carries one forward tag over
frames `1..N`:

- A `single` prop (`32×32`) is tagged `idle` and rostered with `Ase`.
- A `smooth_strip` (`160×32`, five `32×32` blocks: `0` convex, `1` vertical, `2`
  horizontal, `3` concave, `4` flat) is tagged `idle-s` and sliced in `groups` by
  `Slice(5, 1, Sprite("<id>", "idle", s))` or `Slice(5, 1, Anim("<id>", "idle", s))`
  into `<id>_0_0` .. `<id>_0_4` (the engine's `docs/assets/rosters.md` §Slicing one
  large picture).
