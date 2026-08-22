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
| `content/`       | The mod itself: `items/`, `jobs/`, `gamemodes/`, `fixtures/`, `substances/`, `reactions/` (`.luau` files returning prototype tables, with optional behavior hooks), plus `tuning.luau` feel knobs. |
| `maps/`          | Station maps as RON (`chillstation.ron` is the default; `outpost.ron` is the test/demo map). |
| `assets/`        | Sprite and sound source manifests consumed by `cargo run -p xtask -- bake-atlas`. |
| `tests/`         | Luau specs (`*_test.luau`) run by the engine's spec runner; `tests/maps/` holds purpose-built spec maps. |

## Running

From the workspace root:

```sh
cargo run -p lunatic-server                 # defaults: tfs/maps/chillstation.ron, --content tfs/content
cargo run -p lunatic-server -- --mode free_build
cargo run -p lunatic-server -- tfs/maps/outpost.ron --content tfs/content
```

## Authoring

- `docs/SCRIPTING.md` is the ratified v1 content contract (anchors,
  handler kinds, transactions). It is the destination, not yet the runtime.
- `docs/LUAU-API.md` documents the as-built v0 surface these files use
  today: seven hooks (`on_interact`, `on_use`, `on_bump`, `on_attack`,
  `on_mob_life`, `on_use_self`, `on_pull`) and the `ctx` query/effect
  table.
- `content/tuning.luau` overrides engine feel constants; the engine's
  compiled defaults are the values its tests pin.
- `docs/GAMEMODES.md` defines the Space Station/Free Build split and the
  `content/gamemodes/*.luau` policy schema.

## Specs

```sh
cargo run -q -p lunatic-server -- test tfs             # every tests/*_test.luau
cargo run -q -p lunatic-server -- test tfs vendor      # only files whose NAME contains "vendor"
cargo run -q -p lunatic-server -- test tfs --json out.json    # CI result document
cargo run -q -p lunatic-server -- test tfs --load-only # content lint, no Sim
```

The filter is a case-insensitive substring of the spec's FILE NAME, so
`vendor`, `vend`, and `vendor_test.luau` all select the same file; the
tail line reports how many specs were filtered out. A failure prints the
assertion's own message with Luau's `file:line` stamp.

Each spec runs in a fresh trusted VM against a fresh headless Sim and
drives it through `t`, which is the same `SimCommand` seam the Rust
harness uses — a spec asserts what a player could cause, never what a
mod could sneak. There is no raw entity handle, no component access, and
no direct spawn in `t`, and none should ever be added.

| Group | Functions |
| ----- | --------- |
| World | `t.world(ron [, seed [, mode]])`, `t.world_file(name [, seed [, mode]])` (mode = a `content/gamemodes/` id; omitted = the pack default), `t.join([job]) -> player` (a mode that seats bodies on connection takes no job) |
| Seeds | `t.fault(x, y, tick)` (hull failure), `t.outage([tick])` (breaker trip) |
| Clock | `t.now()`, `t.tick()`, `t.run_ticks(n)`, `t.run_seconds(s)` |
| Verbs | `t.click(p, x, y [, target])` (target = the entity the client's hit-test named, from `t.target_at`; omitted = a click that landed on the ground), `t.throw(p, x, y [, target])` (the same click while throw mode is armed: the active hand's item flies at that tile), `t.move(p, dir)`, `t.say(p, text)`, `t.drop(p)`, `t.equip(p)`, `t.unequip(p, slot)` (a worn slot off into a free hand), `t.swap_hands(p)`, `t.use_self(p)`, `t.use_on_other(p)` (the active hand's item used on the item in the other hand),  `t.rotate(p, x, y, target, clockwise)`, `t.pull(p, x, y, target)` (ctrl+click: take hold of a loose thing and drag it), `t.stop_pull(p)`, `t.ui_act(p, act [, payload])`, `t.ui_close(p)` |
| Looking | `t.examine(p, x, y [, target])` (shift+click; omitted target = the ground, which examines the turf), `t.examine_held(p [, hand])`, `t.examine_worn(p, slot)`, `t.examine_stored(p, slot, index)` (1-based, as `t.take_from` counts), `t.examine_held_stored(p, index [, hand])` (0-based, as `t.take_held` counts) — each answers `{ title, sprite, lines, spans }`, or **nil** for every refusal there is (out of view, a forged claim, an empty slot, a spent throttle). `lines` are flat finished sentences; `spans[i]` is the same line uncollapsed into `{ text, color = "#RRGGBB" \| nil }` runs, so a spec can assert which words wear a substance's colour |
| Body | `t.pos(p) -> x, y`, `t.health(p) -> {brute, oxy, state}`, `t.set_health(p, fields)`, `t.blood_moles(p)`, `t.sprite(p)`, `t.hands(p) -> {[1], [2], active, held}`, `t.worn(p) -> {id, uniform, suit, belt, back, mask}`, `t.stored(p, slot)` (what a worn container holds, in storage order) |
| Tile | `t.turf(x, y)`, `t.is_breached(x, y)`, `t.items_at(x, y)`, `t.target_at(x, y, id)`, `t.count_items(id)`, `t.door_at(x, y) -> {open, powered}` |
| Atmos | `t.pipe(x, y)`, `t.pipe_pressure(x, y [, layer])`, `t.room_pressure(x, y)`, `t.canister_pressure(x, y)` |
| Power | `t.cable_at(x, y)`, `t.apc_at(x, y) -> {charge, equipment, lighting, environment, alarmed, charging}`, `t.segment_at(x, y) -> {feeder, branch, apc_hops}`, `t.lit(x, y)` |
| Observed | `t.messages(p)`, `t.sounds(p)`, `t.last_ui(p) -> state, pushes`, `t.ui(p)` (parsed), `t.vitals(p) -> {oxy, brute, pressure}` |
| Ledger | `t.ledger_rows([event])`, `t.ledger_has(...needles)` |

`t.ledger_rows` hands back rows in the shift JSONL's own shape — `tick`,
`event` (snake_case), the event's own fields alongside it, `actor`
(`{kind = "player" | "system" | "script", ...}`), and `pos`/`room` where
the sim knew them. The optional argument filters by event name in either
spelling (`"TurfChanged"` or `"turf_changed"`). `t.ledger_has` is the
blunt grep against a Debug flatten, kept for one-line "did this happen
at all" assertions.

Reading is what `t` does; changing the world is what a player does. The
power and plumbing surfaces are queries only — a spec that wants a
severed feeder cuts it with wirecutters, in somebody's hands.
