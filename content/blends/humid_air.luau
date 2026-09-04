-- Ordinary air with the shower running: standard air plus half a mole
-- of water vapour per tile.
--
-- `water:gas` is spelled out because water rests LIQUID at 20 C, so an
-- unsuffixed row here would paint a room with a puddle in the air
-- (docs/map-properties/blends.md).
--
-- The half mole is chosen between two lines. Water's own file makes
-- vapour visible from 0.25 mol on a tile (`visible.moles`), so this
-- room fogs. And the saturation density this engine derives from
-- water's boil and latent heat is 1.164 mol/m3 at 20 C -- p_sat/RT with
-- p_sat = 1 atm * exp(-l_vap/R * (1/T - 1/T_boil)) -- so the first
-- atmos pass condenses none of it back out. A room that rained on tick
-- one would be a room nobody could see fog in.
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local TILE_VOLUME_M3 = 1.0
local T = 293.15
local n = ONE_ATMOSPHERE_PA * TILE_VOLUME_M3 / (R * T)

local L_VAP_J_PER_MOL = 40660.0
local T_BOIL_K = 373.15
local p_sat = ONE_ATMOSPHERE_PA * math.exp(-L_VAP_J_PER_MOL / R * (1.0 / T - 1.0 / T_BOIL_K))
local SATURATED = p_sat * TILE_VOLUME_M3 / (R * T)
local VAPOUR = 0.5
assert(VAPOUR < SATURATED)

return {
    id = "humid_air",
    name = "Humid air",
    rows = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
        { "water:gas", VAPOUR },
    },
    temperature_k = T,
    amount = "per_tile",
}
