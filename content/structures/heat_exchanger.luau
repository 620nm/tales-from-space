-- A plate heat exchanger: two of them, or none.
--
-- tg's `/obj/machinery/atmospherics/components/unary/heat_exchanger`
-- (components/unary_devices/heat_exchanger.dm) -- "exchanges heat
-- between two input gases. Set up for fast heat transfer."
--
-- One pipe behind it, one flat face pointing the other way, and by
-- itself it does nothing at all. Stand a second plate on the tile it
-- faces, facing back, and the two faces are pressed together: from that
-- moment the two runs behind them share a temperature, completely,
-- every tick. No dial, no switch, no power -- two pieces of metal
-- touching, which is exactly what it is.
--
-- That "completely, every tick" is the point. Everything else in the
-- kit that moves heat is throttled; this is the fast path, and it is
-- why a burn chamber's loop and a coolant loop are joined by a row of
-- these rather than by a pump. Neither loop's gas ever mixes with the
-- other -- the two nets stay two nets, which is what lets you run
-- plasma one side of a plate and nitrogen the other.
--
-- IT NEEDS A PARTNER AND IT SAYS SO BY DOING NOTHING. tg's `atmos_init`
-- looks one step past its own face for another exchanger looking back
-- (heat_exchanger.dm:37-49) and gives up quietly if there is none. A
-- single plate is not broken, it is half of a machine.
--
-- Unpowered, and tg says it twice: the unary base declares no
-- `use_power`, and the plate's `process_atmos` never asks whether it is
-- operational. It exchanges heat in the dark.
return {
    id = "heat_exchanger",
    name = "heat exchanger",
    sprite = "he_plate_n",
    dense = false,
    -- One state. A plate is bolted down or it is a fitting in your
    -- hands; there is nothing in between and nothing to switch.
    states = { "anchored" },
    facing_sprites = {
        -- The facing is the FACE -- the side that looks for a partner.
        -- The pipe is behind it, which is why these cells are tg's dirs
        -- reversed (see tfs/assets/sprites.ron).
        anchored = {
            north = "he_plate_n",
            south = "he_plate_s",
            east = "he_plate_e",
            west = "he_plate_w",
        },
    },
    atmos = {
        device = "heat_exchanger",
    },
    build = {
        on = { "floor", "plating" },
        from_item = "heat_exchanger_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the heat exchanger down.",
        done = "The heat exchanger is bolted to the deck, plate outward.",
    },
    transitions = {
        {
            -- `can_unwrench = TRUE` with no further guard
            -- (heat_exchanger.dm:8): there is no position to be in and
            -- nothing to turn off first.
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { heat_exchanger_fitting = 1 },
            start = "You start unfastening the heat exchanger.",
            done = "The heat exchanger comes up off the deck.",
        },
    },
}
