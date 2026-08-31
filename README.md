# Tales from Space

Tales from Space (TfS) is the game: every item, job, substance, reaction,
map, and behavior handler that turns the lunatic engine into something worth
logging into. It is authored as a Luau mod with id `lunatic/tfs`
(docs/SCRIPTING.md §5.1 — vendor/mod; the vendor is the authoring group).
This standalone repository is loaded by the sibling lunatic engine through
`LUNATIC_PACK`; the engine ships no game content of its own.

## Layout

| Directory        | Contents |
| ---------------- | -------- |
| `content/`       | The mod itself: `main.luau` (the pack entrypoint), `capabilities.luau`, `part_tree.luau`, `lib/` (shared tables the rosters read), pack rosters (`items/`, `jobs/`, `bodies/`, `gamemodes/`, `fixtures/`, `substances/`, `reactions/`, `air/`) whose `.luau` files return prototype data and register behavior through explicit `Definition:handle` calls, plus `tuning.luau` feel knobs. |
| `maps/`          | Station maps as RON (`chillstation.ron` is the default; `outpost.ron` is the test/demo map). |
| `assets/`        | Sprite, sound and whole-picture source manifests plus the tracked `tg-revision` consumed and verified by `cargo run -p xtask -- bake-atlas`. |
| `tests/`         | Luau specs (`*_test.luau`) run by the engine's spec runner; `tests/maps/` holds purpose-built spec maps. |

## Running

This repository is content only; the engine is
[lunatic](https://github.com/620nm/lunatic), checked out beside it.
Every command below runs from that checkout with `LUNATIC_PACK`
naming this one (the engine ships no content and never looks anywhere
it was not told):

```sh
export LUNATIC_PACK=../tales-from-space
cargo run -p lunatic-server                 # defaults: the map mod.toml names, <pack>/content
cargo run -p lunatic-server -- --mode free_build
cargo run -p lunatic-server -- "$LUNATIC_PACK/maps/outpost.ron"
cargo run -p xtask -- bake-atlas            # reads <pack>/assets, needs ../tgstation
```

## Authoring

- `docs/SCRIPTING.md` is the v1 content design: anchors, handler kinds,
  transactions, events, tasks, and scoped state.
- `docs/LUAU-API.md` documents the as-built v1 `sim` surface and named
  occurrence records; `idl/v1.json` freezes its names.
- `docs/BIOLOGY.md` is what a body IS: `content/bodies/*.luau` plans,
  the `part` and `organ` blocks on items, and the capacity formulas that
  decide what a crewman can do.
- `content/tuning.luau` overrides engine feel constants; the engine's
  compiled defaults are the values its tests pin.
- `content/capabilities.luau` opts into optional client grammars. TfS
  explicitly enables `interactions.body`; body-plan definitions alone do not
  expose hands, jobs, vitals or respawn to a player.
- `content/air/*.luau` are the air recipes a mapper paints rooms with
  (`{ id, name, gases = { {key, moles} }, temperature_k }`,
  docs/ATMOS.md §11). Required content like every other roster; they are
  DEFAULTS the map editor copies into a map, never state — the sim seeds
  every tile from the map's own presets.
- `docs/GAMEMODES.md` defines the Space Station/Free Build split and the
  `content/gamemodes/*.luau` policy schema.
- `content/lib/*.luau` is the pack's SHARED CODE. There is no `require`
  (docs/SCRIPTING.md §1.6): a `lib/` file returns a table and the loader
  publishes it as a global named for the file, so `lib/vessel.luau`
  becomes `vessel` and every roster file may read it — at prototype time
  as well as inside a handler. `lib/` loads after the entrypoints and
  before every roster, lexically within itself, so one shared file may
  read another. Nothing in `lib/` may call `sim.define`: shared code
  publishes tables, rosters declare things, and the loader refuses the
  other way round. Two callers today — `lib/vessel.luau` is the pour,
  swig, spill and gas-charge gestures every vessel wears, and
  `lib/cards.luau` is the deck a card and a deck of cards both read.

### Palette categories

`category = "..."` on an item or structure table is the group a palette —
the map editor's, today — files that entry under. It is free text and
nothing checks it against a list, because a pack that groups its own things
differently is not wrong.

Leave it out and the server derives one from what the file already declares:
an item with a `slot` is `wearables`, with `storage` it is `containers`,
with `tool` it is `tools`, with `component` or `board` it is `machine
components`, and anything else is `misc`; a structure with `fitting` is
`fittings`, one with `atmos` or
`meter` is `atmospherics`, and the rest are `structures`. Machines are
always `machines`. The derivation reads FIELDS and never ids — the engine
must not learn to recognise one — so a file whose grouping the rule gets
wrong says so itself. The loose pipe pieces do exactly that
(`items/*_fitting.luau`), because "a thing you carry to the plumbing" is not
something any field they set can say.

## Specs

```sh
cargo run -q -p lunatic-server -- test "$LUNATIC_PACK"             # every tests/*_test.luau
cargo run -q -p lunatic-server -- test "$LUNATIC_PACK" vendor      # only files whose NAME contains "vendor"
cargo run -q -p lunatic-server -- test "$LUNATIC_PACK" --json out.json    # CI result document
cargo run -q -p lunatic-server -- test "$LUNATIC_PACK" --load-only # content lint, no Sim
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
| Body | `t.pos(p) -> x, y`, `t.body(p) -> {plan, controllable, animate, label, thresholds, conscious, posture, health, <owner pool id> = n, properties = {<property id> = n}, blood, bleed_rate}` (`controllable` and `animate` are the two facts `content/bodies/human.luau` sets answering a threshold, `label` is its word for them, and `thresholds` lists the declared line ids this body is past; the pool and property keys are this pack's own, from `content/part_tree.luau`), `t.body_id(p)` (the wire id of a session's body, for clicking one crewman on another — surgery names the patient this way), `t.bodies_at(x, y) -> {{...}}` (every body on a tile as `t.body` reads one, plus `id` (a click target), `name`, `worn` (the `t.worn` map), `parts` (the `t.parts` map) and `player` (whether a session is at the wheel) — the only way to see a body nobody is, such as one a drawer's stock stood up; ghosts are excluded), `t.parts(p) -> {[zone] = {zone, label, <attachment pool id> = n, max, efficiency, present, bleeding, tags, states, organs, socket_tags}}` (a seated organ is an opaque handle a spec may test for truth but not dereference — ask `t.organ_damage(p, socket)` for its state; an empty socket answers `false`), `t.capacity(p, id)` (nil for a capacity the plan lacks), `t.organ_damage(p, socket)` (nil for an empty socket), `t.set_organ_damage(p, socket, n)` (the organ PRECONDITION setter, as `t.set_health` is for pools: `n` at or above the organ's max is failure — it exists because the only thing that damages an organ over time is decay, and a brain takes half an hour to decay to failure), `t.doll(p) -> {{id, label, rect, sprite, slot}}` (the target doll this session's browser was sent, in plan order — `slot` is the numbered target key, which is how a spec presses one), `t.set_zone(p, zone)` and `t.rest(p [, on])` (the surgeon's targeted zone and a body lying down — B2 stand-ins until B3 lands `SetTargetZone` and `Rest`), `t.health(p) -> {<pool id> = n, health, controllable, animate, label}` (one key per pool the pack declares — an attachment pool sums the parts and the body; `health` is the number the plan's `thresholds` are compared against, and the last three are what the pack made of them), `t.set_health(p, fields)` (a PRECONDITION setter, never a verb: it routes through the damage seam, lands zone-less channels on the plan's `default_zone`, and always re-evaluates), `t.blood_moles(p)`, `t.blood(p) -> {<key> = moles}` (what is in a bloodstream, phase-collapsed — `t.contents` for a body), `t.sprite(p)`, `t.hands(p) -> {[1], [2], active, held}`, `t.worn(p) -> {<equipment id> = item id}` (one key per FILLED slot of the pack's declared equipment roster), `t.stored(p, slot)` (what a worn container holds, in storage order) |
| Tile | `t.turf(x, y)`, `t.subfloor_exposed(x, y)`, `t.is_breached(x, y)`, `t.items_at(x, y)`, `t.item_at(x, y, id)`, `t.structure_at(x, y) -> {id, state, sprite, overlays}` (nil for a tile with nothing standing on it; `overlays` is the rest of the stack, bottom first — authored per state or computed by the sim, one list either way, because that is what a crewman sees), `t.target_at(x, y, id)`, `t.count_items(id)`, `t.door_at(x, y) -> {open, powered}` |
| Atmos | `t.pipe(x, y)`, `t.pipe_pressure(x, y [, layer])`, `t.pipe_temperature(x, y [, layer])`, `t.pipe_energy(x, y [, layer])`, `t.pipe_gas(x, y [, layer]) -> {<key> = moles}`, `t.room_pressure(x, y)`, `t.room_temperature(x, y)`, `t.room_gas(x, y) -> {<key> = moles}`, `t.canister_pressure(x, y)`, `t.tank_pressure(x, y)`, `t.tank_gas(x, y) -> {<key> = moles}`, `t.deck(x, y) -> {capacity, temperature, energy}` (the solid mass a room stands on — J/K, K, J; every deck is finite, plating included), `t.wind(x, y) -> east, north` (what the air over a tile is doing, m/s on the map's axes; a wall answers 0, 0). Three PRECONDITION setters stand beside them, never assertions: `t.heat_pipe(x, y, joules [, layer])`, `t.foul_room(x, y, gas, moles)` and `t.charge_vessel(x, y, gas, kpa)` (gas into the canister or reservoir on a tile, to a pressure — the only way to reach the ratings a vessel fails at, since no pump on the station gets near them) |
| Vessels | `t.vessel(handle) -> {pressure_kpa, temp_k, volume_l, headspace_l, sealed, moles, contents = {<key> = {solid, liquid, gas}}}` — the whole reading of anything with an inside (beaker, bloodstream, tank, canister, reservoir), nil for anything else, and the same answer content's `sim.vessel` gets; a phase nothing is standing in is absent rather than zero. The single numbers beside it: `t.contents(handle) -> {<key> = moles}` (phase-collapsed), `t.holder_k(handle)`, `t.holder_kpa(handle)` |
| Sky | `t.environment() -> {id, name, sink_k, insolation}` (where the station was parked this shift, rolled off the mode's roster), `t.set_environment{sink_k =, insolation =}` (a PRECONDITION setter — no player moves a station between orbits; the roll it overwrites is renamed `"custom"`), `t.space_radiated()` (NET joules the hull has put into the sky, negative under a star) |
| Power | `t.cable_at(x, y)`, `t.apc_at(x, y) -> {charge, equipment, lighting, environment, alarmed, charging}`, `t.segment_at(x, y) -> {l1, l2, l3, live, feed, lighting_feed}` (the segment id on each layer that has cable, and which layer BIT a consumer here would bind to per channel), `t.ports_at(x, y) -> {kind, energized, l1 = {mode, in_w, out_w}, l2 =, l3 =}` (a bridge's ports, one per layer that has cable under it), `t.lit(x, y)` |
| Observed | `t.messages(p)`, `t.sounds(p)`, `t.last_ui(p) -> state, pushes`, `t.ui(p)` (parsed), `t.vitals(p) -> {<readout id> = n}` (the last private readout push this client got, keyed by the pack's declared readout ids) |
| Books | `t.matter_totals() -> {moles, energy_j, substances = {<key> = moles}}` — every body of matter there is, added up: every cell, the vented register, the reservoirs and the hull's radiation account, plus every beaker, bottle, canister, reservoir and bloodstream. The one reading here that is not a gauge a crewman could hold, and it exists because an identity spec's claim is that a mole which left one surface ARRIVED at another rather than being made on the way. Read-only, taken on demand, no counter. NEITHER TOTAL IS INVARIANT ACROSS EVERYTHING: a reaction whose product count differs from its reactant count moves `moles`; a reaction with an enthalpy, a thermostat pass and a sunlit hull each move `energy_j`; a dispenser press and a metabolizing liver leave no accumulator behind. A spec asserts one of them over a window where the arithmetic holds, and says which and why (`tests/identity_*_test.luau`). `t.nullified_moles()` is the companion reading: moles the settling sweep has taken off tiles that were left holding less gas than the engine still has an opinion about (`docs/MATTER-WORLD.md` §3 step 8). It is inside `t.matter_totals` already, and it is exposed on its own because a spec proving a room reached zero has to tell gas that left through a grille from gas that fell under that floor. `t.nullified() -> {<key> = moles}` is the same register by substance, `t.room_gas`'s shape, which is what a per-substance conservation sum needs |
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
severed run cuts it with wirecutters, in somebody's hands.
