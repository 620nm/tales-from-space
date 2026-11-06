-- A junction: the seam between a radiator run and ordinary pipe.
--
-- tg's `/obj/machinery/atmospherics/pipe/heat_exchanging/junction`
-- (heat_exchange/junction.dm) -- "a one meter junction that connects
-- regular and heat-exchanging pipe".
--
-- Radiator pipe joins only radiator pipe (tg's
-- `HE_type_check`, he_pipes.dm:18-21), which is what makes a cooling
-- loop a closed circuit rather than a branch of the distribution main.
-- This is the piece that opens it: two mouths, one net across itself,
-- and the runs on either side stay the kinds they were. It is the
-- color adapter's trick applied to the other half of a length's
-- identity, and it is the same engine primitive doing it.
--
-- EACH END TAKES ONE KIND, and `joins` is where that is said. The
-- engine calls the mechanism a KIND ADAPTER, because that is what it
-- does: the color adapter joins two paint jobs, this joins two kinds,
-- and heat exchange is what THIS station happens to use it for. tg spells
-- it as an override on `is_connectable` (junction.dm:30-33): the end at
-- `REVERSE_DIR(dir)` is type-checked as ORDINARY pipe -- "we want a
-- normal pipe instead" -- and the end at `dir` as this family. The
-- engine numbers the same two mouths back then front, back being the
-- one behind the facing, so the list below reads plain first and
-- radiator second. `"standard"` is the composition's ordinary
-- pipe kind; the second is this pack's own kind, named by the item that
-- lays it.
--
-- SO IT HAS FOUR FACINGS where the color adapter has two axes. Turn a
-- color adapter around and it does exactly what it did; turn this
-- around and the two runs it was welding come apart, because the end
-- that takes radiator pipe is now pointing at the main. tg aims it
-- and never normalizes it, and neither does this.
--
-- IT CONDUCTS NOTHING. tg gives it `WALL_HEAT_TRANSFER_COEFFICIENT`,
-- which is 0.0 (__DEFINES/atmospherics/atmos_core.dm:119), behind a
-- 300 K deadband -- a fitting that is deliberately inert,
-- so the seam is a seam and not a radiator. Here it is a device rather
-- than a length, and a device holds gas without trading heat with the
-- deck at all, which lands in the same place.
--
-- Seventy liters, one length of ordinary pipe: tg gives a pipe
-- `UNARY_PIPE_VOLUME * device_type` and this has two ends
-- (pipes.dm:27-28).
return {
    id = "radiator_junction",
    visual_layer = "pipe",
    name_label = "lunatic/tfs:entity.radiator_junction.name",
    name = "junction",
    sounds = { toggle = "click" },
    sprite = "radiator_junction_s",
    dense = false,
    states = { "anchored" },
    facing_sprites = {
        anchored = {
            north = "radiator_junction_n",
            south = "radiator_junction_s",
            east = "radiator_junction_e",
            west = "radiator_junction_w",
        },
    },
    atmos = {
        channel = "l3",
        network = "pipe",
        -- The engine's word for the mechanism, not for this fitting: an
        -- adapter whose two ends admit different KINDS, sibling of the
        -- one whose ends admit different colors.
        device = "kind_adapter",
        -- Back mouth, then front. Back is behind the facing, which is
        -- tg's `REVERSE_DIR(dir)`: ordinary pipe. Front is the facing:
        -- radiator pipe.
        joins = { "standard", "radiator_pipe" },
    },
    build = {
        sound = "smash",
        on = { "component:station_base" },
        from_item = "radiator_junction_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the junction down.",
        done = "The junction is bolted between the two runs.",
    },
    transitions = {
        {
            sound = "smash",
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { radiator_junction_fitting = 1 },
            start = "You start unfastening the junction.",
            done = "The junction comes up, and the two runs part.",
        },
    },
}
