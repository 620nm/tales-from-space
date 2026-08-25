-- Aiuri. tg: `/datum/chemical_reaction/medicine/aiuri`, 4 aiuri from
-- 1 ammonia + 1 sulphuric acid + 2 hydrogen, required_temp 50,
-- optimal_temp 300, overheat_temp 315, temp_exponent_factor 5,
-- thermic_constant -400 (recipes/cat2_medicines.dm:110-126).
--
-- THE DEPARTURE: the hydrogen legs are gone and the product count falls
-- from four to two. Hydrogen is H2 here (D3) and a permanent gas, so a
-- bench recipe cannot stand on it (D19); aiuri is fictional, so D1 lets
-- the count move with the legs -- two in, two out, the same arithmetic
-- lube and acetone got. The other departure is the one liquid ammonia
-- always brings: the leg names a phase that stands only under a lid,
-- about 8.6 atmospheres of the substance's own vapour, so this is
-- bottle work.
--
-- The window is tg's three numbers through the documented mapping
-- (docs/CHEMISTRY.md 5):
--   temp_min = required_temp = 50
--   opt_lo   = optimal_temp  = 300
--   opt_hi   = overheat_temp = 315
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 315 + 250 = 565
-- and the exponent verbatim: 5, which is a steep approach and a long
-- gentle tail. Room temperature sits in the plateau, so this one needs
-- no chamber at all.
--
-- ...WHICH IS THE JOKE, because it makes its own cold. Energy is the
-- documented rule with tg's sign carried through
-- (docs/CHEMISTRY.md 6: + is exothermic, - endothermic, and tg's
-- `thermic_constant` is a temperature delta, so its -400 is heat
-- LEAVING the vessel):
--   -400 x 2 x 75.3 = -60 240 J per extent
-- A tenth of an extent takes six kilojoules out of a mixture whose
-- whole heat capacity is about eleven joules per kelvin, so the bottle
-- frosts hard enough to walk itself down out of its own window and
-- stop. Aiuri is the one rule on this bench that a chemist has to keep
-- WARM, and the reaction chamber earns its power draw doing it.
return {
    id = "aiuri",
    reactants = { ["ammonia:liquid"] = 1.0, ["sulfuric_acid:liquid"] = 1.0 },
    products = { ["aiuri:liquid"] = 2.0 },
    energy = -60240.0,
    rate = {
        bell = {
            temp_min = 50.0,
            opt_lo = 300.0,
            opt_hi = 315.0,
            temp_max = 565.0,
            exponent = 5.0,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
