-- Oxygen: the station's own gas, and the whole of what it is.
--
-- interactions we use:
--   CH4(l) + 2 O2(l) -> CO2 + 2 H2O (lox_detonation)
-- interactions we know exist but don't need:
--   liquid O2 with lube, naphtha, wax, blood or any other organic:
--     each is as violent as methane in reality, but only the fuel a cold
--     world pours is wired to detonate; the rest sit beside LOX inert
--
-- This file used to carry oxygen's LOOK only, because its physics lived
-- in a Rust table the engine shipped with. That table is gone: there is
-- no built-in roster any more, and a pack that names no oxygen has none
-- (docs/CHEMISTRY.md §2). What the engine keeps is the arithmetic — the
-- ideal gas law, the reaction step, the breath thresholds — and every
-- number those arithmetics are ABOUT is here.
--
-- Physics:
--   * molar mass 32 g/mol.
--   * gas cv 20 J/(mol·K), tg's `specific_heat` verbatim, gas_types.dm
--     (/datum/gas/oxygen): the atmos column was tuned against it.
--   * THE DIAGRAM, a departure from tg, which models no liquid oxygen:
--     a cold world needs LOX. NIST WebBook (C7782447): melting point
--     54.36 K, normal boiling point 90.19 K, critical temperature
--     154.6 K, heat of vaporization 6.82 kJ/mol at the boiling point,
--     heat of fusion 0.444 kJ/mol. Liquid density 1.141 g/mL at the
--     boiling point; the solid's 1.33 is approximate (CRC). Condensed cv
--     figures are approximate cp values near the boiling point.
--
-- THE BOIL SPELLING, because the line has to be right at 94 K:
--   Psat(94) = 101.325 * exp((6820 / 8.3145) * (1/90.19 - 1/94))
--            = 101.325 * exp(0.3686) = 146.5 kPa  (real about 146)
-- A triple anchor at 54.36 K runs 40 K to get there and lands at
-- 85 kPa, 40 % low, which would leave pure oxygen liquid at 1 atm and
-- 94 K. With this line pure oxygen outside a cold world stays gas up to
-- 146 kPa and condenses to LOX above it. Above 154.6 K nothing condenses
-- it, so every canister at room temperature is gas at any pressure.
-- At a thermomachine's 73.15 K floor the line is at 12.2 kPa, so the
-- 21 kPa oxygen share of station air liquefies there.
--
-- tg: /datum/reagent/oxygen, `color = COLOR_GRAY` (other_reagents.dm:
-- 983). tg carries oxygen as a reagent as well as a gas, which is why
-- the shelf can dispense it at all.
return {
    id = "o2",
    name = "oxygen",
    molar_mass = 32.0,
    cv = { solid = 46.0, liquid = 53.0, gas = 20.0 },
    phase = { melt = 54.36, boil = 90.19, l_fus = 444, l_vap = 6820, critical = 154.6 },
    density = { solid = 1.33, liquid = 1.141 },
    -- Liquid oxygen near 90 K, approximate (CRC).
    flow = { viscosity = 0.196, surface_tension = 13.2, contact_angle = 10 },
    color = "#808080",
    -- Liquid oxygen is pale blue, and so is its frost.
    appearance = {
        liquid = { profile = "puddle", tint = "#9EC3F0" },
        solid = { profile = "crystalline", tint = "#C4DAF6" },
    },
    -- What lungs are looking for. The threshold a breath is held to is
    -- the engine's (tg's `safe_oxygen_min`, 16 kPa of partial
    -- pressure); which gas clears it is this line, and this line is the
    -- only place on the station that says the crew breathes oxygen.
    breath = { breathable = true },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). The air a station is
    -- commissioned full of, so it leads.
    relevance = 100,
    -- The gas a crew breathes: the first thing a scrubber panel should offer.
    group = "atmospheric",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for oxygen, OX included.
    -- Breathable air is 21%; richer than 23.5% is an oxygen-enriched room.
    hazard = { health = 0, fire = 0, instability = 0, special = "oxidizer", above = 0.235 },
}
