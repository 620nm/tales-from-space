-- Diethylamine. tg: `/datum/chemical_reaction/diethylamine`,
-- 2 diethylamine from 1 ammonia + 1 ethanol, thermic_constant 50
-- (recipes/others.dm:442-446).
--
-- The ratio and the product count are tg's, unchanged. THE DEPARTURE is
-- the same word space cleaner needed: the ammonia leg names its LIQUID.
-- One id per molecule (D3) means `ammonia` is NH3, which boils at 240 K
-- and is a gas everywhere on this station -- so the phase this recipe
-- means stands in a sealed bottle under about 8.6 atmospheres of its
-- own vapour. Press the ammonia into a bottle, let the condensation
-- heat out on the deck, then press the ethanol.
--
-- tg states no temperature, so this gets the shared MIXING BELL:
-- 100/280/900/1000 (docs/CHEMISTRY.md 5). Energy by the documented
-- rule:
--   50 x 2 x 75.3 = 7530 J per extent
--
-- It SWELLS hard -- 25 mL of ammonia and 58 of ethanol come out as 207
-- of amine -- so the free shell volume is the real ceiling on a batch
-- (D16, docs/MATTER.md 5) and a fifty-millilitre bottle makes about a
-- fifth of an extent's worth. The bench works in the amounts that fit.
return {
    id = "diethylamine",
    reactants = { ["ammonia:liquid"] = 1.0, ["ethanol:liquid"] = 1.0 },
    products = { ["diethylamine:liquid"] = 2.0 },
    energy = 7530.0,
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
