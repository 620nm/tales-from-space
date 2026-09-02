-- A gas mixer: the filter run backwards, and the reason the
-- distribution loop carries air rather than two gases in two pipes.
--
-- tg's `/obj/machinery/atmospherics/components/trinary/mixer`
-- (components/trinary_devices/mixer.dm). Two intakes -- the back port
-- and the side one -- are drawn from at a set ratio and merged into the
-- outlet in front, until that outlet reads `target_kpa`. Every tg map
-- has one of these set to 79/21 with a nitrogen line on one intake and
-- an oxygen line on the other; that is where a station's air comes
-- from.
--
-- `ratio` is the BACK intake's share of the mix, by moles, and the side
-- port supplies the rest. tg stores the two as separate numbers that
-- must sum to one (`node1_concentration`/`node2_concentration`,
-- mixer.dm:14-17) and rewrites the second whenever the first moves; one
-- number says the same thing and cannot disagree with itself. A side at
-- zero is ignored outright rather than multiplied by zero, so a mixer
-- set to 100/0 is a pass-through and its empty intake need not be
-- plumbed at all.
--
-- `target_kpa` is where it stops. A mixer never overshoots and never
-- runs backwards: an outlet already at target ends the pass before a
-- mole is drawn. The airmix on tg's maps runs at MAX_OUTPUT_PRESSURE,
-- 4500, which is what `max_kpa` here allows and the panel's dial
-- reaches.
--
-- The one number in this file that is not a setting: the mixer's OUTLET
-- is 300 L where every other mouth in the kit is 200 (tg widens it in
-- `Initialize`, mixer.dm:22-24). It is not written here because it is
-- not a choice -- it is what a gas mixer IS, and the engine gives the
-- mechanism its own geometry.
--
-- Off out of the box; an empty hand opens the panel, which is where it
-- gets switched on. No power hookup yet, as with the rest of the kit.
return {
    id = "gas_mixer",
    name = "gas mixer",
    sprite = "mixer_off_n",
    ui = { modules = { "mixer" } },
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
    facing_sprites = {
        off = {
            north = "mixer_off_n",
            south = "mixer_off_s",
            east = "mixer_off_e",
            west = "mixer_off_w",
        },
        running = {
            north = "mixer_on_n",
            south = "mixer_on_s",
            east = "mixer_on_e",
            west = "mixer_on_w",
        },
    },
    atmos = {
        device = "mixer",
        positions = { "off", "running" },
        -- tg's ONE_ATMOSPHERE default and its MAX_OUTPUT_PRESSURE
        -- ceiling (mixer.dm:13, 42-45).
        target_kpa = 101.325,
        max_kpa = 4500.0,
        ratio = 0.5,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "gas_mixer_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start bolting the gas mixer down.",
        done = "The gas mixer is seated on the pipe.",
    },
    transitions = {
        {
            -- tg's `can_unwrench`: "You cannot unwrench [src], turn it
            -- off first!" (mixer.dm:186-190). Expressed as the state
            -- the row belongs to rather than as a refusal in Rust.
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { gas_mixer_fitting = 1 },
            start = "You start unbolting the gas mixer.",
            done = "The gas mixer comes up off the pipe.",
        },
    },
    variants = {
        -- tg's `/mixer/airmix`: the machine a department's air comes
        -- out of, set to `N2STANDARD` and left alone for the life of
        -- the station -- 79% out of the back intake, 21% out of the
        -- side, dial open all the way (`target_pressure =
        -- MAX_OUTPUT_PRESSURE`, mixer.dm:239). A mixer that had to be
        -- dialled in by hand before a station could breathe would be a
        -- machine shipping mis-configured.
        --
        -- All three are placement properties, so a mapper can say the
        -- same thing on a bare `gas_mixer` and this variant is only
        -- the shorthand. No `build`: it is laid, not raised.
        airmix = {
            name = "air mixer",
            props = { on = true, ratio = 0.79, target_kpa = 4500.0 },
        },
        -- The mirror image, as the filter has: node1 and node3 change
        -- places and node2 stays (mixer.dm:212-214). It matters more
        -- here than on a filter, because a mixer's two intakes carry
        -- DIFFERENT gases -- flipping is how the nitrogen line feeds
        -- the back port when it comes at the junction from the other
        -- side, without re-routing the run.
        flipped = {
            name = "gas mixer",
            sprite = "mixer_f_off_n",
            props = { flipped = true },
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
        },
    },
}
