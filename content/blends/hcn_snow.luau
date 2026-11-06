-- HCN snow: the fallout of the cryo-hydrocarbon world's low air
-- (environments/cryo_hydrocarbon.luau). Hydrogen cyanide freezes at
-- 259.9 K, so at 94 K it falls and lies as frost; warmed indoors it melts
-- and boils (298.8 K) into a poison.
--
-- A fallout reads only its rows' proportions and its temperature, and every
-- row must rest condensed at that temperature. `:solid` says what it is.
-- The amount is the solid's own density (0.9 g/mL over 27.025 g/mol,
-- the `hcn` substance) so the file reads as a meter of frost; the layer's
-- `kg_per_m2_s` sets how much falls. 94 K is the air it falls through, so a
-- flake lands with no heat to trade.
local DENSITY_G_PER_ML = 0.9
local MOLAR_MASS = 27.025

return {
    id = "hcn_snow",
    name = "HCN snow",
    rows = {
        { "hcn:solid", DENSITY_G_PER_ML * 1e6 / MOLAR_MASS },
    },
    temperature_k = 94.0,
    amount = "per_m3",
}
