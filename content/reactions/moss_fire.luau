-- Moss burning in air: grass_fire.luau's chemistry on a damper fuel, so
-- it burns three times slower (divisor 27, a chosen figure) and walks
-- through a carpet behind a meadow fire. Same latch, ramp, energy and
-- ash; every number there is cited in that file.
return {
    id = "moss_fire",
    priority = "fire",
    requires = {
        { min = { "moss:solid", 0.1 } },
        { min = { "o2:gas", 0.01 } },
        { column = { "alight", 0.5 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = 250, hi = math.huge },
    reactants = { ["moss:solid"] = 1.0, ["o2:gas"] = 6.0 },
    products = { ["co2:gas"] = 6.0, ["water:gas"] = 5.0, ["ash:solid"] = 0.081 },
    rate = {
        burn = {
            limiting = "moss:solid",
            divisor = 27.0,
            ramp = { floor_k = 250, ceiling_k = 1000 },
        },
    },
    energy = 2.6e6,
}
