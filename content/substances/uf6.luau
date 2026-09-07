-- Uranium hexafluoride: the cascade's working gas, and a white
-- crystalline solid on any deck this station keeps at room temperature.
--
-- Physics:
--   * molar mass 352.02 g/mol (NIST Chemistry WebBook, CAS 7783-81-5).
--   * The phase spelling is `triple` because UF6 has no liquid at one
--     atmosphere at all: triple point 337.2 K at 151.7 kPa (64 C,
--     1134 mmHg -- Oliver, Milton & Grisard, "The Vapor Pressure and
--     Critical Constants of Uranium Hexafluoride", JACS 75 (1953)
--     2827-2829), subliming at 329.8 K (56.6 C) at 101 kPa (USEC-651,
--     tabulated in NRC ML22327A183). One atmosphere crosses the
--     SUBLIMATION line, so a canister of it cracked in a corridor
--     leaves frost, never a puddle.
--   * l_vap = 29.5e3 J/mol is NIST WebBook's phase-change entry (at
--     352 K, from Oliver et al. 1953). l_fus = 19.2e3 J/mol is the
--     commonly tabulated triple-point fusion enthalpy; no primary
--     source verified here, so treat it as an ESTIMATE.
--   * cv per phase, J/(mol·K) -- TfS tuning, chosen in the JANAF
--     ballpark but not verified against a primary source. The solid
--     number is what a classical crystal must be: 7 atoms x 3R
--     Dulong-Petit = 7 x 24.94 = 174.6, and a real solid sits a little
--     under its classical limit, so 166. The gas pays 3R = 24.9 for
--     translation and rotation and the rest is vibration waking up, so
--     130; the liquid between the two, 188.
--   * solid density 5.09 g/mL at 20 C (USEC-651, NRC ML22327A183).
--
-- `decay_heat` -- TfS tuning. Real U-238 decay power is ~8.5 W per
-- tonne, which is 8.5e-6 W/g x 352.02 g/mol = 3.0e-6 W/mol: nothing.
-- The gameplay number is 25 W/mol, chosen so a canister's worth is a
-- storeroom problem on the scale of minutes: a 40-mol fill emits
-- 40 x 25 = 1000 W into its own 40 x 130 = 5200 J/K, which is
-- 1000 / 5200 = 0.19 K/s while the gas holds the heat alone. In a
-- walled room the deck under it drinks most of that (a walled tile's
-- deck is ~1.5e5 J/K against the ~4e3 of the air over it), so a sealed
-- room holding a canister per tile climbs ~0.005 K/s = 0.3 K/min, with
-- the air standing a few kelvin over the deck within the first minutes
-- -- warm on a gauge fast, dangerous on the scale of a shift, never a
-- bomb.
--
-- `visible.tint` is a GAMEPLAY CALL: real UF6 gas is colourless and the
-- solid is white. The faintest green-white is what a cloud of it wears
-- so the hazard overlay can say "this room is not air" without hiding
-- the floor (the water.luau steam argument, one saturation step over).
--
-- It earns a file because a mapper reaches for it: an enrichment wing,
-- a cascade hall, a cylinder yard are all rooms somebody will draw.
return {
    id = "uf6",
    name = "uranium hexafluoride",
    molar_mass = 352.02,
    cv = { solid = 166.0, liquid = 188.0, gas = 130.0 },
    phase = { triple = { t = 337.2, kpa = 151.7 }, l_fus = 19.2e3, l_vap = 29.5e3 },
    decay_heat = 25.0,
    density = { solid = 5.09 },
    visible = { moles = 0.25, factor = 20, tint = "#E9F2E4" },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). With the other poisons,
    -- between nitrous oxide (60) and tritium (40).
    relevance = 50,
    dangerous = true,
    group = "poison",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- Fictional: a corrosive radiotoxic heavy-metal fluoride; the fire
    -- scale stays zero because it does not burn, and the instability is
    -- the HF it makes with any water it finds.
    hazard = { health = 3, fire = 0, instability = 1, special = "radioactive" },
}
