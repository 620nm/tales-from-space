-- A manual valve: a length of pipe with a wheel on it.
--
-- tg's `/obj/machinery/atmospherics/components/binary/valve`
-- (components/binary_devices/valve.dm). It is the simplest thing in
-- atmospherics and the one that teaches what the rest are: it draws no
-- power, it has no window, it has nothing to set. You turn the wheel,
-- and the two runs it sits between are either one body of gas or two.
--
-- The `atmos` block is that sentence to the engine. `device = "valve"`
-- means an OPEN one does not pump — it fuses (tg's
-- `custom_reconcilation`), so the two sides equalise by volume and a
-- valve is a decision about topology rather than a machine that runs.
-- Shutting it splits the gas back by what each side holds, to the mole.
--
-- One second to turn, which is tg's own (`addtimer(..., 1 SECONDS)`,
-- valve.dm:69), and it is the whole feel of the thing: an atmospherics
-- valve is a commitment, and you cannot spam the wheel out of it.
--
-- It is NOT dense. Atmospherics machinery lies in the deck at tg's
-- `GAS_PIPE_HIDDEN_LAYER` and inherits `/obj`'s density of false: you
-- walk over a valve, the way you walk over the pipe either side of it.
--
-- The two states are the two positions, and naming them here is what
-- gives the engine the words for both the picture and the sentence a
-- player is told ("The manual valve is open."). The engine supplies the
-- frame; every noun in it is from this file.
return {
    id = "manual_valve",
    name = "manual valve",
    sprite = "valve_shut_n",
    dense = false,
    states = { "shut", "open" },
    -- A binary device reaches along one axis, so north and south are
    -- one picture and east and west are the other -- tg's
    -- `PIPING_CARDINAL_AUTONORMALIZE` (valve.dm:14), whose art does not
    -- even ship a south cell.
    facing_sprites = {
        shut = {
            north = "valve_shut_n",
            south = "valve_shut_s",
            east = "valve_shut_e",
            west = "valve_shut_w",
        },
        open = {
            north = "valve_open_n",
            south = "valve_open_s",
            east = "valve_open_e",
            west = "valve_open_w",
        },
    },
    atmos = {
        device = "valve",
        positions = { "shut", "open" },
        switch_secs = 1.0,
    },
}
