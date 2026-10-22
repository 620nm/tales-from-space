# Blood types

**Human reservoir.** Blood lives on `human_chest` (the torso carries tg's
bloodstream, `_bodyparts.dm:947-969`) as moles of `blood` in its 6 L bloodstream at 310.15 K.
The pack's runtime `normal = 14` mol converts tg's `BLOOD_VOLUME_NORMAL = 560` u
at 0.025 mol/u (`code/__DEFINES/mobs.dm:20`; the engine's
`docs/chemistry/tg-bridge.md`). Every blood-volume band uses the same conversion
(`code/__DEFINES/mobs.dm:20-25`):

| tg define | Units | Moles |
|---|---:|---:|
| `BLOOD_VOLUME_NORMAL` | 560 | 14 |
| `BLOOD_VOLUME_SAFE` | 476 | 11.9 |
| `BLOOD_VOLUME_OKAY` | 392 | 9.8 |
| `BLOOD_VOLUME_RISKY` | 308 | 7.7 |
| `BLOOD_VOLUME_BAD` | 224 | 5.6 |
| `BLOOD_VOLUME_SURVIVE` | 112 | 2.8 |

The pack's `dead_below` uses the `BLOOD_VOLUME_SURVIVE` band. The `human`
plan declares one reservoir, `blood`, as its
`wound_reservoir`: `stack_drain_per_s = 0.0125` (0.5 u/s x 0.025,
`_bodyparts.dm:1629-1630`) and `lying_factor = 0.75` (`_bodyparts.dm:1667-1668`);
the engine needs both knobs and refuses a reservoir without them. Regrowth and
the low-blood oxygen cost (`mobs.dm:28`; `blood.dm:253-262`) use
`content/lib/blood_harmony.luau`. Blood above normal is drawn back to normal in
one pass by choice: tg trims a surplus over time, and this pack settles a
transfusion at the next body cadence instead.

## Roster and compatibility

The type order and weights match tg's weighted picker
(`code/__HELPERS/mobs.dm:10-22`). The pack roster declares this order; the rider
stores the zero-based position (`content/rosters/blood_types.luau`;
`content/lib/blood_identity.luau`). Table weights follow tg's picker and donor
types accepted by each recipient follow tg's `compatible_types`
(`code/modules/mob/living/blood_types.dm:175-240`).

| Index (0-based) | Type | Weight | Donors accepted by recipient |
|---:|---|---:|---|
| 0 | O- | 4 | O- |
| 1 | O+ | 36 | O-, O+ |
| 2 | A- | 3 | A-, O- |
| 3 | A+ | 28 | A-, A+, O-, O+ |
| 4 | B- | 1 | B-, O- |
| 5 | B+ | 20 | B-, B+, O-, O+ |
| 6 | AB- | 1 | A-, B-, AB-, O- |
| 7 | AB+ | 5 | A-, A+, B-, B+, O-, O+, AB-, AB+ |

## Typing and transfusions

On a primary `body.spawn.done`, after native setup assigns the final name,
`blood_identity` stamps a type; `on_life` retries when regrown blood can carry
it and leaves settled types unchanged (`content/bodies/human.luau`; `content/lib/blood_identity.luau`;
`content/lib/blood_harmony.luau`; the engine's `docs/luau-api/lifecycle.md`). A rider
meet settles receiver-wins. An incompatible transfusion requests toxin equal
to half the moles actually moved (`code/modules/mob/living/blood.dm:406-410`);
incompatible donor blood added directly as a substance makes the same request
(`code/modules/mob/living/carbon/life.dm:495-499`). Both requests are bounded
by the native holder's remaining capacity
(`code/modules/reagents/chemistry/holder/holder.dm:119-124`).

See [IV drips](iv-drip.md) for connection, flow, and disconnection behavior.

## Health analyzer

The analyzer sends its report lines privately and immediately to the user. Its
explicit self action scans the user. A body scan reads one reachable, visible and
disclosed body on the same plane within one tile, diagonals included. A vessel
scan reads the accessible, disclosed matter item selected as the exact target.
It inspects only that target, never hidden crate contents, and never assigns a
blood type. tg's item interaction selects a living body
(`code/game/objects/items/devices/scanners/health_analyzer.dm:65-104`); the pack
also scans a selected matter vessel
(`content/items/surgery/health_analyzer.luau:215-228`).

A body report shows overall health as a whole percent or deceased status,
then the brute, burn, toxin and suffocation values, each rounded up
(`content/items/surgery/health_analyzer.luau:53-79`;
`code/game/objects/items/devices/scanners/health_analyzer.dm:151-171,230-245`).
When blood and a positive normal are available, the displayed percent rounds
`blood / blood_normal x 100` to a whole percent. The bands use the raw fraction:
LOW is above 70% through 85%, CRITICAL is at or below 70%, and normal is above
85%. Volume in cl is blood moles divided by 0.025 mol per cl, retaining
fractional cl (`content/items/surgery/health_analyzer.luau:81-95`). The fraction
limits match tg's SAFE (85%) and OKAY (70%) thresholds against its 560-u normal;
the pack applies them to the body's `blood_normal`
(`code/game/objects/items/devices/scanners/health_analyzer.dm:376-410`;
`code/__DEFINES/mobs.dm:20-22`).

When body blood data is available, a typed body reports its type and
compatible donor types in the order shown in the table above. An untyped body
still reports percent and volume without a type and omits the donor line. LOW
recommends a compatible blood transfusion; CRITICAL recommends an urgent
compatible blood transfusion. Donor and recommendation text is plain private
output instead of tg's conditional HTML tooltips
(`content/items/surgery/health_analyzer.luau:97-119`;
`code/game/objects/items/devices/scanners/health_analyzer.dm:385-408`). The pack
does not implement iron's blood-restoration effect
(`content/substances/iron.luau:1-3`) or salglu's blood-volume effect
(`content/substances/salglu.luau:22-26`), so recommendations are transfusion
only.

A vessel report sums the exact target's blood across solid, liquid and gas
matter phases, converts it to cl and prints its settled type or `untyped`. An
empty or water-only vessel reports zero cl and still reports a type status.
Vessel inspection reads only the selected matter item; it does not traverse
container contents or stamp blood identity
(`content/items/surgery/health_analyzer.luau:122-138`).

## Blood-type paper stock

The pinned compatibility paper preserves historical L and U rows beyond the
eight types in the human roster (`reference/text/blood-type-compatibility.md`;
`content/rosters/blood_types.luau:6-17`). Native paper file seeds and
openable-structure stock are present at spawn (the engine's
`docs/content-schema/files.md:46-57` and the engine's
`docs/content-schema/variants.md:87`), while tg closets populate contents on
first open through `dump_contents()`
(`code/game/objects/structures/crates_lockers/closets.dm:507-511`).
