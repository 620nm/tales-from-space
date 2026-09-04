-- A lump of ice in a beaker: two moles of water, frozen, at ten degrees
-- under melting.
--
-- The `:solid` suffix is not decoration. An unsuffixed row lands in the
-- phase water rests in AT THIS BLEND'S TEMPERATURE, and 263.15 K is
-- below the melt, so it would land solid anyway -- but a blend that
-- means ice has to say so, or warming the file by ten degrees would
-- silently make it a puddle (docs/map-properties/blends.md).
--
-- It is sized to FIT: two moles at water's solid density is under forty
-- millilitres, which a fifty-millilitre beaker has room for. Ice is
-- matter with a volume, and a shell it does not fit in is a shell the
-- deposit has to argue with.
--
-- Left in a room at 20 C it melts, which is the whole demonstration:
-- the beaker's contents move from one state to another with nobody
-- touching them.
local MOLES = 2.0
local MOLAR_MASS_G_PER_MOL = 18.015
local ICE_DENSITY_G_PER_ML = 0.917
local BEAKER_ML = 50.0
assert(MOLES * MOLAR_MASS_G_PER_MOL / ICE_DENSITY_G_PER_ML < BEAKER_ML)

local MELT_K = 273.15
local UNDERCOOL_K = 10.0

return {
    id = "ice_block",
    name = "Ice",
    rows = {
        { "water:solid", MOLES },
    },
    temperature_k = MELT_K - UNDERCOOL_K,
    amount = "total",
}
