-- Oxygen: the station's own gas, and the whole of what it is.
--
-- This file used to carry oxygen's LOOK only, because its physics lived
-- in a Rust table the engine shipped with. That table is gone: there is
-- no built-in roster any more, and a pack that names no oxygen has none
-- (docs/CHEMISTRY.md §2). What the engine keeps is the arithmetic — the
-- ideal gas law, the reaction step, the breath thresholds — and every
-- number those arithmetics are ABOUT is here.
--
-- Physics, verbatim from tg:
--   * molar mass 32 g/mol.
--   * cv 20 J/(mol·K) — tg `specific_heat`, gas_types.dm
--     (/datum/gas/oxygen).
--   * `gas_only`: tg models no liquid oxygen, so neither do we. Giving
--     it a boiling point would be a divergence dressed as a refinement,
--     and every atmos number ported alongside assumes the gas column.
--
-- tg: /datum/reagent/oxygen, `color = COLOR_GRAY` (other_reagents.dm:
-- 983). tg carries oxygen as a reagent as well as a gas, which is why
-- the shelf can dispense it at all.
return {
    id = "o2",
    name = "oxygen",
    molar_mass = 32.0,
    cv = 20.0,
    phase = "gas_only",
    color = "#808080",
    -- What lungs are looking for. The threshold a breath is held to is
    -- the engine's (tg's `safe_oxygen_min`, 16 kPa of partial
    -- pressure); which gas clears it is this line, and this line is the
    -- only place on the station that says the crew breathes oxygen.
    breath = { breathable = true },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). The air a station is
    -- commissioned full of, so it leads.
    relevance = 100,
}
