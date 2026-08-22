-- Water, for its LOOK only.
--
-- Water is a BUILTIN substance: its mass, its three specific heats and
-- its melting and boiling points live in the engine's matter registry
-- because atmos needs them long before a beaker does. The registry
-- skips a content substance whose key it already knows (invariant I9,
-- docs/CHEMISTRY.md), so this file registers no physics and could not
-- override any if it tried -- what it contributes is the METADATA half,
-- which the registry does not own.
--
-- Today that is two fields: what water looks like through glass, and
-- what it looks like hanging in a room. The alternative was a colour
-- table under `crates/`, which would put a substance name and a hex
-- value in engine code; a substance file that names only what it looks
-- like keeps the vocabulary where vocabulary lives.
--
-- tg: /datum/reagent/water, `color = "#AAAAAA77"` (other_reagents.dm:
-- 117). The trailing 77 is BYOND's alpha byte and is DROPPED: colour
-- here is a three-byte multiply with no alpha of its own
-- (crates/lunatic-core/src/color.rs), so water tints its fill the same
-- grey tg does and simply does not thin it.
--
-- `visible.tint` is STEAM: the colour water wears in its gas phase,
-- which is what a boiled beaker gives off and what a plasma fire makes
-- (tg's `water_vapor` is that gas phase and nothing else, so the engine
-- roster carries no twin for it). Almost white with the faintest blue
-- in it (0.90/0.93/0.97 in the old renderer, unchanged): fog reads as a
-- thinning of the room rather than a colour laid over it, which is the
-- only way a hazard overlay can sit on top of a corridor without hiding
-- what is in it. The threshold that decides WHEN it is drawn is the
-- registry's (docs/CHEMISTRY.md); this is only the colour.
return {
    id = "water",
    name = "water",
    color = "#AAAAAA",
    visible = { tint = "#E6EDF7" },
}
