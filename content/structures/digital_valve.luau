-- A digital valve: the manual valve, with the wheel replaced by a
-- control surface.
--
-- tg's `/obj/machinery/atmospherics/components/binary/valve/digital`
-- (valve.dm:78-86), and the striking thing about it is how LITTLE of it
-- there is. It is the same subtype as the manual valve, does the same
-- thing to gas -- open, it fuses its two pipelines into one body of gas
-- rather than pumping -- and differs in exactly one line: its
-- `interaction_flags_machine` turns on the `ALLOW_SILICON` flag that
-- the manual valve's carries a comment about deliberately withholding
-- ("Intentionally no allow_silicon flag", valve.dm:13).
--
-- That is a design statement, and it is worth keeping. The manual valve
-- is the atmospherics component nobody can operate from a chair: to
-- shut a distribution main with one, somebody has to walk to it and put
-- a hand on it, and the second the wheel takes is a second they are
-- standing there. The digital valve is what you install when you want
-- that decision to be remotely available, and losing the guarantee is
-- the price.
--
-- Here the `ui` declaration gives it the settings window
-- the whole in-line roster shares -- the equivalent surface, since
-- silicons do not exist yet -- and `switch_secs = 0` takes the wheel
-- away: a digital valve throws on the command, where a manual one
-- swings for a second you cannot interrupt.
--
-- Unpowered, like its twin (`use_power = NO_POWER_USE` on the base
-- valve, valve.dm:18). tg ships a `dvalve_nopower` picture for it that
-- nothing can reach, which is a leftover rather than a rule.
return {
    id = "digital_valve",
    name = "digital valve",
    sprite = "dvalve_shut_ns",
    ui = { modules = { "flow" } },
    -- ON THE ROOM'S NETWORK. An endpoint carries its own address and
    -- joins one hub, which is how an air alarm comes to draw this
    -- machine's settings instead of a crewman kneeling at it. The class
    -- word is what stops the alarm adopting the comms box next to it,
    -- and it is spelled out rather than shared because `lib/` is not
    -- published into the structure registry's sandbox
    -- (structures/air_alarm.luau, docs/content-schema/link.md).
    link = {
        network_interface = true,
        role = "endpoint",
        class = "atmos",
    },
    dense = false,
    states = { "shut", "open" },
    facing_sprites = {
        shut = {
            north = "dvalve_shut_ns",
            south = "dvalve_shut_ns",
            east = "dvalve_shut_ew",
            west = "dvalve_shut_ew",
        },
        open = {
            north = "dvalve_open_ns",
            south = "dvalve_open_ns",
            east = "dvalve_open_ew",
            west = "dvalve_open_ew",
        },
    },
    -- Seven frames, 1.4 seconds, over a valve that throws INSTANTLY.
    --
    -- That reads like a contradiction and is in fact tg's own shape.
    -- `flick()` lays an animation over an object without touching what
    -- the object is doing (valve.dm:24-29); the position is changed by
    -- something else entirely. On the manual valve that something is a
    -- one-second timer, and on this one -- because `switch_secs = 0`
    -- above takes the wheel away, the deliberate divergence this file
    -- is about -- it is the command itself. So the gas moves the moment
    -- you throw it and the mechanism is still visibly closing for a
    -- second and a bit afterwards, which is what a solenoid does.
    --
    -- Worth having precisely BECAUSE the valve is remote: a digital
    -- valve is the one nobody is standing next to, so the picture is
    -- the only way anyone in the room learns it just moved.
    moving_sprites = {
        {
            from = "shut",
            to = "open",
            secs = 1.4,
            north = "dvalve_opening_ns",
            south = "dvalve_opening_ns",
            east = "dvalve_opening_ew",
            west = "dvalve_opening_ew",
        },
        {
            from = "open",
            to = "shut",
            secs = 1.4,
            north = "dvalve_closing_ns",
            south = "dvalve_closing_ns",
            east = "dvalve_closing_ew",
            west = "dvalve_closing_ew",
        },
    },
    atmos = {
        device = "valve",
        positions = { "shut", "open" },
        switch_secs = 0.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "digital_valve_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the digital valve down.",
        done = "The digital valve is bolted to the deck.",
    },
    transitions = {
        {
            -- A valve has no `can_unwrench` override in tg at all --
            -- the base one is a flat TRUE (valve.dm:11) -- so an open
            -- one comes up if you insist. The gush of air that follows
            -- is the plumbing's answer, not the ratchet's.
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { digital_valve_fitting = 1 },
            start = "You start unfastening the digital valve.",
            done = "The digital valve comes up off the deck.",
        },
    },
}
