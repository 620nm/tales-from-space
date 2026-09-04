-- A filter: the fork in the pipe that every waste loop is built
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
    id = "filter",
    name = "filter",
    sprite = "filter_off_n",
    ui = { modules = { "filter" } },
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
    -- goes down and a wrench stands the machine up as the centre
    -- section between the neighbouring runs
    -- (docs/CONSTRUCTION.md, "Fittings, portables, and the round trip").
    build = {
        on = { "floor", "plating" },
        from_item = "filter_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start bolting the filter down.",
        done = "The filter is seated on the pipe.",
    },
    transitions = {
        {
            -- Only while it is OFF. tg's `can_unwrench` refuses a
            -- running filter outright ("turn off!", filter.dm:176-180),
            -- and here that is not a special case in the engine: the
            -- row simply belongs to the "off" state, so a running one
            -- has no wrench row and is told "The filter must be off
            -- first."
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { filter_fitting = 1 },
            start = "You start unbolting the filter.",
            done = "The filter comes up off the pipe.",
        },
    },
    -- The preconfigurations. tg ships eighteen `/filter/atmos/<gas>`
    -- subtypes, each the base machine with `on = TRUE` and one gas in
    -- `filter_type` (filter.dm:224-229), because a waste loop is a
    -- CHAIN of filters and a mapper laying one should not have to open
    -- eighteen panels. Here each is a line: `props` is the placement
    -- bag any map could already write by hand, said once
    -- (docs/MAP-PROPERTIES.md, docs/CONTENT-SCHEMA.md §1.1a).
    --
    -- None of them declares a `build`: a preset is something a MAP
    -- lays, not something a player raises, and tg agrees — every preset
    -- filter shares the base's `construction_type`, so the fitting in
    -- your hands only ever knows how to become a plain filter.
    variants = {
        co2 = {
            name = "carbon dioxide filter",
            sprite = "filter_on_n",
            props = { on = true, filter = "co2" },
        },
        n2 = {
            name = "nitrogen filter",
            sprite = "filter_on_n",
            props = { on = true, filter = "n2" },
        },
        -- The mirrored machine, which is NOT a turned one: tg's
        -- `get_node_connects` swaps node1 and node3 and leaves node2
        -- where it is (trinary_devices.dm:43-51), so the flow reverses
        -- along the axis while the side port keeps its wall — the
        -- filtered outlet ends up on the other hand of the stream. A
        -- pipe run bending the other way needs it.
        --
        -- It is the one variant with a `build` of its own, because it
        -- is the one a player raises: its own fitting goes down and the
        -- same fitting comes back up, which is why its `transitions`
        -- are restated too.
        flipped = {
            name = "filter",
            sprite = "filter_f_off_n",
            props = { flipped = true },
            facing_sprites = {
                off = {
                    north = "filter_f_off_n",
                    south = "filter_f_off_s",
                    east = "filter_f_off_e",
                    west = "filter_f_off_w",
                },
                running = {
                    north = "filter_f_on_n",
                    south = "filter_f_on_s",
                    east = "filter_f_on_e",
                    west = "filter_f_on_w",
                },
            },
            build = {
                on = { "floor", "plating" },
                from_item = "filter_flipped_fitting",
                tool = "wrench",
                secs = 2.0,
                start = "You start bolting the filter down.",
                done = "The filter is seated on the pipe.",
            },
            transitions = {
                {
                    at = "off",
                    tool = "wrench",
                    secs = 2.0,
                    gone = true,
                    yields = { filter_flipped_fitting = 1 },
                    start = "You start unbolting the filter.",
                    done = "The filter comes up off the pipe.",
                },
            },
        },
    },
}
