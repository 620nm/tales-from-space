-- Space cleaner. tg: `/datum/chemical_reaction/space_cleaner`,
-- 2 cleaner from 1 ammonia + 1 water, no thermic_constant
-- (recipes/others.dm:447-451).
--
-- Shared mixing bell, no energy. Two presses and a stir: the shortest
-- useful chain on the bench, and the one a janitor asks for.
return {
    id = "space_cleaner",
    reactants = { ammonia = 1.0, water = 1.0 },
    products = { space_cleaner = 2.0 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 100.0,
            opt_lo = 280.0,
            opt_hi = 900.0,
            temp_max = 1000.0,
            exponent = 2.0,
            base_rate = 0.05,
        },
    },
}
