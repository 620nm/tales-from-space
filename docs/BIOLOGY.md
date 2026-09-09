# Bodies, damage and surgery — the pack's tuning

What Tales from Space declares over the engine's body mechanism: the
part-tree indices, the human plan, the organ roster, the surgical set, and
every constant that is this pack's choice rather than a tg port.

The MECHANISM is the engine's and lives in the sibling checkout:
`../lunatic/docs/BIOLOGY.md` (plan, pools, capacities, thresholds),
`../lunatic/docs/SURGERY.md` (states, operations, implements),
`../lunatic/docs/LOOKS.md` (the layer stack). Nothing here restates a rule
those files own; this file says which numbers and words fill them.

Numbers carrying a tg cite are ported verbatim (`../lunatic/docs/PORTING.md`).
Numbers marked **not ported** are this pack's own invention — tg has no
capacity model, so RimWorld's shape carries our constants.

## `content/part_tree.luau` — the pack-wide indices

| Roster | Rows |
|---|---|
| `equipment` | `id`, `uniform`, `suit` (`seals`), `belt`, `back` (`quick_store`), `mask` (`breathes`) |
| `pools` | `brute`/`burn` — attachment storage, ports `impact`/`heat`; `oxy`/`tox` — owner storage, ports `oxygen_loss`/`toxin_load` (carbon.dm:424-433; _bodyparts.dm:780-803) |
| `properties` | `health` = `health_fraction`, `damage` = `damage_fraction`, `oxy`/`tox` = `{ pool = … }`, `blood` = `blood_fraction` |
| `capacity_roles` | `consciousness moving manipulation sight hearing speech breathing blood metabolism`, each bound to the same-meaning native port |
| `readouts` | `brute burn oxy tox` off pools; `pressure`/`temperature` (suffix `C`)/`tank` off the telemetry ports |
| `aim` | `aimed = 80`, `lying_bonus = 10`, `thrown = 65` (item_attack.dm:321-326; living_defense.dm:263-264) |

The ids are ours; the ports are the only thing the engine reads. Slot
capabilities are properties of the PLACE — `mask` is what a supply line
reaches lungs through, `suit` what holds pressure; tg splits the same facts
across MASKINTERNALS and STOPSPRESSUREDAMAGE (__DEFINES/obj_flags.dm:80,84).

## `content/bodies/human.luau` — the plan

`playable = true`, `max_health = 100` (mobs.dm:236), `hands = 2`
(living_defines.dm:120), `default_zone = "chest"`, `knockdown = true`,
`pool_coeff` 1 on all four (basic.dm:51), `doll_sprite = "target_doll"`.

**Thresholds.** `crit` at `health <= 0`, `dead` at `health <= -1`
(combat.dm:88-90), `undone` at `viability <= 0`. The engine latches the
crossing; `content/bodies/human.luau`'s own hook answers it.

**Parts** (declaration order is the ZONE order):

| Slot | `hit_weight` | `max` / `coeff` | `bleed_scale` | Notes |
|---|---|---|---|---|
| `head` | 1 | 200 / 1 | 0.5 | `vital`, target key 8 |
| `chest` | 1 | 200 / 1 | 1 | `vital`, target key 5 |
| `pelvis` | 4 | 50 / 0.75 | 0.25 | target key 2 |
| `l_arm` / `r_arm` | 4 | 50 / 0.75 | 0.25 | `hand = 1` / `hand = 2`, keys 6 / 4 |
| `l_leg` / `r_leg` | 4 | 50 / 0.75 | 0.25 | keys 3 / 1 |

Weights and the core/limb split are tg's (mob_helpers.dm:36-41;
bodyparts.dm:8-11, 23-26; _bodyparts.dm:1639-1644). Every part item carries
`efficiency = {{0,1},{1,1}}` — flesh never disables by damage, tg's
`LIMB_NO_DISABLE` (__DEFINES/bodyparts.dm:71) — `pool_mod` 1 on brute and
burn, and `robotic = false`.

**Blood** lives on `human_chest`, because tg carries the carbon bloodstream
with the torso (_bodyparts.dm:947-969): `normal = 560`, `dead_below = 112`,
`regen_per_s = 0.25`, `oxy_per_missing = 0.01` (mobs.dm:20-28;
blood.dm:256-262), and a `bloodstream` holder of the same body of blood —
`volume_m3 = 0.0056` (560 cL read as centilitres) at 310.15 K.

**Sockets and organs.**

| Socket | Zone | Tags | `requires` |
|---|---|---|---|
| `brain` | head | `brain` | `bone_sawed`; `mind_seat` |
| `eyes` / `ears` / `tongue` | head | `eye` / `ear` / `tongue` | — |
| `heart` / `lungs` / `liver` / `stomach` | chest | `heart` / `lung` / `liver` / `stomach` | `bone_sawed` |
| `appendix` | chest | — | `bone_sawed` |

Chest organs and the brain behind a saw is tg's `organ_check`
(operation_organ_manip.dm:279-284).

## Not ported — the capacity constants

tg has no capacity model, so these are ours. The formula VOCABULARY is
RimWorld's; the numbers are not reconstructed from anywhere.

| Constant | Value |
|---|---|
| `awake_below` on `consciousness` | 0.30 |
| `min_capable` on `moving` | 0.15 |
| every `lerp1` weight | 0.2 |
| limb `efficiency` curve | `{{0,1},{1,1}}` (tg's flesh rule, not a curve tg has) |
| brain `curve` | `{{0,1},{0.6,1},{1,0}}` — a linear brain would slow every `do_after` from the first trauma |
| cybernetic `efficiency` 1.25 | one output multiplier abstracting tg's per-organ tiers (liver x1.2/x1.5, _liver.dm:266-280) |

`best` is declared on no capacity in this pack.

**Ported into the formulas**: the `oxy` step at 50
(`OXYLOSS_PASSOUT_THRESHOLD`, mobs.dm:14), the `blood` step at 0.4
(`BLOOD_VOLUME_BAD` 224/560), the `health` step at -0.3
(`HEALTH_THRESHOLD_FULLCRIT` / `MAX_LIVING_HEALTH`, combat.dm:89), cardiac
arrest's `when_zero` oxy 4/s + brute 1/s held unconscious
(human/life.dm:292-295), liverlessness' tox 0.6/s (carbon/life.dm:746).

**Not carried from tg**: the `BAD..SURVIVE` 7.5 %/s blackout roll
(blood.dm:242-244) — the `blood` step holds the body under instead;
`losebreath += 0.25` in soft crit (carbon/life.dm:89-90) — a per-tick roll
is not a hook's to make; the liverless 0.5/s random organ damage
(carbon/life.dm:746-747).

## Organs — `content/items/organ_*.luau`

`max_health / low / high`, then `heal_per_s` and `decay_per_s` as fractions
of `max_health` per second (`STANDARD_ORGAN_HEALING` 50/100000 and
`STANDARD_ORGAN_DECAY` 111/100000, DNA.dm:138-141, times the per-organ
multiplier).

| Organ | `max_health` | `low` / `high` | `heal_per_s` | `decay_per_s` | Source |
|---|---|---|---|---|---|
| `brain` | 200 | 45 / 120 | 0 | 0.000555 (x0.5) | brain_item.dm:16-20 |
| `heart` | 100 | 10 / 45 | 0.0005 | 0.0027750 (x2.5) | _heart.dm:11 |
| `lungs` | 100 | 10 / 45 | 0.0005 | 0.000999 (x0.9) | _lungs.dm:11 |
| `stomach` | 100 | 10 / 45 | 0.0005 | 0.0012765 (x1.15) | _stomach.dm:16 |
| `liver` / `ears` / `appendix` | 100 | 10 / 45 | 0.0005 | 0.00111 (x1) | _organ.dm:30-33 |
| `eyes` | 50 | 20 / 30 | 0.0005 | 0.00111 | _eyes.dm:12-14 |
| `tongue` | 100 | 10 / 45 | 0 | 0 (x0) | brain_item.dm:16 |

`brain` and `heart` are `vital`; `brain` is `mind_seat`.

**Lungs are a vessel**: `volume_ml = 6000` (**not ported** — tg's lungs have
no volume) with `bellows.tidal_ml = 1990`, tg's `BREATH_VOLUME` verbatim.
The engine's bellows stroke is `../lunatic/docs/biology/breathing-and-organs.md`.

## Surgery — the tool words and the set

The engine interns a tool word and never lists one, so this roster is
entirely ours. Surgical implements: `scalpel`, `hemostat`, `retractor`,
`cautery`, `saw`, `drill`, `suture`, `bonegel`. Improvised stand-ins reuse
the construction words and the ordinary item fields — `cutters`,
`screwdriver`, `crowbar`, lit `welder`, `sharp = "edged" | "pointy"`,
`force_min`, `heat`. Their multipliers are tg's, tabled in
`../lunatic/docs/surgery/numbers.md`.

`content/operations/` — times in seconds, tg cites in the files:

| Operation | Time | Numbers |
|---|---|---|
| `incise_skin` | 1.6 | — |
| `retract_skin` | 2.4 | — |
| `clamp_bleeders` / `unclamp_bleeders` | 2.4 | clamp heals brute 20, `heal_if = "bone_sawed"` |
| `close_incision` | 2.4 | heals brute 40, `heal_if = "bone_sawed"`; clears every state |
| `close_incision_self` | 4.8 | `self_only`, burn 5 (tg's x2 time, _operation.dm:134-171) |
| `saw_bone` | 5.4 | brute 50 |
| `drill_bone` | 3 | — |
| `fix_bone` | 4 | heals brute 40, unconditional |
| `incise_organs` | 2.4 | brute 10 |
| `remove_organ` / `insert_organ` | 1 | — |
| `repair_heart` | 9 | `to_fraction` 0.6, failure 0.2 |
| `repair_lungs` | 4.2 | `to_fraction` 0.6, failure 0.1 |
| `repair_liver` | 5.2 | `to_fraction` 0.1, failure 0.15 |
| `repair_brain` | 10 | `to_fraction` 0.25, failure 0.3 |
| `tend_wounds` | 2.5 | flat brute 5 + burn 5, offered only on INTACT skin |

**Divergences from the tg table.** `tend_wounds` applies once per click and
heals a flat 5+5 rather than `5 + 0.07 x loss`, and inverts tg's
availability on purpose so it does not crowd the mid-operation window.
Organ repair models `heal_to` as set-to-fraction for every organ, the brain
included, and the repair times are ours, not tg's. There is no `revival`
operation: a defibrillator is an ITEM here
(`content/items/defib.luau`). `amputate` waits on the engine's B5 wounds.

**The bone lock stays.** Chest sockets keep `requires = { "bone_sawed" }`,
and no improvised edge under force 10 stands in for a saw
(operation_generic.dm:344-346). So the charter's floor rescue is **not a
heart swap**: on bare deck with a shard and wirecutters, incise, retract,
clamp and close take 4, 6, 6 and 6 s at 32 %, 77 %, 20 % and 12 % failure —
expected `4/0.68 + 6/0.23 + 6/0.80 + 6/0.88 ~= 46 s`, the open chest
bleeding 1.5/s then 0.2/s at x 0.75 lying, about 40 units of blood, never
near `BAD`. Dropping `requires` from the chest sockets would make the swap
`4/0.68 + 6/0.23 + 6/0.52 + 2.5/0.89 + 2.5 ~= 49 s` against the 41 s arrest
clock — a coin flip, and this file would have to say so.

## The death latch

The engine latches nothing. `organ_heart` is `vital`, so the `viability`
port reads 0 the moment it is missing or failing; `human.luau`'s threshold
hook calls `sim.fail_organ` on the heart when its own `dead` line is
crossed. Healing the parts clears the health line and leaves the heart
stopped; the body returns only when a replacement is seated, a `repair`
lands, or `content/items/defib.luau` heals it. The engine's account of why
this shape is content's is `../lunatic/docs/surgery/as-built.md`.

## Looks

`human.luau`'s `looks` block draws six part cells in `layers` order
(`chest head l_arm r_arm l_leg r_leg`), `face = "head"`, physiques `m`/`f`,
16 skin tones, and tg's hair and facial-hair rosters. Each roster LEADS
with tg's own default row, because the engine takes the FIRST row as
`Look::default_for` and does not guess. The pack ships no undergarments, so
a crewman is bare under the jumpsuit; tg draws them always
(human_update_icons.dm:668-700).
