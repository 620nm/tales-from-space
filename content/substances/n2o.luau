-- Nitrous oxide: a chamber a mapper fills on purpose.
--
-- Physics, verbatim from tg: molar mass 44 g/mol, cv 40 J/(mol·K) (tg
-- `specific_heat`, gas_types.dm, /datum/gas/nitrous_oxide), and
-- `gas_only`.
--
-- tg's sleeping agent puts a mob under; nothing here does yet, because
-- the engine has no unconsciousness that is not crit and inventing one
-- inside a port would be inventing a mechanism. When it lands it lands
-- as a `breath` column and a threshold, beside the three that already
-- exist, and this file gains one line.
--
-- tg: /datum/reagent/nitrous_oxide, `color = COLOR_GRAY`
-- (other_reagents.dm:1682).
return {
    id = "n2o",
    name = "nitrous oxide",
    molar_mass = 44.0,
    cv = 40.0,
    phase = "gas_only",
    color = "#808080",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). A chamber a mapper fills on
    -- purpose.
    relevance = 60,
    -- tg's `dangerous = TRUE` (gas_types.dm:149).
    group = "poison",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for nitrous oxide, OX included. Both the health rating
    -- and the symbol wait for a twentieth of the room: below that this
    -- is a dose somebody was given rather than an atmosphere.
    hazard = { health = 2, fire = 0, instability = 0, special = "oxidizer", above = 0.05 },
}
