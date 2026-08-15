-- The mirrored gas filter. tg's
-- `/obj/machinery/atmospherics/components/trinary/filter/flipped`
-- (filter.dm:202-204).
--
-- Flipping is not turning. tg's `get_node_connects` swaps node1 and
-- node3 and leaves node2 where it is (trinary_devices.dm:43-51), so
-- the flow reverses along the axis while the side port stays put --
-- which puts the filtered outlet on the OTHER HAND of the stream. A
-- filter turned around would move all three mouths and be the same
-- machine facing the other way; this one is its mirror image, and a
-- pipe run bending the other way needs it.
--
-- Everything else is gas_filter.luau's, and that file carries the
-- reasoning.
return {
    id = "gas_filter_flipped",
    name = "gas filter",
    sprite = "filter_f_off_n",
    dense = false,
    states = { "off", "running" },
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
    atmos = {
        device = "filter",
        flipped = true,
        positions = { "off", "running" },
        rate_lps = 200.0,
        max_rate_lps = 200.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "gas_filter_flipped_fitting",
        tool = "wrench",
        secs = 2.0,
        over = "pipe",
        start = "You start bolting the gas filter down.",
        done = "The gas filter is seated on the pipe.",
    },
    transitions = {
        {
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { gas_filter_flipped_fitting = 1 },
            start = "You start unbolting the gas filter.",
            done = "The gas filter comes up off the pipe.",
        },
    },
}
