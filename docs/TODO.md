# Tales from Space — owed work

Work this pack still owes, one `##` entry per item: the problem with code
pointers, then a `Done:` paragraph that is the acceptance criterion. Finished
work is deleted, not archived. Entries that wait on the engine say "once the
engine offers X"; engine contracts are the engine's `docs/…`.

## Vital organs: heart failure and brain removal

`content/operations/repair_heart.luau`, `content/items/anatomy/organ_heart.luau`,
`content/items/surgery/defib.luau` and `content/bodies/human.luau` treat a
missing heart as death.

Done: a missing heart is total heart failure. Oxygen damage accrues over time
and the body dies only if the operator is too slow; paddles are needed only
then (tg `life.dm:789-796`, `heart/_heart.dm:113-160`). The grace is an
`arrest_grace_s` knob on the heart, once the engine offers it. Removing the
brain is instant death that severs mind from body, and always needs paddles.

## Aim groupings and absent parts

`content/part_tree.luau` and `content/bodies/human.luau` (`target_slot`) lay
out the numbered target keys, but the engine assumes an aimed part exists.

Done: the pack defines its target groupings and declares what happens when
an aimed part is absent on the target's body plan, with a spec for a target
that lacks the aimed part.

## Air alarm modes and thresholds

`content/fixtures/air_alarm.luau` and `content/structures/atmos/air_alarm.luau`
read joined machines through the reach proxy but carry no tg modes or
thresholds.

Done: tg's air alarm modes and threshold tables run as pack Luau over the
reach proxy, cited `file:line` against the tg checkout, with specs in
`tests/atmos/environment/air_alarm_test.luau`.

## Speech stacking

`ui/voice.ts` draws each speech bubble alone, so overlapping speakers
overprint.

Done: `ui/voice.ts` stacks bubbles over the engine's bounded per-speaker
queue, newest nearest the speaker, with a UI acceptance capture.

## Pin the engine revision

`assets/tg-revision` pins the tg checkout; nothing pins the engine
(`.github/workflows/ci.yml` checks out the engine at its head).

Done: `assets/lunatic-revision` holds an engine sha, `.github/workflows/ci.yml`
checks that sha out, and a lint in `tools/` fails when the pinned sha is not
reachable in the engine. It mirrors `assets/tg-revision`.

## Blood identity rider (design settled 2026-10-19, Draft)

Blood carries no identity: the pack declares no rider kinds, so a
transfusion cannot be typed, reacted to, or traced. The shape, built so
DNA and contagion slide in without a rewrite:

- Kind `blood_identity`, carriers `{ "blood" }`, field `type` (ref into a
  `blood_types` roster: tg's eight human types with `compatible_types`
  beside them in the lib, `blood_types.dm:175-240`; assignment by tg's
  weights `__HELPERS/mobs.dm:10-22`). Later field `dna` (number, minted
  with `sim.random_keyed` on the Mind's stable identity). Meet:
  receiver wins, settled explicitly; an incompatible type reacts per tg
  (`blood.dm:406-410`, `carbon/life.dm:495-499`).
- Kind `contagion`, carriers `{ "blood", "water" }`, field `illnesses`
  (refs into an `illnesses` roster). Meet: union. Declared when the
  first illness entry exists; written here so the first kind's choices
  already fit it.
- One writer (`blood_identity.stamp(body)` in one lib function, run on
  the body's first `blood_harmony.on_life` pass), one meet dispatcher
  registered per kind, specs assert rider fields by name, carriers never
  widened for convenience.
- Before the reaction leg: confirm whether the meet payload carries
  arrived moles (engine `docs/luau-api/anchors.md`); if not, the meet
  only settles the type and tg's figure lands at the transfer
  completion, which knows the dose.

Done: the three-vessel spec (syringe and beakers, one world) passes its
first four legs — compatible O- into A+ settles silently after one meet;
incompatible A+ into O- is refused with tg's toxin at half volume; a
split draw keeps the rider on both halves; blood drawn back out of
blood+water clears `blood_identity` as carrier-gone — and legs five
(contagion survival, per-vessel cure, transfusion transmission) and six
(per-vessel `dna` naming the donor) join the same world when their kinds
land.
