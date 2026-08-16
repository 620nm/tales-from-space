-- A passive vent: a hole between a pipe run and the room over it, and
-- nothing whatever else.
--
-- tg's `/obj/machinery/atmospherics/components/unary/passive_vent`
-- (components/unary_devices/passive_vent.dm), whose entire description
-- is "It is an open vent." No power, no setpoint, no direction, no
-- switch: each pass it moves gas until the run and the tile over it
-- hold the same molar density, and which way that runs is not a
-- property of the vent at all -- it is a property of which side is
-- fuller. tg's `internal.equalize(external)`, which is the whole
-- machine.
--
-- WHY A STATION HAS ANY. Two reasons, and both are about the day
-- something has gone wrong. It is unpowered, so it goes on being a hole
-- when the breaker trips and the powered vents have all become grilles
-- -- which is exactly when you want a distribution line still feeding.
-- And it works BACKWARDS as readily as forwards, so it is also how gas
-- gets INTO a line: stand one in a chamber you have filled and the run
-- behind it fills too.
--
-- What that costs you is a valve you do not have. There is no shutting
-- one, so a passive vent in a room that decompresses empties the line
-- behind it into space, and the bottle on the far end pays for every
-- second of it. tg gives the powered vent a shut-off and this one none,
-- deliberately; the answer is a manual valve upstream, not a dial here.
return {
    id = "passive_vent",
    name = "passive vent",
    sprite = "vent_passive",
    dense = false,
    -- ONE state, because there is one thing it can be: open. A machine
    -- with a position is a machine somebody could have set wrongly, and
    -- the point of this one is that nobody can.
    atmos = {
        device = "passive_vent",
        -- Layer 3, the distribution layer -- the same run a supply vent
        -- draws from, because that is the line this thing exists to
        -- charge.
        --
        -- `on` with no way to turn it off, and `powered` false: tg's
        -- passive vent overrides no `use_power` at all, which is the
        -- design statement the whole file is about.
        on = true,
        powered = false,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "passive_vent_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the passive vent down.",
        done = "The passive vent is bolted to the deck, open to the room.",
    },
    transitions = {
        {
            -- Coming up is the only control this machine has, which is
            -- worth remembering before unbolting one on a charged main.
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { passive_vent_fitting = 1 },
            start = "You start unfastening the passive vent.",
            done = "The passive vent comes up off the deck.",
        },
    },
}
