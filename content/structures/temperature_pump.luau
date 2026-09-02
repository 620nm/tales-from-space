-- A temperature pump: the machine that moves heat and no gas at all.
--
-- tg's `/obj/machinery/atmospherics/components/binary/temperature_pump`
-- (components/binary_devices/temperature_pump.dm) -- "a pump that moves
-- heat from one pipeline to another. The input will get cooler, and the
-- output will get hotter."
--
-- Not one mole crosses it. Its two sides stay exactly as separate as a
-- shut valve leaves them, and what travels between them is energy,
-- which is the only reason a station can be cooled at all: you cannot
-- chill a chamber by pumping its air away, but you can stand one of
-- these between the chamber's loop and a radiator loop and pump the
-- HEAT out.
--
-- It only ever runs downhill (temperature_pump.dm:61) -- it is a
-- throttled conductor, not a refrigerator, and no setting makes it push
-- heat into a side that is already hotter. What the dial does is decide
-- how much of the conduction between the two sides it actually moves,
-- as a percentage.
--
-- THAT DIAL SHIPS AT ZERO (tg's `heat_transfer_rate = 0`,
-- temperature_pump.dm:11), which is a real trap and is kept: a pump
-- somebody has only switched on does nothing whatever, forever, and the
-- panel is where you find out. tg's `click_alt` maximises it in one
-- press; here the panel's + button and its entry box do the same job.
--
-- Powered, and firmly so: tg bills a flat 200 W every pass it runs
-- (temperature_pump.dm:70-76). A dead equipment channel stops it.
return {
    id = "temperature_pump",
    name = "temperature pump",
    sprite = "tpump_off_n",
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
    states = { "off", "running" },
    facing_sprites = {
        off = {
            north = "tpump_off_n",
            south = "tpump_off_s",
            east = "tpump_off_e",
            west = "tpump_off_w",
        },
        running = {
            north = "tpump_on_n",
            south = "tpump_on_s",
            east = "tpump_on_e",
            west = "tpump_on_w",
        },
    },
    atmos = {
        device = "temperature_pump",
        positions = { "off", "running" },
        -- tg's `heat_transfer_rate = 0` out of the crate, as the share
        -- the engine stores it in. The panel talks percent because a
        -- technician does.
        ratio = 0.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "temperature_pump_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the temperature pump down.",
        done = "The temperature pump is bolted to the deck.",
    },
    transitions = {
        {
            -- tg's temperature pump overrides no `can_unwrench` of its
            -- own, so the family default applies and a running one is
            -- not to be pulled out of the line. The guard is the state,
            -- so the wrench earns "must be off first" rather than
            -- silence.
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { temperature_pump_fitting = 1 },
            start = "You start unfastening the temperature pump.",
            done = "The temperature pump comes up off the deck.",
        },
    },
}
