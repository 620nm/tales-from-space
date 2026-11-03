-- Grass burning in air: C6H10O5 + 6 O2 -> 6 CO2 + 5 H2O, leaving ash.
--
-- tg has no burning ground cover, so the numbers are real plant matter
-- and this pack's choice. Like ethanol fire the `alight` latch is the
-- spark: a struck flame lights the sward and lib/ignition.luau spreads it
-- tile to tile. The burn ramps up from 250 K and is at full rate by
-- 1000 K, a grass fire's flame; a ninth of what stands burns a pass at
-- full rate, plasma fire's divisor. No ceiling holds it. A coat under a
-- tenth of a mole (16 g/m2, under the look's first rung) is too thin to
-- carry a flame, so a tile burns out bare and its latch lets go.
--
-- Energy is cellulose's lower heating value, 16.1 MJ/kg x 162.14 g/mol
-- (the water leaves as gas). Ash is 5 % of the dry mass, at ash's
-- 100 g/mol (substances/ash.luau): 0.05 x 162.14 / 100.
return {
    id = "grass_fire",
    priority = "fire",
    requires = {
        { min = { "grass:solid", 0.1 } },
        { min = { "o2:gas", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = 250, hi = math.huge },
    reactants = { ["grass:solid"] = 1.0, ["o2:gas"] = 6.0 },
    products = { ["co2:gas"] = 6.0, ["water:gas"] = 5.0, ["ash:solid"] = 0.081 },
    rate = {
        burn = {
            limiting = "grass:solid",
            divisor = 9.0,
            ramp = { floor_k = 250, ceiling_k = 1000 },
        },
    },
    energy = 2.6e6,
}
