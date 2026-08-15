-- A gas pump: the machine a distribution loop is actually built out of.
--
-- tg's `/obj/machinery/atmospherics/components/binary/pump`
-- (components/binary_devices/pump.dm), whose whole description is "a
-- pump that moves gas by pressure". It faces one way and it only moves
-- gas that way: in at the back, out at the front, until the far side
-- reads the target and then not one mole further. Point one the wrong
-- way round and it is a very expensive length of pipe.
--
-- `target_kpa` is tg's `ONE_ATMOSPHERE` default and `max_kpa` its
-- `MAX_OUTPUT_PRESSURE` (4500), which is the ceiling on anything that
-- later turns the dial. Both are numbers rather than engine constants
-- because the next station may want a high-pressure line, and that
-- should be a file somebody edits rather than a build somebody makes.
--
-- Off out of the box, as tg's is: the mapped `/pump/on` subtype exists
-- for lines that are meant to be running at roundstart, and here that
-- is `on = true` on a second entry rather than a second sprite state.
--
-- No power hookup yet. tg's pump draws idle power and refuses to run
-- unpowered; ours runs regardless, which is the one place this is not
-- yet tg. It lands with the rest of the binary roster.
return {
    id = "gas_pump",
    name = "gas pump",
    sprite = "pump_off_n",
    dense = false,
    states = { "off", "running" },
    facing_sprites = {
        off = {
            north = "pump_off_n",
            south = "pump_off_s",
            east = "pump_off_e",
            west = "pump_off_w",
        },
        running = {
            north = "pump_on_n",
            south = "pump_on_s",
            east = "pump_on_e",
            west = "pump_on_w",
        },
    },
    atmos = {
        device = "pump",
        positions = { "off", "running" },
        target_kpa = 101.325,
        max_kpa = 4500.0,
    },
}
