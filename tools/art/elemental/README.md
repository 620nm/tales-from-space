# Elemental sprite tools

Authors, exports and audits the elemental matter and fire sprites: 60 `.aseprite`
sources under `assets/originals/art/matter/{gasses,liquids,solids}/` and
`assets/originals/art/fx/fire/`. The art rules are
[docs/art-reference/elemental-asset-guide.md](../../../docs/art-reference/elemental-asset-guide.md).
Everything generated lands in the pack's gitignored `target/art/elemental/`
(`png/`, `views/`, `boards/`, `manifests/`, `gallery/`, `audit/`); nothing generated is
tracked.

| Path | Purpose |
|---|---|
| `elemental_kit.py` | Per domain: validates the specs, exports each source's frames through Aseprite MCP, audits colour, chroma and junction tiles, writes `manifests/<domain>.json` and a review board. |
| `specs/spec_{gasses,liquids,solids,fire}.py` | `SPRITES = [...]`: procedural pixel rows, layers, durations, tint samples and metadata per sprite. |
| `build_gallery.py` | Bundles the manifests with `gallery/` into `target/art/elemental/gallery/`. `reading_thresholds()` is the one place the gallery's amounts (mL, mol) come from. |
| `gallery/` | The authored page: `index.html`, `gallery_app.js`, `gallery_styles.css`. |
| `audit/audit_assets.py` | Reads the `.aseprite` binaries, the Aseprite CLI export, the manifests and the gallery data; reports palette, chroma, tag, seam and loop findings. |
| `audit/render_diagnostics.py` | Composite plates (gas gradient, liquid gradient, loop wrap) from the audit's exports. |
| `audit/audit_browser.mjs` | Headless Chromium walk of the built gallery with screenshots. |

## Setup

- Python 3 with Pillow (`pip install pillow`). The audits and `build_gallery.py` need only that.
- `elemental_kit.py` also needs the `mcp` client package and an aseprite-mcp server
  checkout (a Python package run as `python -m aseprite_mcp`) with its own venv; point
  `ASEPRITE_MCP_REPO` at the checkout.
- The Aseprite binary (the CLI build).
- `audit/audit_browser.mjs`: Node and `playwright` with a Chromium.

| Variable | Meaning | Default |
|---|---|---|
| `ASEPRITE_PATH` | Aseprite binary | `aseprite` on `PATH` |
| `ASEPRITE_MCP_REPO` | aseprite-mcp checkout, put on the server's `PYTHONPATH` | unset: `aseprite_mcp` must import in the interpreter below |
| `ASEPRITE_MCP_PYTHON` | interpreter that runs the server | `$ASEPRITE_MCP_REPO/.venv/bin/python`, else the interpreter running the kit |
| `LUNATIC_TG` | tgstation checkout, for the gallery's turf tiles | `../tgstation` beside the pack, or beside the primary checkout when the pack is a `.worktrees/<branch>` worktree; absent: the gallery has no turf backgrounds |
| `PLAYWRIGHT_MODULE` | module name or path for `audit_browser.mjs` | `playwright`, resolved from `NODE_PATH` |
| `CHROMIUM_PATH` | browser binary for `audit_browser.mjs` | Playwright's own |

The pack root is derived from these scripts' location (`tools/art/elemental/` is three
levels below it); no path in them is machine-specific.

## Use

Run from anywhere; each script finds the pack itself.

```sh
E=tools/art/elemental
python3 $E/elemental_kit.py --domain gasses --check-specs   # no Aseprite or MCP needed
python3 $E/elemental_kit.py --domain gasses                 # export + audit what is on disk
python3 $E/elemental_kit.py --domain gasses --only gas_mist_smooth_gentle
python3 $E/build_gallery.py                                 # needs all four manifests
python3 $E/audit/audit_assets.py
python3 $E/audit/render_diagnostics.py
node $E/audit/audit_browser.mjs
```

An existing `.aseprite` is exported and audited as it stands, so hand edits survive. A
missing source is drawn from its spec. `--rebuild-sources` redraws every source of the
domain from its spec and replaces the file, discarding hand edits and any tag or
layer change; review the diff before committing the result. `--only ID` (repeatable)
exports just those ids and leaves the domain manifest and board untouched.

## Bake link

The baker reads each `.aseprite` directly (tags are the states); no PNG is baked from
these exports. A `smooth_strip` is 160×32 and is cut by `Slice(5, 1, <row>)`; the
engine's `docs/assets/rosters.md` §Slicing one large picture owns the rule. On an
original, `Anim("name", "idle", s)` reads the tag `idle-s`.

Every source carries one tag `idle` (frames 1..N, forward), the spec default. A
`Slice(5, 1, Anim(...))` row wants `idle-s`, so those sources need a second tag
spanning the same frames:

```sh
# a PNG strip per frame, the form the audits and gallery read
aseprite -b assets/originals/art/matter/gasses/gas_mist_smooth_gentle.aseprite \
  --save-as 'target/art/elemental/png/gas/gas_mist_smooth_gentle_f{frame1}.png'
# tag edits: Aseprite MCP set_tag / delete_tag, or set the spec's "tag" and use --rebuild-sources
```

## Remaining assumptions

- The gallery (`gallery/gallery_app.js`) still carries scenario presets, substance
  tables and prose log lines with their own literals; only the sprite and shell
  switch amounts read `DATA.thresholds`.
- Specs are tuned to `docs/art-reference/palettes/tales-from-space.gpl` and refuse any
  colour outside it; the audits also refuse its `-reserved` swatches.
