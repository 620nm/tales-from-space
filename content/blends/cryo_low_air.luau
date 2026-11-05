-- The low air of the cryo-hydrocarbon world, over its basins and seas
-- (level -1 and below, environments/cryo_hydrocarbon.luau): the same 1.5 bar
-- at 94 K as `cryo_air`, with twice the methane, 15 kPa.
--
-- 15 kPa is 87 % of methane's saturation at 94 K, 17.15 kPa (the arithmetic
-- is cryo_air.luau's), so the low air holds near the dew line and still
-- does not condense: the engine refuses an ambient row above it at load.
-- The total stays at the upper air's so the two layers differ only in mix.
--
-- n = 150000 / (8.314 * 94) = 191.93 mol/m3: methane 19.194, nitrogen 172.74.
-- No haze row: an airborne-particle primitive does not exist yet, so the
-- bleakness here is the methane and the HCN snow's sight extinction.
local R = 8.314
local T = 94.0
local TOTAL_PA = 150000.0
local METHANE_PA = 15000.0

local METHANE_TRIPLE_K = 90.69
local METHANE_TRIPLE_PA = 11700.0
local METHANE_L_VAP = 8190.0
local saturation_pa = METHANE_TRIPLE_PA
    * math.exp(-METHANE_L_VAP / R * (1.0 / T - 1.0 / METHANE_TRIPLE_K))
assert(METHANE_PA < saturation_pa)

return {
    id = "cryo_low_air",
    name = "Cryo-hydrocarbon low air",
    rows = {
        { "n2", (TOTAL_PA - METHANE_PA) / (R * T) },
        { "methane:gas", METHANE_PA / (R * T) },
    },
    temperature_k = T,
    amount = "per_m3",
}
