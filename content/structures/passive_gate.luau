-- A passive gate: the machine that keeps a department breathing
-- through a blackout.
--
-- tg's `/obj/machinery/atmospherics/components/binary/passive_gate`
-- (components/binary_devices/passive_gate.dm), and its own file
-- describes it better than a paraphrase can: "similar to the regular
-- pump except: it doesn't require power, can not transfer low pressure
-- to higher pressure (so it's more like a valve where you can control
-- the flow), passes gas when output pressure lower than target
-- pressure".
--
-- So it is a one-way tap. Open it and gas runs DOWNHILL from the back
-- port to the front until the front reaches `target_kpa` or the two
-- sides come level, whichever happens first; it will never push, and no
-- setting makes it. Put one between the mains and a department and that
-- department keeps its air at whatever the mains can give it by
-- themselves -- which is the point, because that is the moment the
-- pumps have stopped.
--
-- `powered` is false by default for this mechanism (tg's
-- `use_power = NO_POWER_USE`, passive_gate.dm:19) and this file does not
-- override it: a gate that needed power would be a pump with extra
-- steps.
return {
    id = "passive_gate",
    name = "passive gate",
    sprite = "passgate_off_ns",
    dense = false,
    states = { "shut", "open" },
    facing_sprites = {
        shut = {
            north = "passgate_off_ns",
            south = "passgate_off_ns",
            east = "passgate_off_ew",
            west = "passgate_off_ew",
        },
        open = {
            north = "passgate_on_ns",
            south = "passgate_on_ns",
            east = "passgate_on_ew",
            west = "passgate_on_ew",
        },
    },
    atmos = {
        device = "passive_gate",
        positions = { "shut", "open" },
        -- tg's `target_pressure = ONE_ATMOSPHERE` and its dial's
        -- `MAX_OUTPUT_PRESSURE` (passive_gate.dm:21,45).
        target_kpa = 101.325,
        max_kpa = 4500.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "passive_gate_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the passive gate down.",
        done = "The passive gate is bolted to the deck.",
    },
    transitions = {
        {
            -- tg's `can_unwrench` again, and note that this one has no
            -- `is_operational` in it (passive_gate.dm:108-112): an
            -- unpowered machine is open or shut on its own account, so
            -- open is open and you do not pull it out of a live line.
            at = "shut",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { passive_gate_fitting = 1 },
            start = "You start unfastening the passive gate.",
            done = "The passive gate comes up off the deck.",
        },
    },
}
