# The station's air

What Chillstation's atmospherics department IS: where the gas is stored,
what each placement says out loud, and the spec that asserts the whole
loop still works.

The MECHANISM — what a vent, a scrubber, an injector, a canister and a
pipenet do — is the engine's, and is not restated here: read the engine
checkout's `docs/ATMOS.md` and its children (`docs/atmos/station-loop.md`
for the loop shape, `docs/atmos/room-devices.md` for the four room
machines, `docs/atmos/vessels-and-meter.md` for bottles and ports). This
file owns only what THIS pack chose.

Sources: `maps/chillstation.ron`, `content/blends/canister_air.luau`,
`content/structures/air_scrubber.luau`, `content/tuning.luau`,
`tests/station_air_test.luau`.

## The loop, by coordinate

```
chambers → siphon scrubbers → yellow draw → filter row → mixer
        → supply main (layer 4) → layer adapter → distro (layer 3) → vents → rooms
rooms   → scrubbers → scrubbers main (layer 2) → adapter → process line → filter row
```

Atmospherics is one block in the south-west; the station is drawn around
a central Commons. Three fittings carry the department across the south
corridor, all on deck a technician can stand on:

| tile | fitting | why there |
|---|---|---|
| (20, 20) | `manual_valve` `"open"`, `{ "layer": 4 }` | the supply main's isolation point |
| (22, 20) | `layer_adapter` | puts the layer-4 main onto the layer-3 run the vents are plumbed to |
| (13, 20) | `manual_valve` `"open"`, `{ "layer": 2 }` | the waste side's own wheel, cuttable without touching supply |

Both wheels ship **open**. A commissioned station's valves are: an
isolation point is a thing you CAN shut, not one that starts shut, and
shipping them shut cuts the loop the spec asserts.

## The supply bottles

Eight canisters at (8, 17), (9, 17), (10, 17), (11, 17), (15, 22),
(17, 22), (19, 25) and (23, 26), each standing on a `connector_port` and
each arriving CHARGED and OPEN:

```ron
(8, 17, "canister", { "blend": "canister_air", "open": true }),
```

A bottle that said neither opens the shift empty with the valve shut,
which is what an empty bottle looks like. So this station's distribution
main being pressurised at roundstart is a sentence somebody wrote in the
map, never something the engine did.

The rack's arithmetic is written on the map beside the ports, because a
station redraw changes the volume the reserve has to hold up.

### `canister_air`

`content/blends/canister_air.luau` — tg's own canister charge, declared
once as a blend rather than as twenty canister subtypes:

- tg rates a canister `maximum_pressure` 90 atm and ships `filled = 0.5`
  (`code/modules/atmospherics/machinery/portable/canister.dm`), so
  **45 atm** of 21/79 at 293.15 K.
- `n = P·V/(R·T)` at one tile = **3741.6 mol**, split 21/79 into
  `o2` 392.87 and `n2` 1477.94.
- Authored `amount = "per_tile"` because the blend is a DENSITY: one
  tile of it and the 2 m³ bottle holding it both read **4559.6 kPa**.

The map declares the same numbers inline under `blends` so a mapper can
copy the row; the other stores are named after the pressure a 2500 L
shell of them reads at 20 °C (`co2_23000kpa`, `n2_5000kpa`, …).

## The Commons grille

```ron
(16, 17, "air_scrubber", "scrubbing", { "whole_air": false, "rate_lps": 200.0, "floor_kpa": 0.0 }),
```

This one placement contradicts the prototype deliberately. A grille
dropped on a deck today is a RETURN GRILLE — whole air, gently, down to
a floor just under the vent's release line, which is what a hull that
radiates wants once there is a heating loop to feed
(`content/structures/air_scrubber.luau` ships `rate_lps = 5.0`,
`target_kpa = 100.0`). This grille is the department's **CO2 recovery
leg** and predates that loop: pointed at the one gas, dial wide open at
no floor, taking it to the last mole, with the chamber at the far end of
the filter row as its destination.

Every knob in a property bag is an OVERRIDE and silence keeps what the
file gave it, so the placement says only what is different.

## The chambers

Three sealed gas chambers, each with tg's pair: an injector pushing gas
in off the green feed and a scrubber set to SIPHON drawing it back out
onto the yellow draw, both shipping running.

```ron
(15, 33, "air_injector", "injecting", { "pipe": "west" }),
(15, 34, "air_scrubber", "siphoning", { "pipe": "south" }),
```

Aimed by the MOUTH, not the picture: each of these has two joinable
mouths, so an automatic fit that guessed the other one gets a machine
that moves nothing. `"pipe": "west"` reads "its feed is west of it".

The chamber feed's bottles are STORAGE, not regulators — a fastened
bottle is one body with its line and the injectors have no ceiling — so
the pair's header is bounded by two pumps holding the feed at one
atmosphere, which is the regulator job tg gives a pump and never a
bottle.

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

## The spec

`tests/station_air_test.luau` loads `maps/chillstation.ron` — the map
players actually get — and asks the four questions a crew would ask on
the way to work. A compact mirror of the station would be a spec that
passes while the station is broken, which is the one thing the file
exists to prevent. Rooms, vents and the walked route are pinned by
coordinate.

1. **The rooms hold breathable air, and keep holding it** — over
   minutes, not at tick zero. A station that starts at an atmosphere and
   slowly loses it is invisible to any test that only looks at boot.
2. **A fouled room comes clean and the carbon dioxide lands in the tank
   labelled for it** — scrubber → scrubbers main → layer adapter →
   process line → the filter that catches CO2 → its own orange feed →
   the CO2 chamber's injector → the chamber. `t.foul_room` stands in for
   lungs the station has too few of to do this in a test's worth of
   ticks.
3. **An isolation valve isolates.** An engineer is walked to the wheel
   on the green chamber feed — a manual valve has no panel by design.
   Shut is not a picture: it is the feed becoming two bodies of gas, and
   the proof is the isolated side EMPTYING (the chamber injectors keep
   draining it with nothing able to refill), which is sharper than "the
   pressure did not change".
4. **A breached room, resealed, refills from distro.** Last, because it
   decompresses the room the engineer is standing in. A room open to
   space settles at roughly half an atmosphere and HOLDS rather than
   falling to zero, because there is gas storage behind the supply main
   — the recovery story, and the reason a department beats a bottle.

**A commissioned department reads as IDLE on a fresh station, and that
is correct.** Nobody has breathed yet, so a scrubber pointed at carbon
dioxide takes nothing and a pump set to one atmosphere feeding a main
that opens at one atmosphere has arrived before it started. What proves
the plumbing is turning a scrubber round.

Related pack specs: `tests/adapters_test.luau` (pull the layer adapter
with a wrench and the ring parts from the department, conserving every
mole).
