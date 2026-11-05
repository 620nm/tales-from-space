-- The upper air of the cryo-hydrocarbon world, the sky over every level the
-- environment's low stratum does not claim: 1.5 bar at 94 K, nitrogen with
-- 5 % methane (environments/cryo_hydrocarbon.luau).
--
-- `methane:gas` is spelled out because methane rests liquid at 94 K and one
-- atmosphere (the engine's one-atmosphere rest rule puts its boil near
-- 113 K), so an unsuffixed row would paint the sky with a puddle. Nitrogen
-- boils near 77 K and rests gas here without one.
--
-- 7.5 kPa of methane is about 44 % of its saturation at 94 K, so the air
-- holds it. The line the engine condenses against is methane's triple-form
-- curve (the `methane` substance: triple 90.69 K at 11.70 kPa, l_vap
-- 8190 J/mol):
--   p_sat(94) = 11700 * exp(-8190/8.314 * (1/94 - 1/90.69)) = 17.15 kPa.
-- The engine refuses an ambient row above that line at load.
--
-- `per_m3`: moles per cubic metre, p/RT. n = 150000 / (8.314 * 94)
-- = 191.93 mol/m3, of which methane 9.597 and nitrogen 182.34.
local R = 8.314
local T = 94.0
local TOTAL_PA = 150000.0
local METHANE_PA = 7500.0

local METHANE_TRIPLE_K = 90.69
local METHANE_TRIPLE_PA = 11700.0
local METHANE_L_VAP = 8190.0
local saturation_pa = METHANE_TRIPLE_PA
    * math.exp(-METHANE_L_VAP / R * (1.0 / T - 1.0 / METHANE_TRIPLE_K))
assert(METHANE_PA < saturation_pa)

return {
    id = "cryo_air",
    name = "Cryo-hydrocarbon air",
    rows = {
        { "n2", (TOTAL_PA - METHANE_PA) / (R * T) },
        { "methane:gas", METHANE_PA / (R * T) },
    },
    temperature_k = T,
    amount = "per_m3",
}
