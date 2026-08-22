-- Hydrogen, tg's REAGENT rather than the molecule: tg's ammonia takes
-- 3 parts hydrogen to 1 nitrogen (others.dm:433), which is H3N and not
-- 3 H2 + N2. The fiction is kept verbatim -- these recipes are not real
-- chemistry and pretending otherwise would rebalance every one of them
-- -- and the physics is the ELEMENT's: one atom's molar mass, and a
-- Dulong-Petit specific heat where nothing memorable is on record.
-- docs/CHEMISTRY.md, D2.
-- tg: /datum/reagent/hydrogen (other_reagents.dm:1028).
return {
    id = "hydrogen",
    name = "hydrogen",
    molar_mass = 1.008,
    cv = 25.0,
    -- What it looks like through glass (tg: other_reagents.dm:1031 (COLOR_GRAY)).
    color = "#808080",
}
