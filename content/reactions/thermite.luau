-- Thermite. tg: `/datum/chemical_reaction/thermite`, 3 thermite from
-- 1 aluminium + 1 iron + 1 oxygen, no thermic_constant
-- (recipes/pyrotechnics.dm:214-217).
--
-- THE DEPARTURE: iron and oxygen become IRON OXIDE, and the aluminium
-- doubles. tg's third leg is loose oxygen, which no source hands to an
-- open beaker now that a substance arrives in the phase it rests in
-- (D19) -- and real thermite has never taken loose oxygen anyway. It
-- takes an oxide. So the two legs tg spells separately become the one
-- thing they would actually be (substances/iron_oxide.luau) and the
-- ratio is the reaction everybody has seen:
--   2 Al + Fe2O3 -> Al2O3 + 2 Fe
-- with tg's product count of 3 kept, because thermite is a mixture
-- rather than a compound and D1 lets a fictional product keep the
-- number a chemist feels.
--
-- Two reactants and no gate at all, which is still the point: the
-- engine's conservation clamp takes the extent as the MINIMUM of what
-- every reactant can supply (docs/REACTIONS.md, section 5), so a beaker
-- holding one of the two does nothing whatsoever and needs no rule
-- saying so. The spec that watches a lone leg stay inert is watching
-- that clamp.
--
-- Shared mixing bell, no energy. (Thermite's own violence is what a
-- welder does with the product, and the wall-burning half of it waits
-- on cell-deposit effects -- docs/CHEMISTRY.md, Gaps.)
return {
    id = "thermite",
    reactants = { ["aluminium:solid"] = 2.0, ["iron_oxide:solid"] = 1.0 },
    products = { ["thermite:solid"] = 3.0 },
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
