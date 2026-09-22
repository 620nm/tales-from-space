# Atmospherics

What the pack's atmospherics content IS: where the gas is stored, what
each placement says out loud, and the focused specs that assert the loop
still works.

The MECHANISM — what a vent, a scrubber, an injector, a canister and a
pipenet do — is the engine's, and is not restated here: read the engine
checkout's `docs/ATMOS.md` and its children (`docs/atmos/station-loop.md`
for the loop shape, `docs/atmos/room-devices.md` for the four room
machines, `docs/atmos/vessels-and-meter.md` for bottles and ports). This
file owns only what THIS pack chose.

Sources: `content/blends/canister_air.luau`,
`content/blends/breathable_air.luau`, `content/blends/refrigerated_air.luau`,
`content/environments/cold_outdoors.luau`,
`content/structures/atmos/air_scrubber.luau`, `content/tuning.luau`,
`tests/atmos/environment/flooded_alcove_test.luau`,
`tests/atmos/environment/tile_air_test.luau`.

## The airs

Three blends are what tiles breathe. `breathable_air` is 21/79 at 20 C and
one atmosphere — tg's `OPENTURF_DEFAULT_ATMOS`
(`code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:7`), and
`default = true`: what an unpainted indoor tile opens with, and what a
mapper paints back onto a room they emptied. `refrigerated_air` is the
same mixture at `COLD_ROOM_TEMP` (259.15 K,
`code/__DEFINES/atmospherics/atmos_core.dm:33`), topped up to one
atmosphere by tg's kitchen rule (`KITCHEN_COLDROOM_ATMOS`,
`atmos_mapping_helpers.dm:21`): painted, a walk-in; named by the
`cold_outdoors` profile, the cold sky. `vacuum` is nothing at 2.7 K: a
pumped-down room, which its neighbours flow into — space is a boundary
they drain through instead, and a wall holds no cell at all (the
engine's `docs/atmos/blends.md`).

The map-atmosphere tile is the unpainted outdoor one: it opens on the
map's fixed `environment.atmosphere_blend` or the selected profile's
ambient, and recovery tends back toward that recipe afterward (the
engine's `docs/mapping/environment.md` and
`docs/matter-world/environment.md`). Painted air stays an explicit
per-tile choice, and a tile naming a blend the map never declared
refuses the world at parse — content fails closed before a single tick
(the engine's `docs/map-properties/blends.md`).

## Component contracts

The pack chooses the vocabulary and defaults; the engine owns the per-tick
flow. A map or focused fixture composes these parts into a loop without
changing their identity:

| component | authored contract |
|---|---|
| `air_scrubber` | An `atmos` endpoint on pipe layer `l2`; filters `co2` at 5 L/s and returns whole air down to 100 kPa. Its `siphoning` position is the zero-floor whole-air override. |
| `air_injector` | A powered `l3` endpoint that injects at 50 L/s by default, with no pressure setpoint or ceiling. |
| `manual_valve` | An unpowered `l3` topology switch. Open joins the two runs; shut separates them. |
| `layer_adapter` | The deliberate bridge between pipe layers. It has no pump, direction or power draw; joining it joins the connected layers. |
| `stationary_tank` | A 2,500 L, 46,000 kPa reservoir on `l3` with four open mouths. The placement supplies its contents and starting pressure instead of a gas-specific prototype. |
| `canister` | A portable 2,000 L vessel. It arrives empty and shut; a placement may charge it with a blend and open it, and an unfastened open vessel releases into its room. |

Every property bag is an override. Omitted fields keep the prototype's
default, so a fixture can test one changed setting without silently inventing
the rest of a machine's state.

### `canister_air`

`content/blends/canister_air.luau` declares the pack's premixed canister
charge once, rather than creating a gas-specific canister roster. Tg's
90-atmosphere maximum and `filled = 0.5` give a 45-atmosphere 21/79 mixture
at 293.15 K. At one 1 m³ tile, `n = P·V/(R·T)` gives 1870.8 mol, split into
392.87 mol `o2` and 1477.94 mol `n2`. The blend is authored as a density with
`amount = "per_tile"`, so the 2 m³ vessel holds 3741.6 mol and reads the same
4559.6 kPa.

Other blends such as `co2_23000kpa` and `n2_5000kpa` are independent authored
recipes. Their pressure and phase behavior belongs to the substance and matter
systems, not to a canister or tank prototype.

## Tuning

`content/tuning.luau` overrides the engine's feel constants:

| key | value | what reads it |
|---|---|---|
| `safe_pressure_kpa` | 85.0 | the scrubber's purge picture, and the pressure half of the hazard bands |
| `hazard` | bands table | what a powered vent or scrubber reports about its own tile |
| `cord_range` | 6 | the power side |

Out-of-range or broken values fall back to engine defaults with a
warning; the engine's own test suite pins the engine defaults and never
this file's numbers.

## Focused coverage

These specs exercise the contracts through the player-facing world seam; they
are not a claim that one map assembles a station-scale department:

- `tests/atmos/environment/room_devices_test.luau` checks room↔pipe transfer,
  scrubber filtering and injector delivery in small inline worlds.
- `tests/atmos/environment/scrubber_floor_test.luau` checks the pack-specific
  whole-air floor and the distinction between return and siphon positions.
- `tests/atmos/environment/canister_test.luau` checks canister→pipe→vent→room
  supply and recovery after a breach; `canister_water_test.luau` checks a
  liquid charge, headspace and vapor behavior.
- `tests/atmos/pipenet/stationary_tank_test.luau`, `tank_fill_test.luau`,
  `tank_flow_test.luau` and `tank_mouths_test.luau` check placement fills,
  ideal-gas amounts, transfer and four-mouth sharing. The `tests/maps/tank_row.ron`
  fixture and `tank_row_test.luau` check seven independent substances without
  cross-talk.
- `tests/maps/cold_outpost.ron` and `tests/maps/flooded_alcove.ron` are focused
  map fixtures whose specs assert authored ambient air and liquid containment.

The maps lane only parses, preflights and round-trips these documents. Actual
boot and tick/step behavior is asserted by the named specs, and
`tools/map-fixture-coverage.mjs` fails the gate when a `tests/maps/` fixture
is not loaded by its named spec or that spec did not pass.
