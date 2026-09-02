-- Nitrogen: the other four fifths of ordinary air.
--
-- Physics, verbatim from tg: molar mass 28 g/mol, cv 20 J/(mol·K) (tg
-- `specific_heat`, gas_types.dm, /datum/gas/nitrogen), and `gas_only`
-- because tg models no liquid nitrogen either.
--
-- Nothing declares it breathable, which is the point of the column
-- being a declaration: a body draws four fifths of every lungful out of
-- this and keeps none of it, and the engine needs no rule saying so.
--
-- tg: /datum/reagent/nitrogen, `color = COLOR_GRAY`
-- (other_reagents.dm:1018).
return {
    id = "n2",
    name = "nitrogen",
    molar_mass = 28.0,
    cv = 20.0,
    phase = "gas_only",
    color = "#808080",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). The other four fifths of
    -- ordinary air.
    relevance = 90,
    -- The other four fifths of ordinary air.
    group = "atmospheric",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for nitrogen.
    -- Breathable air is 79% nitrogen, so only a richer room is an asphyxiant.
    hazard = { health = 0, fire = 0, instability = 0, special = "asphyxiant", above = 0.85 },
}
