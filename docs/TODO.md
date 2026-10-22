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

## Blood identity rider

Blood carries its type through `content/riders/blood_identity.luau` and
`content/lib/blood_identity.luau` (legs 1-4 in
`tests/bodies/blood_identity_test.luau`); illness indices ride separately in
the `contagion` rider ([biology/illness.md](biology/illness.md)). A donor
cannot be named, and the crew record does not show a player's type. The
engine owns rider transport and meetings and reads no disease or donor word: a rider
follows its carrier through draw, pour, split and injection, only vessels
and bloodstreams keep it, and cells, tanks and canisters shed it. Rosters,
medical behaviour, progression, immunity, forensics and presentation are
pack Luau. tg anchors: `blood.dm:400-410` (infection before compatibility),
`carbon/life.dm:479-499`, `elements/blood_reagent.dm:172-235` (merge),
`datums/dna/dna.dm:249-257`, `scanners/health_analyzer.dm:402-409`.

Blood typing and health-analyzer reports are implemented; see
[Blood types](biology/blood-types.md).

The remaining deferred legs are:

- Field `dna` on `blood_identity` is vessel identity: it names the donor of
  blood in a vessel or bloodstream, with a declared no-donor value for
  synthetic packs. Deck forensics is not this field: a pack table keyed by
  the blood decal instance, written at the wound by `content/lib/bloodshed.luau`,
  which knows the victim.
- The toxin answer uses one note queue per issuing prototype
  (`blood_identity.note_transfusion`). It still assumes issue-order
  completion and one note per stroke; an admitted command with no completion
  leaves a stale note. One meet handler replaces the queue when the engine
  carries the parcel's carrier moles on `matter.rider.arrived` and
  `matter.rider.meet` (journal rows and anchor payloads).

Known gaps: crew sharing a name share a type; a body without a Mind keys its
draw on `body.name`, so matching names can collide.

Done: the crew record shows each player's type. Donor identity is named in
vessel `dna`, synthetic packs use a declared no-donor value, and deck records
are keyed by the blood decal instance, with separate assertions for donor
identity and deck forensics.
