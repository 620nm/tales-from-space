# Mop

`content/items/tools/mop.luau`, on `content/lib/vessel.luau`'s `soak`. Each row
is one tg behavior, with its decision: **api** uses an existing pack API, **luau**
is new pack Luau, **adapted** keeps the job and changes the means, **omitted**
gives its reason. No row needs an engine change.

tg paths: `mop.dm` is `code/game/objects/items/mop.dm`, `cleaner.dm` is
`code/datums/components/cleaner.dm`.

## The object

| tg | Behavior | Decision |
| --- | --- | --- |
| `mop.dm:2-6` | Name, description, sprite | api: same words, `obj/service/janitor.dmi` art |
| `mop.dm:6-9` | Custodial in-hands | api: `held_mop_l`, `held_mop_r` |
| `mop.dm:7` | `icon_angle = 135` | omitted: the sprite pipeline draws the cell as baked |
| `mop.dm:10-13` | Force 8, throw 10, speed 3, range 7 | api: verbatim |
| `mop.dm:14` | Normal weight class | api: the pack's default item size |
| `mop.dm:15-16` | Attack verbs | omitted: the pack's melee line is generic |
| `mop.dm:17-18` | Flammable, half a sheet of iron | omitted: items have neither fact here |
| `mop.dm:21` | 15 unit head | adapted: `volume_ml = 250`, the finite head; other tub sizes keep tg's ratio to it |
| `mop.dm:22` | 1.5 s stroke | luau: `SoakSpec.seconds = 1.5`, `sim.do_after` |
| `mop.dm:23` | Force string | omitted: no force readout here |
| `mop.dm:30-36` | Fantasy bonuses | omitted: no fantasy affixes in the pack |
| `mop.dm:41` | Walking aid | omitted: no limp mechanic to aid |
| `mop.dm:43` | `janitor_devices` for the locator | omitted: no custodial locator |
| `mop.dm:77-119` | Advanced mop, condenser | omitted: not requested |

## The stroke

| tg | Behavior | Decision |
| --- | --- | --- |
| `mop.dm:40` | Cleaner component on tile click | luau: `soak` action on any tile without a wall or reinforcement, so natural ground counts |
| `cleaner.dm:96` | One clean at a time per tool | luau: `stroking` list; a second click on a busy mop does nothing until the stroke ends, and an entry past its end is free |
| `cleaner.dm:120-143` | Timed action, interrupted by moving | api: `sim.do_after` with `stationary`; a stroke interrupted by walking lifts nothing |
| `mop.dm:24-28,51` | Never scrubs a bucket, mop bucket or sink | adapted: clicking a vessel wrings; the deck branch never sees one |
| `mop.dm:53-55` | A dry mop refuses | omitted: a mop here starts dry and absorbs |
| `mop.dm:56-58` | Cleans only with a cleaning reagent | omitted: same reason; residue sweeps regardless (`docs/TURFS.md`) |
| `mop.dm:68-75` | Stroke spends the head onto the tile | adapted, reversed: the tile fills the head |
| `mop.dm:71` | Exposes the floor, wetting it | omitted: a film underfoot is out of scope for this work |
| `mop.dm:74` | Cleaning skill scales the spend | omitted: no skills in the pack |

## What a stroke lifts

| Found on the tile | Result | Line |
| --- | --- | --- |
| Settled liquid | Lifted, trimmed to the head | "You run the mop over the deck." |
| Floating beads (`sim.matter.liquid_settling`) | Lifted the same way | "You chase the floating beads into the mop." |
| Loose solid, no liquid | Lifted | "You scrape the deposit up into the mop." |
| Liquid with loose solid | Both lifted, in proportion | The liquid's line |
| Ice (`pinned_solids`) | Liquid lifted; every solid on that tile stays | The liquid's line, or dry |
| Nothing loose | Nothing | "The deck here is dry." |
| Any tile, head full | Nothing lifted | "The mop is soaked through." |

A **deposit** is solid-phase matter in the tile's cell: ash, salt, reaction
solids. Ground `material` is a still fact of the tile, not cell matter, and
stays. Shards and fallout are residue, swept whether or not the head lifts
anything. Decals are never cleanable (`docs/TURFS.md`).

Ice pins a tile because `sim.matter.transfer` filters by phase, not substance:
lifting the solids would lift the ice. A `substance` filter on transfer is the
generic primitive that would free ash lying on ice.

## Where the head goes

| tg | Behavior | Decision |
| --- | --- | --- |
| `_cup.dm:636-644` | Bucket douses the mop, 5 u | adapted, reversed: mop click on any vessel wrings the head into it |
| `janitor.dm:31-44` | Mop bucket douses the mop | adapted, reversed: secondary on a tub pours the head in |
| `janitor.dm:33-35` | A soaked mop refuses a dousing | adapted: nothing douses a mop; a full head refuses a stroke with the soaked line |
| Not in tg | Empty mop refuses a wring | api: the vessel's empty line |
| `code/game/objects/structures/water_structures/sink.dm:166,228`, `water_source.dm:93` | Sink wets a mop | omitted: no sink fixture |
| `other_reagents.dm:162` | Water wets the floor | omitted: as `mop.dm:71` |
| `robot_upgrades.dm:205` | Cyborg advanced mop | omitted: no such module |

A full mop has no picture of its own: `janitor.dmi` holds one `mop` state and tg
draws nothing for a wet one, so the soaked line is the only tell. A wet mop
needs new art.

The head is an open vessel, so what it holds can evaporate and take the deck's
temperature.
