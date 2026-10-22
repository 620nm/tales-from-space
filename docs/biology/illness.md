# Illness

TG source values below refer to pinned `tgstation@7cb126ac8864a0d0952c48d25375a5bebaef512b`.

## Carrier and catalog

The `contagion` rider is carried by blood and water. Its `illnesses` field is
a `refs` set into the ordered `illnesses` roster, so each value is a
zero-based roster index. The current roster contains `rhinovirus` at index 0.
The carrier rule follows any amount of either substance in any phase, and the
engine carries riders through draws, splits, transfers and pours (the engine's
`docs/content-schema/riders.md:30-40` and `docs/matter/rider.md:46-63`).

The engine preserves separate same-kind rider entries as pending meetings
(the engine's `docs/matter/rider.md:56-63,83-95`). Vessel meetings union,
deduplicate, sort and settle their illness indices. Body arrivals and meetings
instead pass the carried indices to host exposure. The host keeps only accepted
active infections, then synchronizes the bloodstream rider to that set; a
resistant or otherwise rejected exposure can leave a subset or an empty rider
(`content/lib/medical/contagion.luau:177-190`,
`content/lib/medical/host_illness.luau:160-195`).

Active infection state lives in the body's private server-only
`lunatic/tfs:illnesses` variable; resistance lives in the separate private
server-only `lunatic/tfs:illness_resistance` variable. Neither belongs to the
Mind. `host_illness.snapshot` returns a fresh, sorted copy for reporting
(`content/lib/medical/host_illness.luau:22-23,29-31,102-119,197-200`,
`content/lib/medical/illness_course.luau:58-113`).

Fluid exposure requires a live, animating human with working lungs, a working
heart and nonzero blood. The shared fluid event cannot distinguish ingested
matter from an injection. tg checks the stomach for `INGEST` and the heart for
`INJECT` or `PATCH` (`code/datums/elements/blood_reagent.dm:97-105`), so the
fluid route uses the heart-and-blood gate as its shared approximation. The
`airborne` exposure route retains the lung requirement and skips that
fluid-only heart-and-blood gate (`content/lib/medical/host_illness.luau:70-89,129-158`).

## Rhinovirus course

The catalog entry is `rhinovirus`, named **The Cold**, with agent
`XY-rhinovirus`, three stages, a 0.5 spreading modifier, infectivity 41, and
lungs as its required organ (`code/datums/diseases/cold.dm:1-12`,
`code/datums/diseases/_disease.dm:23-48`). The course follows tg's base
`/datum/disease/cold` values. Stage progression uses `stage_prob * 2`, or
4% per second; each successful roll toggles `half_stage`, and every second
success advances the stage (`code/datums/diseases/_disease.dm:157-166`).

Each symptom has its own 0.5% per-second roll at stages 2 and 3: sneeze,
cough, sore throat, and mucus (`code/datums/diseases/cold.dm:25-47`). A
per-second probability `p` applied over `s` seconds uses
`1 - (1 - p/100)^s`, matching tg's `SPT_PROB` (`code/__DEFINES/maths.dm:243-247`).
The illness cadence applies these probabilities with keyed randomness
(`content/lib/medical/illness_course.luau:14-33,130-140`).

The host advances on its two-second life pass and converts each per-second
chance across the elapsed time (`content/bodies/human.luau:744-751`,
`content/lib/medical/illness_course.luau:142-159,336-354`). The lying-down and
baseline cure rolls are separate alternatives, not a single conditional rate.
At stage 2, lying down gives 23% per second and the independent baseline gives
0.025% per second. At stage 3, the rates are 12.5% and 0.005%. A successful
rest cure or stage-1 natural final cure records resistance; losing a required
organ removes the infection without resistance
(`code/datums/diseases/cold.dm:35-55`,
`code/datums/diseases/cold.dm:14-18`,
`content/lib/medical/host_illness.luau:224-245`,
`content/lib/medical/illness_course.luau:220-234,348-352`).

Natural recovery does not wait for 180 cycles. Each life pass adds
`stage / max_stages` to `peaked_cycles`; the base chance per second is
`peaked_cycles / (180 / 2)`, multiplied by 1.2 after the stage peak, clamped to
0–100, then converted across elapsed time with SPT. If natural recovery rolls
at stage 1, the separate ordinary final gate is `prob(4 * 6)`, or 24%
(`code/__DEFINES/diseases.dm:60-103`,
`code/datums/diseases/_disease.dm:189-192,244-262`,
`content/lib/medical/illness_course.luau:14-33,130-140,207-234`).

Only lying posture is a supported rest cue. The body model has no sleep,
nutrition or mood state, and there is no spaceacillin, so the course omits those
tg recovery modifiers (`content/part_tree.luau:48-54`,
`code/datums/diseases/_disease.dm:129-135,193-242`). The stage-3 flu conversion
and contact-skin spread are also absent
(`code/datums/diseases/cold.dm:39-52`,
`code/datums/diseases/_disease.dm:4-5`). Blood and water carriage does not
mean direct skin transmission. Only live, animating human bodies run the host
course (`content/lib/medical/host_illness.luau:87-89,202-211`).

While a host is infected, its bloodstream carries the matching contagion
rider so drawn blood remains infectious. Cure removes that illness from the
body state and rewrites or clears the bloodstream rider.

## Airborne spread

This pack follows intended airborne spread instead of tg's inverted source
guard: `airborne_spread` returns when `can_spread_airborne_diseases()` is true,
although a positive predicate result denotes an eligible source. The pack uses
explicit source checks (`code/datums/diseases/_disease.dm:300-309`,
`code/datums/diseases/_MobProcs.dm:136-159`,
`content/lib/medical/airborne.luau:127-145`).

The human life callback advances `host_illness` before `airborne`. Each body
adds `ev.elapsed_seconds` to its private airborne timer and receives a breath
attempt whenever that timer reaches eight seconds, independent of global tick
phase. The interval matches tg's healthy breath cadence of four two-second life
passes (`content/bodies/human.luau:744-751`,
`content/lib/medical/airborne.luau:4,115-125`,
`code/modules/mob/living/carbon/life.dm:46-57`).

At each eligible boundary, each active rhinovirus infection uses
`SPT(41 × 4, 2 s)`, or 59.04%, for the source breath gate. The 164% per-second
input is left intact inside the two-second SPT conversion; it is not clamped
first. Only after a successful source roll does each eligible target get its
separate 24% check,
`min(50 × 0.5 − 1, 50)`, from the 0.5 spreading modifier. The existing SPT
formula defines the conversion above. Source and target draws use separate
illness-specific purposes keyed to their respective bodies
(`code/datums/diseases/cold.dm:1-12`,
`code/datums/diseases/_disease.dm:419-423`,
`code/__DEFINES/maths.dm:244-247`,
`code/datums/diseases/_MobProcs.dm:102-109`,
`content/lib/medical/airborne.luau:147-182`).

A source must be alive, have an animating body with working lungs and positive
breathing capacity, lack a worn `breath_mask`, lack active internals, and have a
tile. Candidates come from an unfiltered radius-three query on the same plane
and level. The helper uses the native body fact's `animate` flag, excludes the
source, then limits recipients to absolute-coordinate Chebyshev distance two,
including diagonals. It also requires native line of sight: an intermediate
projectile-blocking or dense tile, or a shut door, blocks the path; endpoints
do not. This shared-air approximation reads neither atmospheric connectivity
nor FOV (`content/lib/medical/airborne.luau:98-102,158-168`; the engine's
`docs/luau-api/queries.md:101-111`).

Both source emission protections are hard blocks. Internals state is copied from
the native `inventory.present.supply` fact onto the tank item; emission reads
only current hand and worn inventory entries, so a dropped or stowed tank does
not leave protection on its former carrier (`content/lib/item_actions.luau:5-18`,
`content/lib/medical/airborne.luau:35-53,134-137`).

At the target, the pack reads the `lunatic/tfs:biology.bio_protection` script
var from worn items, sums declared BIO points, and caps the total at 100. The
current pack initializes the var on its breath mask; future head and mask data
can declare the same var. The catch gate tests active internals first at 75%,
then BIO points, matching tg's carbon override followed by the parent check
(`content/lib/medical/airborne.luau:71-84,169-180`,
`code/datums/diseases/_MobProcs.dm:163-186`). The breath mask's pack data is
50 BIO, matching tg's `/obj/item/clothing/mask/breath` value
(`content/items/gear/breath_mask.luau:3-7,49-52`,
`code/modules/clothing/masks/breath.dm:19-20`), so it blocks about half of
otherwise eligible catches. The current pack defines no medical-mask item;
tg's medical mask is 90 BIO (`code/modules/clothing/masks/breath.dm:49-50`),
which future pack data can declare on the same var. Active internals leaves
about one quarter of otherwise eligible catches. With neither protection, the
protection gates always pass. Deterministic roll-stub assertions exercise the
production gate through `content/fixtures/bio_protection.luau`, driven by
`tests/helpers/airborne_protection.luau` from
`tests/bodies/rhinovirus_spread_test.luau`.
Host exposure remains authoritative for recipient human-body, required-organ
and resistance checks; the airborne route skips only the fluid-specific
heart-and-blood gate described above. The
helper delegates accepted candidates to `host_illness.expose` and does not
write illness state itself (`content/lib/medical/airborne.luau:182`,
`content/lib/medical/host_illness.luau:74-89,129-194`).

## Culture bottle

The culture variant holds 0.1125 mol of blood: 4.5 tg units at 0.025 mol per
unit. Blood has a molar mass of 400 g/mol and density 1.0 g/mL, so the charge
occupies 45 mL in the bottle's 50 mL shell and leaves 5 mL of headspace
(`content/substances/blood.luau:6-12,31-34`,
`content/items/vessels/bottle.luau:39-41`, and the engine's
`docs/content-schema/vessels.md:15-19`). The initializer seeds only
`contagion` with `rhinovirus`; it does not assign a `blood_identity` rider, so
the synthetic culture remains untyped.

tg names its variant `Rhinovirus culture bottle`, describes it as “A small
bottle. Contains XY-rhinovirus culture in synthblood medium.”, and seeds
`/datum/disease/advance/cold`
(`code/modules/reagents/reagent_containers/cups/bottle.dm:303-306`;
`code/modules/reagents/reagent_containers.dm:26,80-83`). This port uses the
base `/datum/disease/cold` course above, not tg's advanced cold variant.

## Analyzer report

The scanner invokes the read-only report hook after its own accepted-target,
reach and disclosure checks. Body reports use the host snapshot; vessel reports
use only the selected vessel's contagion indices and catalog. A vessel report
says `Carried in fluid`; it does not invent a host stage. The body key
`lunatic/tfs:lib.analyzer_pathogens.rhinovirus_body` reports the name, airborne
type, stage/max and `Cure: Rest`; the vessel key
`lunatic/tfs:lib.analyzer_pathogens.rhinovirus_vessel` reports the same name
and type with `Stage: Carried in fluid` and `Host cure: Rest`. Each known
illness gets one private keyed message to the user; an empty or
unknown result gets one `No pathogens detected.` message from
`lunatic/tfs:lib.analyzer_pathogens.none`. The report does not traverse hidden
container contents and works for a disclosed blood or water vessel, including
water with no blood. Its fields follow tg's analyzer disease block: name,
spread type, stage and cure
(`code/game/objects/items/devices/scanners/health_analyzer.dm:441-468`).
