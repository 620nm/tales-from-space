-- Libital. tg: `/datum/chemical_reaction/medicine/libital`,
-- 3 libital from 1 phenol + 1 oxygen + 1 nitrogen, required_temp 225,
-- optimal_temp 700, overheat_temp 840, temp_exponent_factor 1.75,
-- thermic_constant 75 (recipes/cat2_medicines.dm:51-68).
--
-- THE DEPARTURE: the two gas legs become one solid. tg's recipe is
-- phenol plus loose oxygen plus loose nitrogen, and both of those are
-- permanent gases here -- a source deposits what a substance IS, and a
-- gas over an open vessel is refused (D19, docs/CHEMISTRY.md 7).
-- Saltpetre is KNO3: it carries the nitrogen and the oxygen in one
-- solid a button already dispenses, which is what a nitrate is FOR.
-- The product count stays at tg's three (D1 -- libital is fictional, so
-- there is no atom balance to keep) and the ratio becomes one solid leg
-- for one liquid one.
--
-- The window is tg's three numbers through the documented mapping
-- (docs/CHEMISTRY.md 5):
--   temp_min = required_temp = 225
--   opt_lo   = optimal_temp  = 700
--   opt_hi   = overheat_temp = 840
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 840 + 475 = 1315
-- and the exponent verbatim: 1.75. What that shape MEANS at the bench
-- is the point of the recipe. At room temperature the bell is
-- ((300-225)/(700-225))^1.75 = 0.04, so a beaker on the deck makes
-- libital about twenty-five times slower than the reaction chamber
-- does. It is not gated -- it is SLOW -- and the machine is what turns
-- an afternoon into two minutes.
--
-- Energy is the documented rule, Q = THETA x r_product x 75.3:
--   75 x 3 x 75.3 = 16 942.5 J per extent
-- which is the largest exotherm on this shelf, and it works with the
-- chamber rather than against it.
--
-- IT SWELLS, hard. A mole of phenol is 88 mL and a mole of saltpetre
-- 48, against 540 for the three libital that come out, so a whole
-- extent needs 404 millilitres of room it does not have. Geometry caps
-- every swelling extent by the free shell volume and grows no vessel
-- (D16, docs/MATTER.md 5), so a fifty-millilitre bottle makes about a
-- tenth of an extent and the bench works in the amounts that fit.
return {
    id = "libital",
    reactants = { ["phenol:liquid"] = 1.0, ["saltpetre:solid"] = 1.0 },
    products = { ["libital:liquid"] = 3.0 },
    energy = 16942.5,
    rate = {
        bell = {
            temp_min = 225.0,
            opt_lo = 700.0,
            opt_hi = 840.0,
            temp_max = 1315.0,
            exponent = 1.75,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
