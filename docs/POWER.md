# The station's power

What this pack chose about electricity: which load class each consumer
draws on, what the panels, banks and fittings store, the ladder a panel
runs as its cell drains, the alarm it raises, and what a fitting looks
like on its own cell.

The MECHANISM — cable layers and ports, the 0.5 Hz balance, outlets and
cords, stores, gates and load classes — is the engine's, and is not
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

A prototype under `structures/` spells its own class word, because
`lib/` is not published into the structure registry's sandbox.

## What each prototype stores

| prototype | declares | tg |
|---|---|---|
| `apc` | `store` 1 MJ, charging at 10 kW, `report`; `bridge.gates`; `names_room` | STANDARD_BATTERY_CHARGE (`power.dm:32`, `battery.dm:17`); 1% of the cell a second (CHARGELEVEL, `apc_main.dm:9`, `:708`) |
| `smes` | `store` 5 MJ, 200 kW in and out; `bridge.throttles` | five batteries (`machine_circuitboards.dm:374`); `smes.dm:26`, `:37` |
| `light` | `load_class = "lighting"`; `store` 1.2 kJ, charged and drained at 2 W | cell/emergency_light (`cell.dm:237`); LIGHT_EMERGENCY_POWER_USE (`lights.dm:2`, `power.dm:27`) |

Three choices differ from tg on purpose. The panel fits the plain 1 MJ
battery where tg's APC ships the 2.5 MJ upgraded one (`battery.dm:29`,
`apc_main.dm:43`), and starts full where tg's starts at 90%
(`apc_main.dm:41`). The bank's throttles start at their 200 kW caps
where tg's start at 50 kW (`smes.dm:24`, `:35`); the engine sets a level
at its store's own cap.

Faces are tg's overlay stacks. The panel wears its cover lock, its
charge screen and one lamp per class (`apc_appearance.dm:49-61`); the
atlas holds only tg's unlocked lock picture (`apcox-0`), so both lock
states draw it. The bank wears its output lamp, its input lamp and a
five-segment bar (`smes.dm:144-150`, `:344-346`).

## The panel ladder

`fixtures/apc.luau` answers `flow.store.done`, which the engine raises
for every `report` store on every real pass (every two seconds; the
boot pass is quiet, so a panel booting low sheds on the first). It runs tg's autoset (`apc_main.dm:637-664`, thresholds
`:11`, `:13`) and throws each class gate that disagrees, in class
order, with `sim.flow.set_gate`:

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

Not yet ported: tg's charge-mode toggle (`apc_main.dm:61`, `:499-503`)
and its manual per-channel override (`apc_power_proc.dm:118-123`).

## The power alarm

The same handler keeps `lunatic/tfs:power_alarm` on the panel, replicated
to `sight`: raised when the network is tripped or the cell is under
30%, cleared only when the breaker is back and the cell is over 75%
(`apc_main.dm:15`, `:672-673`). Every raise and clear is a `VarSet` row
in the shift record, and a spec reads it through `t.structure_at`'s
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
