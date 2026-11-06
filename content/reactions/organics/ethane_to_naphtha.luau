-- Ethane to naphtha: sea ethane upgraded to the shelf's fuel.
--
-- interactions which require catalysts:
--   4 C2H6 -> C8H16 + 4 H2, catalyst synthesis_catalyst (ethane_to_naphtha)
--
-- Sea ethane upgraded to naphtha, the shelf's C8H16 bookkeeping unit
-- (docs/PETROCHEMISTRY.md owns the model). It folds dehydrogenation and
-- oligomerization into one step, as reactions/naphtha.luau folds CO2
-- hydrogenation, and leaves hydrogen behind. Atoms balance: C 8 = 8,
-- H 24 = 16 + 8.
--
-- Window, catalyst and energy are reactions/naphtha.luau's: the same
-- catalyst bed at the same 450-470 K, and 0 J because naphtha is a
-- bookkeeping unit with no measured formation enthalpy.
return {
    id = "ethane_to_naphtha",
    reactants = { ["ethane:gas"] = 4.0 },
    products = { ["naphtha:liquid"] = 1.0, ["hydrogen:gas"] = 4.0 },
    catalysts = { ["synthesis_catalyst:liquid"] = 0.025 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 450.0,
            opt_lo = 455.0,
            opt_hi = 465.0,
            temp_max = 470.0,
            exponent = 2.0,
            base_rate = 0.00625,
        },
    },
}
