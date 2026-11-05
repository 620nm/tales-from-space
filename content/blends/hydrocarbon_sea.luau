-- A sea of liquid methane and ethane, 70:30 by mole, at 94 K: what a tile
-- standing in the cryo-hydrocarbon world's sea is filled with, laid by the
-- `hydrocarbon_sea` terrain profile (terrain.luau).
--
-- `per_m3` of the liquid mixture, its molar volumes added (ideal mixing):
--   methane 16.043 g/mol / 0.42 g/mL = 38.198 mL/mol,
--   ethane  30.069 g/mol / 0.65 g/mL = 46.260 mL/mol,
--   mixture 0.7 * 38.198 + 0.3 * 46.260 = 40.617 mL/mol,
-- so a cubic metre holds 10^6 / 40.617 = 24 620 mol: methane 17 234, ethane
-- 7 386. The fill scales the rows to its depth, so this sets the proportion.
--
-- Both rows say `:liquid`: at 94 K methane rests liquid under one
-- atmosphere (it boils near 113 K) and ethane well inside its liquid range
-- (triple 90.37 K, boils 184.6 K). A world warmer than methane's boil
-- cannot lay this sea at all; the engine refuses the fill.
local METHANE_G_PER_MOL = 16.043
local METHANE_LIQUID_G_PER_ML = 0.42
local ETHANE_G_PER_MOL = 30.069
local ETHANE_LIQUID_G_PER_ML = 0.65
local METHANE_SHARE = 0.7
local ETHANE_SHARE = 0.3

local mixture_ml_per_mol = METHANE_SHARE * METHANE_G_PER_MOL / METHANE_LIQUID_G_PER_ML
    + ETHANE_SHARE * ETHANE_G_PER_MOL / ETHANE_LIQUID_G_PER_ML
local mol_per_m3 = 1e6 / mixture_ml_per_mol

return {
    id = "hydrocarbon_sea",
    name = "Hydrocarbon sea",
    name_label = "lunatic/tfs:blends.hydrocarbon_sea.name",
    rows = {
        { "methane:liquid", METHANE_SHARE * mol_per_m3 },
        { "ethane:liquid", ETHANE_SHARE * mol_per_m3 },
    },
    temperature_k = 94.0,
    amount = "per_m3",
    terrain = { profile = "hydrocarbon_sea" },
}
