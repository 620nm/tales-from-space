-- A gas filter: the fork in the pipe that every waste loop is built
-- out of.
--
-- tg's `/obj/machinery/atmospherics/components/trinary/filter`
-- (components/trinary_devices/filter.dm). It is the first machine here
-- with THREE mouths: gas comes in at the back, whatever the roster
-- names leaves by the side port, and everything else carries straight
-- on out the front. Chain one per gas and a mixed atmosphere comes
-- apart into bottles, which is the whole of tg's atmospherics
-- department.
--
-- `device = "filter"` is that sentence to the engine, and the third
-- port comes with it: a trinary's mouths are behind the facing, the
-- facing, and `turn(dir, -90)` (trinary_devices.dm:43-51). Point one
-- into a straight run and the side port stares at bare deck, and a
-- filter with a mouth on nothing does not run at all -- tg refuses the
-- same way (`nodes[1] && nodes[2] && nodes[3]`, filter.dm:58). It wants
-- a T.
--
-- `rate_lps` is tg's `MAX_TRANSFER_RATE`, and it is a rate over the
-- input mouth's own 200 L rather than an absolute flow: at 200 L/s the
-- machine passes exactly a portful each pass, and turning it down to
-- 100 halves that. An empty `filter` list is tg's own default and means
-- everything goes straight through -- a filter with nothing selected is
-- a length of pipe with a rate limit, not a wall.
--
-- Off out of the box, as tg's is. The window is where it gets switched
-- on: unlike the manual valve there is no wheel here, and an empty hand
-- on one opens its panel (tg's `ui_interact`, filter.dm:123-127).
--
-- It is NOT dense, and it hides in the deck with the rest of the
-- plumbing.
--
-- No power hookup yet, the same gap the pump has: tg's filter draws
-- idle power and stops when the area does. It lands with the rest of
-- the kit.
return {
    id = "gas_filter",
    name = "gas filter",
    sprite = "filter_off_n",
    dense = false,
    states = { "off", "running" },
    -- Four pictures per position, where a binary device has two: a
    -- trinary reaches three ways, so every rotation is a different
    -- machine to look at.
    facing_sprites = {
        off = {
            north = "filter_off_n",
            south = "filter_off_s",
            east = "filter_off_e",
            west = "filter_off_w",
        },
        running = {
            north = "filter_on_n",
            south = "filter_on_s",
            east = "filter_on_e",
            west = "filter_on_w",
        },
    },
    atmos = {
        device = "filter",
        positions = { "off", "running" },
        rate_lps = 200.0,
        max_rate_lps = 200.0,
    },
    -- The round trip, exactly as the connector port's is: a fitting
    -- goes down on the run and a wrench stands the machine up
    -- (docs/construction.md, "The fitting round trip").
    build = {
        on = { "floor", "plating" },
        from_item = "gas_filter_fitting",
        tool = "wrench",
        secs = 2.0,
        over = "pipe",
        start = "You start bolting the gas filter down.",
        done = "The gas filter is seated on the pipe.",
    },
    transitions = {
        {
            -- Only while it is OFF. tg's `can_unwrench` refuses a
            -- running filter outright ("turn off!", filter.dm:176-180),
            -- and here that is not a special case in the engine: the
            -- row simply belongs to the "off" state, so a running one
            -- has no wrench row and is told "The gas filter must be off
            -- first."
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { gas_filter_fitting = 1 },
            start = "You start unbolting the gas filter.",
            done = "The gas filter comes up off the pipe.",
        },
    },
}
