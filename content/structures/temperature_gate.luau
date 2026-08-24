-- A temperature gate: a valve that reads a thermometer.
--
-- tg's `/obj/machinery/atmospherics/components/binary/temperature_gate`
-- (components/binary_devices/temperature_gate.dm) -- "an activable gate
-- that compares the input temperature with the interface set
-- temperature to check if the gas can flow from the input side to the
-- output side or not".
--
-- Nothing else in the kit can tell one mole from another by how hot it
-- is. A pump moves whatever is in front of it; a filter sorts by which
-- gas it is. This sorts by TEMPERATURE, which is what makes it the
-- piece a freezer loop is finished with: cold gas leaves for the
-- distribution main and anything the coolers have not caught yet stays
-- in the loop for another lap.
--
-- Armed, it passes gas while its INPUT side is below `target_k` and
-- holds it back at or above. It releases towards the input's own
-- pressure rather than to a setpoint (temperature_gate.dm:76), so like
-- the pressure valve it approaches level and never crosses it -- the
-- temperature decides WHETHER, and the plumbing decides how much.
--
-- THE SENSOR CAN BE REVERSED. A multitool on the gate inverts it
-- (temperature_gate.dm:137-145) and the same device then passes only
-- what is HOTTER than its setting, which is the machine you put on the
-- other leg: heat leaves for the radiators, cold gas stays where it is
-- wanted. tg tells you which way round a gate is set on examine and
-- nowhere else; the panel here says so too, because a reversed gate at
-- 273 K and a broken one look identical from the corridor.
--
-- It draws power (the binary base's idle draw, which
-- temperature_gate.dm does not override) and stops without it. That is
-- deliberate on tg's part and worth keeping: this is a machine with an
-- opinion, unlike the passive gate beside it, and an opinion needs the
-- lights on.
return {
    id = "temperature_gate",
    name = "temperature gate",
    sprite = "tgate_off_n",
    dense = false,
    -- "armed" rather than "open", the same word the pressure valve
    -- wears and for the same reason: the gate is watching. Whether
    -- anything is actually crossing is the gas's business.
    states = { "shut", "armed" },
    facing_sprites = {
        shut = {
            north = "tgate_off_n",
            south = "tgate_off_s",
            east = "tgate_off_e",
            west = "tgate_off_w",
        },
        armed = {
            north = "tgate_on_n",
            south = "tgate_on_s",
            east = "tgate_on_e",
            west = "tgate_on_w",
        },
    },
    atmos = {
        device = "temperature_gate",
        alternate_tool = "multitool",
        positions = { "shut", "armed" },
        -- tg's `target_temperature = T0C` and `max_temperature = 4500`
        -- (temperature_gate.dm:10,14). The floor is TCMB and the engine
        -- holds it -- a setpoint below the coldest thing there is would
        -- be a gate that can never open.
        target_k = 273.15,
        max_k = 4500.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "temperature_gate_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the temperature gate down.",
        done = "The temperature gate is bolted to the deck.",
    },
    transitions = {
        {
            -- tg's `can_unwrench`: "You cannot unwrench [src], turn it
            -- off first!" (temperature_gate.dm:131-135).
            at = "shut",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { temperature_gate_fitting = 1 },
            start = "You start unfastening the temperature gate.",
            done = "The temperature gate comes up off the deck.",
        },
    },
}
