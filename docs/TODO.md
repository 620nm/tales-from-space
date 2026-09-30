# Tales from Space — owed work

Work this pack still owes, one `##` entry per item: the problem with code
pointers, then a `Done:` paragraph that is the acceptance criterion. Finished
work is deleted, not archived. Entries that wait on the engine say "once the
engine offers X"; engine contracts are the engine's `docs/…`.

## Hover highlight treatment

`ui/overlay/main.tsx` draws the hover card and the pixel-perfect highlight
because the engine highlights by default.

Done: once `interactions.hover` exists, `content/capabilities.luau` declares
the treatment `"lift"`, and the pixel-perfect highlight and the hover card in
`ui/overlay/main.tsx` look and behave as they do now.

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
