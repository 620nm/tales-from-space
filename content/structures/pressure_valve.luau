-- A pressure valve: a relief valve, not a regulator.
--
-- tg's `/obj/machinery/atmospherics/components/binary/pressure_valve`
-- (components/binary_devices/pressure_valve.dm) -- "an activable one
-- way valve that let gas pass through if the pressure on the input side
-- is higher than the set pressure".
--
-- It is the passive gate with the test moved to the other end, and that
-- is the entire machine. A gate watches its OUTPUT and holds a line AT
-- a pressure. This watches its INPUT and does nothing at all until
-- something upstream goes over `target_kpa`, at which point it bleeds
-- the excess forward and shuts again (pressure_valve.dm:181-186). Plumb
-- one out of a burn chamber or a supply main and it is the thing that
-- stops a line letting go.
--
-- `target_kpa` is a TRIGGER, never a destination: once it opens, tg
-- releases towards the input's own pressure and the half-the-gap rule
-- does the limiting, so the valve bleeds a line down over several
-- passes rather than slamming it. Its dial goes to a hundred
-- atmospheres, which is tg's own ceiling for this machine
-- (`ONE_ATMOSPHERE*100`, pressure_valve.dm:225) and the highest number
-- anything in the kit accepts.
--
-- Unpowered, like the gate (`use_power = NO_POWER_USE`,
-- pressure_valve.dm:130): a safety device that needs the lights on is
-- not a safety device.
return {
    id = "pressure_valve",
    name = "pressure valve",
    sprite = "pvalve_off_n",
    dense = false,
    -- "armed" rather than "open", because that is what the position
    -- means: the valve is watching, and whether anything is crossing is
    -- the line's business rather than the handle's.
    states = { "shut", "armed" },
    facing_sprites = {
        shut = {
            north = "pvalve_off_n",
            south = "pvalve_off_s",
            east = "pvalve_off_e",
            west = "pvalve_off_w",
        },
        armed = {
            north = "pvalve_on_n",
            south = "pvalve_on_s",
            east = "pvalve_on_e",
            west = "pvalve_on_w",
        },
    },
    atmos = {
        device = "pressure_valve",
        positions = { "shut", "armed" },
        target_kpa = 101.325,
        max_kpa = 10132.5,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "pressure_valve_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the pressure valve down.",
        done = "The pressure valve is bolted to the deck.",
    },
    transitions = {
        {
            -- tg's `can_unwrench` (pressure_valve.dm:229-233).
            at = "shut",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { pressure_valve_fitting = 1 },
            start = "You start unfastening the pressure valve.",
            done = "The pressure valve comes up off the deck.",
        },
    },
}
