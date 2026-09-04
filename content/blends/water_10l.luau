-- Ten litres of water, as a dose: what somebody left in the bottom of a
-- supply bottle.
--
-- The bottle is the same canister every gas store on the station uses,
-- and that is the point of the file. A canister is a shell with a valve
-- on it; nothing about it says gas, and a mapper who wants one standing
-- full of water writes this blend on the placement instead of asking
-- for a second noun.
--
-- Authored as an absolute AMOUNT (`amount = "total"`), because ten
-- litres is ten litres whatever it was poured into -- a density would
-- mean a bigger shell held more of it, which is what a pressure does
-- and not what a puddle does.
--
-- The row is unsuffixed, so it lands in the phase water RESTS in at
-- this temperature: liquid (docs/content-schema/blends.md). Water's own
-- file is where the 1.0 g/mL and the 18.015 g/mol come from.
local LITRES = 10.0
local ML_PER_L = 1000.0
local DENSITY_G_PER_ML = 1.0
local MOLAR_MASS_G_PER_MOL = 18.015
local n = LITRES * ML_PER_L * DENSITY_G_PER_ML / MOLAR_MASS_G_PER_MOL

return {
    id = "water_10l",
    name = "Water, ten litres",
    rows = {
        { "water", n },
    },
    temperature_k = 293.15,
    amount = "total",
}
