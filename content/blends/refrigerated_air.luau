-- Cold air at one atmosphere: a kitchen's walk-in, a morgue, anywhere
-- the point is that things keep -- and the cold sky outside. Breathable air
-- held at -14 C, topped up so the cold costs warmth and nothing else.
--
-- Two roles, one rule. Painted onto indoor tiles it is the walk-in: the
-- room opens cold and stays breathable. Named by the `cold_outdoors`
-- profile (`content/environments/cold_outdoors.luau`) it is the cold sky
-- unpainted outdoor tiles open on, and what recovery tends back toward
-- (the engine's `docs/mapping/environment.md`).
--
-- tg: COLD_ROOM_TEMP = 259.15
-- (code/__DEFINES/atmospherics/atmos_core.dm:33, "-14C - Temperature
-- used for kitchen cold room, medical freezer, etc"). A kitchen coldroom
-- is mapped KITCHEN_COLDROOM_ATMOS = "o2=26;n2=97;TEMP=259.15"
-- (code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:21), whose own
-- comment says the mol count is raised "to reach about 101.3 kpA" --
-- while the snow outside is COLD_ATMOS = "o2=22;n2=82;TEMP=259.15"
-- (code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:19), the same
-- chill left thin. This file follows the kitchen rule rather than either
-- pair of numbers: the same 21/79 mixture as breathable air, at enough moles
-- to sit at one atmosphere while cold. tg's own 26/97 is 21.1/78.9, the
-- same mixture to a rounding error.
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local TILE_VOLUME_M3 = 1.0
local T = 259.15
local n = ONE_ATMOSPHERE_PA * TILE_VOLUME_M3 / (R * T)

return {
    id = "refrigerated_air",
    name = "Refrigerated air",
    variant_of = "breathable_air",
    rows = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
    },
    temperature_k = T,
    amount = "per_tile",
}
