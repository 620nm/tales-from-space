# Drainage sprite tools

Authors, validates and previews the liquid drainage and intake fixtures (`floor_drain`,
`scupper`, `sump_pump`, `intake_head`, `intake_vault`, `intake_upper_deck`,
`intake_ceiling_below`, `vault_mouth_caps`), sourced at
`assets/originals/art/machines/drainage/`. The art rules are
[docs/art-reference/drainage-asset-guide.md](../../../docs/art-reference/drainage-asset-guide.md).
Everything generated lands in the pack's gitignored `target/art/drainage/` (`png_1x/`,
`png_8x/`, `layers/`, `manifests/`, `gallery/` and two boards); nothing generated is tracked.

| Path | Purpose |
|---|---|
| `drainage_kit.py` | Validates the specs, draws a missing source through Aseprite MCP, exports each source's frames and writes `manifests/<fixture>.json`. |
| `intake_validation.py` | Validates the multi-Z intake head suite (`intake_head`, `intake_vault`, `intake_upper_deck`, `intake_ceiling_below`, `vault_mouth_caps`). |
| `specs/spec_{floor_drain,scupper,sump_pump,intake_head,intake_vault,intake_upper_deck,intake_ceiling_below,vault_mouth_caps}.py` | `SPEC`: pixel rows, layers, durations and tags of one source. |
| `build_gallery.py` | Bundles the manifests with `gallery/` into `target/art/drainage/gallery/`, and draws `overview_board.png`. |
| `pipe_workbench.py` | Pipe stubs, mouth caps (`scrub`, `vent`, `inje`, `vault`) and riser sleeves for the gallery, and `pipe_connections_board.png`. |
| `gallery/` | The authored page: `index.html`, its stylesheet and scripts. `gallery_data.js` is generated beside the copy in `target/`. |

## Setup

- Python 3 with Pillow.
- `drainage_kit.py` without `--check-specs` also needs the `mcp` client package and an
  aseprite-mcp server checkout; run it with an interpreter that has them.
- The Aseprite binary (the CLI build).
- A tgstation checkout, for the gallery's turfs, caps and reference sprites.

| Variable | Meaning | Default |
|---|---|---|
| `ASEPRITE_PATH` | Aseprite binary | `aseprite` on `PATH` |
| `ASEPRITE_MCP_REPO` | aseprite-mcp checkout, put on the server's `PYTHONPATH` | unset: `aseprite_mcp` must import in the interpreter below |
| `ASEPRITE_MCP_PYTHON` | interpreter that runs the server | `$ASEPRITE_MCP_REPO/.venv/bin/python`, else the interpreter running the kit |
| `LUNATIC_TG` | tgstation checkout | `../tgstation` beside the pack, or beside the primary checkout when the pack is a `.worktrees/<branch>` worktree |
| `DRAINAGE_FONT` | TTF for board labels | Noto Sans Mono; absent: Pillow's default |

## Use

Run from anywhere; each script finds the pack itself.

```sh
D=tools/art/drainage
python3 $D/drainage_kit.py --check-specs                      # no Aseprite or MCP needed
python3 $D/drainage_kit.py                                    # export what is on disk
python3 $D/drainage_kit.py --fixture scupper --rebuild-sources
python3 $D/build_gallery.py                                   # needs all eight manifests
```

An existing `.aseprite` is exported as it stands, so hand edits survive. A missing source
is drawn from its spec. `--rebuild-sources` redraws from the spec and replaces the file,
discarding hand edits; review the diff before committing the result.

## Bake link

The baker reads each `.aseprite` directly: tags are the states. A `<state>-<dir>` tag is what
a `Directions` or `Anim` row names by `<state>`. The sump pump's `e`/`w` and `n`/`s` tags
overlap on purpose, one pair per manifold axis. The scupper's faces take their one-tile
displacement from the `offsets` table in `assets/sprites.ron`.
