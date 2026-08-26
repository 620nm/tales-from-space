-- Carbon dioxide: what a sealed room fills up with, what a plasma fire
-- makes, and the one substance on this shelf that has no liquid phase
-- at station pressure.
--
-- THE DIAGRAM, and why it is a triple point rather than a boiling
-- point. CO2 has no normal boiling point: its solid's vapour pressure
-- clears one atmosphere at 194.7 K, which is BELOW the 216.55 K triple
-- point, so a block of it on a warm deck goes straight to gas and
-- never puddles. A `boil` spelling is refused for exactly that reason
-- (docs/CONTENT-SCHEMA.md 1.2), and the file authors the triple point
-- the two lines actually meet at.
--
-- Numbers are the NIST WebBook's CO2 phase-change data: triple point
-- 216.55 K at 517 kPa, heat of fusion 9.02 kJ/mol, heat of
-- vaporization 16.2 kJ/mol at the triple point, critical temperature
-- 304.1 K (above which there is no condensation at all, however hard
-- you press it), solid density 1.56 g/mL at 195 K and liquid 0.77 g/mL
-- near the critical point. The sublimation line the engine derives
-- from these is Hess's law -- L_sub = L_fus + L_vap -- and is never
-- authored (docs/MATTER.md 5).
--
-- Heat capacities: the GAS row is tg's `specific_heat = 30` verbatim
-- (gas_types.dm, /datum/gas/carbon_dioxide), because the atmos column
-- is what that number was tuned against. The condensed rows are real
-- CO2's, which no tg number covers because tg has no dry ice.
--
-- There is ONE carbon dioxide and no second one: the bench makes this
-- (reactions/carbon_dioxide.luau), the plasma fire makes this
-- (reactions/plasma_fire.luau), a brewing can makes this
-- (reactions/fermentation.luau), and it is the same substance the
-- room's air is made of. That is what a single matter registry buys.
--
-- tg: /datum/reagent/carbondioxide, `color = "#B0B0B0"`
-- (other_reagents.dm:1666).
return {
    id = "co2",
    name = "carbon dioxide",
    molar_mass = 44.0,
    cv = { solid = 54.0, liquid = 85.0, gas = 30.0 },
    phase = { triple = { t = 216.55, kpa = 517.0 }, l_fus = 9020, l_vap = 16200, critical = 304.1 },
    density = { solid = 1.56, liquid = 0.77 },
    color = "#B0B0B0",
    -- What a sealed room fills up with while you are busy. Over the
    -- engine's line it costs TIME before it costs anything else (tg's
    -- `safe_co2_max` and its twelve-second clock).
    breath = { waste = true },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). What a room full of people
    -- fills up with, and what a mapper drawing a stale chamber reaches
    -- for.
    relevance = 80,
    -- What a room full of people fills up with -- ordinary air on the way
    -- out, and grouped with the air rather than with the poisons even
    -- though tg flags it `dangerous` (gas_types.dm:98): a scrubber is
    -- pointed at it every shift.
    group = "atmospheric",
}
