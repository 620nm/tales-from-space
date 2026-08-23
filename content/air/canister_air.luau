-- WHAT A SUPPLY BOTTLE ARRIVES HOLDING: breathable air, at the pressure
-- tg fills a canister to.
--
-- tg's canister is rated `maximum_pressure` 90 atmospheres and ships
-- `filled = 0.5` of that (code/modules/atmospherics/machinery/portable/
-- canister.dm), 21/79 at room temperature -- so 45 atmospheres, which
-- in a 2 m3 bottle is 3741.6 moles (docs/ATMOS.md 11).
--
-- Authored as moles PER TILE, like every other recipe here, because a
-- preset is a DENSITY and the engine scales it by whatever it is poured
-- into: one tile of this reads 4559.6 kPa, and the 2 m3 bottle holding
-- it reads the same -- pressure is a density, not an amount.
--
-- It is a recipe rather than a canister subtype for the reason the
-- whole preset system exists: tg has /canister/oxygen beside
-- /canister/nitrogen beside /canister/air, twenty-odd files that are
-- one object with a different charge. Here the bottle is one noun and
-- a map says what somebody filled it with.
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local TILE_VOLUME_M3 = 1.0
local T = 293.15
local FILL_ATM = 45.0
local n = ONE_ATMOSPHERE_PA * FILL_ATM * TILE_VOLUME_M3 / (R * T)

return {
    id = "canister_air",
    name = "Canister air",
    gases = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
    },
    temperature_k = T,
}
