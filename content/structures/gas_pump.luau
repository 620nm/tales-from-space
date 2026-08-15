-- A gas pump: the machine a distribution loop is actually built out of.
--
-- tg's `/obj/machinery/atmospherics/components/binary/pump`
-- (components/binary_devices/pump.dm), whose whole description is "a
-- pump that moves gas by pressure". It faces one way and it only moves
-- gas that way: in at the back, out at the front, until the far side
-- reads the target and then not one mole further. Point one the wrong
-- way round and it is a very expensive length of pipe.
--
-- `target_kpa` is tg's `ONE_ATMOSPHERE` default and `max_kpa` its
-- `MAX_OUTPUT_PRESSURE` (4500), which is the ceiling on anything that
-- later turns the dial. Both are numbers rather than engine constants
-- because the next station may want a high-pressure line, and that
-- should be a file somebody edits rather than a build somebody makes.
--
-- Off out of the box, as tg's is: the mapped `/pump/on` subtype exists
-- for lines that are meant to be running at roundstart, and here that
-- is `on = true` on a second entry rather than a second sprite state.
--
-- It draws power and stops without it, which is the `atmos` block's
-- default for this mechanism (tg's `use_power = IDLE_POWER_USE` at
-- `BASE_MACHINE_IDLE_CONSUMPTION * 0.25`, binary_devices.dm:5-6). So it
-- is on the equipment channel of whatever APC feeds the branch under
-- its tile, it goes dark when that channel sheds, and it picks the line
-- back up when the power returns -- nobody has to re-throw the switch,
-- because the switch never moved.
--
-- And it wears the settings panel every machine with a dial on it
-- wears, which is why an empty hand on this OPENS something rather than
-- switching it: tg's `interact()` on a pump is `ui_interact`
-- (pump.dm:68), where the manual valve's starts the wheel turning.
return {
    id = "gas_pump",
    name = "gas pump",
    sprite = "pump_off_ns",
    dense = false,
    states = { "off", "running" },
    -- A binary device reaches along one axis, so north and south are
    -- one picture and east and west are the other -- tg's
    -- `PIPING_CARDINAL_AUTONORMALIZE` (pump.dm's parent,
    -- binary_devices.dm:9), whose art does not even ship a south cell.
    -- Two names for two pictures, therefore, rather than four names for
    -- the same two: `pump_on` is a five-frame loop and duplicating it
    -- would cost ten atlas cells nobody would ever look at.
    facing_sprites = {
        off = {
            north = "pump_off_ns",
            south = "pump_off_ns",
            east = "pump_off_ew",
            west = "pump_off_ew",
        },
        -- The running picture MOVES: tg's `pump_on-1` is five frames at
        -- a twentieth of a second (binary_devices.dmi). Nothing here
        -- says so -- a loop needs no anchor and no duration, because it
        -- has no beginning anyone has to agree on, so the frame count
        -- and the timing come out of the .dmi at bake time and the
        -- client runs it off its own clock.
        running = {
            north = "pump_on_ns",
            south = "pump_on_ns",
            east = "pump_on_ew",
            west = "pump_on_ew",
        },
    },
    atmos = {
        device = "pump",
        positions = { "off", "running" },
        target_kpa = 101.325,
        max_kpa = 4500.0,
    },
    build = {
        on = { "floor", "plating" },
        from_item = "gas_pump_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the pump down.",
        done = "The pump is bolted to the deck.",
    },
    transitions = {
        {
            -- Only while it is OFF -- tg's `can_unwrench`: "You cannot
            -- unwrench [src], turn it off first!" (pump.dm:103-107).
            -- The guard is the state itself, so a wrench swung at a
            -- running pump is answered with "The gas pump must be off
            -- first." rather than with silence.
            at = "off",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { gas_pump_fitting = 1 },
            start = "You start unfastening the pump.",
            done = "The pump comes up off the deck.",
        },
    },
}
