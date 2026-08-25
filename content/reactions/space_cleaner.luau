-- Space cleaner. tg: `/datum/chemical_reaction/space_cleaner`,
-- 2 cleaner from 1 ammonia + 1 water, no thermic_constant
-- (recipes/others.dm:448-452).
--
-- The ratio is tg's, unchanged. THE DEPARTURE is one word: both sides
-- name a PHASE. Ammonia is a gas at room temperature now that there is
-- one id per molecule, and cleaner is made out of the liquid -- which
-- is what a sealed bottle holds under ammonia's own vapour pressure,
-- about 8.6 atm at 293 K. So this is the janitor's bottle rather than
-- the janitor's beaker, and the ammonia in it either came off the
-- dispenser under a lid or was synthesized there
-- (reactions/ammonia.luau).
--
-- Shared mixing bell, no energy. Two presses and a stir: the shortest
-- useful chain on the bench, and the one a janitor asks for.
return {
    id = "space_cleaner",
    reactants = { ["ammonia:liquid"] = 1.0, ["water:liquid"] = 1.0 },
    products = { ["space_cleaner:liquid"] = 2.0 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 100.0,
            opt_lo = 280.0,
            opt_hi = 900.0,
            temp_max = 1000.0,
            exponent = 2.0,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
