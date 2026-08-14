# Tales from Space

Tales from Space (TfS) is the game: every item, job, substance, reaction,
map, and behavior hook that turns the lunatic engine into something worth
logging into. It is authored as a Luau mod with id `lunatic/tfs`
(docs/SCRIPTING.md §5.1 — vendor/mod; the vendor is the authoring group).
This directory is structured to become a standalone repository once the
engine's test fixtures no longer lean on it.

## Layout

| Directory        | Contents |
| ---------------- | -------- |
| `content/`       | The mod itself: `items/`, `jobs/`, `fixtures/`, `substances/`, `reactions/` (`.luau` files returning prototype tables, with optional behavior hooks), plus `tuning.luau` feel knobs. |
| `maps/`          | Station maps as RON (`chillstation.ron` is the default; `outpost.ron` is the test/demo map). |
| `assets/`        | Sprite and sound source manifests consumed by `cargo run -p xtask -- bake-atlas`. |
| `tests/`         | Luau specs (`*_test.luau`) run by the engine's spec runner; `tests/maps/` holds purpose-built spec maps. |

## Running

From the workspace root:

```sh
cargo run -p lunatic-server                 # defaults: tfs/maps/chillstation.ron, --content tfs/content
cargo run -p lunatic-server -- tfs/maps/outpost.ron --content tfs/content
```

## Authoring

- `docs/SCRIPTING.md` is the ratified v1 content contract (anchors,
  handler kinds, transactions). It is the destination, not yet the runtime.
- `docs/luau-api.md` documents the as-built v0 surface these files use
  today: five hooks (`on_interact`, `on_use`, `on_bump`, `on_attack`,
  `on_mob_life`) and the `ctx` query/effect table.
- `content/tuning.luau` overrides engine feel constants; the engine's
  compiled defaults are the values its tests pin.
