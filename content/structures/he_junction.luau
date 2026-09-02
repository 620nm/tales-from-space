-- A junction: the seam between a heat-exchange run and ordinary pipe.
--
-- tg's `/obj/machinery/atmospherics/pipe/heat_exchanging/junction`
-- (heat_exchange/junction.dm) -- "a one meter junction that connects
-- regular and heat-exchanging pipe".
--
-- Heat-exchanging pipe joins only heat-exchanging pipe (tg's
-- `HE_type_check`, he_pipes.dm:18-21), which is what makes a cooling
-- loop a closed circuit rather than a branch of the distribution main.
-- This is the piece that opens it: two mouths, one net across itself,
-- and the runs on either side stay the kinds they were. It is the
-- colour adapter's trick applied to the other half of a length's
-- identity, and it is the same engine primitive doing it.
--
-- EACH END TAKES ONE KIND, and `joins` is where that is said. tg spells
-- it as an override on `is_connectable` (junction.dm:30-33): the end at
-- `REVERSE_DIR(dir)` is type-checked as ORDINARY pipe -- "we want a
-- normal pipe instead" -- and the end at `dir` as this family. The
-- engine numbers the same two mouths back then front, back being the
-- one behind the facing, so the list below reads plain first and
-- heat-exchange second. `"pipe"` is the engine's own word for the
-- unauthored length every map is made of; the second is this pack's own
-- kind, named by the item that lays it.
--
-- SO IT HAS FOUR FACINGS where the colour adapter has two axes. Turn a
-- colour adapter around and it does exactly what it did; turn this
-- around and the two runs it was welding come apart, because the end
-- that takes heat-exchange pipe is now pointing at the main. tg aims it
-- and never normalises it, and neither does this.
--
-- IT CONDUCTS NOTHING. tg gives it `WALL_HEAT_TRANSFER_COEFFICIENT`,
-- which is 0.0 (__DEFINES/atmospherics/atmos_core.dm:119), behind a
-- 300 K deadband -- a heat-exchange fitting that is deliberately inert,
-- so the seam is a seam and not a radiator. Here it is a device rather
-- than a length, and a device holds gas without trading heat with the
-- deck at all, which lands in the same place.
--
-- Seventy litres, one length of ordinary pipe: tg gives a pipe
-- `UNARY_PIPE_VOLUME * device_type` and this has two ends
-- (pipes.dm:27-28).
return {
    id = "he_junction",
    name = "junction",
    sprite = "he_junction_s",
    dense = false,
    states = { "anchored" },
    facing_sprites = {
        anchored = {
            north = "he_junction_n",
            south = "he_junction_s",
            east = "he_junction_e",
            west = "he_junction_w",
        },
    },
    atmos = {
        device = "he_junction",
        -- Back mouth, then front. Back is behind the facing, which is
        -- tg's `REVERSE_DIR(dir)`: ordinary pipe. Front is the facing:
        -- heat-exchanging pipe.
        joins = { "pipe", "he_pipe" },
    },
    build = {
        on = { "floor", "plating" },
        from_item = "he_junction_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the junction down.",
        done = "The junction is bolted between the two runs.",
    },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { he_junction_fitting = 1 },
            start = "You start unfastening the junction.",
            done = "The junction comes up, and the two runs part.",
        },
    },
}
