-- The skeleton a pressure tank is welded out of (tg's
-- /obj/structure/tank_frame, code/modules/atmospherics/machinery/
-- components/tank.dm:560-697). Four sheets stand one up; twelve more
-- plate it; a torch seals the plating and the frame becomes the vessel.
-- Every step runs backwards, which is tg's own chain and not a
-- convenience: a crowbar takes the plating off, a screwdriver takes the
-- bare frame apart, and both hand back exactly what they cost.
--
-- MATERIAL SUBSTITUTION, deliberate and the only change to tg's recipe:
-- tg's frame is FOUR PLASTEEL (sheet_types.dm:297, the "Large Gas Tank"
-- stack recipe) and its plating is twelve sheets of anything rigid
-- (add_plating checks MATERIAL_CLASS_RIGID, tank.dm:631). This station
-- has no plasteel and no material classes, so metal stands in for both
-- and the COUNTS are tg's, untouched: 4 to raise, 12 to plate. tg is
-- itself equivocal about the frame's material -- the finished tank's
-- `custom_materials` is IRON, with a comment explaining that plasteel
-- was deliberately kept off the tank to stop its pressure rating being
-- silently multiplied (tank.dm:17) -- so metal is a smaller departure
-- than the sheet count would suggest.
--
-- The frame is DISPLACED out of the box, unlike a girder. tg's stack
-- recipe spawns `anchored = FALSE` (tank.dm:563) and the welder refuses
-- to seal one that is not bolted down ("You need to wrench [src] to the
-- floor before finishing", tank.dm:680-682), so wrenching it is a real
-- step and not a way of taking the bolts back out.
return {
    id = "stationary_tank_frame",
    name = "tank frame",
    sprite = "stationary_tank_frame",
    dense = true,
    states = { "displaced", "anchored", "plated" },
    state_sprites = {
        displaced = "stationary_tank_frame",
        anchored = "stationary_tank_frame",
        plated = "stationary_tank_plated",
    },
    -- Nothing holds an unbolted frame to the deck, so a walker can
    -- shove it and a decompression can drag it. Plated is not loose:
    -- twelve sheets of steel on a frame is not a thing you shoulder
    -- aside, and tg will not let you unwrench one either.
    loose = { "displaced" },
    build = {
        on = { "floor", "plating" },
        with = { metal = 4 },
        -- tg's `time = 1 SECONDS` on the stack recipe.
        secs = 1.0,
        start = "You start bending sheets into a tank frame.",
        done = "The tank frame stands.",
    },
    transitions = {
        -- tg's `default_unfasten_wrench(user, tool, time = 0.5 SECONDS)`
        -- (tank.dm:610-613), both ways.
        {
            at = "displaced",
            tool = "wrench",
            secs = 0.5,
            to = "anchored",
            start = "You start bolting the frame down.",
            done = "The frame is bolted to the deck.",
        },
        {
            at = "anchored",
            tool = "wrench",
            secs = 0.5,
            to = "displaced",
            start = "You start unbolting the frame.",
            done = "The frame shifts loose of its bolts.",
        },
        -- tg's `screwdriver_act_secondary`: 1 second, and the bare
        -- frame comes apart into what it cost (tank.dm:615-624, and
        -- `atom_deconstruct` at :588-591 drops the four sheets).
        {
            at = "displaced",
            tool = "screwdriver",
            secs = 1.0,
            yields = { metal = 4 },
            gone = true,
            start = "You start taking the frame apart.",
            done = "The frame comes apart.",
        },
        -- tg's `add_plating`: 3 seconds and TANK_PLATING_SHEETS (12)
        -- (tank.dm:626-660). Only onto a bolted frame -- tg's welder
        -- check further down makes an unbolted plated frame a dead end,
        -- and refusing it here says so a step earlier.
        {
            at = "anchored",
            with = { metal = 12 },
            secs = 3.0,
            to = "plated",
            start = "You start plating the tank frame.",
            done = "The plating is on.",
        },
        -- tg's `crowbar_act_secondary`: 2 seconds, and every sheet of
        -- the plating comes back (tank.dm:662-673).
        {
            at = "plated",
            tool = "crowbar",
            secs = 2.0,
            yields = { metal = 12 },
            to = "anchored",
            start = "You start prying off the outer plating.",
            done = "The plating comes away.",
        },
        -- tg's `welder_act`: 2 seconds, and the frame IS the tank
        -- (tank.dm:675-697). `gone` + `leaves` rather than a fourth
        -- state, because a sealed vessel is a different prototype with
        -- a different mechanism -- it holds gas, and the frame does
        -- not. That is the same shape a sliced wall uses to leave a
        -- girder standing.
        {
            at = "plated",
            tool = "welder",
            secs = 2.0,
            fuel = 2.0,
            gone = true,
            leaves = "stationary_tank",
            start = "You start sealing the plating with the welder.",
            done = "The tank is sealed and ready to accept gases.",
        },
    },
}
