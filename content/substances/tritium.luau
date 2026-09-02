-- Tritium: what a plasma fire makes when it has more oxygen than it
-- knows what to do with.
--
-- Physics, verbatim from tg: molar mass 6 g/mol, cv 10 J/(mol·K) (tg
-- `specific_heat`, gas_types.dm, /datum/gas/tritium), and `gas_only`.
-- The lightest thing on the station and the one with the least heat in
-- it per mole, which is why a supersaturated fire runs away: the same
-- joules land in a fifth of the heat capacity.
--
-- `visible` carries the threshold and NO tint, which is deliberate: a
-- gas the room can see enough of to matter but that nothing has been
-- given a colour for is simply not drawn (the stream draws a gas that
-- is both visible and tinted, and nothing else). The day somebody wants
-- to see it, one line here is the whole change.
--
-- It also earns a file because a mapper reaches for it: the station
-- ships a tank of it standing in the annex, and a chamber authored to
-- hold it is a thing somebody will want to draw.
return {
    id = "tritium",
    name = "tritium",
    molar_mass = 6.0,
    cv = 10.0,
    phase = "gas_only",
    visible = { moles = 0.25, factor = 20 },
    dangerous = true,
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). Under the air a station is
    -- made of, over every reagent that only ever lives in a beaker.
    relevance = 40,
    -- tg's `dangerous = TRUE` (gas_types.dm:175).
    group = "poison",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- Fictional: hydrogen's fire numbers, and it is the isotope that decays.
    hazard = { health = 2, fire = 4, instability = 1, special = "radioactive" },
}
