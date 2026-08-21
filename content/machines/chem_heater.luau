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
-- The coefficient is tg's BUILT machine rather than tg's bare one:
-- `heater_coefficient = 0.05` on the type (chem_heater.dm:17) is what
-- an unassembled chamber has, and 0.1 is what one built out of ordinary
-- parts runs at (chem_heater.dm:88), which is what a station has. The
-- best micro-lasers take it to 0.4 (chem_heater.dm:390); parts tiers
-- are not a thing here, so the middle of tg's range is the machine.
return {
    id = "chem_heater",
    name = "reaction chamber",
    sprite = "chem_heater",
    examine = {
        flavor = "A hotplate with a dial and a cradle for one vessel. It "
            .. "holds a temperature steadier than any hand over a flame.",
    },
    dense = true,
    corded = true,
    chem = {
        device = "heater",
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
}
