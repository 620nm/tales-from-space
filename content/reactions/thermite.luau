-- Thermite. tg: `/datum/chemical_reaction/thermite`, 3 thermite from
-- 1 aluminium + 1 iron + 1 oxygen, no thermic_constant
-- (recipes/pyrotechnics.dm:214-217).
--
-- Three reactants and no gate at all, which is the point: the engine's
-- conservation clamp takes the extent as the MINIMUM of what every
-- reactant can supply (docs/MATTER.md, section 6), so a beaker holding
-- any two of the three does nothing whatsoever and needs no rule
-- saying so. The spec that watches the pairs stay inert is watching
-- that clamp.
--
-- Shared mixing bell, no energy.
return {
    id = "thermite",
    reactants = { ["aluminium:solid"] = 1.0, ["iron:solid"] = 1.0, o2 = 1.0 },
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
