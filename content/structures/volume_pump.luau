-- A volumetric gas pump: the machine you move a TANKFUL with.
--
-- tg's `/obj/machinery/atmospherics/components/binary/volume_pump`
-- (components/binary_devices/volume_pump.dm), whose whole description
-- is "a pump that moves gas by volume". The gas pump beside it works to
-- a pressure and stops when it gets there; this one has no notion of
-- arriving. It moves `rate_lps` litres a second and keeps moving them,
-- which is what you want when the job is "empty that canister into this
-- line" and not "hold this line at an atmosphere".
--
-- `rate_lps` is tg's `transfer_rate`, out of the box at its
-- `MAX_TRANSFER_RATE` of 200 L/s (volume_pump.dm:23) -- which is the
-- whole 200 L of the input port every pass, so a fresh one is wide
-- open. `max_kpa` is its `VOLUME_PUMP_MAX_OUTPUT_PRESSURE`: not a
-- setpoint (this machine has none) but the pressure the mechanism is
-- rated to push against, and the mark the panel's gauge is drawn
-- against.
--
-- THE LIMITERS. Above that rated pressure it simply stops -- unless
-- somebody takes a MULTITOOL to it, which disables the limits and makes
-- the machine leak a tenth of everything it moves into the room it is
-- standing in (volume_pump.dm:97-101,162-170). That is the trade, and
-- it is a deliberate one: a line pressurised past what the kit is rated
-- for, paid for in the air an engineer is breathing. Somewhere with no
-- room to leak into it jams and turns its own limiters back on.
--
-- It is NOT dense: atmospherics machinery lies in the deck and you walk
-- over it, like the pipe either side.
return {
    id = "volume_pump",
    name = "volumetric gas pump",
    sprite = "volpump_off_ns",
    dense = false,
    states = { "off", "running" },
    -- A binary device reaches along one AXIS, so north and south share a
    -- picture and east and west share the other -- tg's
    -- `PIPING_CARDINAL_AUTONORMALIZE`, whose art does not even ship a
    -- south cell.
    facing_sprites = {
        off = {
            north = "volpump_off_ns",
            south = "volpump_off_ns",
            east = "volpump_off_ew",
            west = "volpump_off_ew",
        },
        running = {
            north = "volpump_on_ns",
            south = "volpump_on_ns",
            east = "volpump_on_ew",
            west = "volpump_on_ew",
        },
    },
    atmos = {
        device = "volume_pump",
        alternate_tool = "multitool",
        positions = { "off", "running" },
        rate_lps = 200.0,
        max_rate_lps = 200.0,
        max_kpa = 9000.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "volume_pump_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the volumetric pump down.",
        done = "The volumetric pump is bolted to the deck.",
    },
    transitions = {
        {
            -- Only while it is OFF. tg's `can_unwrench`: "You cannot
            -- unwrench [src], turn it off first!" (volume_pump.dm:156-160)
            -- -- said here by the state guard, which answers a wrench
            -- swung at a running one with "The volumetric gas pump must
            -- be off first."
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { volume_pump_fitting = 1 },
            start = "You start unfastening the volumetric pump.",
            done = "The volumetric pump comes up off the deck.",
        },
    },
}
