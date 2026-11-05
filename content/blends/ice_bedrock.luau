-- Water ice as bedrock: the deep ground of the cryo-hydrocarbon world, where
-- ice at 94 K is as hard as granite. A tile NAMES it as its ground; see
-- silica_ground.luau for why a ground is a `per_m3` density of solid.
--
-- Moles in one cubic metre: 0.917 g/mL * 10^6 g per m3 over 18.015 g/mol
-- (substances/water.luau) = 50 902 mol.
--
-- It lays the `ice_ground` profile, not `sheet_ice`: rock, not a frozen
-- sea, so a tile naming it stands on ice with no bed of ice in its cell
-- (terrain.luau). 94 K is the world it is laid in.
local DENSITY_G_PER_ML = 0.917 -- substances/water.luau
local MOLAR_MASS = 18.015

return {
    id = "ice_bedrock",
    name = "Ice bedrock",
    name_label = "lunatic/tfs:blends.ice_bedrock.name",
    rows = {
        { "water:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 94.0,
    amount = "per_m3",
    terrain = { profile = "ice_ground" },
}
