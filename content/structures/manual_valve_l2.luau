-- A manual valve on the waste main.
--
-- The same machine as manual_valve.luau with one line different, and
-- that line is a piping layer. tg does this constantly -- its
-- atmospherics roster is full of `/layer1`, `/layer2` and `/layer4`
-- subtypes, because a mapper needs the same device on whichever main
-- runs past, and a device's layer is a property of the ENTRY here.
--
-- It yields the ordinary valve fitting, because it is an ordinary
-- valve: what differs is which main it was bolted onto.
--
-- A manual valve: a length of pipe with a wheel on it.
--
-- tg's `/obj/machinery/atmospherics/components/binary/valve`
-- (components/binary_devices/valve.dm). It is the simplest thing in
-- atmospherics and the one that teaches what the rest are: it draws no
-- power, it has no window, it has nothing to set. You turn the wheel,
-- and the two runs it sits between are either one body of gas or two.
--
-- The `atmos` block is that sentence to the engine. `device = "valve"`
-- means an OPEN one does not pump — it fuses (tg's
-- `custom_reconcilation`), so the two sides equalise by volume and a
-- valve is a decision about topology rather than a machine that runs.
-- Shutting it splits the gas back by what each side holds, to the mole.
--
-- One second to turn, which is tg's own (`addtimer(..., 1 SECONDS)`,
-- valve.dm:69), and it is the whole feel of the thing: an atmospherics
-- valve is a commitment, and you cannot spam the wheel out of it.
--
-- It is NOT dense. Atmospherics machinery lies in the deck at tg's
-- `GAS_PIPE_HIDDEN_LAYER` and inherits `/obj`'s density of false: you
-- walk over a valve, the way you walk over the pipe either side of it.
--
-- The two states are the two positions, and naming them here is what
-- gives the engine the words for both the picture and the sentence a
-- player is told ("The manual valve is open."). The engine supplies the
-- frame; every noun in it is from this file.
return {
    id = "manual_valve_l2",
    name = "manual valve (scrubbers)",
    sprite = "valve_shut_ns",
    dense = false,
    states = { "shut", "open" },
    -- A binary device reaches along one axis, so north and south are
    -- one picture and east and west are the other -- tg's
    -- `PIPING_CARDINAL_AUTONORMALIZE` (valve.dm:14), whose art does not
    -- even ship a south cell. Two names for two pictures.
    facing_sprites = {
        shut = {
            north = "valve_shut_ns",
            south = "valve_shut_ns",
            east = "valve_shut_ew",
            west = "valve_shut_ew",
        },
        open = {
            north = "valve_open_ns",
            south = "valve_open_ns",
            east = "valve_open_ew",
            west = "valve_open_ew",
        },
    },
    -- The wheel turning, and the same 1.4s of art over the same 1.0s
    -- timer manual_valve.luau explains at length. A valve on the waste
    -- main is the same machine as one on the distribution main; the
    -- only thing this file changes is which run it reaches.
    moving_sprites = {
        {
            from = "shut",
            to = "open",
            secs = 1.4,
            north = "valve_opening_ns",
            south = "valve_opening_ns",
            east = "valve_opening_ew",
            west = "valve_opening_ew",
        },
        {
            from = "open",
            to = "shut",
            secs = 1.4,
            north = "valve_closing_ns",
            south = "valve_closing_ns",
            east = "valve_closing_ew",
            west = "valve_closing_ew",
        },
    },
    atmos = {
        device = "valve",
        -- Piping layer 2, which is the whole reason this file
        -- exists. A valve takes its layer from its entry and there is
        -- no per-placement layer in the map format, so reaching the waste main
        -- means a preset -- exactly as tg reaches one, with the
        -- `/layer2` and `/layer4` subtypes it hangs off half the
        -- atmospherics roster.
        layer = 2,
        positions = { "shut", "open" },
        switch_secs = 1.0,
    },
    -- Raised from a fitting and yielding one back, which is tg's
    -- universal atmospherics construction rather than a quirk of this
    -- machine: `/obj/item/pipe/wrench_act` deletes the fitting and
    -- spawns the machine (construction.dm:268-312), and
    -- `on_deconstruction` mints the machine's `construction_type` back
    -- onto the tile (atmosmachinery.dm:511-520). Two seconds each way,
    -- tg's own (`use_tool(..., 2 SECONDS)`, atmosmachinery.dm:456).
    --
    -- No `over = "pipe"`. A binary device is not a fitting laid ON a
    -- run, it is a length OF one: tg looks for conflicting atmospherics
    -- on the turf and at nothing else (construction.dm:276-296), so a
    -- valve goes down on bare deck and the pipe is run up to it.
    build = {
        on = { "floor", "plating" },
        from_item = "manual_valve_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the valve down.",
        done = "The valve is bolted to the deck.",
    },
    transitions = {
        {
            -- No state guard, and that is tg: the valve is the one
            -- machine in the family with no `can_unwrench` override
            -- (the base var is a flat TRUE, valve.dm:11), so an open
            -- one comes up if you insist on it. What follows is the
            -- plumbing's business.
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { manual_valve_fitting = 1 },
            start = "You start unfastening the valve.",
            done = "The valve comes up off the deck.",
        },
    },
}
