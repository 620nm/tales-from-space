-- Mercury: the metal that pours. A dispenser button, and the one
-- element on this shelf whose `unmodeled` rest phase is a LIQUID --
-- which is not a convenience but the fact everybody knows about it.
--
-- Real molar mass and the real molar heat capacity (Hg, 28.0
-- J/(mol*K)), with an authored `unmodeled` rest phase per D2
-- (docs/CHEMISTRY.md): mercury boils at 630 K, which the reaction
-- chamber reaches -- and mercury vapour is a genuinely lethal thing
-- that nothing here would do anything with, so a curve would be a
-- promise the game does not keep.
-- tg: /datum/reagent/mercury (other_reagents.dm:1045).
return {
    id = "mercury",
    name = "mercury",
    molar_mass = 200.59,
    cv = 28.0,
    phase = { unmodeled = "liquid" },
    -- Real mercury, 13.53 g/mL: the densest thing on this shelf by a
    -- long way, and a mole of it is fifteen millilitres.
    density = { liquid = 13.53 },
    -- What it looks like through glass (tg: other_reagents.dm:1048,
    -- COLOR_WEBSAFE_DARK_GRAY).
    color = "#484848",
}
