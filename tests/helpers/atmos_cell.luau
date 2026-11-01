-- The atmospheric cell this pack declares (`simulation.tile` in
-- content/capabilities.luau), read through `t.tile`. Blends
-- are densities (`amount = "per_m3"`), and `t.room_gas` reads moles per
-- cell, so a spec turns a density into a cell's moles through this volume.
local atmos_cell = {}

local tile = t.tile()
assert(tile, "the pack declares simulation.tile")
atmos_cell.CELL_VOLUME_M3 = tile.cell_volume_m3
atmos_cell.R_GAS = 8.314

-- Moles of ideal gas per cubic metre at a pressure (Pa) and temperature (K):
-- the density a `per_m3` blend carries, p/RT.
function atmos_cell.density_mol_per_m3(pressure_pa: number, kelvin: number): number
    return pressure_pa / (atmos_cell.R_GAS * kelvin)
end

-- Moles a cell holds at a density given in mol per cubic metre.
function atmos_cell.cell_moles(density_mol_per_m3: number): number
    return density_mol_per_m3 * atmos_cell.CELL_VOLUME_M3
end

return atmos_cell
