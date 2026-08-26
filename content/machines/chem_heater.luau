-- The reaction chamber: a hotplate with a thermostat and a slot for
-- one beaker. tg's `/obj/machinery/chem_heater` (chem_heater.dm).
--
-- No script at all. Everything this machine does is mechanism — a
-- vessel goes in, a dial says how hot, the element works towards it —
-- and mechanism is the engine's (AGENTS.md's boundary test). What is
-- content is the whole of this file: what it is called, what it looks
-- like with and without something in it, where its dial opens and how
-- hard it drives.
--
-- THE COEFFICIENT IS THE LASER. tg's `RefreshParts` sets
-- `heater_coefficient = 0.1` and multiplies it by the tier of the one
-- micro-laser its board asked for (chem_heater.dm:86-90). `0.05` on the
-- type (chem_heater.dm:17) is what an UNASSEMBLED chamber has, which is
-- the floor of the clamp below; 0.4 is what tg's own debug chamber
-- calls upgraded (chem_heater.dm:390), which is the ceiling.
--
-- So `coeff` here is the plain built machine and `parts.scale` is the
-- rest of tg's line: base times the efficiency of what is in the
-- socket. On this pack's ladder (lib/stock_parts.luau) a tier-four
-- laser is worth 3.0, so the best chamber runs at 0.3 -- short of tg's
-- 0.4, because tg multiplies by the RATING (1/2/3/4) while this pack's
-- efficiencies climb more gently. Two thirds of the way up tg's range
-- for the last rung of the ladder is the trade that ladder is tuned for.
return {
    id = "chem_heater",
    name = "reaction chamber",
    sprite = "chem_heater",
    ui = { modules = { "thermostat_dock", "parts" } },
    examine = {
        flavor = "A hotplate with a dial and a cradle for one vessel. It "
            .. "holds a temperature steadier than any hand over a flame.",
    },
    dense = true,
    corded = true,
    chem = {
        device = "thermostat",
        -- tg's `target_temperature = 300` (chem_heater.dm:14): a shade
        -- over room temperature, so a chamber switched on with nobody
        -- watching does nearly nothing.
        target_k = 300,
        coeff = 0.1,
        -- Ours, not tg's — tg writes the setpoint straight off the
        -- interface with no ceiling at all (chem_heater.dm:242-245).
        -- A thousand kelvin covers every temperature window in the
        -- reaction registry with room to spare.
        max_k = 1000,
        sprite_loaded = "chem_heater_loaded",
    },
    -- One socket, because tg's board asks for one micro-laser
    -- (machine_circuitboards.dm:807-809). The clamp is tg's own pair of
    -- bookends, so no ladder a pack ships can drive this chamber outside
    -- the range tg's own numbers describe.
    parts = {
        slots = { "laser" },
        scale = {
            coeff = { by = "laser", law = "multiply", clamp = { 0.05, 0.4 } },
        },
    },
    variants = {
        -- tg's `/fullupgrade` boards ship a frame stocked with tier
        -- fours (machine_circuitboards.dm:766-773). There is no such
        -- board here -- a lathe would print it -- so the upgraded
        -- chamber is a preconfiguration a map may place, and its tier is
        -- exactly the placement key a mapper could have written by hand
        -- (docs/MAP-PROPERTIES.md).
        fullupgrade = {
            name = "reaction chamber (upgraded)",
            props = { laser_1 = "4" },
        },
    },
}
