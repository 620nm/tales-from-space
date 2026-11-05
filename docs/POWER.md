# The station's power

What this pack chose about electricity: which load class each consumer
draws on, what the panels, banks and fittings store, the ladder a panel
runs as its cell drains, the alarm it raises, and what a fitting looks
like on its own cell.

The MECHANISM — cable layers and ports, the cadenced balance (default 2 s),
outlets and cords, stores, gates and load classes — is the engine's, and is not
restated here: read the engine checkout's `docs/POWER.md` and its
children (`docs/power/stores.md`, `docs/power/load-classes.md`,
`docs/power/topology.md`, `docs/power/cords-and-doors.md`). An older
citation of "docs/POWER.md, Outlets and cords" or "Layers and ports"
names that engine doc. This file owns only what THIS pack chose.

Sources: `content/compositions.luau`, `content/lib/load_classes.luau`,
`content/structures/power/{apc,smes,light}.luau`,
`content/fixtures/{apc,light}.luau`, `content/lib/netmsg.luau`,
`content/items/tools/multitool.luau`, `tests/power/`.

## Load classes

The power network declares tg's three area channels
(`code/__DEFINES/machines.dm:3-5`) as its load classes, in this order
(`lib/load_classes.luau`, read by every caller that walks them), and
`equipment` is the default of any consumer that names none — tg's
machine default (`_machinery.dm:118`).

| class | tg | who draws on it |
|---|---|---|
| `equipment` | AREA_USAGE_EQUIP | every corded structure and machine naming none: `content/machines/*.luau`, the access point, the cadaver chamber, and the Bay-line evaporator and steam generator (not tg atmospherics) |
| `lighting` | AREA_USAGE_LIGHT, `light.dm:12` | `light` |
| `environment` | AREA_USAGE_ENVIRON, `door.dm:16`, `atmosmachinery.dm:18`, `_air_alarm.dm:10` | `airlock`, `airlock_wide`; `vent`, `bidirectional_vent`, `air_scrubber`, `air_injector`, `pump`, `volume_pump`, `temperature_gate`, `temperature_pump`, `filter`, `mixer`, `thermomachine`; `air_alarm` |

A utility outlet port draws on no class: it passes whatever its cable
carries. tg's high-volume vent is EQUIP (`vent_pump.dm:362-364`) and is
not shipped. `air_sensor` declares no network and draws nothing.

## Between levels

Cable never joins across levels on its own, whatever lies between (glass,
a hole). The `power` kind `hub` (tg's multi-z cable hub, `power/multiz.dm:1-12`)
joins only a hub on the same channel directly above or below it; the pipe kind
`adapter` (tg's "Multi-Deck Adapter", `pipes/multiz.dm:2-60`) does the same for
gas. One channel per hub, unlike tg's all-layer hub; the adapter joins every
lateral side, unlike tg's one-mouth adapter. The coil's dial lays a hub
after its three lines; the dispenser and RPD dispense the adapter
(`tests/levels/vertical_links_test.luau`).

## Floor outlet covers and connections

Utility outlet ports are small flush floor plates with a round removable
cap. They start closed; an empty-hand primary click within reach opens or
closes the cap. Tools keep their normal use priority. The closed cap hides
the three independent cable-layer lamps and opening it shows them; it never
changes electrical delivery or what a lamp reports.

Hovering an open port draws arrows to visible consumers: solid green for a
powered connection, solid amber for an unpowered connection, and thinner,
faint dashed grey for reachable alternatives with lower preference. Closed
covers and a pointer outside the port draw no arrows. The prototype owns
all three styles and its `open` eligibility state.

The engine's `docs/looks/connections.md` owns selection and disclosure:
current serving selection wins, otherwise a physically cabled outlet may
remain selected without power. These are derived preferences, not manually
stored plugs. Hidden consumers never appear in the overlay.

## What each prototype stores

| prototype | declares | tg |
|---|---|---|
| `apc` | `store` 1 MJ, charging at 10 kW, `report`; `bridge.gates` | STANDARD_BATTERY_CHARGE (`power.dm:32`, `battery.dm:17`); 1% of the cell a second (CHARGELEVEL, `apc_main.dm:9`, `:708`) |
| `smes` | `store` 5 MJ, 200 kW in and out; `bridge.throttles` | five batteries (`machine_circuitboards.dm:374`), each STANDARD_BATTERY_CHARGE (`battery.dm:17`); `smes.dm:26`, `:37` |
| `light` | `load_class = "lighting"`; `store` 1.2 kJ, charged and drained at 2 W | cell/emergency_light (`cell.dm:237`); LIGHT_EMERGENCY_POWER_USE (`lights.dm:2`, `power.dm:27`) |

Four choices differ from tg on purpose. The panel fits the plain 1 MJ
battery where tg's APC ships the 2.5 MJ upgraded one (`battery.dm:29`,
`apc_main.dm:43`), and starts full where tg's starts at 90%
(`apc_main.dm:41`). The bank holds five plain batteries, 5 MJ, and
starts full, where tg's board ships five high-capacity ones empty
(`machine_circuitboards.dm:376`; `battery.dm:35`, 50 MJ;
`power_store.dm:53`). The bank's throttles start at their 200 kW caps
where tg's start at 50 kW (`smes.dm:24`, `:35`); the engine sets a level
at its store's own cap.

Faces are tg's overlay stacks. The panel wears its cover lock, its
charge screen and one lamp per class (`apc_appearance.dm:49-61`); the
atlas holds only tg's unlocked lock picture (`apcox-0`), so both lock
states draw it. The bank wears its output lamp, its input lamp and a
five-segment bar (`smes.dm:144-150`, `:344-346`).

## The panel ladder

`fixtures/apc.luau` answers `flow.store.done`, which the engine raises
for a `report` store on a real pass whose report changed (charge, feed,
reserve or trip): at most every two seconds and never at equilibrium,
so a full or empty cell is heard once. The boot pass is quiet, so a
panel booting low sheds on the first. It runs tg's autoset (`apc_main.dm:637-664`, thresholds
`:11`, `:13`) and throws each class gate that disagrees, in class
order, with `sim.flow.set_gate`. The ladder is one rung per class of
`lib/load_classes.luau`, and the file refuses to load when a class has
no rung or a rung names no class:

| cell | `equipment` | `lighting` | `environment` |
|---|---|---|---|
| 30% and over | on | on | on |
| under 30% | off | on | on |
| under 15% | off | off | on |
| empty | off | off | off |

So doors, vents, scrubbers, pumps and the air alarm keep running until
the cell is empty, which is tg's intent (`apc_main.dm:645-650`), while
machines drop at 30% and lights at 15%. Each write is a `DeliveryGateSet`
row under the script. The ladder never throws the master: that switch is
the player's, in the panel's window, where the class rows are read-only.

Not yet ported: tg's charge-mode toggle (`apc_main.dm:61`, `:499-503`),
its manual per-channel override (`apc_power_proc.dm:118-123`), and its
emergency-lighting toggle, which keeps a room's fittings off their
cells (`apc_main.dm:537-543`, `light.dm:517`). With no override, a
quarantined `fixtures/apc.luau` (the engine's
`docs/luau-api/runtime.md`) leaves every panel's class gates where they
stand for the rest of the shift.

## The power alarm

The same handler keeps `lunatic/tfs:power_alarm` on the panel, replicated
to `sight`: raised when the network is tripped or the cell is under
30%, cleared only when the breaker is back and the cell is over 75%
(`apc_main.dm:15`, `:672-673`). Every raise and clear is a `VarSet` row
in the round record, and a spec reads it through `t.structure_at`'s
`vars`. The panel's window does not show it yet.

## Running on reserve

`flow.reserve.done` fires when a gated panel starts, or stops, feeding
its bus off its own cell, and the panel emits the `low_power` light flag
onto its network, set or clear (`lib/netmsg.luau`). Every fitting it
feeds hears it as parent or sibling and dims to half power, colourless:
the flag is a condition in the fitting's flag stack, and the worst
condition wins. Which output layers a panel feeds off its cell is the
map's `<layer>_reserve` flag (the engine's `docs/power/map-format.md`).

## A fitting on its own cell

A fitting with no socket serving `lighting` in cord reach — the mains
gone on a layer its panel does not feed from reserve, or its panel has
shed `lighting` — runs off its own cell while the cell holds a pass's
draw, and the engine says so on `flow.source.done`. `fixtures/light.luau`
then burns tg's low-power look (`light.dm:67-73`, applied at
`:536-538`), superseding the flag stack as tg's low-power branch
supersedes area effects (`light.dm:282-289`):

| | value | tg |
|---|---|---|
| colour | `#FF3232` | COLOR_VIVID_RED (`colors.dm:64`) |
| range | a quarter of the tube's: 6 → 1.5 | `bulb_low_power_brightness_mul` 0.25 |
| power | 0.75 × the cell's level, never under 0.5 | `bulb_low_power_pow_mul`, `_pow_min` |

The power is set once, at the switch, where tg recomputes it every
tick. At 2 W a full cell lasts ten minutes; the fitting goes dark when
it empties, and back to its flag stack the moment it hears the grid.
While fed it recharges at 2 W, billed to the socket serving `lighting`
where tg bills its cell to EQUIP (`power.dm:253`, called at
`light.dm:335`; the engine's `docs/power/stores.md`). A shed `lighting`
class therefore stops recharging too.

The tube's pixels need no picture of their own: the engine draws the
fitting's greyscale `light_layer` in the colour and power it burns, so
the red above is also the tube on the wall.

## The multitool

Held to an open deck, the multitool reads `sim.segment_live` and says
which classes the cable carries, one authored sentence per set of
classes in class order (`items.multitool.carrying_*` in
`locale/en.json`), or that it is dead.

## The gas turbine

tg's gas turbine (`code/modules/power/turbine/`) stands in three sections
along one line: the inlet compressor behind the core rotor, the turbine
outlet ahead of it, each built on a machine frame from its own board and its
one installable part (`lib/power/gas_turbine.luau`). The tool vendor sells
the four boards and the tier-one parts; tiers two to four are map-placed
only. A screwdriver opens or shuts a section's panel; open, it turns (tg's
wrench is the Rotate gesture here) and a crowbar takes it apart. A line
mapped or built whole links silently. A multitool on the shut core rotor
checks the line in tg's order (`turbine.dm:497-559`), says the first break,
and on a whole line logs the rotor in its buffer; the same multitool on the
control computer links it to that rotor, on the same map and not since
rebuilt. Opening any panel on the line unlinks it. An empty hand opens the
console's window on its rotor (`lib/power/gas_turbine_console.luau`).

The sections move no gas and make no power: tg's compression, expansion,
rpm, damage and grid output (`turbine.dm:625-685`) wait on a native device.
Each part's tier carries tg's efficiency (`turbine_parts.dm:31-54`,
`:107-117`) in its `component`, and its rated rpm and temperature on its
examine line (`:18`), from `lib/power/turbine_parts.luau`.
