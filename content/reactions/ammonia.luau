-- Ammonia, the Haber process. tg: `/datum/chemical_reaction/ammonia`,
-- 3 ammonia from 3 hydrogen + 1 nitrogen, thermic_constant 50
-- (recipes/others.dm:433-441).
--
-- THE DEPARTURE: the real ratio, in gas. tg's hydrogen reagent is a
-- single atom and its recipe is H3N; there is one id per molecule
-- here, so the balance is N2 + 3 H2 -> 2 NH3, stated per mole of
-- product: 0.5 N2 + 1.5 H2 -> 1 NH3. Every participant is a real
-- molecule, so the ratio is the molecule's rather than tg's.
--
-- AND IT IS A PRESSURE VESSEL, which is the point. Nitrogen and
-- hydrogen are permanent gases: no source hands them to an open
-- beaker (D19), so they arrive from a canister through a connector
-- port into something with a lid on it. The gates say the same thing
-- in numbers -- a hundred kilopascals of nitrogen and three hundred of
-- hydrogen, which is the 1:3 stoichiometry read as partial pressures
-- and which no room on the station is anywhere near. Real ammonia
-- synthesis wants 200 atm; this wants four, which is a bench's worth
-- of the same idea.
--
-- THE WINDOW is 600/650/800/850 rather than the shared mixing bell,
-- because this one is not a mixing reaction: tg's own recipe is
-- untemperatured, but tg's is a beaker of liquids and this is a
-- catalytic gas synthesis that has never happened cold. 600 K is a
-- little under the real process's 700 K, and the top of the band is
-- where a bench heater gives out.
--
-- ENERGY, and a sign worth saying out loud. The Haber process is
-- EXOTHERMIC: the standard enthalpy of formation of ammonia is
-- -46 kJ/mol, meaning 46 kJ come OUT for every mole made. This engine
-- writes energy from the holder's point of view -- positive is heat
-- into the vessel (docs/CHEMISTRY.md 6) -- so the number here is
-- +46 000 J per extent. It is the real enthalpy rather than the
-- Theta rule, because every participant is a real molecule and there
-- is nothing fictional left for a convention to stand in for.
return {
    id = "ammonia",
    reactants = { ["n2:gas"] = 0.5, ["hydrogen:gas"] = 1.5 },
    products = { ["ammonia:gas"] = 1.0 },
    energy = 46000.0,
    requires = {
        { partial_pressure_at_least = { substance = "n2", kpa = 100.0 } },
        { partial_pressure_at_least = { substance = "hydrogen", kpa = 300.0 } },
    },
    rate = {
        bell = {
            temp_min = 600.0,
            opt_lo = 650.0,
            opt_hi = 800.0,
            temp_max = 850.0,
            exponent = 2.0,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
