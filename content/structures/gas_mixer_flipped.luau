-- The mirrored gas mixer. tg's
-- `/obj/machinery/atmospherics/components/trinary/mixer/flipped`
-- (mixer.dm:212-214).
--
-- The same mirroring the flipped filter gets: node1 and node3 change
-- places, node2 stays, so the flow reverses along the axis while the
-- side intake keeps its wall. Which matters more here than on a filter,
-- because a mixer's two intakes carry DIFFERENT gases -- flipping is
-- how you feed the nitrogen line into the back port when it comes at
-- the junction from the other direction, without re-routing the run.
--
-- Everything else is gas_mixer.luau's, and that file carries the
-- reasoning.
return {
    id = "gas_mixer_flipped",
    name = "gas mixer",
    sprite = "mixer_f_off_n",
    dense = false,
    states = { "off", "running" },
    facing_sprites = {
        off = {
            north = "mixer_f_off_n",
            south = "mixer_f_off_s",
            east = "mixer_f_off_e",
            west = "mixer_f_off_w",
        },
        running = {
            north = "mixer_f_on_n",
            south = "mixer_f_on_s",
            east = "mixer_f_on_e",
            west = "mixer_f_on_w",
        },
    },
    atmos = {
        device = "mixer",
        flipped = true,
        positions = { "off", "running" },
        target_kpa = 101.325,
        max_kpa = 4500.0,
        ratio = 0.5,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "gas_mixer_flipped_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start bolting the gas mixer down.",
        done = "The gas mixer is seated on the pipe.",
    },
    transitions = {
        {
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { gas_mixer_flipped_fitting = 1 },
            start = "You start unbolting the gas mixer.",
            done = "The gas mixer comes up off the pipe.",
        },
    },
}
