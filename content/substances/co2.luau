-- Carbon dioxide: what a sealed room fills up with, and what a plasma
-- fire makes.
--
-- Physics, verbatim from tg: molar mass 44 g/mol, cv 30 J/(mol·K) (tg
-- `specific_heat`, gas_types.dm, /datum/gas/carbon_dioxide), and
-- `gas_only` — tg has no dry ice in its gas mixtures.
--
-- There is ONE carbon dioxide and no second one: the bench makes this
-- over 777 K (reactions/carbon_dioxide.luau), the plasma fire makes
-- this (reactions/plasma_fire.luau), and it is the same substance the
-- room's air is made of. That is what a single matter registry buys.
--
-- tg: /datum/reagent/carbondioxide, `color = "#B0B0B0"`
-- (other_reagents.dm:1666).
return {
    id = "co2",
    name = "carbon dioxide",
    molar_mass = 44.0,
    cv = 30.0,
    phase = "gas_only",
    color = "#B0B0B0",
    -- What a sealed room fills up with while you are busy. Over the
    -- engine's line it costs TIME before it costs anything else (tg's
    -- `safe_co2_max` and its twelve-second clock).
    breath = { waste = true },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). What a room full of people
    -- fills up with, and what a mapper drawing a stale chamber reaches
    -- for.
    relevance = 80,
}
