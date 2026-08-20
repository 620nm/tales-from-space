-- Water, for its LOOK only.
--
-- Water is a BUILTIN substance: its mass, its three specific heats and
-- its melting and boiling points live in the engine's matter registry
-- because atmos needs them long before a beaker does. The registry
-- skips a content substance whose key it already knows (invariant I9,
-- docs/reagents.md), so this file registers no physics and could not
-- override any if it tried -- what it contributes is the METADATA half,
-- which the registry does not own.
--
-- Today that is one field: what water looks like through glass. The
-- alternative was a colour table under `crates/`, which would put a
-- substance name and a hex value in engine code; a substance file that
-- names only what it looks like keeps the vocabulary where vocabulary
-- lives.
--
-- tg: /datum/reagent/water, `color = "#AAAAAA77"` (other_reagents.dm:
-- 117). The trailing 77 is BYOND's alpha byte and is DROPPED: colour
-- here is a three-byte multiply with no alpha of its own
-- (crates/lunatic-core/src/color.rs), so water tints its fill the same
-- grey tg does and simply does not thin it.
return {
    id = "water",
    name = "water",
    color = "#AAAAAA",
}
