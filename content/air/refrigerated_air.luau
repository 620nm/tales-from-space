-- The cold room: a kitchen's walk-in, a morgue, anywhere the point is
-- that things keep. Ordinary breathable air, held at -14 C.
--
-- tg: COLD_ROOM_TEMP = 259.15
-- (code/__DEFINES/atmospherics/atmos_core.dm:33, "-14C - Temperature
-- used for kitchen cold room, medical freezer, etc"), and the mix a
-- kitchen coldroom is actually mapped with is
-- KITCHEN_COLDROOM_ATMOS = "o2=26;n2=97;TEMP=259.15"
-- (code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:20), whose own
-- comment says the mol count is raised "to reach about 101.3 kpA".
-- That is the rule this file follows rather than the two numbers: the
-- same 21/79 breathable mixture as standard air, at enough moles to
-- sit at one atmosphere while cold -- so walking in costs a crewmember
-- their warmth and nothing else. tg's own 26/97 is 21.1/78.9, the same
-- mixture to a rounding error.
local R = 8.314
local ONE_ATMOSPHERE_PA = 101325.0
local TILE_VOLUME_M3 = 1.0
local T = 259.15
local n = ONE_ATMOSPHERE_PA * TILE_VOLUME_M3 / (R * T)

return {
    id = "refrigerated_air",
    name = "Refrigerated air",
    gases = {
        { "o2", n * 0.21 },
        { "n2", n * 0.79 },
    },
    temperature_k = T,
}
